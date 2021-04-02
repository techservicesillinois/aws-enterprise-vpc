# Common-factor module (i.e. abstract base class) for the three types of subnets.
# Note that this module does NOT create a default route, but returns rtb_id so that the subclass can do so.
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

variable "vpc_id" { type = string }
variable "name" { type = string }
variable "cidr_block" { type = string }
variable "availability_zone" { type = string }
# map with fixed keys (rather than list) until https://github.com/hashicorp/terraform/issues/4149
variable "pcx_ids" { type = map(string) }
variable "transit_gateway_id" { type = list(string) }

# NB: re-run Terraform when the prefix list changes, until
# https://github.com/hashicorp/terraform-provider-aws/issues/15273
variable "transit_gateway_prefix_lists" { type = map }

variable "ipv6_cidr_block" {
  type    = string
  default = null
}

# map with fixed keys (rather than list) until https://github.com/hashicorp/terraform/issues/4149
variable "endpoint_ids" { type = map(string) }

variable "map_public_ip_on_launch" { type = bool }

variable "assign_ipv6_address_on_creation" {
  description = "Optional override (defaults to true iff ipv6_cidr_block provided)"
  type        = bool
  default     = null
}

variable "propagating_vgws" {
  type    = list(string)
  default = []
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
  value = aws_subnet.subnet.id
}

output "route_table_id" {
  value = aws_route_table.rtb.id
}

## Resources

# look up VPC

data "aws_vpc" "vpc" {
  id = var.vpc_id
}

# create Subnet and associated Route Table

resource "aws_subnet" "subnet" {
  tags = merge(var.tags, {
    Name = var.name
  }, var.tags_subnet)

  availability_zone       = var.availability_zone
  cidr_block              = var.cidr_block
  ipv6_cidr_block         = var.ipv6_cidr_block
  map_public_ip_on_launch = var.map_public_ip_on_launch
  vpc_id                  = var.vpc_id

  assign_ipv6_address_on_creation = (var.assign_ipv6_address_on_creation != null
    # honor explicit override
    ? var.assign_ipv6_address_on_creation
    # default to true iff the subnet has IPv6
    : (var.ipv6_cidr_block != null)
  )
}

resource "aws_route_table" "rtb" {
  tags = merge(var.tags, {
    Name = "${var.name}-rtb"
  }, var.tags_route_table)

  vpc_id           = var.vpc_id
  propagating_vgws = var.propagating_vgws
}

resource "aws_route_table_association" "rtb_assoc" {
  # note: tags not supported
  subnet_id      = aws_subnet.subnet.id
  route_table_id = aws_route_table.rtb.id
}

# routes for VPC Peering Connections (if any)

data "aws_vpc_peering_connection" "pcx" {
  for_each = var.pcx_ids

  id = each.value
}

resource "aws_route" "pcx" {
  # note: tags not supported
  for_each = data.aws_vpc_peering_connection.pcx

  route_table_id = aws_route_table.rtb.id

  # CIDR block of whichever VPC (requester or accepter) isn't _our_ VPC
  destination_cidr_block    = each.value.vpc_id == var.vpc_id ? each.value.peer_cidr_block : each.value.cidr_block
  vpc_peering_connection_id = each.value.id
}

# routes for Gateway VPC Endpoints (if any)

resource "aws_vpc_endpoint_route_table_association" "endpoint_rta" {
  # note: tags not supported
  for_each = var.endpoint_ids

  vpc_endpoint_id = each.value
  route_table_id  = aws_route_table.rtb.id
}

# routes for Transit Gateway prefix lists (if any)

data "aws_ec2_managed_prefix_list" "tgw_pl" {
  for_each = length(var.transit_gateway_id) > 0 ? var.transit_gateway_prefix_lists : {}

  # input var may specify either name or id for convenience
  name = lookup(each.value, "name", null)
  id   = lookup(each.value, "id", null)
}

# workaround https://github.com/hashicorp/terraform-provider-aws/issues/15273 :
# Terraform cannot yet create a route referencing the prefix list id, but it
# can read the prefix list and create a route to each CIDR.  The disadvantage
# is that we must re-run Terraform to update our routes when the prefix list
# changes, but fortunately for our purposes this should be rare.
resource "aws_route" "tgw" {
  #for_each = data.aws_ec2_managed_prefix_list.tgw_pl
  for_each = merge([for k,v in data.aws_ec2_managed_prefix_list.tgw_pl : { for c in v.entries[*].cidr :
    "${k}_${c}" => c
  }]...)

  route_table_id              = aws_route_table.rtb.id
  #destination_prefix_list_id = each.value.id
  destination_cidr_block      = length(regexall(":", each.value)) == 0 ? each.value : null
  destination_ipv6_cidr_block = length(regexall(":", each.value)) > 0 ? each.value : null
  transit_gateway_id          = var.transit_gateway_id[0]
}
