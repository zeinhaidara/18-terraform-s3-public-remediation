output "remediation_role_arn" {
  description = "ARN of the IAM role SSM assumes to run the remediation document."
  value       = aws_iam_role.remediation.arn
}

output "config_rule_names" {
  description = "Names of the Config rules created by this module."
  value = [
    aws_config_config_rule.s3_public_read_prohibited.name,
    aws_config_config_rule.s3_public_write_prohibited.name,
  ]
}
