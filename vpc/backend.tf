# Backend configuration for Terraform remote state
#
# Copyright (c) 2021 Board of Trustees University of Illinois

terraform {
  backend "s3" {
    region         = "us-east-2"
    dynamodb_table = "terraform"
    encrypt        = "true"

    # must be unique to your AWS account; try replacing
    # uiuc-tech-services-sandbox with the friendly name of your account
    bucket = "terraform.uiuc-tech-services-sandbox.aws.illinois.edu" #FIXME

    # must be unique (within bucket) to this repository + environment
    key = "Shared Networking/vpc/terraform.tfstate"
  }
}

## Read remote state from global environment

data "terraform_remote_state" "global" {
  backend = "s3"

  # must match ../global/backend.tf
  config = {
    region = "us-east-2"
    bucket = "terraform.uiuc-tech-services-sandbox.aws.illinois.edu" #FIXME
    key    = "Shared Networking/global/terraform.tfstate"
  }
}
