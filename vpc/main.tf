# Example environment to create a fully-functional Enterprise VPC
#
# Copyright (c) 2017 Board of Trustees University of Illinois

terraform {
  required_version = "~> 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.38"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.1"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.2"
    }
  }

  # see backend.tf for remote state configuration
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
  description = "short name of this VPC, e.g. foobar1 if the full name is aws-foobar1-vpc"
  type        = string
}

variable "vpc_cidr_block" {
  description = "entire IPv4 CIDR block allocated by Technology Services for this VPC"
  type        = string
}

variable "assign_generated_ipv6_cidr_block" {
  description = "Request an Amazon-provided IPv6 CIDR block (/56) for this VPC?"
  type        = bool
  default     = false
}

variable "assign_ipv6_address_on_creation" {
  description = "Should new network interfaces on IPv6-enabled subnets automatically get IPv6 addresses?"
  type        = bool
  default     = false
}

variable "subnets_by_availability_zone_suffix" {
  description = "Maps availability zone suffix (e.g. 'a' for us-east-2a) to subnet key to subnet details"
  type        = map
}

variable "use_transit_gateway" {
  description = "Should this VPC attach to (and create routes toward) a Transit Gateway?"
  type        = bool
  default     = false
}

variable "transit_gateway_id" {
  description = "Optionally specify *which* Transit Gateway (e.g. tgw-abcd1234)"
  type        = string
  # common case: exactly one Transit Gateway is available in the region (shared
  # with your AWS account via Resource Access Manager), so we can choose that
  # one automatically
  default     = null
}

variable "transit_gateway_attachment_subnets" {
  description = "Specify one subnet per Availability Zone to be used for the Transit Gateway attachment (may be public-, campus-, or private-facing).  Maps availability zone suffix (e.g. 'a' for us-east-2a) to subnet key"
  type        = map(string)
  default     = {}
}

variable "use_dedicated_vpn" {
  description = "Should this VPC create dedicated VPN connections?  (note: this solution is deprecated in favor of Transit Gateway)"
  type        = bool
  default     = false
}

variable "nat_gateways" {
  description = "Optionally specify one NAT gateway per Availability Zone (attached to a public-facing subnet).  Maps availability zone suffix (e.g. 'a' for us-east-2a) to subnet key"
  type        = map(string)
  default     = {}
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

output "aws-enterprise-vpc_version" {
  value = "v0.11"
}

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

output "vpc_ipv6_cidr_block" {
  value = aws_vpc.vpc.ipv6_cidr_block
}

output "tgw_attachment" {
  value = var.use_transit_gateway ? aws_ec2_transit_gateway_vpc_attachment.tgw_attach[0].id : null
}

output "vpc_region" {
  value = var.region
}

## Providers

# default provider for chosen region
provider "aws" {
  region = var.region

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
  cidr_block = var.vpc_cidr_block

  # Request an Amazon-provided IPv6 CIDR block (/56) for this VPC?
  assign_generated_ipv6_cidr_block = var.assign_generated_ipv6_cidr_block

  enable_dns_support   = true
  enable_dns_hostnames = true

  # Comment this out if you really need to destroy your entire VPC.  Note that
  # if you subsequently recreate it, you will need to contact Technology
  # Services again to re-enable Enterprise Networking features for the new VPC.
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

# create attachment to Transit Gateway

data "aws_ec2_transit_gateway" "tgw" {
  count = var.use_transit_gateway ? 1 : 0

  # NB: var can be null if we only have one TGW in the region
  id = var.transit_gateway_id
}

resource "aws_ec2_transit_gateway_vpc_attachment" "tgw_attach" {
  count = var.use_transit_gateway ? 1 : 0

  tags = merge(var.tags, {
    Name = "${var.vpc_short_name}-tgw-attachment"
  })

  transit_gateway_id = data.aws_ec2_transit_gateway.tgw[0].id
  vpc_id             = aws_vpc.vpc.id

  # Since we know the only traffic we receive from the Core Services TGW will
  # be destined for this VPC, it doesn't matter whether we use public-facing,
  # campus-facing, or private-facing subnets for the attachment.
  #
  # https://github.com/hashicorp/terraform/issues/28330 workaround: avoid
  # dependency cycles by using only hardcoded static literal references (add
  # lines if needed)
  #subnet_ids = [for az_suffix,subnet_key in var.transit_gateway_attachment_subnets : try(
  #  module.public-facing-subnet[subnet_key].id,
  #  module.campus-facing-subnet[subnet_key].id,
  #  module.private-facing-subnet[subnet_key].id,
  #  # https://github.com/hashicorp/terraform/issues/15469#issuecomment-515240849
  #  # so we know which occurrence failed
  #  file("\nERROR: var.transit_gateway_attachment_subnets contains unexpected subnet '${subnet_key}'"))]
  subnet_ids = [for az_suffix,subnet_key in var.transit_gateway_attachment_subnets :
    subnet_key == "public1-a-net" ? module.public-facing-subnet["public1-a-net"].id :
    subnet_key == "public1-b-net" ? module.public-facing-subnet["public1-b-net"].id :
    subnet_key == "public1-c-net" ? module.public-facing-subnet["public1-c-net"].id :
    subnet_key == "campus1-a-net" ? module.campus-facing-subnet["campus1-a-net"].id :
    subnet_key == "campus1-b-net" ? module.campus-facing-subnet["campus1-b-net"].id :
    subnet_key == "campus1-c-net" ? module.campus-facing-subnet["campus1-c-net"].id :
    subnet_key == "private1-a-net" ? module.private-facing-subnet["private1-a-net"].id :
    subnet_key == "private1-b-net" ? module.private-facing-subnet["private1-b-net"].id :
    subnet_key == "private1-c-net" ? module.private-facing-subnet["private1-c-net"].id :
    # https://github.com/hashicorp/terraform/issues/15469#issuecomment-515240849
    file("\nERROR: var.transit_gateway_attachment_subnets contains unexpected subnet '${subnet_key}'")]

  # Comment this out if you really need to destroy the attachment.  Note that
  # if you subsequently recreate it, you will need to contact Technology
  # Services again to reprovision the Core Services side.
  lifecycle {
    prevent_destroy = true
  }
}

locals {
  # passing this (instead of the data source) to subnets ensures that Terraform
  # will create the attachment *before* trying to create routes to it, but also
  # necessitates the above workaround to avoid dependency cycles for the subnet
  # modules used for the attachment.  Currently this behaves well in the common
  # case, but should it ever cause insurmountable problems we can use the
  # alternative version below and just apply multiple times.
  transit_gateway_id_local = aws_ec2_transit_gateway_vpc_attachment.tgw_attach[*].transit_gateway_id
  #transit_gateway_id_local = data.aws_ec2_transit_gateway.tgw[*].id
}

# create one NAT gateway in each Availability Zone (if needed)
#
# NAT gateways are important if you need private-facing subnets with outbound
# Internet access.  Campus-facing subnets can use NAT gateways too, but can
# also use the Transit Gateway for egress (which potentially saves money by not
# deploying NAT gateways).

module "nat" {
  source   = "git::https://github.com/techservicesillinois/aws-enterprise-vpc.git//modules/nat-gateway?ref=v0.11"
  for_each = { for az_suffix,subnet_key in var.nat_gateways : "${var.region}${az_suffix}" => {
    az_suffix  = az_suffix
    subnet_key = subnet_key
  }}

  tags = merge(var.tags, {
    Name = "${var.vpc_short_name}-nat-${each.value.az_suffix}"
  })

  # Subnets are defined further down.
  public_subnet_id = module.public-facing-subnet[each.value.subnet_key].id
}

# create an IPv6 Egress-Only Internet Gateway for private-facing subnets
#
# Unlike the NAT gateways this doesn't incur an hourly charge, so it's okay to
# create it even if we don't need it.

resource "aws_egress_only_internet_gateway" "eigw" {
  # note: tags not supported
  vpc_id = aws_vpc.vpc.id
}

# create a VPN Gateway with a VPN Connection to each of the Customer Gateways
# defined in the global environment
#
# Note: this solution is deprecated in favor of Transit Gateway.

resource "aws_vpn_gateway" "vgw" {
  count = var.use_dedicated_vpn ? 1 : 0

  tags = merge(var.tags, {
    Name = "${var.vpc_short_name}-vgw"
  })

  amazon_side_asn = 64512
}

resource "aws_vpn_gateway_attachment" "vgw_attachment" {
  count = var.use_dedicated_vpn ? 1 : 0

  vpn_gateway_id = aws_vpn_gateway.vgw[0].id
  vpc_id         = aws_vpc.vpc.id
}

module "vpn1" {
  source = "git::https://github.com/techservicesillinois/aws-enterprise-vpc.git//modules/vpn-connection?ref=v0.11"
  count  = var.use_dedicated_vpn ? 1 : 0

  tags                = var.tags
  name                = "${var.vpc_short_name}-vpn1"
  vpn_gateway_id      = aws_vpn_gateway.vgw[0].id
  customer_gateway_id = data.terraform_remote_state.global.outputs.customer_gateway_ids[var.region]["vpnhub-aws1-pub"]
  create_alarm        = true

  alarm_actions             = try([data.terraform_remote_state.global.outputs.vpn_monitor_arn[var.region]], null)
  insufficient_data_actions = try([data.terraform_remote_state.global.outputs.vpn_monitor_arn[var.region]], null)
  ok_actions                = try([data.terraform_remote_state.global.outputs.vpn_monitor_arn[var.region]], null)
}

output "vpn1_customer_gateway_configuration" {
  sensitive = true
  value     = one(module.vpn1[*].customer_gateway_configuration)
}

resource "null_resource" "vpn1" {
  count = var.use_dedicated_vpn ? 1 : 0

  triggers = {
    t = module.vpn1[0].id
  }

  # Comment this out if you really need to destroy the VPN connection.  Note: if
  # you subsequently recreate it, you will need to contact Technology Services
  # again to rebuild the on-campus configuration.
  lifecycle {
    prevent_destroy = true
  }
}

module "vpn2" {
  source = "git::https://github.com/techservicesillinois/aws-enterprise-vpc.git//modules/vpn-connection?ref=v0.11"
  count  = var.use_dedicated_vpn ? 1 : 0

  tags                = var.tags
  name                = "${var.vpc_short_name}-vpn2"
  vpn_gateway_id      = aws_vpn_gateway.vgw[0].id
  customer_gateway_id = data.terraform_remote_state.global.outputs.customer_gateway_ids[var.region]["vpnhub-aws2-pub"]
  create_alarm        = true

  alarm_actions             = try([data.terraform_remote_state.global.outputs.vpn_monitor_arn[var.region]], null)
  insufficient_data_actions = try([data.terraform_remote_state.global.outputs.vpn_monitor_arn[var.region]], null)
  ok_actions                = try([data.terraform_remote_state.global.outputs.vpn_monitor_arn[var.region]], null)
}

output "vpn2_customer_gateway_configuration" {
  sensitive = true
  value     = one(module.vpn2[*].customer_gateway_configuration)
}

resource "null_resource" "vpn2" {
  count = var.use_dedicated_vpn ? 1 : 0

  triggers = {
    t = module.vpn2[0].id
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

locals {
  # passing this to subnets ensures that Terraform will accept the peering
  # connection before trying to read CIDR data from it
  pcx_ids_local = { for k,v in aws_vpc_peering_connection_accepter.pcx : k=>v.id }
}

# create Subnets as specified
#
# Each subnet's cidr_block must be a subset of the overall vpc_cidr_block.
# Subnets do not need to be the same size; you can divide your IPv4 allocation
# in whatever way best suits your needs.
#
# IPv6 subnet CIDRs are always /64, and will be calculated from the VPC's IPv6
# CIDR block once it is known.
#
# Note that you can't resize or renumber existing Subnets in AWS once you
# create them.  You _can_ delete and re-create them with Terraform, but they
# will need to be emptied of service-oriented resources first.
#
# Each type of subnet (public-facing, campus-facing, and private-facing) uses a
# separate Terraform module which accepts slightly different parameters.

locals {
  # rearrange with availability_zone inside each object, and calculate IPv6
  # cidr blocks (if any) based on the actual allocation
  subnet_details = merge([ for az_suffix,v in var.subnets_by_availability_zone_suffix : { for subnet_key,d in v :
    subnet_key => {
      type              = d.type
      availability_zone = "${var.region}${az_suffix}"
      cidr_block        = d.cidr_block
      # e.g. xx03::/64 for ipv6_index=3, or null if not using IPv6
      ipv6_cidr_block   = try(cidrsubnet(aws_vpc.vpc.ipv6_cidr_block, 64 - split("/",aws_vpc.vpc.ipv6_cidr_block)[1], d.ipv6_index), null)
    }
  }]...)

  # see endpoints.tf
  gateway_vpc_endpoint_ids = { for k,v in aws_vpc_endpoint.gateway : k=>v.id }
}

module "public-facing-subnet" {
  source   = "git::https://github.com/techservicesillinois/aws-enterprise-vpc.git//modules/public-facing-subnet?ref=v0.11"
  for_each = { for k,v in local.subnet_details: k=>v if v.type == "public" }

  tags              = var.tags
  name              = "${var.vpc_short_name}-${each.key}"
  availability_zone = each.value.availability_zone
  cidr_block        = each.value.cidr_block
  ipv6_cidr_block   = each.value.ipv6_cidr_block

  assign_ipv6_address_on_creation = var.assign_ipv6_address_on_creation

  vpc_id              = aws_vpc.vpc.id
  pcx_ids             = local.pcx_ids_local
  endpoint_ids        = local.gateway_vpc_endpoint_ids
  transit_gateway_id  = local.transit_gateway_id_local
  internet_gateway_id = aws_internet_gateway.igw.id
}

module "campus-facing-subnet" {
  source   = "git::https://github.com/techservicesillinois/aws-enterprise-vpc.git//modules/campus-facing-subnet?ref=v0.11"
  for_each = { for k,v in local.subnet_details: k=>v if v.type == "campus" }

  tags              = var.tags
  name              = "${var.vpc_short_name}-${each.key}"
  availability_zone = each.value.availability_zone
  cidr_block        = each.value.cidr_block
  # ipv6 not supported

  vpc_id             = aws_vpc.vpc.id
  pcx_ids            = local.pcx_ids_local
  endpoint_ids       = local.gateway_vpc_endpoint_ids
  transit_gateway_id = local.transit_gateway_id_local
  vpn_gateway_id     = one(aws_vpn_gateway.vgw[*].id)

  # outbound IPv4 Internet access via NAT gateway in this AZ, if any
  # (NB: if no NAT gateway, campus-facing subnet will use TGW for egress)
  nat_gateway_id = [for k,v in module.nat: v.id if k == each.value.availability_zone]
}

module "private-facing-subnet" {
  source   = "git::https://github.com/techservicesillinois/aws-enterprise-vpc.git//modules/private-facing-subnet?ref=v0.11"
  for_each = { for k,v in local.subnet_details: k=>v if v.type == "private" }

  tags              = var.tags
  name              = "${var.vpc_short_name}-${each.key}"
  availability_zone = each.value.availability_zone
  cidr_block        = each.value.cidr_block
  ipv6_cidr_block   = each.value.ipv6_cidr_block

  assign_ipv6_address_on_creation = var.assign_ipv6_address_on_creation

  vpc_id             = aws_vpc.vpc.id
  pcx_ids            = local.pcx_ids_local
  endpoint_ids       = local.gateway_vpc_endpoint_ids
  transit_gateway_id = local.transit_gateway_id_local

  # outbound IPv4 Internet access via NAT gateway in this AZ, if any
  nat_gateway_id = [for k,v in module.nat: v.id if k == each.value.availability_zone]

  # outbound IPv6 Internet access via EIGW, but only if we also have NAT for
  # IPv4 (to avoid a confusing disparity)
  egress_only_gateway_id = contains(keys(module.nat),each.value.availability_zone) ? [aws_egress_only_internet_gateway.eigw.id] : []
}
