# This file supplies values for the variables defined in main.tf
#
# Copyright (c) 2017 Board of Trustees University of Illinois

# AWS region (must be us-east-2 for an Enterprise VPC)
region = "us-east-2"

# Your 12-digit AWS account number
account_id = "999999999999" #FIXME

# The short name of your VPC, e.g. "foobar1" if the full name is "aws-foobar1-vpc"
vpc_short_name = "example" #FIXME

# Optional IPv4 CIDR blocks from which to allow ssh
#ssh_cidr_blocks = ["128.174.0.0/16", "130.126.0.0/16", "192.17.0.0/16", "10.192.0.0/10"]

# Optional SSH public key material
#ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2..."

