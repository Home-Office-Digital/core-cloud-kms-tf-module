locals {
  common_tags = {
    cost-centre      = var.cc_tags.cost_centre
    account-code     = var.cc_tags.account_code
    portfolio-id     = var.cc_tags.portfolio_id
    project-id       = var.cc_tags.project_id
    service-id       = var.cc_tags.service_id
    environment-type = var.cc_tags.environment_type
    owner-business   = var.cc_tags.owner_business
    budget-holder    = var.cc_tags.budget_holder
  }

  # Owning account, used to scope the root-admin and service-principal
  # statements' conditions.
  account_id = data.aws_caller_identity.current.account_id

  # Accounts of the supplied key_users, parsed from their IAM ARNs
  # (arn:partition:iam::<account>:...). KMS honours cryptographic use (Encrypt,
  # Decrypt, GenerateDataKey, ...) cross-account, so the aws:PrincipalAccount
  # condition is scoped to the accounts actually granted — which both constrains
  # the wildcard resource (CKV_AWS_356) and allows cross-account users.
  #
  # key_administrators has no equivalent: KMS does not honour cross-account key
  # administration (PutKeyPolicy, ScheduleKeyDeletion, ...) even when the
  # condition matches, so administrators are constrained to the owning account
  # (var validation rejects foreign ARNs) and the admin statement uses
  # account_id directly.
  user_accounts = toset([for arn in var.key_users : split(":", arn)[4]])

  # Effective alias: derive from name when alias_name is not supplied, and
  # ensure the alias/ prefix is present either way.
  alias_input = var.alias_name == null ? var.name : var.alias_name
  alias_name  = startswith(local.alias_input, "alias/") ? local.alias_input : "alias/${local.alias_input}"

  # Administration actions granted to key_administrators. ReplicateKey is only
  # relevant, and only valid, for multi-region keys.
  administrator_actions = concat(
    [
      "kms:Create*",
      "kms:Describe*",
      "kms:Enable*",
      "kms:List*",
      "kms:Put*",
      "kms:Update*",
      "kms:Revoke*",
      "kms:Disable*",
      "kms:Get*",
      "kms:Delete*",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion",
    ],
    var.multi_region ? ["kms:ReplicateKey"] : []
  )

  # Cryptographic actions granted to key_users and key_service_principals.
  key_usage_actions = [
    "kms:Encrypt",
    "kms:Decrypt",
    "kms:ReEncrypt*",
    "kms:GenerateDataKey*",
    "kms:DescribeKey",
  ]

  # Effective key policy: the override wins when it is a non-empty string,
  # otherwise the generated policy document is used.
  key_policy = var.policy_override != null && var.policy_override != "" ? var.policy_override : data.aws_iam_policy_document.key.json
}
