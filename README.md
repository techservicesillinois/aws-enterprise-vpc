# AWS Enterprise VPC Example

This infrastructure-as-code (IaC) repository is intended to help you efficiently deploy your own Enterprise VPC, as documented in [Amazon Web Services VPC Guide for Illinois](https://answers.uillinois.edu/illinois/page.php?id=71015).

There is no one-size-fits-all blueprint for an entire VPC; while they all generally have the same building blocks, the details can vary widely depending on your individual needs.  To that end, this repository provides:

  1. a collection of reusable Terraform modules (under `modules/`) to construct the various individual components that make up an Enterprise VPC, abstracting away internal details where possible

  2. a set of example IaC environments for shared networking resources (`global/` and `vpc/`) which combine those modules and a few primitives together into a fully-functional Enterprise VPC

  3. an example service environment (`example-service/`) which demonstrates how to look up previously-created VPC and Subnet resources by tag:Name in order to build service-oriented resources on top of them, in this case launching an EC2 instance into one of the subnets.

_Note_: these same building blocks can also be used to construct an Independent VPC.

If you are not familiar with Terraform, the six-part blog series [A Comprehensive Guide to Terraform](https://blog.gruntwork.io/a-comprehensive-guide-to-terraform-b3d32832baca) provides an excellent introduction.  You can also consult Terraform's official [Getting Started Guide](https://www.terraform.io/intro/getting-started/install.html).  That said, it should be possible to follow the Quick Start instructions below _without_ first reading anything else.

One thing you should know: **if at first you don't succeed, try 'apply' again.**  Terraform is usually good at handling dependencies and concurrency for you behind the scenes, but once in a while you may encounter a transient AWS API error while trying to deploy many changes at once simply because Terraform didn't wait long enough between steps.



## Quick Start
--------------

### Prerequisites

You will need:

  * an AWS account which has been added to the appropriate [resource shares](https://docs.aws.amazon.com/ram/latest/userguide/working-with-shared.html)

  * an official name (e.g. "aws-foobar1-vpc") and IPv4 allocation (e.g. 10.x.y.0/24) for your Enterprise VPC

  * an S3 bucket **with versioning enabled** for storing [Terraform state](https://www.terraform.io/docs/state/), and a DynamoDB table for state locking (see also https://www.terraform.io/docs/backends/types/s3.html).

    _Caution_: always obtain expert advice before rolling back or modifying a Terraform state file!

    To create these resources (once per AWS account):

    1. Set up the AWS Command Line Interface on your workstation (see "Workstation Setup" further down).

    2. Choose a [valid S3 bucket name](http://docs.aws.amazon.com/AmazonS3/latest/dev/BucketRestrictions.html#bucketnamingrules).

       * S3 bucket names are _globally_ unique, so you must choose one that is not already in use by another AWS account. One possible strategy is to use the pattern

             bucket = "terraform.uiuc-tech-services-sandbox.aws.illinois.edu"

         replacing 'uiuc-tech-services-sandbox' with the friendly name of your AWS account.

    3. Use AWS CLI to create the chosen bucket (replacing 'FIXME') and enable versioning:

           aws s3api create-bucket --create-bucket-configuration LocationConstraint=us-east-2 \
             --bucket FIXME
           aws s3api put-bucket-versioning --versioning-configuration Status=Enabled \
             --bucket FIXME

    4. Use AWS CLI to create a DynamoDB table for state locking, called "terraform" (this name does _not_ need to be globally unique):

           aws dynamodb create-table --region us-east-2 --table-name terraform \
             --attribute-definitions AttributeName=LockID,AttributeType=S \
             --key-schema AttributeName=LockID,KeyType=HASH \
             --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1

  * your own copy of the sample environment code, in your own source control repository, **customized** to reflect your AWS account and the specific subnets and other components you want your VPC to comprise.

    Download the [latest release of this repository](https://github.com/techservicesillinois/aws-enterprise-vpc/releases/latest) to use as a starting point.

    Note that you do _not_ need your own copy of the module code; the [module source paths](https://www.terraform.io/docs/modules/sources.html) specified in the example environments point directly to this online repository.

**At minimum, you must edit the values marked with '#FIXME' comments in the following files**:
   * in `global/backend.tf`:
     - bucket
   * in `global/terraform.tfvars`:
     - account_id
     - resource_share_arns
   * in `vpc/backend.tf`:
     - bucket (2 occurrences, same value)
   * in `vpc/terraform.tfvars`:
     - account_id
     - vpc_short_name
     - vpc_cidr_block
     - cidr_block (multiple occurrences, all different values)

Hint: <http://jodies.de/ipcalc-archive/ipcalc-0.41/ipcalc> can help you with subnet math.  Use e.g. `ipcalc 10.x.y.0/24 26 --nobinary` to display all possible /26 subnets within your VPC allocation, and `ipcalc 10.x.y.0/24 27 --nobinary` to display all possible /27 subnets.  You can mix and match subnets of different sizes to suit your needs as long as the actual addresses don't overlap (i.e. the Broadcast address at the end of the first subnet you choose must be smaller than the base Network address at the beginning of the second one, and so on).

You may wish to make additional changes depending on your specific needs (e.g. to deploy more or fewer distinct subnets); read the comments for some hints.

If you leave everything else unchanged, the result will be an Enterprise VPC in us-east-2 (Ohio) with four subnets (one public-facing and one campus-facing in each of two Availability Zones), i.e. many but not all of the elements shown in the Detailed Enterprise VPC Example diagram:
![Enterprise VPC Example diagram](https://answers.uillinois.edu/images/group180/71015/EnterpriseVPCExample.png)


### Workstation Setup

_Note: these instructions were written for GNU/Linux. Some adaptation may be necessary for other operating systems._

You can run this code from any workstation (even a laptop); there is no need for a dedicated deployment server.  Since the Terraform state is kept in S3, you can even run it from a different workstation every day, so long as you carefully follow [the golden rule of Terraform](https://blog.gruntwork.io/how-to-use-terraform-as-a-team-251bc1104973#7fe9):
> **"The master branch of the live [source control] repository should be a 1:1 representation of what’s actually deployed in production."**

To set up a new workstation:

1. Download [Terraform](https://www.terraform.io/downloads.html) for your system, extract the binary from the .zip archive, and put it somewhere on your PATH (e.g. `/usr/local/bin/terraform`)

2. Install the [AWS Command Line Interface](http://docs.aws.amazon.com/cli/latest/userguide/) and configure it with an appropriate set of credentials to access your AWS account.

   * You may find it convenient to use a named profile in order to easily switch between multiple AWS accounts on the same workstation:

         aws configure --profile uiuc-tech-services-sandbox
         AWS Access Key ID [None]: XXX
         AWS Secret Access Key [None]: YYY
         Default region name [None]: us-east-2
         Default output format [None]: json

     If you do, set the `AWS_PROFILE` environment variable so that Terraform (as well as the AWS CLI itself) will know which set of credentials to use:

         export AWS_PROFILE=uiuc-tech-services-sandbox

   * Verify that you can successfully run `aws ec2 describe-vpcs` from the command line and get a response.


### Deployment Steps

1. Set `AWS_PROFILE` if needed (see above).

2. Deploy the `global` environment first.  This creates resources which apply to the entire AWS account rather than to a single VPC.

       cd global
       terraform init
       terraform apply
       cd ..

3. Next, deploy the `vpc` environment to create your VPC:

       cd vpc
       terraform init
       terraform apply

   and generate the detailed output file needed for the following step:

       terraform output -json > details.json

4. Contact Technology Services to enable Enterprise VPC networking features.

   * Attach the `details.json` file generated in the previous step.

5. By default, recursive DNS queries from instances within your VPC will be handled by [AmazonProvidedDNS](http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_DHCP_Options.html#AmazonDNS).  If you wish to use one of the other options documented in [Amazon Web Services Recursive DNS Guide for Illinois](https://answers.uillinois.edu/illinois/page.php?id=74081),

   * Edit `vpc/terraform.tfvars` to set `rdns_option` and `core_services_resolvers`

   * Deploy the `vpc` environment again (as above).

   _Note_: be sure to read and understand [`modules/rdns-forwarder/README.md`](modules/rdns-forwarder/README.md) before deploying Option 3.



### Example Service

If you like, you can now deploy the `example-service` environment to launch an EC2 instance in one of your new public-facing subnets (note that you will need to edit `example-service/backend.tf` and `example-service/terraform.tfvars` first).

    cd example-service
    terraform init
    terraform apply
    cd ..

When you're done testing the example-service environment, be sure to clean it up with `terraform destroy`.

Notice that the `example-service` code does _not_ directly depend on any of the shared networking code or the remote state it produces; it merely requires that the AWS account contains a VPC with a certain tag:Name, and that this VPC contains a Subnet with a certain tag:Name.



## Where To Go From Here
------------------------

After your VPC is deployed, the next logical step is to write additional infrastructure-as-code to deploy service-oriented resources into it (as illustrated by `example-service/`).  In general, IaC for service-oriented resources does _not_ need to reside in the same source control repository as the IaC for your shared networking resources; on the contrary, it is often advantageous to keep them separate.  A few helpful hints:

  * Don't change the name (i.e. tag:Name) of a VPC or Subnet once you deploy it.  This allows service IaC environments to reference VPC and Subnet objects by tag:Name, with the expectation that those values will remain stable even if for some reason the entire VPC has to be rebuilt.

  * Multiple IaC environments for the same AWS account can all use the same S3 bucket and DynamoDB table for Terraform state, **provided that each environment's backend configuration stanza specifies a different `key` value**.

    This example code suggests the following pattern:

        key = "Shared Networking/global/terraform.tfstate"
        key = "Shared Networking/vpc/terraform.tfstate"

    where 'Shared Networking' is meant to uniquely identify this IaC _repository_, and 'global' or 'vpc' the environment directory within this repository.

    Note that the key for `example-service` does _not_ begin with 'Shared Networking' because it's a separate piece of IaC which would normally reside in its own repository.


### Multiple VPCs

To create a second VPC in the same AWS account, just copy the `vpc/` environment directory (**excluding** the `vpc/.terraform/` subdirectory, if any) to e.g. `other-vpc/` and modify the necessary values in the new files.

**IMPORTANT**: **don't forget to change `key`** in the backend configuration stanza of `other-vpc/backend.tf` before running any Terraform commands!

    .
    ├── global/
    ├── vpc/
    └── other-vpc/

You may find it convenient to name the environment directories after the VPCs themselves (e.g. "foobar1-vpc").


#### Multiple Regions

To create your new VPC in a different region, simply edit the `region` variable value in e.g. `other-vpc/terraform.tfvars`.

* This does _not_ require modifying the hardcoded region names in `other-vpc/backend.tf` (or the prerequisite steps of this document); those singleton items are independent of which region the VPC itself is deployed into.

* You _may_ need to add more per-region singleton resources in `global/main.tf` (following the established pattern)


### Multiple AWS accounts

If you wish to keep IaC for several different AWS accounts in the same repository, put the code for each AWS account in a separate top-level directory with its own set of environments, e.g.

    .
    ├── account1/
    │   ├── global/
    │   └── vpc/
    └── account2/
        ├── global/
        └── vpc/

Note that each AWS account will need to use a different S3 bucket for Terraform state.


### Destroying VPCs

The example `vpc/main.tf` uses [`prevent_destroy`](https://www.terraform.io/docs/configuration/resources.html#prevent_destroy) to guard against inadvertent destruction of certain resources; if you really need to destroy your entire VPC, you must first comment out each occurrence of this flag.  **Please note: if you destroy and subsequently recreate your VPC, you will need to contact Technology Services again to re-enable Enterprise Networking features for the new VPC.**

In order for Terraform to successfully destroy a VPC, all other resources that depend on that VPC must be removed first.  Unfortunately, the error message returned by the [AWS API method](https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_DeleteVpc.html) and printed by Terraform does not provide any indication of _which_ resources are the obstacle:

    aws_vpc.vpc: DependencyViolation: The vpc 'vpc-abcd1234' has dependencies and cannot be deleted.
	  status code: 400, request id: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

If you find yourself in this situation, here is a set of AWS CLI commands (using bash-style variable substitution syntax) which may help you identify resources which are still associated with the VPC:

    export VPC_ID=vpc-abcd1234
    export VPC_REGION=us-east-2
    aws ec2 describe-subnets --region $VPC_REGION --filters Name=vpc-id,Values=$VPC_ID
    aws ec2 describe-security-groups --region $VPC_REGION --filters Name=vpc-id,Values=$VPC_ID --query 'SecurityGroups[?GroupName!=`default`]'
    aws ec2 describe-internet-gateways --region $VPC_REGION --filters Name=attachment.vpc-id,Values=$VPC_ID
    aws ec2 describe-vpn-gateways --region $VPC_REGION --filters Name=attachment.vpc-id,Values=$VPC_ID --query 'VpnGateways[?State!=`deleted`]'
    aws ec2 describe-nat-gateways --region $VPC_REGION --filter Name=vpc-id,Values=$VPC_ID --query 'NatGateways[?State!=`deleted`]'
    aws ec2 describe-vpc-endpoints --region $VPC_REGION --filters Name=vpc-id,Values=$VPC_ID
    aws ec2 describe-vpc-peering-connections --region $VPC_REGION --filters Name=accepter-vpc-info.vpc-id,Values=$VPC_ID
    aws ec2 describe-vpc-peering-connections --region $VPC_REGION --filters Name=requester-vpc-info.vpc-id,Values=$VPC_ID
    aws ec2 describe-route-tables --region $VPC_REGION --filters Name=vpc-id,Values=$VPC_ID --query 'RouteTables[?Associations[?Main==`false`]]'
    aws ec2 describe-network-interfaces --region $VPC_REGION --filters Name=vpc-id,Values=$VPC_ID



## Versioning
-------------

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).  Noteworthy changes in each release are documented in [`CHANGELOG.md`](CHANGELOG.md)

MAJOR.MINOR.PATCH versions of this repository are immutable releases tracked with git tags, e.g. `vX.Y.Z`.

MAJOR.MINOR versions of this repository are tracked as git branches, e.g. `vX.Y`.  These are mutable, but only for non-breaking changes (once `vX.Y.0` has been released).

All [module source paths](https://www.terraform.io/docs/modules/sources.html) used within the code specify a `vX.Y` branch.

What this means (using hypothetical version numbers) is that if you base your own live IaC on the example environment code from release `v1.2.3`, and then re-run it in the future after a `terraform get -update`,
* You will automatically receive any module changes released as `v1.2.4` (which should be safe), because they appear on the `v1.2` branch.
* You will _not_ automatically receive any module changes released as `v1.3.*` or `v2.0.*` (which might be incompatible with your usage and/or involve refactoring that could cause Terraform to unexpectedly destroy and recreate existing resources).

Upgrading existing deployments to a new MAJOR.MINOR version is discussed in [`UPGRADING.md`](UPGRADING.md)



## Known Issues
---------------

* Terraform cannot remove IPv6 from a subnet once enabled [https://github.com/terraform-providers/terraform-provider-aws/issues/10815]
