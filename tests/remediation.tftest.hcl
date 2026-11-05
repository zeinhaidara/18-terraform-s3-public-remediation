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

run "exclusion_tag_can_be_disabled" {
  command = plan

  variables {
    exclusion_tag_key = ""
  }

  assert {
    condition     = aws_config_config_rule.s3_public_read_prohibited.scope[0].tag_key == null
    error_message = "Setting exclusion_tag_key to an empty string must disable the tag-based exemption."
  }
}
