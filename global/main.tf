# Resources created once for the whole AWS account

terraform {
  required_version = ">= 0.9.1"

  backend "s3" {
    region     = "us-east-2"
    lock_table = "terraform"
    encrypt    = "true"

    # must be unique to your AWS account; try replacing
    # uiuc-tech-services-sandbox with the friendly name of your account
    bucket = "terraform.uiuc-tech-services-sandbox.aws.illinois.edu" #FIXME

    # must be unique (within bucket) to this repository + environment
    key = "Shared Networking/global/terraform.tfstate"
  }
}

## Inputs (specified in terraform.tfvars)

variable "region" {
  description = "AWS region for this VPC, e.g. us-east-2"
}

variable "account_id" {
  description = "Your 12-digit AWS account number"
}

## Outputs

output "customer_gateway_ids" {
  value = "${module.cgw.customer_gateway_ids}"
}

output "vpn_monitor_arn" {
  value = "${aws_sns_topic.vpn-monitor.arn}"
}

## Provider

provider "aws" {
  region = "${var.region}"

  # avoid accidentally modifying the wrong AWS account
  allowed_account_ids = ["${var.account_id}"]
}

# for vpn-monitor
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"

  # avoid accidentally modifying the wrong AWS account
  allowed_account_ids = ["${var.account_id}"]
}

# Customer Gateways

module "cgw" {
  #source = "git::https://git.cites.illinois.edu/ts-networking/aws-enterprise-vpc.git//modules/customer-gateways?ref=v0.6"
  source = "../modules/customer-gateways"
}

# Optional CloudWatch monitoring for VPN connections (in all regions): see
# https://aws.amazon.com/answers/networking/vpn-monitor/
#
# Always deploy this in us-east-1 to work around non-existence of S3 bucket
# solutions-builder-us-east-2.s3.amazonaws.com; see
# https://github.com/awslabs/aws-vpn-monitor/issues/1
#
# note: modules/vpn-connection contains a corresponding hard-coded provider
# field for creating CloudWatch alarms!
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
