# Creates a campus-facing subnet within an Enterprise VPC
#
# Copyright (c) 2017 Board of Trustees University of Illinois

terraform {
  required_version = ">= 0.14"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.32"
    }
  }
}

## Inputs

variable "vpc_id" {
  description = "VPC in which to create this subnet, e.g. vpc-abcd1234"
  type        = string
}

variable "name" {
  description = "tag:Name for this subnet"
  type        = string
}

variable "cidr_block" {
  description = "IPv4 CIDR block for this subnet, e.g. 192.168.0.0/27"
  type        = string
}

variable "availability_zone" {
  description = "Availability Zone for this subnet, e.g. us-east-2a"
  type        = string
}

# map with fixed keys (rather than list) until https://github.com/hashicorp/terraform/issues/4149
variable "pcx_ids" {
  description = "Optional map of VPC peering connections e.g. pcx-abcd1234 to use in this subnet's route table"
  type        = map(string)
  default     = {}
}

# map with fixed keys (rather than list) until https://github.com/hashicorp/terraform/issues/4149
variable "endpoint_ids" {
  description = "Optional map of Gateway VPC Endpoints e.g. vpce-abcd1234 to use in this subnet's route table"
  type        = map(string)
  default     = {}
}

# singleton list to work around computed count until https://github.com/hashicorp/terraform/issues/4149
variable "nat_gateway_id" {
  description = "Optional NAT Gateway to use for IPv4 default route, e.g. nat-abcdefgh12345678, wrapped in singleton list"
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.nat_gateway_id) < 2
    error_message = "Only one element allowed."
  }
}

# DEPRECATED in favor of Transit Gateway
variable "vpn_gateway_id" {
  description = "VPN Gateway for campus-facing routes, e.g. vgw-abcd1234"
  type        = string
  default     = null
}

# singleton list to work around computed count until https://github.com/hashicorp/terraform/issues/4149
variable "transit_gateway_id" {
  description = "Optional Transit Gateway for cloud-facing and campus-facing routes, e.g. tgw-abcd1234, wrapped in singleton list"
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.transit_gateway_id) < 2
    error_message = "Only one element allowed."
  }
}

# NB: re-run Terraform when the prefix list changes, until
# https://github.com/hashicorp/terraform-provider-aws/issues/15273
variable "transit_gateway_prefix_lists" {
  description = "Map of existing prefix lists to route toward the Transit Gateway (if provided), specified by either name or id"
  type        = map
  default     = {
    # common case: these prefix lists are already shared with your AWS account
    # via Resource Access Manager (from the core services account)
    uofi-campus-ipv4 = { name = "uofi-campus-ipv4" }
  }
}

variable "default_ipv4_route_via_transit_gateway" {
  description = "Optional override (defaults to true iff not using a NAT gateway)"
  type        = bool
  default     = null
}

variable "tags" {
  description = "Optional custom tags for all taggable resources"
  type        = map
  default     = {}
}

variable "tags_subnet" {
  description = "Optional custom tags for aws_subnet resource"
  type        = map
  default     = {}
}

variable "tags_route_table" {
  description = "Optional custom tags for aws_route_table resource"
  type        = map
  default     = {}
}

## Outputs

output "id" {
  value = module.subnet.id
}

output "route_table_id" {
  value = module.subnet.route_table_id
}

# for convenience, since callers cannot reference module inputs directly
output "cidr_block" {
  value = var.cidr_block
}

## Resources

module "subnet" {
  source = "git::https://github.com/techservicesillinois/aws-enterprise-vpc.git//modules/subnet-common?ref=v0.10"

  vpc_id                          = var.vpc_id
  name                            = var.name
  cidr_block                      = var.cidr_block
  availability_zone               = var.availability_zone
  pcx_ids                         = var.pcx_ids
  endpoint_ids                    = var.endpoint_ids
  map_public_ip_on_launch         = false
  transit_gateway_id              = var.transit_gateway_id
  transit_gateway_prefix_lists    = var.transit_gateway_prefix_lists
  propagating_vgws                = var.vpn_gateway_id == null ? [] : [var.vpn_gateway_id]
  tags                            = var.tags
  tags_subnet                     = var.tags_subnet
  tags_route_table                = var.tags_route_table
}

# default routes (if targets provided)

resource "aws_route" "ipv4_default" {
  # note: tags not supported
  count = length(var.nat_gateway_id)

  route_table_id         = module.subnet.route_table_id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.nat_gateway_id[0]
}

resource "aws_route" "ipv4_default_via_tgw" {
  # note: tags not supported
  count = (var.default_ipv4_route_via_transit_gateway != null
      # honor explicit override
      ? var.default_ipv4_route_via_transit_gateway
      # default to true iff not using a NAT gateway
      : length(var.nat_gateway_id) == 0
    ) ? length(var.transit_gateway_id) : 0

  route_table_id         = module.subnet.route_table_id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = var.transit_gateway_id[0]
}
