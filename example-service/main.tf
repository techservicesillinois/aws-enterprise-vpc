# Example environment to create service-oriented resources in an Enterprise VPC
#
# Copyright (c) 2017 Board of Trustees University of Illinois

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
    key = "FIXME/example-service/terraform.tfstate" #FIXME
  }
}

## Inputs (specified in terraform.tfvars)

variable "region" {
  description = "AWS region for this VPC, e.g. us-east-2"
}

variable "account_id" {
  description = "Your 12-digit AWS account number"
}

variable "vpc_short_name" {
  description = "The short name of your VPC, e.g. foobar if the full name is aws-foobar-vpc"
}

provider "aws" {
  region              = "${var.region}"
  allowed_account_ids = ["${var.account_id}"]
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
  vpc_id = "${data.aws_vpc.vpc.id}"

  tags = {
    Name = "${var.vpc_short_name}-public1-a-net"
  }
}

# launch an EC2 instance in the selected Subnet.  This serves no useful purpose
# except to illustrate how we supply the value for subnet_id (the AMI does
# nothing interesting on its own, and we have not provided ourselves with any
# means to connect to it)

resource "aws_instance" "example" {
  ami           = "ami-71ca9114"
  instance_type = "t2.nano"
  subnet_id     = "${data.aws_subnet.public1-a-net.id}"

  tags {
    Name = "useless-example-instance"
  }
}

# print out its IP addresses (including an auto-assigned public IP, since we
# put it in a public-facing subnet) just for fun

output "private_ip" {
  value = "${aws_instance.example.private_ip}"
}

output "public_ip" {
  value = "${aws_instance.example.public_ip}"
}
