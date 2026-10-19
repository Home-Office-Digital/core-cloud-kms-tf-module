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

run "alias_derived_from_name" {
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
    condition     = aws_kms_alias.this.name == "alias/example"
    error_message = "Alias should default to alias/<name>."
  }
}

run "alias_name_override" {
  command = plan

  variables {
    name       = "example"
    alias_name = "custom"
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
    condition     = aws_kms_alias.this.name == "alias/custom"
    error_message = "A custom alias_name without a prefix should be normalised to alias/<alias_name>."
  }
}
