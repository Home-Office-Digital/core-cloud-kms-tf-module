provider "aws" {
  region                      = "eu-west-2"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}

override_data {
  target = data.aws_caller_identity.current
  values = {
    account_id = "444455556666"
  }
}

override_data {
  target = data.aws_partition.current
  values = {
    partition = "aws"
  }
}

run "policy_contains_root_admin_statement" {
  command = plan

  variables {
    name = "example"
    cc_tags = {
      cost_centre      = "CC001"
      account_code     = "AC001"
      portfolio_id     = "PF001"
      project_id       = "PR001"
      service_id       = "SV001"
      environment_type = "test"
      owner_business   = "owner"
      budget_holder    = "holder"
    }
  }

  assert {
    condition     = strcontains(data.aws_iam_policy_document.key.json, "EnableIAMUserPermissions")
    error_message = "The key policy should contain the root admin statement Sid."
  }

  assert {
    condition     = strcontains(data.aws_iam_policy_document.key.json, "kms:*")
    error_message = "The root admin statement should grant kms:*."
  }

  assert {
    condition     = strcontains(data.aws_iam_policy_document.key.json, "arn:aws:iam::444455556666:root")
    error_message = "The root admin statement should reference the account root ARN."
  }

  assert {
    condition     = strcontains(data.aws_iam_policy_document.key.json, "aws:PrincipalAccount") && strcontains(data.aws_iam_policy_document.key.json, "444455556666")
    error_message = "The root admin statement should be constrained to the owning account via aws:PrincipalAccount."
  }
}

run "policy_contains_service_principal_grant" {
  command = plan

  variables {
    name                   = "example"
    key_service_principals = ["es.amazonaws.com"]
    cc_tags = {
      cost_centre      = "CC001"
      account_code     = "AC001"
      portfolio_id     = "PF001"
      project_id       = "PR001"
      service_id       = "SV001"
      environment_type = "test"
      owner_business   = "owner"
      budget_holder    = "holder"
    }
  }

  assert {
    condition     = strcontains(data.aws_iam_policy_document.key.json, "AllowServicePrincipals")
    error_message = "The key policy should contain the service principal statement Sid when a principal is supplied."
  }

  assert {
    condition     = strcontains(data.aws_iam_policy_document.key.json, "es.amazonaws.com")
    error_message = "The key policy should grant the supplied service principal."
  }

  assert {
    condition     = strcontains(data.aws_iam_policy_document.key.json, "aws:SourceAccount")
    error_message = "The service principal grant should be constrained to the owning account via aws:SourceAccount."
  }
}

run "key_users_receive_usage_permissions" {
  command = plan

  variables {
    name      = "users-example"
    key_users = ["arn:aws:iam::444455556666:role/key-user"]
    cc_tags = {
      cost_centre      = "CC001"
      account_code     = "AC001"
      portfolio_id     = "PF001"
      project_id       = "PR001"
      service_id       = "SV001"
      environment_type = "test"
      owner_business   = "owner"
      budget_holder    = "holder"
    }
  }

  assert {
    condition     = strcontains(data.aws_iam_policy_document.key.json, "AllowKeyUsage") && strcontains(data.aws_iam_policy_document.key.json, "kms:GenerateDataKey")
    error_message = "Key users should receive the cryptographic usage permissions."
  }
}

run "cross_account_key_user_is_scoped_to_its_own_account" {
  command = plan

  variables {
    name = "cross-account-user-example"
    # A user in a different account (123456789012) than the key owner
    # (444455556666). The condition must allow this account, not the owner's,
    # otherwise the grant is self-defeating.
    key_users = ["arn:aws:iam::123456789012:role/remote-user"]
    cc_tags = {
      cost_centre      = "CC001"
      account_code     = "AC001"
      portfolio_id     = "PF001"
      project_id       = "PR001"
      service_id       = "SV001"
      environment_type = "test"
      owner_business   = "owner"
      budget_holder    = "holder"
    }
  }

  assert {
    condition = try(toset(flatten([
      for statement in jsondecode(data.aws_iam_policy_document.key.json).Statement :
      statement.Condition.StringEquals["aws:PrincipalAccount"]
      if statement.Sid == "AllowKeyUsage"
    ])) == toset(["123456789012"]), false)
    error_message = "The key usage condition should be scoped to the supplied principal's account, not the owner account."
  }
}

run "administrator_can_replicate_multi_region_key" {
  command = plan

  variables {
    name               = "multi-region-example"
    multi_region       = true
    key_administrators = ["arn:aws:iam::444455556666:role/key-admin"]
    cc_tags = {
      cost_centre      = "CC001"
      account_code     = "AC001"
      portfolio_id     = "PF001"
      project_id       = "PR001"
      service_id       = "SV001"
      environment_type = "test"
      owner_business   = "owner"
      budget_holder    = "holder"
    }
  }

  assert {
    condition     = strcontains(data.aws_iam_policy_document.key.json, "kms:ReplicateKey")
    error_message = "Key administrators should be granted permission to replicate multi-region keys."
  }
}

run "policy_override_null_uses_generated_policy" {
  command = plan

  variables {
    name = "override-null-example"
    cc_tags = {
      cost_centre      = "CC001"
      account_code     = "AC001"
      portfolio_id     = "PF001"
      project_id       = "PR001"
      service_id       = "SV001"
      environment_type = "test"
      owner_business   = "owner"
      budget_holder    = "holder"
    }
  }

  # With no override, the key's policy must be exactly the generated document.
  # Compare decoded JSON so the assertion does not depend on formatting.
  assert {
    condition     = jsonencode(jsondecode(aws_kms_key.this.policy)) == jsonencode(jsondecode(data.aws_iam_policy_document.key.json))
    error_message = "With policy_override unset, the key policy should equal the generated policy document."
  }
}

run "policy_override_empty_uses_generated_policy" {
  command = plan

  variables {
    name            = "override-empty-example"
    policy_override = ""
    cc_tags = {
      cost_centre      = "CC001"
      account_code     = "AC001"
      portfolio_id     = "PF001"
      project_id       = "PR001"
      service_id       = "SV001"
      environment_type = "test"
      owner_business   = "owner"
      budget_holder    = "holder"
    }
  }

  # An empty-string override is treated as "no override" and must fall back to
  # the generated document, not set an empty policy.
  assert {
    condition     = jsonencode(jsondecode(aws_kms_key.this.policy)) == jsonencode(jsondecode(data.aws_iam_policy_document.key.json))
    error_message = "With an empty policy_override, the key policy should fall back to the generated policy document."
  }
}

run "policy_override_nonempty_replaces_generated_policy" {
  command = plan

  variables {
    name = "override-set-example"
    # A deliberately restrictive override: only the account root, no service or
    # user grants. If the module ignored the override or merged it with the
    # generated grants, this assertion would fail.
    policy_override = "{\"Version\":\"2012-10-17\",\"Id\":\"custom-override\",\"Statement\":[{\"Sid\":\"RootOnly\",\"Effect\":\"Allow\",\"Principal\":{\"AWS\":\"arn:aws:iam::444455556666:root\"},\"Action\":\"kms:*\",\"Resource\":\"*\"}]}"
    # Grants that must NOT appear in the effective policy when overridden.
    key_service_principals = ["es.amazonaws.com"]
    key_users              = ["arn:aws:iam::444455556666:role/key-user"]
    cc_tags = {
      cost_centre      = "CC001"
      account_code     = "AC001"
      portfolio_id     = "PF001"
      project_id       = "PR001"
      service_id       = "SV001"
      environment_type = "test"
      owner_business   = "owner"
      budget_holder    = "holder"
    }
  }

  # The effective policy must be exactly the supplied override document.
  assert {
    condition     = jsonencode(jsondecode(aws_kms_key.this.policy)) == jsonencode(jsondecode(var.policy_override))
    error_message = "A non-empty policy_override should replace the generated policy entirely."
  }

  # And must not have merged in the generated service-principal / user grants.
  assert {
    condition     = !strcontains(aws_kms_key.this.policy, "es.amazonaws.com") && !strcontains(aws_kms_key.this.policy, "AllowServicePrincipals")
    error_message = "An overridden policy must not include the generated service-principal grant."
  }
}

run "cross_account_key_administrator_is_rejected" {
  command = plan

  variables {
    name = "cross-account-admin-example"
    # Administrator in a different account than the key owner (444455556666).
    # KMS does not honour cross-account administration, so the precondition
    # must reject this rather than issue a misleading grant.
    key_administrators = ["arn:aws:iam::123456789012:role/remote-admin"]
    cc_tags = {
      cost_centre      = "CC001"
      account_code     = "AC001"
      portfolio_id     = "PF001"
      project_id       = "PR001"
      service_id       = "SV001"
      environment_type = "test"
      owner_business   = "owner"
      budget_holder    = "holder"
    }
  }

  expect_failures = [aws_kms_key.this]
}
