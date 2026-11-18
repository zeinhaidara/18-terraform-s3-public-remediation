variable "automatic_remediation" {
  description = "Whether Config auto-remediates non-compliant buckets instead of just flagging them."
  type        = bool
  default     = false
}

# AWS Config RemediationConfiguration API limits:
# https://docs.aws.amazon.com/config/latest/APIReference/API_RemediationConfiguration.html
#   MaximumAutomaticAttempts: 1-25 (default 5)
#   RetryAttemptSeconds:      1-2678000 (default 60)
# The module only sends these when automatic_remediation = true.
variable "remediation_max_attempts" {
  description = "Maximum automatic remediation attempts within the retry window before Config adds a remediation exception (1-25). Ignored unless automatic_remediation is true."
  type        = number
  default     = 5

  validation {
    condition     = var.remediation_max_attempts == floor(var.remediation_max_attempts) && var.remediation_max_attempts >= 1 && var.remediation_max_attempts <= 25
    error_message = "remediation_max_attempts must be a whole number between 1 and 25 (AWS Config limit)."
  }
}

variable "remediation_retry_seconds" {
  description = "Time window in seconds in which remediation_max_attempts are counted (1-2678000). Ignored unless automatic_remediation is true."
  type        = number
  default     = 60

  validation {
    condition     = var.remediation_retry_seconds == floor(var.remediation_retry_seconds) && var.remediation_retry_seconds >= 1 && var.remediation_retry_seconds <= 2678000
    error_message = "remediation_retry_seconds must be a whole number between 1 and 2678000 (AWS Config limit)."
  }
}

variable "tags" {
  description = "Tags applied to the IAM role created for remediation."
  type        = map(string)
  default     = {}
}
