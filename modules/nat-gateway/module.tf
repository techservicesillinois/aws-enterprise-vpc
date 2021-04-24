# Creates a NAT Gateway within an Enterprise VPC
#
# Copyright (c) 2017 Board of Trustees University of Illinois

terraform {
  required_version = ">= 0.15"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.35"
    }
  }
}

## Inputs

variable "public_subnet_id" {
  description = "Public-facing subnet in which to create this NAT gateway, e.g. subnet-abcd1234"
  type        = string
}

variable "tags" {
  description = "Optional custom tags for all taggable resources"
  type        = map
  default     = {}
}

variable "tags_eip" {
  description = "Optional custom tags for aws_eip resource"
  type        = map
  default     = {}
}

variable "tags_nat_gateway" {
  description = "Optional custom tags for aws_nat_gateway resource"
  type        = map
  default     = {}
}

## Outputs

output "id" {
  value = aws_nat_gateway.nat.id
}

## Resources

# Elastic IP for NAT Gateway

resource "aws_eip" "nat_eip" {
  tags = merge(var.tags, var.tags_eip)
  vpc  = true
}

# NAT Gateway

resource "aws_nat_gateway" "nat" {
  tags          = merge(var.tags, var.tags_nat_gateway)
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = var.public_subnet_id
}
