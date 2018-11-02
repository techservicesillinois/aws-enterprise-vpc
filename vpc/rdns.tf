# Options for Recursive DNS Resolution within an Enterprise VPC
#
# Copyright (c) 2017 Board of Trustees University of Illinois

## Inputs (specified in terraform.tfvars)

variable "core_services_resolvers" {
  type        = "list"
  description = "IPv4 addresses of Core Services Resolvers in the Core Services VPC with which you have a VPC peering"
  default     = []
}

## If desired, uncomment *only one* of the following sections, depending on
## which option you need.


/*
## Option 1: use AmazonProvidedDNS.
##
## Uncomment this section only if you have previously deployed Option 2 or 3
## and want to return to the default behavior.
##
## Note: if you had previously deployed Option 3, comment out its dhcp_assoc
## now, but leave the actual rdns-forwarder instances in place for a little
## while longer so they can continue to answer queries from running clients
## which have not yet picked up the new DHCP options.

resource "aws_default_vpc_dhcp_options" "default" {}

# re-associate the default DHCP Options Set with your VPC
resource "aws_vpc_dhcp_options_association" "dhcp_assoc" {
  vpc_id          = "${aws_vpc.vpc.id}"
  dhcp_options_id = "${aws_default_vpc_dhcp_options.default.id}"
}
*/


/*
## Option 2: use Core Services Resolvers directly.

# create a DHCP Options Set
resource "aws_vpc_dhcp_options" "dhcp_option2" {
  # fail on empty core_services_resolvers
  count = "${length(var.core_services_resolvers[0]) > 0 ? 1 : 0}"

  tags {
    Name = "${var.vpc_short_name}-dhcp"
  }

  domain_name_servers = "${var.core_services_resolvers}"
  domain_name         = "${var.region}.compute.internal"
}

# associate the DHCP Options Set with your VPC
resource "aws_vpc_dhcp_options_association" "dhcp_assoc" {
  vpc_id          = "${aws_vpc.vpc.id}"
  dhcp_options_id = "${aws_vpc_dhcp_options.dhcp_option2.id}"
}
*/


/*
## Option 3: use Recursive DNS Forwarders within your Enterprise VPC.
##
## Be sure to read and understand [modules/rdns-forwarder/README.md] before
## deploying this option.

module "rdns-a" {
  source = "git::https://github.com/techservicesillinois/aws-enterprise-vpc.git//modules/rdns-forwarder?ref=v0.8"

  tags = {
    Name = "${var.vpc_short_name}-rdns-a"
  }

  instance_type           = "t2.micro"
  core_services_resolvers = "${var.core_services_resolvers}"
  subnet_id               = "${module.public1-a-net.id}"

  # First four IP addresses on each subnet (counting the network address) are
  # reserved by AWS, so compute the fifth one.  If that IP is already taken,
  # you can specify a different one instead, but this should usually work.
  private_ip = "${cidrhost(module.public1-a-net.cidr_block, 4)}"

  zone_update_minute       = "5"
  full_update_day_of_month = "1"
}

module "rdns-b" {
  source = "git::https://github.com/techservicesillinois/aws-enterprise-vpc.git//modules/rdns-forwarder?ref=v0.8"

  tags = {
    Name = "${var.vpc_short_name}-rdns-b"
  }

  instance_type           = "t2.micro"
  core_services_resolvers = "${var.core_services_resolvers}"
  subnet_id               = "${module.public1-b-net.id}"

  private_ip = "${cidrhost(module.public1-b-net.cidr_block, 4)}"

  zone_update_minute       = "35"
  full_update_day_of_month = "15"
}

# create a DHCP Options Set
resource "aws_vpc_dhcp_options" "dhcp_option3" {
  # fail on empty core_services_resolvers
  count = "${length(var.core_services_resolvers[0]) > 0 ? 1 : 0}"

  tags {
    Name = "${var.vpc_short_name}-dhcp"
  }

  domain_name_servers = ["${module.rdns-a.private_ip}", "${module.rdns-b.private_ip}"]
  domain_name         = "${var.region}.compute.internal"
}

# associate the DHCP Options Set with your VPC
resource "aws_vpc_dhcp_options_association" "dhcp_assoc" {
  vpc_id          = "${aws_vpc.vpc.id}"
  dhcp_options_id = "${aws_vpc_dhcp_options.dhcp_option3.id}"
}
*/

