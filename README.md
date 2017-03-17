# AWS Enterprise VPC Example

This infrastructure-as-code (IaC) repository is intended to help you efficiently deploy your own Enterprise VPC, as documented in [Amazon Web Services VPC Guide for Illinois](https://answers.uillinois.edu/illinois/page.php?id=71015).

There is no one-size-fits-all blueprint for an entire VPC; while they all generally have the same building blocks, the details can vary widely depending on your individual needs.  To that end, this repository provides:

  1. several reusable Terraform modules (under `modules/`) to construct the various individual components that make up an Enterprise VPC, abstracting away internal details where possible

  2. a set of example IaC environments for shared networking resources (`global/` and `vpc/`) which combine those modules and a few primitives together into a fully-functional Enterprise VPC

  3. an example service environment (`example-service/`) which demonstrates how to look up previously-created VPC and Subnet resources by tag:Name in order to build service-oriented resources on top of them, in this case launching an EC2 instance into one of the subnets.

_Note_: these same building blocks can also be used to construct an Independent VPC.

If you are not familiar with Terraform, the six-part blog series [A Comprehensive Guide to Terraform](https://blog.gruntwork.io/a-comprehensive-guide-to-terraform-b3d32832baca) provides an excellent introduction, though some details are now obsolete due to recent improvements in Terraform (for example, we no longer need the separate "Terragrunt" tool to effectively manage remote state configuration).  You can also consult Terraform's official [Getting Started Guide](https://www.terraform.io/intro/getting-started/install.html).  That said, it should be possible to follow the Quick Start instructions below _without_ first reading anything else.

One thing you should know: **if at first you don't succeed, try "apply" again.**  Terraform is usually quite good at handling dependencies and concurrency for you behind the scenes, but once in a while you may encounter a transient AWS API error while trying to deploy many changes at once because Terraform didn't wait long enough between steps.



## Quick Start
--------------

### Prerequisites

You will need:

  * an AWS account

  * an official name (e.g. "aws-foobar-vpc") and IPv4 allocation (e.g. 10.x.y.0/24) for your Enterprise VPC

  * an S3 bucket **with versioning enabled** for storing Terraform state, and a DynamoDB table for state locking (see also https://www.terraform.io/docs/backends/types/s3.html)

    1. Choose a [valid S3 bucket name](http://docs.aws.amazon.com/AmazonS3/latest/dev/BucketRestrictions.html#bucketnamingrules).

       * S3 bucket names are _globally_ unique, so you must choose one that is not already in use by another AWS account. One possible strategy is to use the pattern

             bucket = "terraform.uiuc-tech-services-sandbox.aws.illinois.edu"

         replacing "uiuc-tech-services-sandbox" with the friendly name of your AWS account.

    2. Use AWS CLI to create the chosen bucket (replacing FIXME) and enable versioning:

           aws s3api create-bucket --create-bucket-configuration LocationConstraint=us-east-2 --bucket FIXME && \
             aws s3api put-bucket-versioning --versioning-configuration Status=Enabled --bucket FIXME

    3. Use AWS CLI to create a DynamoDB table for state locking called "terraform" (this name does _not_ need to be globally unique):

           aws dynamodb create-table --region us-east-2 --table-name terraform \
               --attribute-definitions AttributeName=LockID,AttributeType=S \
               --key-schema AttributeName=LockID,KeyType=HASH \
               --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1

  * your own copy of this code, in your own source control repository (you can clone this one to use as a starting point), **customized** to reflect your AWS account and the specific subnets and other components you want your VPC to comprise

**At minimum, you must edit the values marked with '#FIXME' comments in the following files**:
   * in `global/terraform.tfvars`:
     - account_id
   * in `global/main.tf`:
     - bucket
   * in `vpc/terraform.tfvars`:
     - account_id
     - vpc_short_name
   * in `vpc/main.tf`:
     - bucket (2 occurrences, same value)
     - cidr_block (multiple occurrences, all different values)

You may wish to make other changes to `global/main.tf` and `vpc/main.tf` depending on your specific needs (e.g. to deploy more or fewer distinct subnets); some hints are included in the comments within those files.  Note in particular that quite a few components can be omitted if you don't need any campus-facing subnets.

If you leave everything else unchanged, the result will be an Enterprise VPC with six subnets (all three types duplicated across two Availability Zones) as shown in the Detailed Enterprise VPC Example diagram:
![Enterprise VPC Example diagram](https://answers.uillinois.edu/images/group180/71015/EnterpriseVPCExample.png)


### Workstation Setup

_Note: these instructions were written for GNU/Linux. Some adaptation may be necessary for other operating systems._

You can run this code from any workstation (even a laptop); there is no need for a dedicated deployment server.  Since the Terraform state is kept in S3, you can even run it from a different workstation every day, so long as you carefully follow [the golden rule of Terraform](https://blog.gruntwork.io/how-to-use-terraform-as-a-team-251bc1104973#.nf92opnyn):
> **"The master branch of the live [source control] repository is a 1:1 representation of what’s actually deployed in production."**

To set up a new workstation:

1. Download [Terraform](https://www.terraform.io/downloads.html) for your system, extract the binary from the .zip archive, and put it somewhere on your PATH (e.g. `/usr/local/bin/terraform`)

2. Install the [AWS Command Line Interface](http://docs.aws.amazon.com/cli/latest/userguide/) and configure it with an appropriate set of credentials to access your AWS account.

   * You may find it convenient to use a named profile in order to easily switch between multiple AWS accounts on the same workstation:

         aws configure --profile uiuc-tech-services-sandbox
         AWS Access Key ID [None]: XXX
         AWS Secret Access Key [None]: YYY
         Default region name [None]: us-east-2
         Default output format [None]: json

     If you do, set the `AWS_PROFILE` environment variable so that Terragrunt and Terraform (as well as the AWS CLI itself) will know which set of credentials to use:

         export AWS_PROFILE=uiuc-tech-services-sandbox

   * Verify that you can successfully run `aws ec2 describe-vpcs` from the command line and get a response.


### Deployment Steps

1. Set `AWS_PROFILE` if needed (see above).

2. Deploy the `global` environment first.  This creates resources which apply to the entire AWS account.

       cd global
       terraform init
       terraform plan
       terraform apply
       cd ..

   * As an optional feature, this environment automatically deploys the [AWS Solution for monitoring VPN Connections](https://aws.amazon.com/answers/networking/vpn-monitor/) and a Simple Notification Service topic which will be used later (by modules/vpn-connection) to create alarm notifications based on this monitoring.

     If you wish to receive these alarm notifications by email, use the AWS CLI to subscribe one or more email addresses to the SNS topic (indicated by the Terraform output "vpn_monitor_arn"):

         aws sns subscribe --region us-east-1 --topic-arn arn:aws:sns:us-east-1:999999999999:vpn-monitor-topic \
          --protocol email --notification-endpoint my-email@example.com

     (then check your email and follow the confirmation instructions)

3. Deploy the `vpc` environment:

       cd vpc
       terraform init
       terraform plan
       terraform apply

   and generate the detailed output file needed for the next step:

       terraform output > details.txt

4. Contact Technology Services to enable Enterprise VPC networking features:

   * Do you need a Core Services VPC peering, VPN connections, or both?

   * Attach the `details.txt` file generated in the previous step.  This contains your AWS account number, your VPC's name, ID, and CIDR block, and additional configuration details (in XML format) for the on-campus side of each VPN connection.

5. If you requested a Core Services VPC peering connection, Technology Services will initiate one and provide you with its ID.  Edit `vpc/terraform.tfvars` to add the new peering connection ID (enclosed in quotes), e.g.

       pcx_ids = ["pcx-abcd1234"]

   and deploy the `vpc` environment again; this will automatically accept the peering connection and add a corresponding route to each of your route tables (nothing else should change).

       cd vpc
       terraform plan
       terraform apply
       cd ..


### Example Service

If you like, you can now deploy the `example-service` environment to launch an EC2 instance in one of your new public-facing subnets (note that you will need to edit `example-service/main.tf` and `example-service/terraform.tfvars` first).

    cd example-service
    terraform init
    terraform plan
    terraform apply
    cd ..

If you do deploy this environment, be sure to `terraform destroy` it afterward (since it doesn't do anything useful).

Notice that the `example-service` code does _not_ directly depend on any of the shared networking code or the remote state it produces; it merely requires that the AWS account contains a VPC with a certain tag:Name, and that this VPC contains a Subnet with a certain tag:Name.



## Where To Go From Here
------------------------

After your VPC is deployed, the next logical step is to write additional infrastructure-as-code to deploy service-oriented resources into it (as illustrated by `example-service/`).  In general, IaC for service-oriented resources does _not_ need to reside in the same source control repository as the IaC for your shared networking resources; on the contrary, it is often advantageous to keep them separate.  A few helpful hints:

  * Don't change the name (i.e. tag:Name) of a VPC or Subnet once you deploy it.  This allows service IaC environments to reference VPC and Subnet objects by tag:Name, with the expectation that those values will remain stable even if for some reason the entire VPC must be rebuilt.

  * Multiple IaC environments for the same AWS account can all use the same S3 bucket and DynamoDB table for Terraform state, **provided that each environment's backend configuration stanza specifies a different `key` value**.

    This example code suggests the following pattern:

        key = "Shared Networking/global/terraform.tfstate"
        key = "Shared Networking/vpc/terraform.tfstate"

    where "Shared Networking" is meant to uniquely identify this IaC _repository_, and "global" or "vpc" the environment directory within this repository.


### Multiple VPCs

If you need to create a second VPC in the same AWS account, just copy the `vpc/` environment directory (**excluding** the `vpc/.terraform/` subdirectory, if any) to e.g. `vpc2/` and modify the necessary values in the new files.

Important: **don't forget to change `key`** in the backend configuration stanza of `vpc2/main.tf`

    .
    ├── global/
    ├── modules/
    ├── vpc/
    └── vpc2/


### Multiple AWS accounts

If you wish to keep IaC for several different AWS accounts in the same repository, put the code for each AWS account in a separate top-level directory with its own set of environments, e.g.

    .
    ├── account1/
    │   ├── global/
    │   └── vpc/
    ├── account2/
    │   ├── global/
    │   └── vpc/
    └── modules/

Note that each AWS account will need to use a different S3 bucket for Terraform state.



## Known Issues
---------------

* After adding a VPC Peering Connection to pcx_ids, each subsequent run rebuilds the route table entries correponding to the peering connection (e.g. `module.public1-a-net.subnet.aws_route.pcx`).  This appears to be a consequence of https://github.com/hashicorp/terraform/issues/3449 and will hopefully be fixed by a future Terraform release.

* Due to https://github.com/hashicorp/terraform/issues/12935, removing previously-configured VPC Peering Connections by emptying `pcx_ids` may result in errors like this:

  > module.public1-a-net.module.subnet.data.aws_vpc_peering_connection.pcx: list "var.pcx_ids" does not have any elements so cannot determine type.

  The workaround is to manually remove the offending data source's existing state:

      terraform state rm module.public1-a-net.module.subnet.data.aws_vpc_peering_connection.pcx

Wishlist:
- public github repository for this code (and replace local module paths with git paths)
- include optional RDNS Forwarders (and DHCP options)
