# Configuration for VPC Endpoints
# https://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/vpc-endpoints.html
#
# Copyright (c) 2018 Board of Trustees University of Illinois

## Inputs (specified in terraform.tfvars)

# Gateway VPC Endpoints, created by default since there is no additional charge
# https://docs.aws.amazon.com/vpc/latest/privatelink/vpce-gateway.html#gateway-endpoint-pricing
variable "gateway_vpc_endpoint_service_names" {
  description = "List of ServiceNames with region replaced by '{{REGION}}'"
  type        = list(string)
  default     = [
    "com.amazonaws.{{REGION}}.dynamodb",
    "com.amazonaws.{{REGION}}.s3",
  ]
}

# Interface VPC Endpoints for AWS services, not created by default since each
# interface incurs cost and consumes an IP address.  Specify the ones you need.
#
# Hint: use `aws ec2 describe-vpc-endpoint-services` to find more service names
variable "interface_vpc_endpoint_service_names" {
  description = "List of ServiceNames with region replaced by '{{REGION}}'"
  type        = list(string)
  default     = []
}

variable "interface_vpc_endpoint_subnets" {
  description = "Specify one subnet per Availability Zone to be used for Interface VPC Endpoints (may be public-, campus-, or private-facing).  Maps availability zone suffix (e.g. 'a' for us-east-2a) to subnet key"
  type        = map(string)
  default     = {}
}

## Resources

locals {
  # which subnets from main.tf to use for Interface VPC Endpoints
  interface_vpc_endpoint_subnet_ids = [for k,v in var.interface_vpc_endpoint_subnets :
    try(module.public-facing-subnet[v].id, module.campus-facing-subnet[v].id, module.private-facing-subnet[v].id,
      # https://github.com/hashicorp/terraform/issues/15469#issuecomment-515240849
      # so we know which occurrence failed
      file("\nERROR: var.interface_vpc_endpoint_subnets contains unexpected subnet '${v}'"))]
}

# create Gateway VPC Endpoints (if desired)

resource "aws_vpc_endpoint" "gateway" {
  for_each = toset([for x in var.gateway_vpc_endpoint_service_names : replace(x, "{{REGION}}", var.region)])

  tags = merge(var.tags, {
    Name = "${var.vpc_short_name}-vpce-${each.value}"
  })

  vpc_id            = aws_vpc.vpc.id
  vpc_endpoint_type = "Gateway"
  service_name      = each.value
}

# create Interface VPC Endpoints (if desired)

resource "aws_vpc_endpoint" "interface" {
  for_each = toset([for x in var.interface_vpc_endpoint_service_names : replace(x, "{{REGION}}", var.region)])

  tags = merge(var.tags, {
    Name = "${var.vpc_short_name}-vpce-${each.value}"
  })

  vpc_id              = aws_vpc.vpc.id
  vpc_endpoint_type   = "Interface"
  service_name        = each.value
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.endpoints[0].id]
  subnet_ids          = local.interface_vpc_endpoint_subnet_ids
}

# Security Group for Interface VPC Endpoints (if any)

# note: as of this writing (2019-11-11) Endpoints support IPv4 traffic only,
# but our SG permits IPv6 anyway in case that changes

resource "aws_security_group" "endpoints" {
  count = length(var.interface_vpc_endpoint_service_names) > 0 ? 1 : 0

  tags = merge(var.tags, {
    Name = "${var.vpc_short_name}-vpc-endpoints"
  })

  name_prefix = "vpc-endpoints-"
  vpc_id      = aws_vpc.vpc.id
}

# allow all outbound
resource "aws_security_group_rule" "endpoint_egress" {
  # note: tags not supported
  count = length(var.interface_vpc_endpoint_service_names) > 0 ? 1 : 0

  security_group_id = aws_security_group.endpoints[0].id
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
}

# allow inbound only from this VPC
resource "aws_security_group_rule" "endpoint_ingress" {
  # note: tags not supported
  count = length(var.interface_vpc_endpoint_service_names) > 0 ? 1 : 0

  security_group_id = aws_security_group.endpoints[0].id
  type              = "ingress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = [aws_vpc.vpc.cidr_block]
  ipv6_cidr_blocks  = (aws_vpc.vpc.ipv6_cidr_block == "" ? null : [aws_vpc.vpc.ipv6_cidr_block])
}
