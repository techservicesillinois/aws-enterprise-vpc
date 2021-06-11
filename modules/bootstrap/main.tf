# This bootstrap environment creates the singleton S3 bucket and DynamoDB table
# used to store Terraform state for other IaC environments.
#
# Copyright (c) 2021 Board of Trustees University of Illinois

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.35"
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

variable "dynamodb_table" {
  description = "Must match hardcoded dynamodb_table in backend stanzas"
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

output "dynamodb_table" {
  value = aws_dynamodb_table.lock_table.name
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

  versioning {
    enabled = true
  }

  # Terraform should never destroy this resource
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_dynamodb_table" "lock_table" {
  name = var.dynamodb_table
  tags = var.tags

  billing_mode = "PAY_PER_REQUEST"

  hash_key = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  # Terraform should never destroy this resource
  lifecycle {
    prevent_destroy = true
  }
}
