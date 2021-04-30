# Example environment to create a fully-functional Enterprise VPC
#
# Copyright (c) 2017 Board of Trustees University of Illinois

terraform {
  # constrain minor version until 1.0 is released
  required_version = "~> 0.12.9"

  required_providers {
    aws  = "~> 2.32"
    null = "~> 2.1"
  }

  backend "s3" {
    region         = "us-east-2"
    dynamodb_table = "terraform"
    encrypt        = "true"

    # must be unique to your AWS account; try replacing
    # uiuc-tech-services-sandbox with the friendly name of your account
    bucket = "terraform.uiuc-tech-services-sandbox.aws.illinois.edu" #FIXME

    # must be unique (within bucket) to this repository + environment
    key = "Shared Networking/vpc/terraform.tfstate"
  }
}

## Read remote state from global environment

data "terraform_remote_state" "global" {
  backend = "s3"

  # must match ../global/main.tf
  config = {
    region = "us-east-2"
    bucket = "terraform.uiuc-tech-services-sandbox.aws.illinois.edu" #FIXME
    key    = "Shared Networking/global/terraform.tfstate"
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

variable "pcx_ids" {
  description = "Optional list of existing VPC Peering Connections (e.g. pcx-abcd1234) to use in routing tables"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Optional custom tags for all taggable resources"
  type        = map
  default     = {}
}

## Outputs

output "account_id" {
  value = var.account_id
}

output "vpc_short_name" {
  value = var.vpc_short_name
}

output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "vpc_cidr_block" {
  value = aws_vpc.vpc.cidr_block
}

output "vpc_region" {
  value = var.region
}

# note: additional outputs are specified in the VPN section below

## Providers

# default provider for chosen region
provider "aws" {
  region = var.region

  # avoid accidentally modifying the wrong AWS account
  allowed_account_ids = [var.account_id]
}

# explicit provider for us-east-2 (VPN connection monitoring)
provider "aws" {
  alias  = "us-east-2"
  region = "us-east-2"

  # avoid accidentally modifying the wrong AWS account
  allowed_account_ids = [var.account_id]
}

## Resources

# create the VPC

resource "aws_vpc" "vpc" {
  tags = merge(var.tags, {
    Name = "${var.vpc_short_name}-vpc"
  })

  # This is the entire IPv4 CIDR block allocated by Technology Services for
  # this Enterprise VPC
  cidr_block = "192.168.0.0/24" #FIXME

  enable_dns_support   = true
  enable_dns_hostnames = true

  # Comment this out if you really need to destroy your entire VPC.  Note: if
  # you subsequently recreate it, you will need to contact Technology Services
  # again to re-enable Enterprise Networking features for the new VPC.
  lifecycle {
    prevent_destroy = true
  }
}

# create the Internet Gateway

resource "aws_internet_gateway" "igw" {
  tags = merge(var.tags, {
    Name = "${var.vpc_short_name}-igw"
  })

  vpc_id = aws_vpc.vpc.id
}

# create a NAT Gateway in each Availability Zone
#
# Omit this section if your campus-facing and private-facing subnets do not
# require outbound Internet access.

module "nat-a" {
  source = "git::https://github.com/techservicesillinois/aws-enterprise-vpc.git//modules/nat-gateway?ref=v0.10"

  tags = merge(var.tags, {
    Name = "${var.vpc_short_name}-nat-a"
  })

  # this public-facing subnet is defined further down
  public_subnet_id = module.public1-a-net.id
}

module "nat-b" {
  source = "git::https://github.com/techservicesillinois/aws-enterprise-vpc.git//modules/nat-gateway?ref=v0.10"

  tags = merge(var.tags, {
    Name = "${var.vpc_short_name}-nat-b"
  })

  # this public-facing subnet is defined further down
  public_subnet_id = module.public1-b-net.id
}

# create a VPN Gateway with a VPN Connection to each of the Customer Gateways
# defined in the global environment
#
# Omit this section if you do not need any campus-facing subnets.

resource "aws_vpn_gateway" "vgw" {
  tags = merge(var.tags, {
    Name = "${var.vpc_short_name}-vgw"
  })

  amazon_side_asn = 64512
  vpc_id          = aws_vpc.vpc.id
}

module "vpn1" {
  source = "git::https://github.com/techservicesillinois/aws-enterprise-vpc.git//modules/vpn-connection?ref=v0.10"

  tags                = var.tags
  name                = "${var.vpc_short_name}-vpn1"
  vpn_gateway_id      = aws_vpn_gateway.vgw.id
  customer_gateway_id = data.terraform_remote_state.global.outputs.customer_gateway_ids[var.region]["vpnhub-aws1-pub"]
  create_alarm        = true

  alarm_actions             = [data.terraform_remote_state.global.outputs.vpn_monitor_arn]
  insufficient_data_actions = [data.terraform_remote_state.global.outputs.vpn_monitor_arn]
  ok_actions                = [data.terraform_remote_state.global.outputs.vpn_monitor_arn]

  providers = {
    aws.vpn_monitor = aws.us-east-2
  }
}

output "vpn1_customer_gateway_configuration" {
  sensitive = true
  value     = module.vpn1.customer_gateway_configuration
}

resource "null_resource" "vpn1" {
  triggers = {
    t = module.vpn1.id
  }

  # Comment this out if you really need to destroy the VPN connection.  Note: if
  # you subsequently recreate it, you will need to contact Technology Services
  # again to rebuild the on-campus configuration.
  lifecycle {
    prevent_destroy = true
  }
}

module "vpn2" {
  source = "git::https://github.com/techservicesillinois/aws-enterprise-vpc.git//modules/vpn-connection?ref=v0.10"

  tags                = var.tags
  name                = "${var.vpc_short_name}-vpn2"
  vpn_gateway_id      = aws_vpn_gateway.vgw.id
  customer_gateway_id = data.terraform_remote_state.global.outputs.customer_gateway_ids[var.region]["vpnhub-aws2-pub"]
  create_alarm        = true

  alarm_actions             = [data.terraform_remote_state.global.outputs.vpn_monitor_arn]
  insufficient_data_actions = [data.terraform_remote_state.global.outputs.vpn_monitor_arn]
  ok_actions                = [data.terraform_remote_state.global.outputs.vpn_monitor_arn]

  providers = {
    aws.vpn_monitor = aws.us-east-2
  }
}

output "vpn2_customer_gateway_configuration" {
  sensitive = true
  value     = module.vpn2.customer_gateway_configuration
}

resource "null_resource" "vpn2" {
  triggers = {
    t = module.vpn2.id
  }

  # Comment this out if you really need to destroy the VPN connection.  Note: if
  # you subsequently recreate it, you will need to contact Technology Services
  # again to rebuild the on-campus configuration.
  lifecycle {
    prevent_destroy = true
  }
}

# accept the specified VPC Peering Connections

resource "aws_vpc_peering_connection_accepter" "pcx" {
  for_each                  = toset(var.pcx_ids)
  tags                      = var.tags
  vpc_peering_connection_id = each.value
  auto_accept               = true
}

# waiting a few seconds for this to take effect enables subnets to handle new
# pcx routes successfully on the first try
resource "null_resource" "wait_for_vpc_peering_connection_accepter" {
  triggers = {
    t = join("", values(aws_vpc_peering_connection_accepter.pcx)[*].id)
  }

  # You may safely comment out this provisioner block if your workstation does
  # not have a sleep command; it just increases the likelihood that you will
  # encounter a transient AWS API error and have to re-run `terraform apply`.
  provisioner "local-exec" {
    command = "sleep 3"
  }
}

# create Subnets
#
# Each subnet's cidr_block must be a subset of the overall VPC cidr_block.
# Subnets do not need to be the same size; you can divide your IP allocation in
# whatever way best suits your needs.
#
# Note that you can't resize or renumber existing Subnets in AWS once you
# create them.  You _can_ delete and re-create them with Terraform by modifying
# this configuration code, but they will need to be emptied of service-oriented
# resources first.
#
# By default we will create six subnets: one of each type (public-facing,
# campus-facing, and private-facing) in each of two Availability Zones.  You
# can modify this section as desired to create more or fewer subnets, customize
# their names, etc.  If you add subnets, pay attention to each subnet's
# Availability Zone, and be sure to choose the correct NAT Gateway (if
# applicable).  Note that each type of subnet uses a separate Terraform module
# which accepts slightly different parameters.
#
# You can omit endpoint_ids and/or nat_gateway_id if you don't want your
# subnets to use those things.

module "public1-a-net" {
  source = "git::https://github.com/techservicesillinois/aws-enterprise-vpc.git//modules/public-facing-subnet?ref=v0.10"

  tags                = var.tags
  vpc_id              = aws_vpc.vpc.id
  name                = "${var.vpc_short_name}-public1-a-net"
  cidr_block          = "192.168.0.0/27" #FIXME
  availability_zone   = "${var.region}a"
  pcx_ids             = var.pcx_ids
  dummy_depends_on    = null_resource.wait_for_vpc_peering_connection_accepter.id
  endpoint_ids        = local.gateway_vpc_endpoint_ids
  endpoint_ids_keys   = local.gateway_vpc_endpoint_ids_keys
  internet_gateway_id = aws_internet_gateway.igw.id
}

module "public1-b-net" {
  source = "git::https://github.com/techservicesillinois/aws-enterprise-vpc.git//modules/public-facing-subnet?ref=v0.10"

  tags                = var.tags
  vpc_id              = aws_vpc.vpc.id
  name                = "${var.vpc_short_name}-public1-b-net"
  cidr_block          = "192.168.0.32/27" #FIXME
  availability_zone   = "${var.region}b"
  pcx_ids             = var.pcx_ids
  dummy_depends_on    = null_resource.wait_for_vpc_peering_connection_accepter.id
  endpoint_ids        = local.gateway_vpc_endpoint_ids
  endpoint_ids_keys   = local.gateway_vpc_endpoint_ids_keys
  internet_gateway_id = aws_internet_gateway.igw.id
}

module "campus1-a-net" {
  source = "git::https://github.com/techservicesillinois/aws-enterprise-vpc.git//modules/campus-facing-subnet?ref=v0.10"

  tags              = var.tags
  vpc_id            = aws_vpc.vpc.id
  name              = "${var.vpc_short_name}-campus1-a-net"
  cidr_block        = "192.168.0.64/27" #FIXME
  availability_zone = "${var.region}a"
  pcx_ids           = var.pcx_ids
  dummy_depends_on  = null_resource.wait_for_vpc_peering_connection_accepter.id
  endpoint_ids      = local.gateway_vpc_endpoint_ids
  endpoint_ids_keys = local.gateway_vpc_endpoint_ids_keys
  vpn_gateway_id    = aws_vpn_gateway.vgw.id
  nat_gateway_id    = module.nat-a.id
}

module "campus1-b-net" {
  source = "git::https://github.com/techservicesillinois/aws-enterprise-vpc.git//modules/campus-facing-subnet?ref=v0.10"

  tags              = var.tags
  vpc_id            = aws_vpc.vpc.id
  name              = "${var.vpc_short_name}-campus1-b-net"
  cidr_block        = "192.168.0.96/27" #FIXME
  availability_zone = "${var.region}b"
  pcx_ids           = var.pcx_ids
  dummy_depends_on  = null_resource.wait_for_vpc_peering_connection_accepter.id
  endpoint_ids      = local.gateway_vpc_endpoint_ids
  endpoint_ids_keys = local.gateway_vpc_endpoint_ids_keys
  vpn_gateway_id    = aws_vpn_gateway.vgw.id
  nat_gateway_id    = module.nat-b.id
}

module "private1-a-net" {
  source = "git::https://github.com/techservicesillinois/aws-enterprise-vpc.git//modules/private-facing-subnet?ref=v0.10"

  tags              = var.tags
  vpc_id            = aws_vpc.vpc.id
  name              = "${var.vpc_short_name}-private1-a-net"
  cidr_block        = "192.168.0.128/27" #FIXME
  availability_zone = "${var.region}a"
  pcx_ids           = var.pcx_ids
  dummy_depends_on  = null_resource.wait_for_vpc_peering_connection_accepter.id
  endpoint_ids      = local.gateway_vpc_endpoint_ids
  endpoint_ids_keys = local.gateway_vpc_endpoint_ids_keys
  nat_gateway_id    = module.nat-a.id
}

module "private1-b-net" {
  source = "git::https://github.com/techservicesillinois/aws-enterprise-vpc.git//modules/private-facing-subnet?ref=v0.10"

  tags              = var.tags
  vpc_id            = aws_vpc.vpc.id
  name              = "${var.vpc_short_name}-private1-b-net"
  cidr_block        = "192.168.0.160/27" #FIXME
  availability_zone = "${var.region}b"
  pcx_ids           = var.pcx_ids
  dummy_depends_on  = null_resource.wait_for_vpc_peering_connection_accepter.id
  endpoint_ids      = local.gateway_vpc_endpoint_ids
  endpoint_ids_keys = local.gateway_vpc_endpoint_ids_keys
  nat_gateway_id    = module.nat-b.id
}
