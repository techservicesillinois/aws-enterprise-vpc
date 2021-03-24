# Singleton resources created once for the whole AWS account
#
# Copyright (c) 2017 Board of Trustees University of Illinois

terraform {
  # constrain minor version until 1.0 is released
  required_version = "~> 0.14.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 2.32"
    }
  }

  backend "s3" {
    region         = "us-east-2"
    dynamodb_table = "terraform"
    encrypt        = "true"

    # must be unique to your AWS account; try replacing
    # uiuc-tech-services-sandbox with the friendly name of your account
    bucket = "terraform.uiuc-tech-services-sandbox.aws.illinois.edu" #FIXME

    # must be unique (within bucket) to this repository + environment
    key = "Shared Networking/global/terraform.tfstate"
  }
}

## Inputs (specified in terraform.tfvars)

variable "account_id" {
  description = "Your 12-digit AWS account number"
  type        = string
}

variable "tags" {
  description = "Optional custom tags for all taggable resources"
  type        = map
  default     = {}
}

## Outputs

output "customer_gateway_ids" {
  value = {
    us-east-1 = module.cgw_us-east-1.customer_gateway_ids
    us-east-2 = module.cgw_us-east-2.customer_gateway_ids
  }
}

output "vpn_monitor_arn" {
  value = {
    us-east-2 = aws_sns_topic.vpn-monitor_us-east-2.arn
  }
}

## Providers

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"

  # avoid accidentally modifying the wrong AWS account
  allowed_account_ids = [var.account_id]
}

provider "aws" {
  alias  = "us-east-2"
  region = "us-east-2"

  # avoid accidentally modifying the wrong AWS account
  allowed_account_ids = [var.account_id]
}

## Resources

# Customer Gateways (per region, add more regions if needed)

module "cgw_us-east-1" {
  source = "git::https://github.com/techservicesillinois/aws-enterprise-vpc.git//modules/customer-gateways?ref=v0.10"

  tags = var.tags

  providers = {
    aws = "aws.us-east-1"
  }
}

module "cgw_us-east-2" {
  source = "git::https://github.com/techservicesillinois/aws-enterprise-vpc.git//modules/customer-gateways?ref=v0.10"

  tags = var.tags

  providers = {
    aws = "aws.us-east-2"
  }
}

# SNS topics for VPN monitoring alerts (add regions if needed).  Note that
# email subscriptions to a topic must be manual, per
# https://www.terraform.io/docs/providers/aws/r/sns_topic_subscription.html

resource "aws_sns_topic" "vpn-monitor_us-east-2" {
  provider = "aws.us-east-2"
  name     = "vpn-monitor-topic"
  tags     = var.tags
}

# Optional IAM Role (regionless) which can be used to publish Flow Logs to
# CloudWatch Logs, created here for convenience: see
# https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs-cwl.html

resource "aws_iam_role" "flow_logs_role" {
  provider    = "aws.us-east-2"
  tags        = var.tags
  name_prefix = "flow-logs-cwl-"
  description = "Use this role to create a Flow Log that publishes to CloudWatch Logs"

  assume_role_policy = <<EOT
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "vpc-flow-logs.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOT
}

resource "aws_iam_role_policy" "flow_logs_role_inline1" {
  # note: tags not supported
  provider    = "aws.us-east-2"
  name_prefix = "flow-logs-cwl-"
  role        = aws_iam_role.flow_logs_role.name

  policy = <<EOT
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOT
}
