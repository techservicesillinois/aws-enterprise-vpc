# This bootstrap environment creates the singleton resources used to store
# Terraform state for other IaC environments.
#
# Copyright (c) 2021 Board of Trustees University of Illinois

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }

  # see backend.tf for remote state configuration
}

## Inputs (specified in terraform.tfvars, or prompt interactively)

variable "account_id" {
  description = "Your 12-digit AWS account number"
  type        = string
  default     = null # for disposable use
}

variable "region" {
  description = "Must match hardcoded region in backend stanzas"
  type        = string
}

variable "bucket" {
  description = "Choose a valid S3 bucket name which is not already in use by any other AWS account.  Hint: try 'terraform.uiuc-tech-services-sandbox.aws.illinois.edu' but replace 'uiuc-tech-services-sandbox' with the friendly name of your AWS account."
  type        = string
}

variable "tags" {
  description = "Optional custom tags for all taggable resources"
  type        = map
  default     = {}
}

## Outputs

output "region" {
  value = var.region
}

output "bucket" {
  value = aws_s3_bucket.remote_state_bucket.bucket
}

## Providers

# default provider for chosen region
provider "aws" {
  region = var.region

  # avoid accidentally modifying the wrong AWS account
  # (waived for disposable use)
  allowed_account_ids = var.account_id == null ? null : [var.account_id]
}

## Resources

resource "aws_s3_bucket" "remote_state_bucket" {
  bucket = var.bucket
  tags   = var.tags

  # Terraform should never destroy this resource
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "remote_state_bucket_versioning" {
  bucket = aws_s3_bucket.remote_state_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}
