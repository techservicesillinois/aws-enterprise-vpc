# Singleton resources created once for the whole AWS account
#
# Copyright (c) 2017 Board of Trustees University of Illinois

terraform {
  required_version = "~> 0.11"

  ## future (https://github.com/hashicorp/terraform/issues/16835)
  #required_providers {
  #  aws    = "~> 1.7"
  #}

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
}

## Outputs

output "customer_gateway_ids" {
  value = {
    us-east-1 = "${module.cgw_us-east-1.customer_gateway_ids}"
    us-east-2 = "${module.cgw_us-east-2.customer_gateway_ids}"
  }
}

output "vpn_monitor_arn" {
  value = "${aws_sns_topic.vpn-monitor.arn}"
}

## Providers

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"

  # avoid accidentally modifying the wrong AWS account
  allowed_account_ids = ["${var.account_id}"]

  # until https://github.com/hashicorp/terraform/issues/16835
  version = "~> 1.7"
}

provider "aws" {
  alias  = "us-east-2"
  region = "us-east-2"

  # avoid accidentally modifying the wrong AWS account
  allowed_account_ids = ["${var.account_id}"]

  # until https://github.com/hashicorp/terraform/issues/16835
  version = "~> 1.7"
}

## Resources

# Customer Gateways (per region, add more regions if needed)

module "cgw_us-east-1" {
  source = "git::https://github.com/cites-illinois/aws-enterprise-vpc.git//modules/customer-gateways?ref=v0.7"

  providers = {
    aws = "aws.us-east-1"
  }
}

module "cgw_us-east-2" {
  source = "git::https://github.com/cites-illinois/aws-enterprise-vpc.git//modules/customer-gateways?ref=v0.7"

  providers = {
    aws = "aws.us-east-2"
  }
}

# Optional CloudWatch monitoring for VPN connections (deployed in one region
# but monitors VPN connections in all regions): see
# https://docs.aws.amazon.com/solutions/latest/vpn-monitor/
resource "aws_cloudformation_stack" "vpn-monitor" {
  provider = "aws.us-east-1"
  name     = "vpn-monitor"

  parameters {
    # 5-minute interval
    CWEventSchedule = "cron(0/5 * * * ? *)"
  }

  template_url = "https://s3.amazonaws.com/solutions-reference/vpn-monitor/latest/vpn-monitor.template"
  capabilities = ["CAPABILITY_IAM"]
  on_failure   = "ROLLBACK"
}

# SNS topic for VPN monitoring alerts (same region as above).  Note that email
# subscriptions to this topic must be manual, per
# https://www.terraform.io/docs/providers/aws/r/sns_topic_subscription.html

resource "aws_sns_topic" "vpn-monitor" {
  provider = "aws.us-east-1"
  name     = "vpn-monitor-topic"
}
