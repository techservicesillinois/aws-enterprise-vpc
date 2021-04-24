# Creates a VPN Connection within an Enterprise VPC
#
# Copyright (c) 2017 Board of Trustees University of Illinois

terraform {
  required_version = ">= 0.15"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.35"
    }
  }
}

## Inputs

variable "name" {
  description = "tag:Name for this VPN Connection"
  type        = string
}

variable "vpn_gateway_id" {
  description = "VPN Gateway to use for this VPN connection, e.g. vgw-abcd1234"
  type        = string
  default     = null
}

# singleton list to work around computed count until https://github.com/hashicorp/terraform/issues/4149
variable "transit_gateway_id" {
  description = "Transit Gateway to use for this VPN connection (specify instead of vpn_gateway_id), e.g. tgw-abcd1234, wrapped in singleton list"
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.transit_gateway_id) < 2
    error_message = "Only one element allowed."
  }
}

variable "customer_gateway_id" {
  description = "Customer Gateway to connect to, e.g. cgw-abcd1234"
  type        = string
}

# explicit tunnel options if desired, see
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpn_connection
# https://docs.aws.amazon.com/vpn/latest/s2svpn/VPNTunnels.html
variable "tunnel1_inside_cidr" {
  type    = string
  default = null
}
variable "tunnel2_inside_cidr" {
  type    = string
  default = null
}

variable "create_alarm" {
  description = "Set true to create a CloudWatch Metric Alarm"
  type        = bool
  default     = false
}

# Each VPN Connection consists of two tunnels which originate from different
# AWS endpoints.  If you create an alarm which requires both tunnels to be UP,
# you will receive alarm notifications when one of the tunnels goes down (e.g.
# because Amazon is performing maintenance on that endpoint) even though the
# remaining tunnel is still up and the VPN Connection is still functional.
variable "alarm_requires_both_tunnels" {
  description = "Set true if *both* tunnels must be up for the alarm state to be OK"
  type        = bool
  default     = false
}

variable "alarm_actions" {
  description = "Optional list of actions (ARNs) to execute when the alarm transitions into an ALARM state from any other state, e.g. [arn:aws:sns:us-east-2:999999999999:vpn-monitor-topic]"
  type        = list(string)
  default     = []
}

variable "insufficient_data_actions" {
  description = "Optional list of actions (ARNs) to execute when the alarm transitions into an INSUFFICIENT_DATA state from any other state."
  type        = list(string)
  default     = []
}

variable "ok_actions" {
  description = "Optional list of actions (ARNs) to execute when the alarm transitions into an OK state from any other state."
  type        = list(string)
  default     = []
}

# see https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html#alarm-evaluation
variable "alarm_period" {
  type        = number
  default     = 60
}
variable "alarm_evaluation_periods" {
  type        = number
  default     = 2
}
variable "alarm_datapoints_to_alarm" {
  type        = number
  default     = 2
}

variable "tags" {
  description = "Optional custom tags for all taggable resources"
  type        = map
  default     = {}
}

variable "tags_vpn_connection" {
  description = "Optional custom tags for aws_vpn_connection resource"
  type        = map
  default     = {}
}

variable "tags_cloudwatch_metric_alarm" {
  description = "Optional custom tags for aws_cloudwatch_metric_alarm resource"
  type        = map
  default     = {}
}

## Outputs

output "vpn" {
  sensitive = true
  value     = aws_vpn_connection.vpn
}

output "id" {
  value = aws_vpn_connection.vpn.id
}

output "transit_gateway_attachment_id" {
  value = aws_vpn_connection.vpn.transit_gateway_attachment_id
}

output "customer_gateway_configuration" {
  sensitive = true
  value     = aws_vpn_connection.vpn.customer_gateway_configuration
}

## Resources

# VPN Connection

resource "aws_vpn_connection" "vpn" {
  tags = merge(var.tags, {
    Name = var.name
  }, var.tags_vpn_connection)

  vpn_gateway_id      = var.vpn_gateway_id
  transit_gateway_id  = try(var.transit_gateway_id[0], null)
  customer_gateway_id = var.customer_gateway_id
  type                = "ipsec.1"

  tunnel1_inside_cidr = var.tunnel1_inside_cidr
  tunnel2_inside_cidr = var.tunnel2_inside_cidr
}

# also tag implicitly-created TGW VPN Attachment if applicable
resource "aws_ec2_tag" "tgw_attachment" {
  for_each = { for k,v in merge(var.tags, {
    Name = var.name
  }, var.tags_vpn_connection)
  : k => v if length(var.transit_gateway_id) > 0 }

  resource_id = aws_vpn_connection.vpn.transit_gateway_attachment_id
  key         = each.key
  value       = each.value
}

# Optional CloudWatch Alarm based on VPN tunnel metrics; see also
# https://docs.aws.amazon.com/vpn/latest/s2svpn/monitoring-cloudwatch-vpn.html
#
# Empirically, TunnelState per VpnId drops from 1 to 0 when just one of the two
# tunnels goes down, so use TunnelState per TunnelIpAddress to distinguish
# between one tunnel down vs both tunnels down.

locals {
  alarm_threshold   = var.alarm_requires_both_tunnels ? 2 : 1
  alarm_description = "verify that ${var.alarm_requires_both_tunnels ? "both tunnels are" : "at least one tunnel is"} UP"
}

resource "aws_cloudwatch_metric_alarm" "vpnstatus" {
  count = var.create_alarm ? 1 : 0

  tags              = merge(var.tags, var.tags_cloudwatch_metric_alarm)
  alarm_name        = "${aws_vpn_connection.vpn.id} | ${var.name}"
  alarm_description = local.alarm_description

  metric_query {
    id          = "e1"
    return_data = "true"
    label       = "Tunnels in BGP ESTABLISHED state"
    expression  = "SUM([m1,m2])"
  }

  metric_query {
    id = "m1"

    metric {
      namespace   = "AWS/VPN"
      metric_name = "TunnelState"
      dimensions  = {
        TunnelIpAddress = aws_vpn_connection.vpn.tunnel1_address
      }

      stat   = "Minimum"
      period = var.alarm_period
    }
  }

  metric_query {
    id = "m2"

    metric {
      namespace   = "AWS/VPN"
      metric_name = "TunnelState"
      dimensions  = {
        TunnelIpAddress = aws_vpn_connection.vpn.tunnel2_address
      }

      stat   = "Minimum"
      period = var.alarm_period
    }
  }

  comparison_operator = "LessThanThreshold"
  threshold           = local.alarm_threshold
  treat_missing_data  = "missing"
  evaluation_periods  = var.alarm_evaluation_periods
  datapoints_to_alarm = var.alarm_datapoints_to_alarm

  alarm_actions             = var.alarm_actions
  insufficient_data_actions = var.insufficient_data_actions
  ok_actions                = var.ok_actions
}
