# This file supplies values for the variables defined in *.tf
#
# Copyright (c) 2017 Board of Trustees University of Illinois

# Your 12-digit AWS account number
account_id = "999999999999" #FIXME

# AWS region for this VPC, e.g. us-east-2
region = "us-east-2"

# short name of this VPC, e.g. "foobar1" if the full name is "aws-foobar1-vpc"
vpc_short_name = "foobar1" #FIXME

# entire IPv4 CIDR block allocated by Technology Services for this VPC
vpc_cidr_block = "192.0.2.0/24" #FIXME

# Request an Amazon-provided IPv6 CIDR block (/56) for this VPC?
assign_generated_ipv6_cidr_block = false

# Should new network interfaces on IPv6-enabled subnets automatically get IPv6 addresses?
assign_ipv6_address_on_creation = false

# By default we will create four Subnets: one public-facing and one
# campus-facing in each of two Availability Zones.
#
# Each subnet's cidr_block must be a subset of the overall vpc_cidr_block.
#
# Hint: use e.g. `ipcalc 192.0.2.0/24 26 --nobinary` to display all possible
# /26 subnets within your vpc_cidr_block, and
# `ipcalc 192.0.2.0/24 27 --nobinary` to display all possible /27 subnets.
# (http://jodies.de/ipcalc-archive/ipcalc-0.41/ipcalc)
#
# You are free to choose a combination of differently sized subnets, so long as
# the actual addresses don't overlap (i.e. the Broadcast address at the end of
# your first subnet must be smaller than the base Network address at the
# beginning of your second one, and so on).
#
# IPv6 subnet CIDRs are always /64, and will be calculated from the VPC's IPv6
# CIDR block once it is known.
#
# Note that you can't resize or renumber existing Subnets in AWS once you
# create them.  You _can_ delete and re-create them with Terraform, but they
# will need to be emptied of service-oriented resources first.
subnets_by_availability_zone_suffix = {
  a = {
    public1-a-net = {
      type       = "public"
      cidr_block = "192.0.2.0/27" #FIXME
      ipv6_index = 1 # xx01::/64
    }
    campus1-a-net = {
      type       = "campus"
      cidr_block = "192.0.2.32/27" #FIXME
      # ipv6 not supported
    }
    #private1-a-net = {
    #  type       = "private"
    #  cidr_block = "192.0.2.64/27" #FIXME
    #  ipv6_index = 3 # xx03::/64
    #}
  }
  b = {
    public1-b-net = {
      type       = "public"
      cidr_block = "192.0.2.128/27" #FIXME
      ipv6_index = 4 # xx04::/64
    }
    campus1-b-net = {
      type       = "campus"
      cidr_block = "192.0.2.160/27" #FIXME
      # ipv6 not supported
    }
    #private1-b-net = {
    #  type       = "private"
    #  cidr_block = "192.0.2.192/27" #FIXME
    #  ipv6_index = 6 # xx06::/64
    #}
  }
}

# Should this VPC attach to (and create routes toward) a Transit Gateway?
use_transit_gateway = true

# Specify one subnet per Availability Zone to be used for the Transit Gateway
# attachment (may be public-, campus-, or private-facing)
transit_gateway_attachment_subnets = {
  a = "public1-a-net"
  b = "public1-b-net"
}

# If you need private-facing subnets with outbound Internet access, specify one
# NAT gateway per availability zone (attached to a public-facing subnet).
nat_gateways = {
  #a = "public1-a-net"
  #b = "public1-b-net"
}

# Add VPC Peering Connection IDs here *after* the peering is created
#pcx_ids = ["pcx-abcd1234"]

# See rdns.tf for explanation, and be sure to read and understand
# [modules/rdns-forwarder/README.md] before deploying Option 3.
#rdns_option = 1

# IPv4 addresses of Core Services Resolvers reachable from this VPC
#core_services_resolvers = ["10.224.1.50", "10.224.1.100"]

# Interface VPC Endpoints for AWS services, not created by default since each
# interface incurs cost and consumes an IP address.  Specify the ones you need.
# The literal substring `{{REGION}}` will be replaced by var.region
#
# Hint: use `aws ec2 describe-vpc-endpoint-services` to find more service names
interface_vpc_endpoint_service_names = [
  #"com.amazonaws.{{REGION}}.ec2",
  #"com.amazonaws.{{REGION}}.ec2messages",
  #"com.amazonaws.{{REGION}}.elasticloadbalancing",
  #"com.amazonaws.{{REGION}}.kinesis-streams",
  #"com.amazonaws.{{REGION}}.kms",
  #"com.amazonaws.{{REGION}}.servicecatalog",
  #"com.amazonaws.{{REGION}}.sns",
  #"com.amazonaws.{{REGION}}.ssm",
]

# Specify one subnet per Availability Zone to be used for Interface VPC
# Endpoints (may be public-, campus-, or private-facing)
interface_vpc_endpoint_subnets = {
  a = "public1-a-net"
  b = "public1-b-net"
}

# Optional custom tags for all taggable resources
#tags = {
#  Contact = "example@illinois.edu"
#}

