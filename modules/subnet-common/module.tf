# Common-factor module (i.e. abstract base class) for the three types of subnets.
# Note that this module does NOT create a default route, but returns rtb_id so that the subclass can do so.
#
# Copyright (c) 2017 Board of Trustees University of Illinois

terraform {
  required_version = ">= 0.12.9"

  required_providers {
    aws = ">= 2.32"
  }
}

## Inputs

variable "vpc_id" { type = string }
variable "name" { type = string }
variable "cidr_block" { type = string }
variable "availability_zone" { type = string }
variable "pcx_ids" { type = list(string) }

# map with fixed keys (rather than list) until https://github.com/hashicorp/terraform/issues/4149
variable "endpoint_ids" { type = map(string) }

# workaround for https://github.com/hashicorp/terraform/issues/22561
variable "endpoint_ids_keys" { type = list(string) }

variable "map_public_ip_on_launch" { type = bool }

variable "propagating_vgws" {
  type    = list(string)
  default = []
}

# workaround for https://github.com/hashicorp/terraform/issues/10462
variable "dummy_depends_on" {
  type = string
  default = ""
}

resource "null_resource" "dummy_depends_on" {
  triggers = {
    t = var.dummy_depends_on
  }
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
  map_public_ip_on_launch = var.map_public_ip_on_launch
  vpc_id                  = var.vpc_id
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
  for_each = toset(var.pcx_ids)

  #id = each.value
  #depends_on = [null_resource.dummy_depends_on]

  # As of TF 0.12.9, using depends_on here results in failures:
  # https://github.com/hashicorp/terraform/issues/22908
  # Work around by embedding the dependency within id instead.
  id = null_resource.dummy_depends_on.id != "" ? each.value : null
}

resource "aws_route" "pcx" {
  # note: tags not supported
  for_each = toset(var.pcx_ids)

  route_table_id = aws_route_table.rtb.id

  # pick whichever CIDR block (requester or accepter) isn't _our_ CIDR block
  destination_cidr_block    = replace(data.aws_vpc_peering_connection.pcx[each.value].peer_cidr_block, data.aws_vpc.vpc.cidr_block, data.aws_vpc_peering_connection.pcx[each.value].cidr_block)
  vpc_peering_connection_id = data.aws_vpc_peering_connection.pcx[each.value].id
}

# routes for Gateway VPC Endpoints (if any)

resource "aws_vpc_endpoint_route_table_association" "endpoint_rta" {
  # note: tags not supported
  #for_each = var.endpoint_ids
  for_each = toset(var.endpoint_ids_keys)

  #vpc_endpoint_id = each.value
  vpc_endpoint_id = var.endpoint_ids[each.value]

  route_table_id = aws_route_table.rtb.id
}
