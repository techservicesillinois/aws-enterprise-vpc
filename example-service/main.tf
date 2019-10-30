# Example environment to create service-oriented resources in an Enterprise VPC
#
# Copyright (c) 2017 Board of Trustees University of Illinois

terraform {
  # constrain minor version until 1.0 is released
  required_version = "~> 0.12.9"

  required_providers {
    aws = "~> 2.32"
  }

  backend "s3" {
    region         = "us-east-2"
    dynamodb_table = "terraform"
    encrypt        = "true"

    # must be unique to your AWS account; try replacing
    # uiuc-tech-services-sandbox with the friendly name of your account
    bucket = "terraform.uiuc-tech-services-sandbox.aws.illinois.edu" #FIXME

    # must be unique (within bucket) to this repository + environment
    key = "FIXME/example-service/terraform.tfstate" #FIXME
  }
}

## Inputs (specified in terraform.tfvars)

variable "account_id" {
  description = "Your 12-digit AWS account number"
  type        = string
}

variable "region" {
  description = "AWS region for this VPC, e.g. us-east-2"
  type        = string
}

variable "vpc_short_name" {
  description = "The short name of your VPC, e.g. foobar1 if the full name is aws-foobar1-vpc"
  type        = string
}

variable "ssh_cidr_blocks" {
  description = "Optional IPv4 CIDR blocks from which to allow SSH"
  type        = list(string)
  default     = []
}

variable "ssh_public_key" {
  description = "Optional SSH public key material"
  type        = string
  default     = ""
}

## Outputs

output "private_ip" {
  value = aws_instance.example.private_ip
}

output "public_ip" {
  value = aws_instance.example.public_ip
}

## Providers

provider "aws" {
  region              = "${var.region}"
  allowed_account_ids = [var.account_id]
}

# Get the latest Amazon Linux AMI matching the specified name pattern

data "aws_ami" "ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-hvm-*-x86_64-gp2"]
  }
}

# look up VPC by tag:Name

data "aws_vpc" "vpc" {
  tags = {
    Name = "${var.vpc_short_name}-vpc"
  }
}

# look up Subnet (within the selected VPC, just in case several VPCs in your
# AWS account happen to have identically-named Subnets) by tag:Name

data "aws_subnet" "public1-a-net" {
  vpc_id = data.aws_vpc.vpc.id

  tags = {
    Name = "${var.vpc_short_name}-public1-a-net"
  }
}

# launch an EC2 instance in the selected Subnet

resource "aws_instance" "example" {
  ami                    = data.aws_ami.ami.id
  instance_type          = "t2.nano"
  subnet_id              = data.aws_subnet.public1-a-net.id
  vpc_security_group_ids = [aws_security_group.example.id]

  # use "null" to omit this argument if we didn't create an aws_key_pair
  key_name = length(aws_key_pair.example) > 0 ? aws_key_pair.example[0].key_name : null

  tags = {
    Name = "example-instance"
  }
}

# SSH Key Pair

resource "aws_key_pair" "example" {
  # only create this resource if ssh_public_key is specified
  count = var.ssh_public_key != "" ? 1 : 0

  key_name_prefix = "example-"
  public_key      = var.ssh_public_key
}

# Security Group

resource "aws_security_group" "example" {
  name_prefix = "example-"
  vpc_id      = data.aws_vpc.vpc.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "allow_outbound" {
  security_group_id = aws_security_group.example.id
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_ssh" {
  # only create this rule if ssh_cidr_blocks is specified
  count = length(var.ssh_cidr_blocks) > 0 ? 1 : 0

  security_group_id = aws_security_group.example.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.ssh_cidr_blocks
}
