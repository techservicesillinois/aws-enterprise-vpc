# Creates a NAT Gateway within an Enterprise VPC
#
# Copyright (c) 2017 Board of Trustees University of Illinois

terraform {
  required_version = ">= 0.11"

  ## future (https://github.com/hashicorp/terraform/issues/16835)
  #required_providers {
  #  aws    = ">= 1.7"
  #}
}

## Inputs

variable "public_subnet_id" {
  description = "Public-facing subnet in which to create this NAT gateway, e.g. subnet-abcd1234"
}

variable "tags" {
  description = "Optional tags to be set on all resources"
  type        = "map"
  default     = {}
}

## Outputs

output "id" {
  value = "${aws_nat_gateway.nat.id}"
}

## Resources

# Elastic IP for NAT Gateway

resource "aws_eip" "nat_eip" {
  tags = "${var.tags}"
  vpc  = true
}

# NAT Gateway

resource "aws_nat_gateway" "nat" {
  tags          = "${var.tags}"
  allocation_id = "${aws_eip.nat_eip.id}"
  subnet_id     = "${var.public_subnet_id}"
}
