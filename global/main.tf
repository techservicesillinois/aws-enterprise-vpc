# Resources created once for the whole AWS account

## Inputs (specified in terraform.tfvars)

variable "region" {
    description = "AWS region for this VPC, e.g. us-east-2"
}

variable "account_id" {
    description = "Your 12-digit AWS account number"
}



## Outputs

output "customer_gateway_ids" {
    value = {
        vpnhub-aws1-pub = "${aws_customer_gateway.vpnhub-aws1-pub.id}"
        vpnhub-aws2-pub = "${aws_customer_gateway.vpnhub-aws2-pub.id}"
    }
}

output "vpn_monitor_arn" {
    value = "${aws_sns_topic.vpn-monitor.arn}"
}



## Provider

provider "aws" {
    region = "${var.region}"
    # avoid accidentally modifying the wrong AWS account
    allowed_account_ids = [ "${var.account_id}" ]
}

# for vpn-monitor
provider "aws" {
    alias = "us-east-1"
    region = "us-east-1"
    # avoid accidentally modifying the wrong AWS account
    allowed_account_ids = [ "${var.account_id}" ]
}



# Customer Gateways
#
# Note: this may result in terraform taking over an existing cgw that was not
# originally created by terraform.  See
# https://github.com/hashicorp/terraform/issues/7492

resource "aws_customer_gateway" "vpnhub-aws1-pub" {
    tags {
        Name = "vpnhub-aws1-pub"
    }
    ip_address = "128.174.0.22"
    bgp_asn = 65044
    type = "ipsec.1"
}

resource "aws_customer_gateway" "vpnhub-aws2-pub" {
    tags {
        Name = "vpnhub-aws2-pub"
    }
    ip_address = "128.174.0.21"
    bgp_asn = 65044
    type = "ipsec.1"
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
    name = "vpn-monitor"
    parameters {
        # 5-minute interval
        CWEventSchedule = "cron(0/5 * * * ? *)"
    }
    template_url = "https://s3.amazonaws.com/solutions-reference/vpn-monitor/latest/vpn-monitor.template"
    capabilities = ["CAPABILITY_IAM"]
    on_failure = "ROLLBACK"
}

# SNS topic for VPN monitoring alerts (same region as above).  Note that email
# subscriptions to this topic must be manual, per
# https://www.terraform.io/docs/providers/aws/r/sns_topic_subscription.html

resource "aws_sns_topic" "vpn-monitor" {
    provider = "aws.us-east-1"
    name = "vpn-monitor-topic"
}
