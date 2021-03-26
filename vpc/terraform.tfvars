# This file supplies values for the variables defined in main.tf
#
# Copyright (c) 2017 Board of Trustees University of Illinois

# Your 12-digit AWS account number
account_id = "999999999999" #FIXME

# AWS region for this VPC, e.g. us-east-2
region = "us-east-2"

# The short name of your VPC, e.g. "foobar1" if the full name is "aws-foobar1-vpc"
vpc_short_name = "example" #FIXME

# Should this VPC attach to (and create routes toward) a Transit Gateway?
use_transit_gateway = true

# Add VPC Peering Connection IDs here *after* the peering is created
#pcx_ids = ["pcx-abcd1234"]

# IPv4 addresses of Core Services Resolvers in your peer Core Services VPC
#core_services_resolvers = ["10.224.1.50", "10.224.1.100"]

# Optional custom tags for all taggable resources
#tags = {
#  Contact = "example@illinois.edu"
#}

