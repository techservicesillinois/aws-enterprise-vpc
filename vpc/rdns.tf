# Options for Recursive DNS Resolution within an Enterprise VPC
#
# Copyright (c) 2017 Board of Trustees University of Illinois

## Inputs (specified in terraform.tfvars)

variable "rdns_option" {
  description = "See rdns.tf comments for explanation"
  type        = number
  default     = null

  validation {
    condition     = var.rdns_option == null || var.rdns_option == 1 || var.rdns_option == 2 || var.rdns_option == 3
    error_message = "If set, rdns_option must be between 1 and 3."
  }
}

variable "rdns_transition" {
  description = "Set true temporarily while transitioning to/from Option 3; see rdns.tf comments for explanation"
  type        = bool
  default     = false
}

variable "core_services_resolvers" {
  description = "IPv4 addresses of Core Services Resolvers reachable from this VPC"
  type        = list(string)
  default     = []
}

# fail on empty core_services_resolvers if chosen option requires it
locals {
  # workaround for lack of assertions https://github.com/hashicorp/terraform/issues/15469
  assert_core_services_resolvers = length(var.core_services_resolvers) > 0 || ((var.rdns_option == null || var.rdns_option == 1) && !var.rdns_transition) ? null : file("ERROR: must specify core_services_resolvers")
}


## Option 1: use AmazonProvidedDNS.
#
# Set rdns_option = 1 only if you have previously deployed Option 2 or 3 and
# want to return to the default behavior.

resource "aws_default_vpc_dhcp_options" "default" {
  count = var.rdns_option == 1 ? 1 : 0
}

# re-associate the default DHCP Options Set with your VPC
resource "aws_vpc_dhcp_options_association" "dhcp_assoc" {
  count = var.rdns_option == 1 ? 1 : 0

  # note: tags not supported
  vpc_id          = aws_vpc.vpc.id
  dhcp_options_id = aws_default_vpc_dhcp_options.default[0].id
}


## Option 2: use Core Services Resolvers directly.

# create a DHCP Options Set
resource "aws_vpc_dhcp_options" "dhcp_option2" {
  count = var.rdns_option == 2 ? 1 : 0

  tags = merge(var.tags, {
    Name = "${var.vpc_short_name}-dhcp"
  })

  domain_name_servers = var.core_services_resolvers
  domain_name         = "${var.region}.compute.internal"
}

# associate the DHCP Options Set with your VPC
resource "aws_vpc_dhcp_options_association" "dhcp_assoc_option2" {
  count = var.rdns_option == 2 ? 1 : 0

  # note: tags not supported
  vpc_id          = aws_vpc.vpc.id
  dhcp_options_id = aws_vpc_dhcp_options.dhcp_option2[0].id
}


## Option 3: use Recursive DNS Forwarders within your Enterprise VPC.
#
# Be sure to read and understand [modules/rdns-forwarder/README.md] before
# deploying this option.
#
# The module blocks below intentionally do NOT use for_each, to facilitate
# upgrading one rdns-forwarder at a time to a new version of the module.
#
# Should you ever decide to transition away from Option 3, set rdns_transition
# = true (along with rdns_option = 1 or 2) to leave the actual rdns-forwarder
# instances in place for a while longer, so that they can continue to answer
# queries from clients which have not yet picked up the new DHCP options.
# After a while, re-run with rdns_transition = false to destroy the instances.
#
# You can also set rdns_transition = true before transitioning _to_ Option 3,
# to make sure clients won't start using the newly deployed forwarders before
# they are fully operational.

module "rdns-a" {
  count  = (var.rdns_option == 3 || var.rdns_transition) ? 1 : 0
  source = "git::https://github.com/techservicesillinois/aws-enterprise-vpc.git//modules/rdns-forwarder?ref=v0.11"

  tags = merge(var.tags, {
    Name = "${var.vpc_short_name}-rdns-a"
  })

  instance_type           = "t4g.micro"
  instance_architecture   = "arm64"
  core_services_resolvers = var.core_services_resolvers
  subnet_id               = module.public-facing-subnet["public1-a-net"].id

  # First four IP addresses on each subnet (counting the network address) are
  # reserved by AWS, so compute the fifth one.  If that IP is already taken,
  # you can specify a different one instead, but this should usually work.
  private_ip = cidrhost(module.public-facing-subnet["public1-a-net"].cidr_block, 4)

  zone_update_minute       = "5"
  full_update_day_of_month = "1"
}

resource "null_resource" "rdns-a" {
  count = (var.rdns_option == 3 || var.rdns_transition) ? 1 : 0

  triggers = {
    t = module.rdns-a[0].id
  }

  # Comment this out when you really need to destroy the forwarder.
  lifecycle {
    prevent_destroy = true
  }
}

module "rdns-b" {
  count  = (var.rdns_option == 3 || var.rdns_transition) ? 1 : 0
  source = "git::https://github.com/techservicesillinois/aws-enterprise-vpc.git//modules/rdns-forwarder?ref=v0.11"

  tags = merge(var.tags, {
    Name = "${var.vpc_short_name}-rdns-b"
  })

  instance_type           = "t4g.micro"
  instance_architecture   = "arm64"
  core_services_resolvers = var.core_services_resolvers
  subnet_id               = module.public-facing-subnet["public1-b-net"].id

  private_ip = cidrhost(module.public-facing-subnet["public1-b-net"].cidr_block, 4)

  zone_update_minute       = "35"
  full_update_day_of_month = "15"
}

resource "null_resource" "rdns-b" {
  count = (var.rdns_option == 3 || var.rdns_transition) ? 1 : 0

  triggers = {
    t = module.rdns-b[0].id
  }

  # Comment this out when you really need to destroy the forwarder.
  lifecycle {
    prevent_destroy = true
  }
}

# create a DHCP Options Set
resource "aws_vpc_dhcp_options" "dhcp_option3" {
  count = var.rdns_option == 3 ? 1 : 0

  tags = merge(var.tags, {
    Name = "${var.vpc_short_name}-dhcp"
  })

  domain_name_servers = [module.rdns-a[0].private_ip, module.rdns-b[0].private_ip]
  domain_name         = "${var.region}.compute.internal"
}

# associate the DHCP Options Set with your VPC
resource "aws_vpc_dhcp_options_association" "dhcp_assoc_option3" {
  count = var.rdns_option == 3 ? 1 : 0

  # note: tags not supported
  vpc_id          = aws_vpc.vpc.id
  dhcp_options_id = aws_vpc_dhcp_options.dhcp_option3[0].id
}
