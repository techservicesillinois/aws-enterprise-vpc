# This file supplies values for the variables defined in main.tf

# AWS region (must be us-east-2 for an Enterprise VPC)
region = "us-east-2"

# Your 12-digit AWS account number
account_id = "999999999999" #FIXME

# S3 bucket used to store Terraform state (from ../.terragrunt)
bucket = "terraform.uiuc-tech-services-sandbox.aws.illinois.edu" #FIXME

# The short name of your VPC, e.g. "foobar" if the full name is "aws-foobar-vpc"
vpc_short_name = "example" #FIXME

# Add VPC Peering Connection IDs here *after* the peering is created
#pcx_ids = ["pcx-abcd1234"]
