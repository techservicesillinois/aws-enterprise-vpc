# Common-factor module (i.e. abstract base class) for the three types of subnets.
# Note that this module does NOT create a default route, but returns rtb_id so that the subclass can do so.

variable "vpc_id" {}
variable "name" {}
variable "cidr_block" {}
variable "availability_zone" {}
variable "pcx_ids" { type = "list" }
variable "endpoint_ids" { type = "list" }
# workaround for https://github.com/hashicorp/terraform/issues/1497
variable "endpoint_count" {}

variable map_public_ip_on_launch {}

# workaround for https://github.com/hashicorp/terraform/issues/11453: have each subclass create its own rtb
#variable propagating_vgws { type = "list", default = [] }
variable rtb_id {}



output "id" {
    value = "${aws_subnet.subnet.id}"
}

output "rtb_id" {
    #value = "${aws_route_table.rtb.id}"
    value = "${var.rtb_id}"
}



# look up VPC

data "aws_vpc" "vpc" {
    id = "${var.vpc_id}"
}

# create Subnet and associated Route Table

resource "aws_subnet" "subnet" {
    tags {
        Name = "${var.name}"
    }
    availability_zone = "${var.availability_zone}"
    cidr_block = "${var.cidr_block}"
    map_public_ip_on_launch = "${var.map_public_ip_on_launch}"
    vpc_id = "${var.vpc_id}"
}

#resource "aws_route_table" "rtb" {
#    tags {
#        Name = "${var.name}-rtb"
#    }
#    vpc_id = "${var.vpc_id}"
#    propagating_vgws = "${var.propagating_vgws}"
#}

resource "aws_route_table_association" "rtb_assoc" {
    subnet_id = "${aws_subnet.subnet.id}"
    #route_table_id = "${aws_route_table.rtb.id}"
    route_table_id = "${var.rtb_id}"
}

# routes for VPC Peering Connections (if any)

data "aws_vpc_peering_connection" "pcx" {
    count = "${length(var.pcx_ids)}"
    id = "${var.pcx_ids[count.index]}"
}
resource "aws_route" "pcx" {
    count = "${length(var.pcx_ids)}"
    #route_table_id = "${aws_route_table.rtb.id}"
    route_table_id = "${var.rtb_id}"
    # pick whichever CIDR block (requester or accepter) isn't _our_ CIDR block
    destination_cidr_block = "${replace(data.aws_vpc_peering_connection.pcx.peer_cidr_block, data.aws_vpc.vpc.cidr_block, data.aws_vpc_peering_connection.pcx.cidr_block)}"
    vpc_peering_connection_id = "${element(data.aws_vpc_peering_connection.pcx.*.id, count.index)}"
}

# routes for VPC Endpoints (if any)

resource "aws_vpc_endpoint_route_table_association" "endpoint_rta" {
    #count = "${length(var.endpoint_ids)}"
    count = "${var.endpoint_count}"
    vpc_endpoint_id = "${var.endpoint_ids[count.index]}"
    #route_table_id = "${aws_route_table.rtb.id}"
    route_table_id = "${var.rtb_id}"
}
