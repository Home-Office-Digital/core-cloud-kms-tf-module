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

run "key_rotation_enabled_by_default" {
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
    condition     = aws_kms_key.this.enable_key_rotation == true
    error_message = "Key rotation should be enabled by default."
  }
}

run "key_rotation_can_be_disabled" {
  command = plan

  variables {
    name                = "example"
    enable_key_rotation = false
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
    condition     = aws_kms_key.this.enable_key_rotation == false
    error_message = "Key rotation should be disabled when enable_key_rotation is false."
  }
}
