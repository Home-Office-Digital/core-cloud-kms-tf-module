# core-cloud-kms-tf-module

A Core Cloud Terraform child module that creates a customer-managed AWS KMS key
with automatic key rotation enabled by default, a configurable key policy, and a
KMS alias. The module exposes the key ARN/ID and alias ARN/name so consuming
modules take an existing key ARN rather than creating their own key.

## Overview

The module creates a single `aws_kms_key` and a single `aws_kms_alias`. The key
policy is generated from an `aws_iam_policy_document` that always grants the
account root full administrative access and optionally grants administration,
usage, and service-principal permissions based on the inputs provided. A full
JSON policy string can be supplied via `policy_override` to replace the generated
policy entirely.

The account-root principal statement enables IAM policies in this account to
delegate KMS permissions; it does not directly grant every IAM identity access.
Treat `key_administrators` as highly trusted principals: their policy-management
permissions can change who may use the key, and tag changes can affect ABAC
controls. Prefer tightly controlled administrative roles and keep application
roles in `key_users`.

Direct `key_service_principals` grants have no source-resource condition. Where
the integration supports `aws:SourceArn` and/or `aws:SourceAccount` conditions,
prefer a complete `policy_override` that includes them. Review overridden
policies carefully to preserve the intended recovery/admin path.

## Requirements

| Name      | Version   |
|-----------|-----------|
| terraform | >= 1.7.5  |
| aws       | ~> 6.66   |

## Usage

```hcl
module "kms" {
  source = "git::https://github.com/Home-Office-Digital/core-cloud-kms-tf-module.git?ref=1.0.0"

  name = "my-service-key"

  # Optional: grant an AWS service principal usage of the key
  key_service_principals = ["es.amazonaws.com"]

  # Optional: create a multi-region key (defaults to false)
  multi_region = false

  # Optional: replace the generated policy entirely with a full JSON document
  # policy_override = file("${path.module}/custom-key-policy.json")

  cc_tags = {
    cost_centre      = "CC001"
    account_code     = "AC001"
    portfolio_id     = "PF001"
    project_id       = "PR001"
    service_id       = "SV001"
    environment_type = "production"
    owner_business   = "my-business-owner"
    budget_holder    = "my-budget-holder"
  }
}
```

## Providers

| Name | Version |
|------|---------|
| aws  | ~> 6.66 |

## Resources

| Name | Type |
|------|------|
| `aws_kms_key.this` | resource |
| `aws_kms_alias.this` | resource |
| `aws_caller_identity.current` | data source |
| `aws_partition.current` | data source |
| `aws_iam_policy_document.key` | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `name` | Name of the KMS key. Used to derive the default alias (`alias/<name>`) and the key description. | `string` | n/a | yes |
| `cc_tags` | Core Cloud mandatory tagging object. Each attribute is mapped to its hyphenated tag key and applied to the KMS key. | `object({ cost_centre = string, account_code = string, portfolio_id = string, project_id = string, service_id = string, environment_type = string, owner_business = string, budget_holder = string })` | n/a | yes |
| `enable_key_rotation` | Whether automatic annual rotation of the KMS key material is enabled. | `bool` | `true` | no |
| `deletion_window_in_days` | Number of days before the key is deleted after being scheduled for deletion. Must be between 7 and 30. | `number` | `30` | no |
| `is_enabled` | Whether the KMS key is enabled. | `bool` | `true` | no |
| `multi_region` | Whether the KMS key is a multi-region key. | `bool` | `false` | no |
| `alias_name` | Alias for the KMS key. When `null` the alias is derived as `alias/<name>`. The `alias/` prefix is added automatically if omitted. | `string` | `null` | no |
| `key_administrators` | List of IAM ARNs granted key administration permissions in the generated key policy. | `list(string)` | `[]` | no |
| `key_users` | List of IAM ARNs granted key usage (cryptographic) permissions in the generated key policy. | `list(string)` | `[]` | no |
| `key_service_principals` | List of AWS service principals (for example `["es.amazonaws.com"]`) granted key usage permissions in the generated key policy. | `list(string)` | `[]` | no |
| `policy_override` | Full JSON key policy string. When set to a non-empty string this replaces the generated key policy entirely. | `string` | `null` | no |
| `extra_tags` | Additional tags applied to the KMS key. Core Cloud mandatory tags take precedence if keys overlap. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `key_arn` | The ARN of the KMS key. |
| `key_id` | The globally unique identifier of the KMS key. |
| `key_alias_arn` | The ARN of the KMS alias. |
| `alias_name` | The display name of the KMS alias (`alias/<name>`). |
