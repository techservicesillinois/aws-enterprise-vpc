# Example configuration for VPC Endpoints
# https://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/vpc-endpoints.html
#
# Copyright (c) 2018 Board of Trustees University of Illinois

# Hint: use `aws ec2 describe-vpc-endpoint-services` to find service names if
# the lists below are out of date.

locals {
  # Gateway VPC Endpoints, enabled by default
  gateway_vpc_endpoint_service_names = [
    "com.amazonaws.${var.region}.dynamodb",
    "com.amazonaws.${var.region}.s3",
  ]

  # Interface VPC Endpoints, disabled by default because they create elastic
  # network interfaces (thus consuming a private IP) on each subnet.  Uncomment
  # the ones you want to use.
  interface_vpc_endpoint_service_names = [
    #"com.amazonaws.${var.region}.ec2",
    #"com.amazonaws.${var.region}.ec2messages",
    #"com.amazonaws.${var.region}.elasticloadbalancing",
    #"com.amazonaws.${var.region}.kinesis-streams",
    #"com.amazonaws.${var.region}.kms",
    #"com.amazonaws.${var.region}.servicecatalog",
    #"com.amazonaws.${var.region}.sns",
    #"com.amazonaws.${var.region}.ssm",
  ]

  # which subnets from main.tf to use for Interface VPC Endpoints
  interface_vpc_endpoint_subnet_ids = ["${module.private1-a-net.id}", "${module.private1-b-net.id}"]

  # derived values used in main.tf
  gateway_vpc_endpoint_count = "${length(local.gateway_vpc_endpoint_service_names)}"
  gateway_vpc_endpoint_ids   = ["${aws_vpc_endpoint.gateway.*.id}"]
}

# create Gateway VPC Endpoints (if desired)

resource "aws_vpc_endpoint" "gateway" {
  count = "${length(local.gateway_vpc_endpoint_service_names)}"

  vpc_id            = "${aws_vpc.vpc.id}"
  vpc_endpoint_type = "Gateway"
  service_name      = "${local.gateway_vpc_endpoint_service_names[count.index]}"
}

# create Interface VPC Endpoints (if desired)

resource "aws_vpc_endpoint" "interface" {
  count = "${length(local.interface_vpc_endpoint_service_names)}"

  vpc_id              = "${aws_vpc.vpc.id}"
  vpc_endpoint_type   = "Interface"
  service_name        = "${local.interface_vpc_endpoint_service_names[count.index]}"
  private_dns_enabled = true
  security_group_ids  = ["${aws_security_group.endpoints.id}"]
  subnet_ids          = ["${local.interface_vpc_endpoint_subnet_ids}"]
}

# Security Group for Interface VPC Endpoints (if any)

resource "aws_security_group" "endpoints" {
  count = "${length(local.interface_vpc_endpoint_service_names) > 0 ? 1 : 0}"

  tags = {
    Name = "${var.vpc_short_name}-vpc-endpoints"
  }

  name_prefix = "vpc-endpoints-"
  vpc_id      = "${aws_vpc.vpc.id}"
}

# allow all outbound
resource "aws_security_group_rule" "endpoint_egress" {
  count = "${length(local.interface_vpc_endpoint_service_names) > 0 ? 1 : 0}"

  security_group_id = "${aws_security_group.endpoints.id}"
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}

# allow inbound only from this VPC
resource "aws_security_group_rule" "endpoint_ingress" {
  count = "${length(local.interface_vpc_endpoint_service_names) > 0 ? 1 : 0}"

  security_group_id = "${aws_security_group.endpoints.id}"
  type              = "ingress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["${aws_vpc.vpc.cidr_block}"]
}
