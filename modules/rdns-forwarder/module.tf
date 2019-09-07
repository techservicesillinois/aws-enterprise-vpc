# Terraform module to launch a Recursive DNS Forwarder
#
# Copyright (c) 2017 Board of Trustees University of Illinois

terraform {
  required_version = ">= 0.12.9"

  required_providers {
    aws = ">= 2.32"
  }
}

## Inputs

variable "instance_type" {
  description = "Type of EC2 instance to use for this RDNS Forwarder, e.g. t2.micro"
  type        = string
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
}

variable "zone_update_minute" {
  description = "Minute (between 0 and 59) to perform the hourly zone list update"
  type        = string
  default     = "0"
}

variable "full_update_day_of_month" {
  description = "Day of month (between 1 and 28) to perform the monthly full update"
  type        = string
  default     = "1"
}

variable "full_update_hour" {
  description = "Hour (between 0 and 23, note UTC) to perform the monthly full update"
  type        = string
  default     = "8"
}

variable "full_update_minute" {
  description = "Minute (between 0 and 59) to perform the monthly full update"
  type        = string
  default     = "17"
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
  default = "v0.9"
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

# Get the latest Amazon Linux AMI named e.g. amzn-ami-hvm-2016.09.1.20170119-x86_64-gp2
data "aws_ami" "ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-hvm-*-x86_64-gp2"]
  }
}

data "template_file" "user_data" {
  template = file("${path.module}/user_data.sh")

  vars = {
    vpc_cidr   = data.aws_vpc.selected.cidr_block
    amazon_dns = cidrhost(data.aws_vpc.selected.cidr_block,2)

    # format as YAML list
    forwarders_list          = join("\n", formatlist("  - %s", var.core_services_resolvers))
    ansible_logfile          = "/var/log/ansible.log"
    ansible_pull_url         = var.ansible_pull_url
    ansible_pull_checkout    = var.ansible_pull_checkout
    ansible_pull_directory   = "/root/aws-enterprise-vpc"
    zone_update_minute       = var.zone_update_minute
    full_update_day_of_month = var.full_update_day_of_month
    full_update_hour         = var.full_update_hour
    full_update_minute       = var.full_update_minute
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
  user_data                   = data.template_file.user_data.rendered

  lifecycle {
    # Avoids unnecessary destruction and recreation of the instance by Terraform
    # when a new release becomes available.  Note that yum update will still get
    # the latest packages regardless of which AMI we start from; see
    # http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AmazonLinuxAMIBasics.html#RepoConfig
    ignore_changes = ["ami"]
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
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  cidr_blocks       = [data.aws_vpc.selected.cidr_block]
}

resource "aws_security_group_rule" "allow_dns_tcp" {
  # note: tags not supported
  security_group_id = aws_security_group.rdns.id
  type              = "ingress"
  from_port         = 53
  to_port           = 53
  protocol          = "tcp"
  cidr_blocks       = [data.aws_vpc.selected.cidr_block]
}

resource "aws_security_group_rule" "allow_icmp" {
  # note: tags not supported
  security_group_id = aws_security_group.rdns.id
  type              = "ingress"
  from_port         = "-1"                                    # ICMP type number
  to_port           = "-1"                                    # ICMP code
  protocol          = "icmp"
  cidr_blocks       = [data.aws_vpc.selected.cidr_block]
}

# IAM Role

resource "aws_iam_instance_profile" "instance_profile" {
  # note: tags not supported
  name = aws_iam_role.role.name
  role = aws_iam_role.role.name
}

resource "aws_iam_role" "role" {
  # note: tags not supported
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

# Permit RDNS Forwarders to publish CloudWatch Logs
# http://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/QuickStartEC2Instance.html
resource "aws_iam_role_policy" "inline1" {
  # note: tags not supported
  name_prefix = "rdns-forwarder-"
  role        = aws_iam_role.role.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:logs:*:*:*"
      ]
    }
  ]
}
EOF
}
