variable "automatic_remediation" {
  description = "Whether Config auto-remediates non-compliant buckets instead of just flagging them."
  type        = bool
  default     = false
}

variable "remediation_max_attempts" {
  description = "Maximum automatic remediation attempts before giving up."
  type        = number
  default     = 5
}

variable "remediation_retry_seconds" {
  description = "Seconds to wait between remediation attempts."
  type        = number
  default     = 60
}

variable "exclusion_tag_key" {
  description = "Tag key used to exempt a bucket from this Config rule. Leave empty to disable exemptions."
  type        = string
  default     = "config-exempt"
}

variable "exclusion_tag_value" {
  description = "Tag value used to exempt a bucket from this Config rule."
  type        = string
  default     = "true"
}

variable "tags" {
  description = "Tags applied to the IAM role created for remediation."
  type        = map(string)
  default     = {}
}
