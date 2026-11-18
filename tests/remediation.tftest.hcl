mock_provider "aws" {}

run "defaults_to_manual_remediation" {
  command = plan

  assert {
    condition     = aws_config_remediation_configuration.s3_public_read_prohibited.automatic == false
    error_message = "Remediation must default to manual (automatic = false) unless explicitly enabled."
  }
}

run "automatic_remediation_can_be_enabled" {
  command = plan

  variables {
    automatic_remediation = true
  }

  assert {
    condition     = aws_config_remediation_configuration.s3_public_write_prohibited.automatic == true
    error_message = "automatic_remediation = true must propagate to the remediation configuration."
  }
}

run "remediation_role_trusts_ssm_only" {
  command = plan

  assert {
    condition     = jsondecode(aws_iam_role.remediation.assume_role_policy).Statement[0].Principal.Service == "ssm.amazonaws.com"
    error_message = "Remediation role must only be assumable by the SSM service."
  }
}

run "remediation_targets_both_rules" {
  command = plan

  assert {
    condition     = aws_config_remediation_configuration.s3_public_read_prohibited.config_rule_name == aws_config_config_rule.s3_public_read_prohibited.name
    error_message = "Read-prohibited remediation must target the read-prohibited rule."
  }

  assert {
    condition     = aws_config_remediation_configuration.s3_public_write_prohibited.config_rule_name == aws_config_config_rule.s3_public_write_prohibited.name
    error_message = "Write-prohibited remediation must target the write-prohibited rule."
  }
}

run "config_rules_have_no_tag_scope" {
  command = plan

  # Config rule scope tag_key/tag_value INCLUDES only tagged resources; it cannot exclude.
  # The rules must therefore evaluate every bucket (no tag scope).
  assert {
    condition     = aws_config_config_rule.s3_public_read_prohibited.scope[0].tag_key == null && aws_config_config_rule.s3_public_read_prohibited.scope[0].tag_value == null
    error_message = "Read rule must not use a tag scope (it would evaluate only tagged buckets)."
  }

  assert {
    condition     = aws_config_config_rule.s3_public_write_prohibited.scope[0].tag_key == null && aws_config_config_rule.s3_public_write_prohibited.scope[0].tag_value == null
    error_message = "Write rule must not use a tag scope (it would evaluate only tagged buckets)."
  }

  assert {
    condition     = contains(aws_config_config_rule.s3_public_read_prohibited.scope[0].compliance_resource_types, "AWS::S3::Bucket")
    error_message = "Rules must be scoped to AWS::S3::Bucket."
  }
}

run "trust_policy_has_confused_deputy_conditions" {
  command = plan

  assert {
    condition     = jsondecode(aws_iam_role.remediation.assume_role_policy).Statement[0].Condition.StringEquals["aws:SourceAccount"] == data.aws_caller_identity.current.account_id
    error_message = "Trust policy must pin aws:SourceAccount to the current account."
  }

  assert {
    condition     = endswith(jsondecode(aws_iam_role.remediation.assume_role_policy).Statement[0].Condition.ArnLike["aws:SourceArn"], "automation-execution/*")
    error_message = "Trust policy must restrict aws:SourceArn to SSM automation executions."
  }
}

run "inline_policy_is_minimal" {
  command = plan

  assert {
    condition     = toset(jsondecode(aws_iam_role_policy.remediation.policy).Statement[0].Action) == toset(["s3:GetBucketPublicAccessBlock", "s3:PutBucketPublicAccessBlock"])
    error_message = "Inline policy must grant exactly Get/PutBucketPublicAccessBlock."
  }
}

run "remediation_uses_existing_ssm_document_and_parameters" {
  # apply against the mocked provider: the role ARN is unknown at plan time
  command = apply

  assert {
    condition     = aws_config_remediation_configuration.s3_public_read_prohibited.target_id == "AWSConfigRemediation-ConfigureS3BucketPublicAccessBlock" && aws_config_remediation_configuration.s3_public_write_prohibited.target_id == "AWSConfigRemediation-ConfigureS3BucketPublicAccessBlock"
    error_message = "Both remediations must target the AWS-owned ConfigureS3BucketPublicAccessBlock document."
  }

  assert {
    condition = alltrue([
      for p in aws_config_remediation_configuration.s3_public_read_prohibited.parameter :
      p.name == "AutomationAssumeRole" ? p.static_value == aws_iam_role.remediation.arn : (p.name == "BucketName" && p.resource_value == "RESOURCE_ID")
    ]) && length(aws_config_remediation_configuration.s3_public_read_prohibited.parameter) == 2
    error_message = "Parameters must be AutomationAssumeRole (role ARN) and BucketName (RESOURCE_ID)."
  }
}

run "retry_settings_omitted_when_report_only" {
  command = plan

  assert {
    condition     = aws_config_remediation_configuration.s3_public_read_prohibited.maximum_automatic_attempts == null && aws_config_remediation_configuration.s3_public_read_prohibited.retry_attempt_seconds == null
    error_message = "Retry settings must not be sent when automatic_remediation = false."
  }
}

run "retry_settings_sent_when_automatic" {
  command = plan

  variables {
    automatic_remediation     = true
    remediation_max_attempts  = 3
    remediation_retry_seconds = 120
  }

  assert {
    condition     = aws_config_remediation_configuration.s3_public_write_prohibited.maximum_automatic_attempts == 3 && aws_config_remediation_configuration.s3_public_write_prohibited.retry_attempt_seconds == 120
    error_message = "Retry settings must propagate when automatic_remediation = true."
  }
}

run "max_attempts_above_limit_rejected" {
  command = plan

  variables {
    remediation_max_attempts = 26
  }

  expect_failures = [var.remediation_max_attempts]
}

run "max_attempts_below_limit_rejected" {
  command = plan

  variables {
    remediation_max_attempts = 0
  }

  expect_failures = [var.remediation_max_attempts]
}

run "retry_seconds_above_limit_rejected" {
  command = plan

  variables {
    remediation_retry_seconds = 2678001
  }

  expect_failures = [var.remediation_retry_seconds]
}

run "retry_seconds_below_limit_rejected" {
  command = plan

  variables {
    remediation_retry_seconds = 0
  }

  expect_failures = [var.remediation_retry_seconds]
}
