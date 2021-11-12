# Bootstrapping Terraform remote state in S3

This directory provides a Terraform module to create the two resources needed for remotely storing [Terraform state](https://www.terraform.io/docs/state/) in the [S3 backend](https://www.terraform.io/docs/backends/types/s3.html):

  * an S3 bucket with [versioning](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html) and [server-side encryption](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucket-encryption.html)
  * a DynamoDB table with a specific schema for state locking


## Usage

To create these resources (only once per AWS account):

  1. Choose a [valid S3 bucket name](http://docs.aws.amazon.com/AmazonS3/latest/dev/BucketRestrictions.html#bucketnamingrules).

     * S3 bucket names are _globally_ unique, so you must choose one that is not already in use by another AWS account.  One possible strategy is to use the pattern

           bucket = "terraform.uiuc-tech-services-sandbox.aws.illinois.edu"

       replacing 'uiuc-tech-services-sandbox' with the friendly name of your AWS account.

  2. In an empty directory (suggested name: `bootstrap`),

         terraform init -from-module=git::https://github.com/techservicesillinois/aws-enterprise-vpc.git//modules/bootstrap
         terraform apply

     Enter your chosen bucket name when prompted.

This singleton S3 bucket and DynamoDB table can be used by any number of infrastructure-as-code (IaC) environments for the same AWS account, **provided that each environment's backend configuration stanza specifies a different `key` value**.  Note in particular that the region where Terraform state is stored (us-east-2 by default) does not need to match the region(s) where other resources are being deployed.


## Escaping Catch-22

In general we strongly recommend that all infrastructure-as-code (IaC) environments be fully specified in source control and their Terraform state kept remotely in S3, so that you can easily destroy or modify them later on.

This bootstrap environment is a justifiable exception to the rule, since it creates just two simple resources which we NEVER intend to destroy.  Running the module once with interactive input and then throwing it away is a convenient and perfectly reasonable substitute for just creating the resources by hand using AWS CLI.

If you wish to do a bit of extra work, however, it is possible to follow the general rule for this environment too.  *After* performing the first successful apply (as above),

  3. Edit the values marked with '#FIXME' comments in `terraform.tfvars` and `backend.tf` and uncomment appropriately.
  4. Run `terraform init` and answer 'yes' to copy existing state from the local file to the new S3 backend.
  5. Run `terraform plan` to make sure there are no changes and that you are no longer prompted interactively for unset variables.
  6. Add this directory's `*.tf` and `terraform.tfvars` files (with your modifications) to source control.
     NB: do NOT add `.terraform/` or `terraform.tfstate` to source control.
