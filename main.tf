data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

# Key policy. Every statement uses resources = ["*"], which in a KMS key policy
# means "the key this policy is attached to" — the only correct form for a key
# policy (an account/region key ARN pattern is for IAM policies, and scoping the
# root statement away from "*" risks KMS's policy-lockout safety check). To keep
# the wildcard-resource statements constrained — and to satisfy CKV_AWS_356,
# which requires a condition on such statements — each statement carries an
# account-scoping condition: aws:PrincipalAccount for the AWS-principal
# statements and aws:SourceAccount for the service-principal grant. This mirrors
# core-cloud-s3-tf-module's key policy.
data "aws_iam_policy_document" "key" {
  statement {
    sid       = "EnableIAMUserPermissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${local.account_id}:root"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalAccount"
      values   = [local.account_id]
    }
  }

  dynamic "statement" {
    for_each = length(var.key_administrators) > 0 ? [1] : []
    content {
      sid       = "AllowKeyAdministration"
      effect    = "Allow"
      actions   = local.administrator_actions
      resources = ["*"]

      principals {
        type        = "AWS"
        identifiers = var.key_administrators
      }

      # Administrators are same-account only: KMS does not honour cross-account
      # key administration even if the condition matched. The variable rejects
      # foreign ARNs, so scoping to the owning account is correct and keeps the
      # wildcard resource constrained (CKV_AWS_356).
      condition {
        test     = "StringEquals"
        variable = "aws:PrincipalAccount"
        values   = [local.account_id]
      }
    }
  }

  dynamic "statement" {
    for_each = length(var.key_users) > 0 ? [1] : []
    content {
      sid       = "AllowKeyUsage"
      effect    = "Allow"
      actions   = local.key_usage_actions
      resources = ["*"]

      principals {
        type        = "AWS"
        identifiers = var.key_users
      }

      # Scope to the accounts of the supplied user principals, so cross-account
      # users are honoured while the wildcard resource stays constrained
      # (CKV_AWS_356).
      condition {
        test     = "StringEquals"
        variable = "aws:PrincipalAccount"
        values   = local.user_accounts
      }
    }
  }

  dynamic "statement" {
    for_each = length(var.key_service_principals) > 0 ? [1] : []
    content {
      sid       = "AllowServicePrincipals"
      effect    = "Allow"
      actions   = local.key_usage_actions
      resources = ["*"]

      principals {
        type        = "Service"
        identifiers = var.key_service_principals
      }

      # Service principals carry no aws:PrincipalAccount, so scope by aws:SourceAccount.
      condition {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [local.account_id]
      }
    }
  }
}

resource "aws_kms_key" "this" {
  description             = var.name
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = var.enable_key_rotation
  is_enabled              = var.is_enabled
  multi_region            = var.multi_region
  policy                  = local.key_policy

  tags = merge(var.extra_tags, local.common_tags)

  lifecycle {
    # KMS does not honour cross-account key administration, so a foreign-account
    # key_administrators ARN would be granted by the policy but could never act.
    # Reject it rather than issue a misleading grant. The owning account is only
    # known here (via the data source), hence a precondition rather than a var
    # validation.
    precondition {
      condition     = alltrue([for arn in var.key_administrators : split(":", arn)[4] == local.account_id])
      error_message = "key_administrators must be in the key's own account (${local.account_id}); KMS does not support cross-account key administration. External administrators must assume a role in the owning account, or use policy_override."
    }
  }
}

resource "aws_kms_alias" "this" {
  name          = local.alias_name
  target_key_id = aws_kms_key.this.key_id
}
