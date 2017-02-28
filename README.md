# AWS Enterprise VPC Example

This infrastructure-as-code (IaC) repository is intended to help you efficiently deploy your own Enterprise VPC as documented in [Amazon Web Services VPC Guide for Illinois](https://answers.uillinois.edu/illinois/page.php?id=71015).

There is no one-size-fits-all blueprint for an entire VPC; while they all generally have the same building blocks, the details can vary widely depending on your individual needs.  To that end, this repository provides:

  1. several reusable Terraform modules (under `modules/`) to construct the various individual components that make up an Enterprise VPC, abstracting away internal details where possible

  2. a set of example IaC environments for shared networking resources (`global/` and `vpc/`) which combine those modules and a few primitives together into a fully-functional Enterprise VPC

  3. an example service environment (`example-service/`) which demonstrates how to look up previously-created VPC and Subnet resources by tag:Name in order to build service-oriented resources on top of them, in this case launching an EC2 instance into one of the subnets.

_Note_: these same building blocks can also be used to construct an Independent VPC.

If you are not familiar with Terragrunt and Terraform, the six-part blog series [A Comprehensive Guide to Terraform](https://blog.gruntwork.io/a-comprehensive-guide-to-terraform-b3d32832baca) provides an excellent introduction and some good ideas for best practices.  That said, it should be possible to follow the Quick Start instructions below without first reading about these tools.

One thing you should know: **if at first you don't succeed, try "apply" again.**  Terraform is usually quite good at handling dependencies and concurrency for you behind the scenes, but once in a while you may encounter a transient AWS API error while trying to deploy many changes at once because it didn't wait quite long enough between steps.



## Quick Start
--------------

### Prerequisites

You will need:

1. an AWS account

2. an official name (e.g. 'aws-foobar-vpc') and IPv4 allocation (e.g. 10.x.y.0/24) for your Enterprise VPC

3. your own copy of this code, in your own source control repository (you can clone this one to use as a starting point), customized to reflect your AWS account and the specific subnets and other components you want your VPC to comprise

**At minimum, you must edit the values marked with '#FIXME' comments in the following files**:
   * in `.terragrunt`:
     - bucket
   * in `global/terraform.tfvars`:
     - account_id
   * in `vpc/terraform.tfvars`:
     - account_id
     - bucket
     - vpc_short_name
   * in `vpc/main.tf`:
     - all occurrences of cidr_block

You may wish to make other changes to `global/main.tf` and `vpc/main.tf` depending on your specific needs (e.g. to deploy more or fewer distinct subnets); some hints are included in the comments within those files.  If you leave everything else unchanged, the result will be an Enterprise VPC with six subnets (all three types duplicated across two Availability Zones) as shown in the Detailed Enterprise VPC Example diagram:
![Enterprise VPC Example diagram](https://answers.uillinois.edu/images/group180/71015/EnterpriseVPCExample.png)


### Workstation Setup

You can run this code from any workstation (even a laptop); there is no need for a dedicated deployment server.  The all-important Terraform state files are automatically synced to S3, so you can run it from a different workstation every day as long as you follow [the golden rule of Terraform](https://blog.gruntwork.io/how-to-use-terraform-as-a-team-251bc1104973#.nf92opnyn):
> "The master branch of the live repository is a 1:1 representation of what’s actually deployed in production."

_Note_: these instructions were written for a GNU/Linux workstation; some adaptation may be necessary for other operating systems.

1. Download the [Terragrunt](https://github.com/gruntwork-io/terragrunt/releases) binary for your system, make it executable (chmod +x), and put it somewhere on your PATH (e.g. `/usr/local/bin/terragrunt`)

2. Download [Terraform](https://www.terraform.io/downloads.html) for your system, extract the binary from the .zip archive, and put it somewhere **NOT** on your PATH (e.g. `/usr/local/libexec/terraform`) so that you won't accidentally invoke it directly.

3. Set environment variable `TERRAGRUNT_TFPATH=/usr/local/libexec/terraform` to tell Terragrunt where to find Terraform.

4. Install the [AWS Command Line Interface](http://docs.aws.amazon.com/cli/latest/userguide/) and configure it with an appropriate set of credentials to access your AWS account.

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

2. Deploy the `global` environment first.  This creates resources which apply to the entire AWS account:

       cd global
       terragrunt get
       terragrunt plan
       terragrunt apply
       cd ..

   * In addition to the required resources, this environment automatically deploys the [AWS Solution for monitoring VPN Connections](https://aws.amazon.com/answers/networking/vpn-monitor/), as well as a Simple Notification Service topic which will be used later to create alarm notifications based on this monitoring.

     If you wish to receive these alarm notifications by email, use the AWS CLI to subscribe one or more email addresses to the SNS topic (indicated by the Terraform output "vpn_monitor_arn"):

         aws sns subscribe --region us-east-1 --topic-arn arn:aws:sns:us-east-1:999999999999:vpn-monitor-topic \
          --protocol email --notification-endpoint my-email@example.com

     (then check your email and follow the confirmation instructions)

3. Deploy the `vpc` environment:

       cd vpc
       terragrunt get
       terragrunt plan
       terragrunt apply

   and generate the detailed output file needed for the next step:

       terragrunt output > details.txt

4. Contact Technology Services to enable Enterprise VPC networking features:

   * Do you need a Core Services VPC peering, VPN connections, or both?

   * Attach the `details.txt` file generated in the previous step.  This contains your AWS account number, your VPC's name, ID, and CIDR block, and additional configuration details (in XML format) for the on-campus side of each VPN connection.

5. If you requested a Core Services VPC peering connection, Technology Services will provide you with its ID.  Edit `vpc/terraform.tfvars` to add the new peering connection ID (enclosed in quotes), e.g.

       pcx_ids = ["pcx-abcd1234"]

   and deploy the `vpc` environment again; this will automatically accept the peering connection and add a corresponding route to each of your route tables (nothing else should change).

       cd vpc
       terragrunt plan
       terragrunt apply
       cd ..


### Example Service

If you like, you can now deploy the `example-service` environment to launch an EC2 instance in one of your new public-facing subnets (note that you will need to edit `example-service/terraform.tfvars`).

    cd example-service
    terragrunt plan
    terragrunt apply
    cd ..

If you do deploy this environment, be sure to `terragrunt destroy` it afterward (since it doesn't do anything useful).

Notice that the `example-service` code does _not_ directly depend on any of the shared networking code or the remote state it produces; it merely requires that the AWS account contains a VPC with a certain tag:Name, and that this VPC contains a Subnet with a certain tag:Name.



## Where To Go From Here
------------------------

After your VPC is deployed, the next logical step is to write additional infrastructure-as-code to deploy service-oriented resources into it (illustrated by `example-service/`).  In general, that code does _not_ need to reside in the same repository with the IaC for your shared networking resources which are used by many services; on the contrary, it is often advantageous to keep them separate.  A few helpful hints:

  * Don't change the name (i.e. tag:Name) of a VPC or Subnet once you deploy it.  This allows service IaC environments to reference VPC and Subnet objects by tag:Name, with the expectation that those values will remain stable even if for some reason the entire VPC must be rebuilt.

  * Multiple IaC repositories which use the same AWS account can all specify the same bucket in `.terragrunt`, **provided you replace the "Shared Networking" portion of the `key` and `state_file_id` values with a different string that is guaranteed to be unique for each such repository.**

    Note that our use of `path_relative_to_include()` ensures uniqueness for multiple environments _within_ the "Shared Networking" repository.


### Multiple VPCs

If you need to create a second VPC in the same AWS account, just copy the `vpc/` environment directory (**excluding** the `vpc/.terraform/` subdirectory, if any) to e.g. `vpc2/` and modify the necessary values in the new files.

    .
    ├── .terragrunt
    ├── global/
    ├── modules/
    ├── vpc/
    └── vpc2/

_Note_: you can name an environment directory however you like, but be very careful about modifying its name _after_ you have started using it, because the directory path is automatically interpolated by Terragrunt into the `key` used to store that environment's Terraform state file in S3.


### Multiple AWS accounts

If you wish to keep live infrastructure-as-code for several different AWS accounts in the same source control repository, put the code for each AWS account in a separate top-level directory with its own `.terragrunt` file (specifying an appropriate bucket for that account) and its own set of environments, e.g.

    .
    ├── account1/
    │   ├── .terragrunt
    │   ├── global/
    │   └── vpc/
    ├── account2/
    │   ├── .terragrunt
    │   ├── global/
    │   └── vpc/
    └── modules/
