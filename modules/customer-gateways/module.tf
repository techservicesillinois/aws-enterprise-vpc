# Creates Customer Gateways in your AWS account corresponding to the VPN
# terminators provided by Technology Services
#
# Copyright (c) 2017 Board of Trustees University of Illinois

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.35"
    }
  }
}

variable "tags" {
  description = "Optional custom tags for all taggable resources"
  type        = map
  default     = {}
}

output "customer_gateway_ids" {
  value = {
    vpnhub-aws1-pub = aws_customer_gateway.vpnhub-aws1-pub.id
    vpnhub-aws2-pub = aws_customer_gateway.vpnhub-aws2-pub.id
  }
}

resource "aws_customer_gateway" "vpnhub-aws1-pub" {
  tags = merge(var.tags, {
    Name = "vpnhub-aws1-pub"
  })

  ip_address = "128.174.0.21"
  bgp_asn    = 65044
  type       = "ipsec.1"
}

resource "aws_customer_gateway" "vpnhub-aws2-pub" {
  tags = merge(var.tags, {
    Name = "vpnhub-aws2-pub"
  })

  ip_address = "128.174.0.22"
  bgp_asn    = 65044
  type       = "ipsec.1"
}
