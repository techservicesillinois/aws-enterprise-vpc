variable "region" {}
variable "account_id" {}
variable "vpc_short_name" {}

provider "aws" {
    region = "${var.region}"
    allowed_account_ids = [ "${var.account_id}" ]
}

# look up VPC by tag:Name

data "aws_vpc" "vpc" {
    tags = {
        Name = "${var.vpc_short_name}-vpc"
    }
}

# look up Subnet (within the selected VPC, just in case several VPCs in your
# AWS account happen to have identically-named Subnets) by tag:Name

data "aws_subnet" "public1-a-net" {
    vpc_id = "${data.aws_vpc.vpc.id}"
    tags = {
        Name = "${var.vpc_short_name}-public1-a-net"
    }
}

# launch an EC2 instance in the selected Subnet.  This serves no useful purpose
# except to illustrate how we supply the value for subnet_id (the AMI does
# nothing interesting on its own, and we have not provided ourselves with any
# means to connect to it)

resource "aws_instance" "example" {
    ami = "ami-71ca9114"
    instance_type = "t2.nano"
    subnet_id = "${data.aws_subnet.public1-a-net.id}"
    tags {
        Name = "useless-example-instance"
    }
}

# print out its IP addresses (including an auto-assigned public IP, since we
# put it in a public-facing subnet) just for fun

output "private_ip" {
    value = "${aws_instance.example.private_ip}"
}
output "public_ip" {
    value = "${aws_instance.example.public_ip}"
}