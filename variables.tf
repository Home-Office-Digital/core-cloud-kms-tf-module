variable "name" {
  description = "Name of the KMS key. Used to derive the default alias (alias/<name>) and the key description."
  type        = string
}

variable "cc_tags" {
  description = "Core Cloud mandatory tagging object. Each attribute is mapped to its hyphenated tag key and applied to the KMS key."
  type = object({
    cost_centre      = string
    account_code     = string
    portfolio_id     = string
    project_id       = string
    service_id       = string
    environment_type = string
    owner_business   = string
    budget_holder    = string
  })
  nullable = false
}

variable "enable_key_rotation" {
  description = "Whether automatic annual rotation of the KMS key material is enabled."
  type        = bool
  default     = true
}

variable "deletion_window_in_days" {
  description = "Number of days before the key is deleted after being scheduled for deletion. Must be between 7 and 30."
  type        = number
  default     = 30
  validation {
    condition     = var.deletion_window_in_days >= 7 && var.deletion_window_in_days <= 30
    error_message = "deletion_window_in_days must be between 7 and 30 inclusive."
  }
}

variable "is_enabled" {
  description = "Whether the KMS key is enabled."
  type        = bool
  default     = true
}

variable "multi_region" {
  description = "Whether the KMS key is a multi-region key."
  type        = bool
  default     = false
}

variable "alias_name" {
  description = "Alias for the KMS key. When null the alias is derived as alias/<name>. The alias/ prefix is added automatically if omitted."
  type        = string
  default     = null
}

variable "key_administrators" {
  description = "List of IAM ARNs granted key administration permissions in the generated key policy. Must be in the key's own account: KMS does not honour cross-account key administration, so external administrators must assume a role in the owning account. Use policy_override for bespoke arrangements."
  type        = list(string)
  default     = []

  # The owning account is only known at apply time, so the cross-account check
  # lives in a lifecycle precondition on aws_kms_key.this rather than here. This
  # validation only enforces well-formed IAM ARNs.
  validation {
    condition     = alltrue([for arn in var.key_administrators : can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:", arn))])
    error_message = "key_administrators must be IAM ARNs (arn:aws:iam::<account-id>:...)."
  }
}

variable "key_users" {
  description = "List of IAM ARNs granted key usage (cryptographic) permissions in the generated key policy."
  type        = list(string)
  default     = []
}

variable "key_service_principals" {
  description = "List of AWS service principals (for example es.amazonaws.com) granted key usage permissions in the generated policy."
  type        = list(string)
  default     = []
}

variable "policy_override" {
  description = "Full JSON key policy string. When set to a non-empty string this REPLACES the generated key policy entirely."
  type        = string
  default     = null
}

variable "extra_tags" {
  description = "Additional tags applied to the KMS key. Core Cloud mandatory tags take precedence if keys overlap."
  type        = map(string)
  default     = {}
}
