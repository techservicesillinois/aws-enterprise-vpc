# Creates a private-facing subnet within an Enterprise VPC
#
# Copyright (c) 2017 Board of Trustees University of Illinois

terraform {
  required_version = ">= 0.12.13"

  required_providers {
    aws = ">= 2.32"
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

variable "ipv6_cidr_block" {
  description = "Optional IPv6 CIDR block for this subnet, e.g. 2001:db8::/64"
  type        = string
  default     = null
}

variable "availability_zone" {
  description = "Availability Zone for this subnet, e.g. us-east-2a"
  type        = string
}

variable "pcx_ids" {
  description = "Optional list of VPC peering connections e.g. pcx-abcd1234 to use in this subnet's route table"
  type        = list(string)
  default     = []
}

# workaround for https://github.com/hashicorp/terraform/issues/10462
variable "dummy_depends_on" {
  type    = string
  default = ""
}

#resource "null_resource" "dummy_depends_on" {
#  triggers = {
#    t = var.dummy_depends_on
#  }
#}

# map with fixed keys (rather than list) until https://github.com/hashicorp/terraform/issues/4149
variable "endpoint_ids" {
  description = "Optional map of Gateway VPC Endpoints e.g. vpce-abcd1234 to use in this subnet's route table"
  type        = map(string)
  default     = {}
}

variable "nat_gateway_id" {
  description = "Optional NAT Gateway to use for IPv4 default route, e.g. nat-abcdefgh12345678"
  type        = string
  default     = ""
}

# workaround for https://github.com/hashicorp/terraform/issues/4149
variable "use_nat_gateway" {
  description = "set this to false if a NAT gateway is _not_ provided"
  type        = bool
  default     = true
}

variable "egress_only_gateway_id" {
  description = "Optional Egress-Only Internet Gateway to use for IPv6 default route, e.g. eigw-abcdefgh12345678"
  type        = string
  default     = null
}

# workaround for https://github.com/hashicorp/terraform/issues/4149
variable "use_egress_only_gateway" {
  description = "set this to false if an Egress-Only Internet Gateway is _not_ provided"
  type        = bool
  default     = true
}

variable "assign_ipv6_address_on_creation" {
  description = "Optional override (defaults to true iff ipv6_cidr_block provided)"
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
  ipv6_cidr_block                 = var.ipv6_cidr_block
  availability_zone               = var.availability_zone
  pcx_ids                         = var.pcx_ids
  dummy_depends_on                = var.dummy_depends_on
  endpoint_ids                    = var.endpoint_ids
  map_public_ip_on_launch         = false
  assign_ipv6_address_on_creation = var.assign_ipv6_address_on_creation
  tags                            = var.tags
  tags_subnet                     = var.tags_subnet
  tags_route_table                = var.tags_route_table
}

# default routes (if targets provided)

resource "aws_route" "ipv4_default" {
  # note: tags not supported
  #count = var.nat_gateway_id == "" ? 0 : 1
  count = var.use_nat_gateway ? 1 : 0

  route_table_id         = module.subnet.route_table_id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.nat_gateway_id
}

resource "aws_route" "ipv6_default" {
  # note: tags not supported
  #count = var.egress_only_gateway_id == null ? 0 : 1
  count = var.use_egress_only_gateway ? 1 : 0

  route_table_id              = module.subnet.route_table_id
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = var.egress_only_gateway_id
}
