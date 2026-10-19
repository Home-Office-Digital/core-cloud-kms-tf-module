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

run "tags_render_correctly" {
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
    condition     = length(aws_kms_key.this.tags) == 8
    error_message = "The KMS key should have exactly 8 common tags."
  }

  assert {
    condition = jsonencode(aws_kms_key.this.tags) == jsonencode({
      cost-centre      = "CC001"
      account-code     = "AC001"
      portfolio-id     = "PF001"
      project-id       = "PR001"
      service-id       = "SV001"
      environment-type = "test"
      owner-business   = "owner"
      budget-holder    = "holder"
    })
    error_message = "The rendered tag map does not match the expected hyphenated keys and values."
  }
}

run "extra_tags_cannot_override_mandatory_tags" {
  command = plan

  variables {
    name = "example"
    extra_tags = {
      "cost-centre" = "OVERRIDE"
      "custom-tag"  = "custom-value"
    }
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
    condition     = aws_kms_key.this.tags["cost-centre"] == "CC001" && aws_kms_key.this.tags["custom-tag"] == "custom-value"
    error_message = "Mandatory tag values should be preserved while non-conflicting extra tags are retained."
  }
}
