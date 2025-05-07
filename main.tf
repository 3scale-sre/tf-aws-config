## Label
module "config_label" {
  source      = "git@github.com:3scale-sre/tf-aws-label.git?ref=tags/0.1.2"
  project     = var.project
  environment = var.environment
  workload    = var.workload
  type        = "config"
  tf_config   = var.tf_config
}

## Config bucket
module "config_bucket" {
  source                  = "terraform-aws-modules/s3-bucket/aws"
  version                 = "v3.8.2"
  bucket                  = module.config_label.id
  acl                     = "private"
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  force_destroy           = true
  attach_policy           = true
  policy                  = data.aws_iam_policy_document.config_bucket_policy.json
  tags                    = module.config_label.tags
  versioning = {
    enabled = true
  }
}

data "aws_iam_policy_document" "config_bucket_policy" {
  statement {
    sid = "AWSConfigBucketPermissionsCheck"

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    actions = [
      "s3:GetBucketAcl",
    ]

    resources = [
      "arn:aws:s3:::${module.config_label.id}",
    ]
  }

  statement {
    sid = "AWSConfigBucketExistenceCheck"

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    actions = [
      "s3:ListBucket",
    ]

    resources = [
      "arn:aws:s3:::${module.config_label.id}",
    ]
  }

  statement {
    sid = "AWSConfigBucketDelivery"

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "arn:aws:s3:::${module.config_label.id}/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"

      values = [
        "bucket-owner-full-control",
      ]
    }
  }
}

## SNS
#resource "aws_sns_topic" "config" {
#  name = module.config_label.id
#}
#
#data "aws_iam_policy_document" "config_sns_policy" {
#  statement {
#    effect = "Allow"
#    principals {
#      type        = "AWS"
#      identifiers = [module.config.aws_config_role_arn]
#    }
#    actions   = ["SNS:Publish"]
#    resources = [aws_sns_topic.config.arn]
#  }
#}
#
#resource "aws_sns_topic_policy" "config" {
#  arn    = aws_sns_topic.config.arn
#  policy = data.aws_iam_policy_document.config_sns_policy.json
#}
#
#resource "aws_sns_topic_subscription" "email" {
#  topic_arn = aws_sns_topic.config.arn
#  protocol  = "email"
#  endpoint  = "var.email"
#}

## Config
module "config" {
  source             = "trussworks/config/aws"
  version            = "4.3.0"
  config_name        = module.config_label.id
  config_logs_bucket = module.config_bucket.s3_bucket_id
  #config_sns_topic_arn                     = aws_sns_topic.config.arn
  check_cloud_trail_encryption             = true
  check_cloud_trail_log_file_validation    = true
  check_multi_region_cloud_trail           = true
  check_guard_duty                         = true
  check_mfa_enabled_for_iam_console_access = true
  check_root_account_mfa_enabled           = true
  check_rds_public_access                  = true
  check_s3_bucket_ssl_requests_only        = false
  tags                                     = module.config_label.tags
}

# Delete all default rules from default SG of default VPC
resource "aws_default_vpc" "default" {
}

resource "aws_default_security_group" "default" {
  vpc_id = aws_default_vpc.default.id
}
