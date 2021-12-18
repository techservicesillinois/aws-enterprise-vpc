# Terraform module to launch a Recursive DNS Forwarder
#
# Copyright (c) 2017 Board of Trustees University of Illinois

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.35"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = ">= 2.2"
    }
  }
}

## Inputs

variable "instance_type" {
  description = "Type of EC2 instance to use for this RDNS Forwarder, e.g. t2.micro"
  type        = string
}

variable "instance_architecture" {
  description = "Architecture of the instance type ('x86_64', 'arm64')"
  type        = string
  default     = "x86_64"

  validation {
    condition     = contains(["x86_64", "arm64"], var.instance_architecture)
    error_message = "Must be one of: 'x86_64', 'arm64'."
  }
}

variable "subnet_id" {
  description = "Subnet in which to launch, e.g. subnet-abcd1234.  Using a public-facing subnet is simplest, but a campus-facing or private-facing subnet will also work as long as it has outbound Internet connectivity (via a NAT Gateway)"
  type        = string
}

# explicitly specifying private_ip helps minimize disruption to other services
# when we destroy and re-create the RDNS Forwarder later on
variable "private_ip" {
  description = "Private IPv4 address of this RDNS Forwarder (must be within the chosen subnet)"
  type        = string
}

variable "associate_public_ip_address" {
  description = "set false if subnet is not public-facing"
  type        = bool
  default     = true
}

variable "core_services_resolvers" {
  description = "IPv4 addresses of Core Services Resolvers to query for University domains"
  type        = list(string)

  validation {
    condition     = length(var.core_services_resolvers) > 0
    error_message = "Cannot be empty."
  }
}

variable "zone_update_minute" {
  description = "Minute (between 0 and 59) to perform the hourly zone list update"
  type        = string
  default     = "0"

  validation {
    condition     = var.zone_update_minute >= 0 && var.zone_update_minute <= 59
    error_message = "Valid range 0-59."
  }
}

variable "full_update_day_of_month" {
  description = "Day of month (between 1 and 28) to perform the monthly full update"
  type        = string
  default     = "1"

  validation {
    condition     = var.full_update_day_of_month == "*" || try(var.full_update_day_of_month >= 1 && var.full_update_day_of_month <= 28, false)
    error_message = "Valid range 1-28."
  }
}

variable "full_update_hour" {
  description = "Hour (between 0 and 23, note UTC) to perform the monthly full update"
  type        = string
  default     = "8"

  validation {
    condition     = var.full_update_hour == "*" || try(var.full_update_hour >= 0 && var.full_update_hour <= 23, false)
    error_message = "Valid range 0-23."
  }
}

variable "full_update_minute" {
  description = "Minute (between 0 and 59) to perform the monthly full update"
  type        = string
  default     = "17"

  validation {
    condition     = var.full_update_minute >= 0 && var.full_update_minute <= 59
    error_message = "Valid range 0-59."
  }
}

variable "create_alarm" {
  description = "Set true to create a CloudWatch Metric Alarm"
  type        = bool
  default     = false
}

variable "alarm_actions" {
  description = "Optional list of actions (ARNs) to execute when the alarm transitions into an ALARM state from any other state, e.g. [arn:aws:sns:us-east-2:999999999999:vpc-monitor-topic]"
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

variable "tags_instance" {
  description = "Optional custom tags for aws_instance resource"
  type        = map
  default     = {}
}

variable "tags_volume" {
  description = "Optional custom volume_tags for aws_instance resource"
  type        = map
  default     = {}
}

variable "tags_security_group" {
  description = "Optional custom tags for aws_security_group resource"
  type        = map
  default     = {}
}

variable "tags_iam_role" {
  description = "Optional custom tags for aws_iam_role resource"
  type        = map
  default     = {}
}

variable "tags_cloudwatch_metric_alarm" {
  description = "Optional custom tags for aws_cloudwatch_metric_alarm resource"
  type        = map
  default     = {}
}

variable "key_name" {
  description = "Optional Key Pair name (for SSH access)"
  type        = string
  default     = ""
}

# git repo URL and branch for ansible-pull (leave these default values alone
# for production deployments)

variable "ansible_pull_url" {
  default = "https://github.com/techservicesillinois/aws-enterprise-vpc.git"
}

variable "ansible_pull_checkout" {
  default = "v0.11"
}

## Outputs

output "id" {
  value = aws_instance.forwarder.id
}

output "private_ip" {
  value = aws_instance.forwarder.private_ip
}

output "security_group_id" {
  value = aws_security_group.rdns.id
}

## Resources

data "aws_subnet" "selected" {
  id = var.subnet_id
}

data "aws_vpc" "selected" {
  id = data.aws_subnet.selected.vpc_id
}

# fail fast if instance_type and instance_architecture are incompatible
data "aws_ec2_instance_type" "this" {
  instance_type = var.instance_type
}
locals {
  # workaround for lack of assertions https://github.com/hashicorp/terraform/issues/15469
  assert_architecture = contains(data.aws_ec2_instance_type.this.supported_architectures, var.instance_architecture) ? null : file("ERROR: mismatch between instance type '${var.instance_type}' and architecture '${var.instance_architecture}'")
}

# Get the latest Amazon Linux 2 AMI named e.g. amzn2-ami-hvm-2.0.20210326.0-x86_64-gp2
data "aws_ami" "ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-${var.instance_architecture}-gp2"]
  }
}

# User Data

data "cloudinit_config" "user_data" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/cloud-config.yml", {
      vpc_cidr   = data.aws_vpc.selected.cidr_block
      amazon_dns = cidrhost(data.aws_vpc.selected.cidr_block, 2)

      forwarders               = var.core_services_resolvers
      ansible_logfile          = "/var/log/ansible.log"
      ansible_pull_url         = var.ansible_pull_url
      ansible_pull_checkout    = var.ansible_pull_checkout
      ansible_pull_directory   = "/root/aws-enterprise-vpc"
      zone_update_minute       = var.zone_update_minute
      full_update_day_of_month = var.full_update_day_of_month
      full_update_hour         = var.full_update_hour
      full_update_minute       = var.full_update_minute

      # force instance replacement if this value changes
      instance_architecture = var.instance_architecture
    })
  }
}

# EC2 instance

resource "aws_instance" "forwarder" {
  tags                        = merge(var.tags, var.tags_instance)
  volume_tags                 = merge(var.tags, var.tags_volume)
  ami                         = data.aws_ami.ami.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  private_ip                  = var.private_ip
  associate_public_ip_address = var.associate_public_ip_address
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.rdns.id]
  iam_instance_profile        = aws_iam_instance_profile.instance_profile.name
  user_data_base64            = data.cloudinit_config.user_data.rendered

  lifecycle {
    # Avoids unnecessary destruction and recreation of the instance by
    # Terraform when a new AMI is released.  Note that yum update will still
    # get the latest packages regardless of which AMI we start from; see
    # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/amazon-linux-ami-basics.html#repository-config
    ignore_changes = [ami]
  }

  # However, do force replacement if instance_architecture changes.
  # Unfortunately depends_on doesn't actually achieve this (see
  # https://github.com/hashicorp/terraform/issues/8099), so our workaround is
  # to put instance_architecture in the user data (see above)
  depends_on = [ null_resource.instance_architecture ]
}

resource "null_resource" "instance_architecture" {
  triggers = {
    instance_architecture = var.instance_architecture
  }
}

# Security Group

resource "aws_security_group" "rdns" {
  tags        = merge(var.tags, var.tags_security_group)
  name_prefix = "rdns-"
  vpc_id      = data.aws_vpc.selected.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "allow_outbound" {
  # note: tags not supported
  security_group_id = aws_security_group.rdns.id
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_dns_udp" {
  # note: tags not supported
  security_group_id = aws_security_group.rdns.id
  type              = "ingress"
  protocol          = "udp"
  from_port         = 53
  to_port           = 53
  cidr_blocks       = [data.aws_vpc.selected.cidr_block]
}

resource "aws_security_group_rule" "allow_dns_tcp" {
  # note: tags not supported
  security_group_id = aws_security_group.rdns.id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 53
  to_port           = 53
  cidr_blocks       = [data.aws_vpc.selected.cidr_block]
}

resource "aws_security_group_rule" "allow_icmp" {
  # note: tags not supported
  security_group_id = aws_security_group.rdns.id
  type              = "ingress"
  protocol          = "icmp"
  from_port         = "-1" # ICMP type number
  to_port           = "-1" # ICMP code
  cidr_blocks       = [data.aws_vpc.selected.cidr_block]
}

# IAM Role

resource "aws_iam_instance_profile" "instance_profile" {
  # note: tags not supported
  name = aws_iam_role.role.name
  role = aws_iam_role.role.name
}

resource "aws_iam_role" "role" {
  tags        = merge(var.tags, var.tags_iam_role)
  name_prefix = "rdns-forwarder-"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# Permit RDNS Forwarders to publish CloudWatch Logs and Metrics
# https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/create-iam-roles-for-cloudwatch-agent-commandline.html
resource "aws_iam_role_policy_attachment" "CloudWatchAgentServerPolicy" {
  # note: tags not supported
  role       = aws_iam_role.role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Optional CloudWatch Alarm

resource "aws_cloudwatch_metric_alarm" "tx-NOERROR" {
  count = var.create_alarm ? 1 : 0

  tags              = merge(var.tags, var.tags_cloudwatch_metric_alarm)
  alarm_name        = "${lookup(var.tags, "Name", "rdns")} tx-NOERROR | ${aws_instance.forwarder.id}"
  alarm_description = "verify rdns-forwarder is answering at least some queries successfully"

  metric_query {
    id          = "e1"
    return_data = "true"
    label       = "DIFF(tx-NOERROR)"
    expression  = "IF(DIFF(m1)>=0,DIFF(m1),0)"
  }

  metric_query {
    id = "m1"

    metric {
      namespace   = "rdns-forwarder"
      metric_name = "collectd_bind_value"
      dimensions  = {
        InstanceId    = aws_instance.forwarder.id
        instance      = "global-server_stats"
        type          = "dns_rcode"
        type_instance = "tx-NOERROR"
      }

      stat   = "Maximum"
      period = var.alarm_period
    }
  }

  comparison_operator = "LessThanOrEqualToThreshold"
  threshold           = 0
  treat_missing_data  = "breaching"
  evaluation_periods  = var.alarm_evaluation_periods
  datapoints_to_alarm = var.alarm_datapoints_to_alarm

  alarm_actions             = var.alarm_actions
  insufficient_data_actions = var.insufficient_data_actions
  ok_actions                = var.ok_actions
}
