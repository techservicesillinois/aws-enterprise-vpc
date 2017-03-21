# Creates Customer Gateways in your AWS account corresponding to the VPN
# terminators provided by Technology Services
#
# Note: this may result in terraform taking over an existing cgw that was not
# originally created by terraform.  See
# https://github.com/hashicorp/terraform/issues/7492

terraform {
  required_version = ">= 0.9.1"
}

output "customer_gateway_ids" {
  value = {
    vpnhub-aws1-pub = "${aws_customer_gateway.vpnhub-aws1-pub.id}"
    vpnhub-aws2-pub = "${aws_customer_gateway.vpnhub-aws2-pub.id}"
  }
}

resource "aws_customer_gateway" "vpnhub-aws1-pub" {
  tags {
    Name = "vpnhub-aws1-pub"
  }

  ip_address = "128.174.0.21"
  bgp_asn    = 65044
  type       = "ipsec.1"
}

resource "aws_customer_gateway" "vpnhub-aws2-pub" {
  tags {
    Name = "vpnhub-aws2-pub"
  }

  ip_address = "128.174.0.22"
  bgp_asn    = 65044
  type       = "ipsec.1"
}
