# Creates a VPN Connection within an Enterprise VPC

terraform {
    required_version = ">= 0.8.7"
}

variable "name" {
    description = "tag:Name for this VPN Connection"
}

variable "vpn_gateway_id" {
    description = "VPN Gateway to use for this VPN connection, e.g. vgw-abcd1234"
}

variable "customer_gateway_id" {
    description = "Customer Gateway to connect to, e.g. cgw-abcd1234"
}

variable "create_alarm" {
    description = "Set true to create a CloudWatch Metric Alarm"
    default = false
}

# Alarm must exist in same region as Metric, i.e. same region as global Lambda
#
# Unfortunately passing this in as a variable isn't currently supported (see
# https://github.com/hashicorp/terraform/issues/11578) so we have to hard-code
# it instead.
#variable "alarm_provider" {
#    description = "Optional provider (TYPE.ALIAS) for Alarm, e.g. aws.us-east-1"
#    default = "aws"
#}

# Unfortunately these generic list variables do not currently work
# (see https://github.com/hashicorp/terraform/issues/11453)
#variable "alarm_actions" {
#    description = "Optional list of actions (ARNs) to execute when the alarm transitions into an ALARM state from any other state, e.g. [arn:aws:sns:us-east-1:999999999999:vpn-monitor-topic]"
#    type = "list"
#    default = []
#}
#variable "insufficient_data_actions" {
#    description = "Optional list of actions (ARNs) to execute when the alarm transitions into an INSUFFICIENT_DATA state from any other state."
#    type = "list"
#    default = []
#}
#variable "ok_actions" {
#    description = "Optional list of actions (ARNs) to execute when the alarm transitions into an OK state from any other state."
#    type = "list"
#    default = []
#}
# so for now we accept a single ARN and add it to all three lists
variable "vpn_monitor_arn" {
    description = "SNS Topic for alarm to notify, e.g. arn:aws:sns:us-east-1:999999999999:vpn-monitor-topic"
    default = ""
}



output "id" {
    value = "${aws_vpn_connection.vpn.id}"
}

output "customer_gateway_configuration" {
    sensitive = true
    value = "${aws_vpn_connection.vpn.customer_gateway_configuration}"
}

# wrapped in here-document delimiters for parsing convenience
output "customer_gateway_configuration_heredoc" {
    sensitive = true
    value = "<<END_XML\n${aws_vpn_connection.vpn.customer_gateway_configuration}\nEND_XML"
}



# Get region of default provider

data "aws_region" "current" {
  current = true
}

# VPN Connection

resource "aws_vpn_connection" "vpn" {
    tags {
        Name = "${var.name}"
    }
    vpn_gateway_id = "${var.vpn_gateway_id}"
    customer_gateway_id = "${var.customer_gateway_id}"
    type = "ipsec.1"
}

# Optional CloudWatch Alarm based on Metric populated by
# https://aws.amazon.com/answers/networking/vpn-monitor/

resource "aws_cloudwatch_metric_alarm" "vpnstatus" {
    #provider = "${var.alarm_provider}"
    provider = "aws.us-east-1"
    count = "${var.create_alarm ? 1 : 0}"
    alarm_name = "${aws_vpn_connection.vpn.id} | ${var.name}"
    alarm_description = "verify that both tunnels are UP"
    namespace = "VPNStatus"
    metric_name = "${aws_vpn_connection.vpn.id}"
    dimensions = {
        CGW = "${var.customer_gateway_id}"
        VGW = "${var.vpn_gateway_id}"
	# data value indicating region of VPN connection, which may be
        # different from region of CloudWatch Metric
        Region = "${data.aws_region.current.name}"
    }
    statistic = "Minimum"
    comparison_operator = "LessThanThreshold"
    threshold = "2"
    period = "300"
    evaluation_periods = "2"
    #alarm_actions = "${var.alarm_actions}"
    #insufficient_data_actions = "${var.insufficient_data_actions}"
    #ok_actions = "${var.ok_actions}"
    alarm_actions = ["${var.vpn_monitor_arn}"]
    insufficient_data_actions = ["${var.vpn_monitor_arn}"]
    ok_actions = ["${var.vpn_monitor_arn}"]
}
