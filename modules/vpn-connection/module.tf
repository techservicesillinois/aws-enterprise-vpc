# Creates a VPN Connection within an Enterprise VPC
#
# Copyright (c) 2017 Board of Trustees University of Illinois

terraform {
  required_version = ">= 0.12.9"

  required_providers {
    aws = ">= 2.32"
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
}

variable "customer_gateway_id" {
  description = "Customer Gateway to connect to, e.g. cgw-abcd1234"
  type        = string
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

# Alarm must exist in same region as Metric, i.e. same region as global Lambda
provider "aws" {
  alias = "vpn_monitor"
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

output "id" {
  value = aws_vpn_connection.vpn.id
}

output "customer_gateway_configuration" {
  sensitive = true
  value     = aws_vpn_connection.vpn.customer_gateway_configuration
}

## Resources

# Get region of default provider

data "aws_region" "current" {}

# VPN Connection

resource "aws_vpn_connection" "vpn" {
  tags = merge(var.tags, {
    Name = var.name
  }, var.tags_vpn_connection)

  vpn_gateway_id      = var.vpn_gateway_id
  customer_gateway_id = var.customer_gateway_id
  type                = "ipsec.1"
}

# Optional CloudWatch Alarm based on Metric populated by
# https://docs.aws.amazon.com/solutions/latest/vpn-monitor/

locals {
  alarm_threshold   = var.alarm_requires_both_tunnels ? 2 : 1
  alarm_description = "verify that ${var.alarm_requires_both_tunnels ? "both tunnels are" : "at least one tunnel is"} UP"
}

resource "aws_cloudwatch_metric_alarm" "vpnstatus" {
  provider          = aws.vpn_monitor
  count             = var.create_alarm ? 1 : 0
  tags              = merge(var.tags, var.tags_cloudwatch_metric_alarm)
  alarm_name        = "${aws_vpn_connection.vpn.id} | ${var.name}"
  alarm_description = local.alarm_description
  namespace         = "VPNStatus"
  metric_name       = aws_vpn_connection.vpn.id

  dimensions = {
    CGW = var.customer_gateway_id
    VGW = var.vpn_gateway_id

    # data value indicating region of VPN connection, which may be
    # different from region of CloudWatch Metric
    Region = data.aws_region.current.name
  }

  statistic           = "Minimum"
  comparison_operator = "LessThanThreshold"
  threshold           = local.alarm_threshold
  period              = "300"
  evaluation_periods  = "2"

  alarm_actions             = var.alarm_actions
  insufficient_data_actions = var.insufficient_data_actions
  ok_actions                = var.ok_actions
}
