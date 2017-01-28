# Creates a private-facing subnet within an Enterprise VPC

variable "vpc_id" {
    description = "VPC in which to create this subnet, e.g. vpc-abcd1234"
}

variable "name" {
    description = "tag:Name for this subnet"
}

variable "cidr_block" {
    description = "IPv4 CIDR block for this subnet, e.g. 192.168.0.0/27"
}

variable "availability_zone" {
    description = "Availability Zone for this subnet, e.g. us-east-2a"
}

variable "pcx_ids" {
    type = "list"
    description = "Optional list of VPC peering connections e.g. pcx-abcd1234 to use in this subnet's route table"
    default = []
}

variable "endpoint_ids" {
    type = "list"
    description = "Optional list of VPC Endpoints e.g. vpce-abcd1234 to use in this subnet's route table"
    default = []
}
# workaround for https://github.com/hashicorp/terraform/issues/1497
variable "endpoint_count" {
    description = "number of elements in endpoint_ids"
    default = 0
}

variable "nat_gateway_id" {
    description = "Optional NAT Gateway to use for default route, e.g. nat-abcdefgh12345678"
    default = ""
}
# workaround for https://github.com/hashicorp/terraform/issues/1497
variable "use_nat_gateway" {
    description = "set this to false if a NAT gateway is _not_ provided"
    default = true
}



output "id" {
    value = "${module.subnet.id}"
}



module "subnet" {
    source = "../subnet-common"
    vpc_id = "${var.vpc_id}"
    name = "${var.name}"
    cidr_block = "${var.cidr_block}"
    availability_zone = "${var.availability_zone}"
    pcx_ids = "${var.pcx_ids}"
    endpoint_ids = "${var.endpoint_ids}"
    endpoint_count = "${var.endpoint_count}"
    map_public_ip_on_launch = false
    rtb_id = "${aws_route_table.rtb.id}"
}

resource "aws_route_table" "rtb" {
    tags {
        Name = "${var.name}-rtb"
    }
    vpc_id = "${var.vpc_id}"
}

# default route (only if nat_gateway_id is provided)

resource "aws_route" "default" {
    #count = "${var.nat_gateway_id == "" ? 0 : 1}"
    count = "${var.use_nat_gateway ? 1 : 0}"
    #route_table_id = "${aws_route_table.rtb.id}"
    route_table_id = "${module.subnet.rtb_id}"
    destination_cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${var.nat_gateway_id}"
}
