data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# Assumes an AWS Config configuration recorder and delivery channel already exist and
# record AWS::S3::Bucket. This module does not create them.
locals {
  # AWS-owned SSM Automation document (bucket-level Block Public Access). Parameters:
  # BucketName, AutomationAssumeRole, plus optional Block*/Restrict* flags (default true).
  remediation_document = "AWSConfigRemediation-ConfigureS3BucketPublicAccessBlock"

  # Retry settings are only sent when automatic remediation is on; they have no meaning
  # for report-only mode.
  max_attempts  = var.automatic_remediation ? var.remediation_max_attempts : null
  retry_seconds = var.automatic_remediation ? var.remediation_retry_seconds : null
}

resource "aws_iam_role" "remediation" {
  name = "config-s3-public-remediation"
  tags = var.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ssm.amazonaws.com" }
      Action    = "sts:AssumeRole"
      # Confused-deputy protection: only SSM Automation executions in this account.
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
        ArnLike = {
          "aws:SourceArn" = "arn:${data.aws_partition.current.partition}:ssm:*:${data.aws_caller_identity.current.account_id}:automation-execution/*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "remediation" {
  name = "s3-public-access-block"
  role = aws_iam_role.remediation.id

  # Resource "*" is deliberate: the buckets to remediate are not known at plan time, and
  # the two actions only read/write Block Public Access settings (no object access).
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetBucketPublicAccessBlock",
        "s3:PutBucketPublicAccessBlock",
      ]
      Resource = "*"
    }]
  })
}

resource "aws_config_config_rule" "s3_public_read_prohibited" {
  name = "s3-bucket-public-read-prohibited"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }

  scope {
    compliance_resource_types = ["AWS::S3::Bucket"]
  }
}

resource "aws_config_config_rule" "s3_public_write_prohibited" {
  name = "s3-bucket-public-write-prohibited"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_WRITE_PROHIBITED"
  }

  scope {
    compliance_resource_types = ["AWS::S3::Bucket"]
  }
}

resource "aws_config_remediation_configuration" "s3_public_read_prohibited" {
  config_rule_name = aws_config_config_rule.s3_public_read_prohibited.name
  resource_type    = "AWS::S3::Bucket"
  target_type      = "SSM_DOCUMENT"
  target_id        = local.remediation_document

  automatic                  = var.automatic_remediation
  maximum_automatic_attempts = local.max_attempts
  retry_attempt_seconds      = local.retry_seconds

  parameter {
    name         = "AutomationAssumeRole"
    static_value = aws_iam_role.remediation.arn
  }

  parameter {
    name           = "BucketName"
    resource_value = "RESOURCE_ID"
  }
}

resource "aws_config_remediation_configuration" "s3_public_write_prohibited" {
  config_rule_name = aws_config_config_rule.s3_public_write_prohibited.name
  resource_type    = "AWS::S3::Bucket"
  target_type      = "SSM_DOCUMENT"
  target_id        = local.remediation_document

  automatic                  = var.automatic_remediation
  maximum_automatic_attempts = local.max_attempts
  retry_attempt_seconds      = local.retry_seconds

  parameter {
    name         = "AutomationAssumeRole"
    static_value = aws_iam_role.remediation.arn
  }

  parameter {
    name           = "BucketName"
    resource_value = "RESOURCE_ID"
  }
}
