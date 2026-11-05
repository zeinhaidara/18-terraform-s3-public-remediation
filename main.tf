data "aws_caller_identity" "current" {}

# assumes an AWS Config configuration recorder is already enabled in the account
locals {
  remediation_document = "AWSConfigRemediation-EnableS3BucketPublicAccessBlock"
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
    }]
  })
}

resource "aws_iam_role_policy" "remediation" {
  name = "s3-public-access-block"
  role = aws_iam_role.remediation.id

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
    tag_key                   = var.exclusion_tag_key != "" ? var.exclusion_tag_key : null
    tag_value                 = var.exclusion_tag_key != "" ? var.exclusion_tag_value : null
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
    tag_key                   = var.exclusion_tag_key != "" ? var.exclusion_tag_key : null
    tag_value                 = var.exclusion_tag_key != "" ? var.exclusion_tag_value : null
  }
}

resource "aws_config_remediation_configuration" "s3_public_read_prohibited" {
  config_rule_name = aws_config_config_rule.s3_public_read_prohibited.name
  resource_type    = "AWS::S3::Bucket"
  target_type      = "SSM_DOCUMENT"
  target_id        = local.remediation_document

  automatic                  = var.automatic_remediation
  maximum_automatic_attempts = var.remediation_max_attempts
  retry_attempt_seconds      = var.remediation_retry_seconds

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
  maximum_automatic_attempts = var.remediation_max_attempts
  retry_attempt_seconds      = var.remediation_retry_seconds

  parameter {
    name         = "AutomationAssumeRole"
    static_value = aws_iam_role.remediation.arn
  }

  parameter {
    name           = "BucketName"
    resource_value = "RESOURCE_ID"
  }
}
