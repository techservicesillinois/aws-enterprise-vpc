# AWS Enterprise VPC Example

This infrastructure-as-code (IaC) repository is intended to help you efficiently deploy your own Enterprise VPC, as documented in [Amazon Web Services VPC Guide for Illinois](https://answers.uillinois.edu/illinois/page.php?id=71015).

There is no one-size-fits-all blueprint for an entire VPC; while they all generally have the same building blocks, the details can vary widely depending on your individual needs.  To that end, this repository provides:

  1. a collection of reusable Terraform modules (under `modules/`) to construct the various individual components that make up an Enterprise VPC, abstracting away internal details where possible

  2. a set of example IaC environments for shared networking resources (`global/` and `vpc/`) which combine those modules and a few primitives together into a fully-functional Enterprise VPC

  3. an example service environment (`example-service/`) which demonstrates how to look up previously-created VPC and Subnet resources by tag:Name in order to build service-oriented resources on top of them, in this case launching an EC2 instance into one of the subnets.

_Note:_ these same building blocks can also be used to construct an Independent VPC.

If you are not familiar with Terraform, the six-part blog series [A Comprehensive Guide to Terraform](https://blog.gruntwork.io/a-comprehensive-guide-to-terraform-b3d32832baca) provides an excellent introduction, and there is also an official [Introduction to Terraform](https://www.terraform.io/intro/) which you may find helpful.  That said, it should be possible to follow the Quick Start instructions below _without_ first reading anything else.

One thing you should know: **if at first you don't succeed, try 'apply' again.**  Terraform is usually good at handling dependencies and concurrency for you behind the scenes, but once in a while you may encounter a transient AWS API error while trying to deploy many changes at once simply because Terraform didn't wait long enough between steps.



## Quick Start
--------------

### Prerequisites

You will need:

  * an AWS account which has been added to the appropriate [resource shares](https://docs.aws.amazon.com/ram/latest/userguide/working-with-shared.html) for your desired region

  * the Amazon Resource Names (ARNs) of those resource shares

  * an official name (e.g. "aws-foobar1-vpc") and IPv4 allocation (e.g. 10.x.y.0/24) for your Enterprise VPC

  * a suitably configured workstation (see "Workstation Setup" further down)

  * an S3 bucket **with versioning enabled** and a DynamoDB table with a specific schema, for remotely storing [Terraform state](https://www.terraform.io/docs/state/) in the [S3 backend](https://www.terraform.io/docs/backends/types/s3.html)

    _Caution:_ always obtain expert advice before rolling back or modifying a Terraform state file!

    See [`modules/bootstrap/README.md`](modules/bootstrap/README.md) to create these resources (only once per AWS account).

  * your own copy of the sample environment code, **customized** for your desired VPC and **stored in your own source control repository**

    Download the [latest release of this public repository](https://github.com/techservicesillinois/aws-enterprise-vpc/releases/latest) to use as a starting point.

    Note that you do _not_ need your own copy of the `modules/` directory; the [module source paths](https://www.terraform.io/docs/modules/sources.html) specified in the example environments point directly to this public repository.

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

You may wish to make additional changes based on your specific needs; read the comments for some hints.  If you leave everything else unchanged, the result will be an Enterprise VPC in us-east-2 (Ohio) with IPv6, four subnets (one public-facing and one campus-facing in each of two Availability Zones), and no NAT Gateways, i.e. many but not all of the elements shown in the Detailed Enterprise VPC Example diagram:
![Enterprise VPC Example diagram](https://answers.uillinois.edu/images/group180/71015/EnterpriseVPCExample.png)


### Workstation Setup

You can run this code from any workstation (even a laptop); there is no need for a dedicated deployment server.  Since the Terraform state is kept in S3, you can even run it from a different workstation every day, so long as you carefully follow the ["golden rule of Terraform"](https://blog.gruntwork.io/how-to-use-terraform-as-a-team-251bc1104973#7fe9):
> **"The master branch of the live [source control] repository should be a 1:1 representation of what’s actually deployed in production."**

If you just want to deploy your VPC as quickly as possible, you can install Terraform in [AWS CloudShell](https://docs.aws.amazon.com/cloudshell/latest/userguide/) like this:

    mkdir -p ~/.local/bin
    export VERSION=1.0.0
    wget -P /tmp https://releases.hashicorp.com/terraform/${VERSION}/terraform_${VERSION}_linux_amd64.zip
    unzip -d ~/.local/bin /tmp/terraform_${VERSION}_linux_amd64.zip
    terraform --version

However, if you're interested in using Terraform for other infrastructure-as-code (IaC) projects beyond this one, it is worthwhile to go ahead and set up your regular workstation:

  _Note: these instructions were written for GNU/Linux. Some adaptation may be necessary for other operating systems._

  1. [Download Terraform](https://www.terraform.io/downloads.html) for your system, extract the binary from the .zip archive, and put it somewhere on your PATH (e.g. `/usr/local/bin/terraform` or `~/.local/bin/terraform`)

  2. Install the [AWS Command Line Interface](http://docs.aws.amazon.com/cli/latest/userguide/) and optionally the [awscli-login plugin](https://github.com/techservicesillinois/awscli-login).  One convenient way to do this is:

         pip3 install --user --upgrade awscli awscli-login

     _Note:_ the `--user` scheme installs executables in the bin subdirectory of `python3 -m site --user-base` (often `~/.local/bin`); make sure this directory is on your PATH.

  3. Configure AWS CLI to use awscli-login:

         aws configure set plugins.login awscli_login

     and configure a [named profile](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html) which will use Shibboleth authentication to assume an appropriate Role in your AWS account:

         aws configure --profile uiuc-tech-services-sandbox
          AWS Access Key ID [None]: 
          AWS Secret Access Key [None]: 
          Default region name [None]: us-east-2
          Default output format [None]: json

         aws --profile uiuc-tech-services-sandbox login configure
          ECP Endpoint URL [None]: https://shibboleth.illinois.edu/idp/profile/SAML2/SOAP/ECP
          Username [None]: yournetid
          Enable Keyring [False]: 
          Duo Factor [None]: passcode
          Role ARN [None]: arn:aws:iam::378517677616:role/TechServicesStaff

     The profile name "uiuc-tech-services-sandbox" is arbitrary, but the Role ARN identifies a specific role to which you have been [granted access](https://answers.uillinois.edu/illinois/page.php?id=71883).

     Duo Factor may be `auto`, `push`, `passcode`, `sms`, or `phone`, or you can leave it blank in the profile to be prompted each time.  See also <https://github.com/techservicesillinois/awscli-login>

  4. Test that you can successfully interact with your AWS account:

         export AWS_PROFILE=uiuc-tech-services-sandbox
         aws login

         aws sts get-caller-identity
         aws iam list-account-aliases --output text
         aws ec2 describe-vpcs --output text

         aws logout
         unset AWS_PROFILE

     Safety tip: when finished, `aws logout` from the profile and either exit your current shell or explicitly unset `AWS_PROFILE` to minimize the opportunity for accidents.


### Deployment Steps

1. Set the `AWS_PROFILE` environment variable and run `aws login` if needed (see above).

2. Deploy the `global` environment first.  This creates resources which apply to the entire AWS account rather than to a single VPC.

       cd global
       terraform init
       terraform apply
       cd ..

   * The global environment automatically creates [Simple Notification Service](https://aws.amazon.com/sns/) topics which can be used later for optional [CloudWatch alarm notifications](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html#alarms-and-actions).

     If you wish to receive these alarm notifications by email, use the AWS CLI to subscribe one or more email addresses to the SNS topics (indicated by the Terraform output "vpn_monitor_arn"):

         aws sns subscribe --region us-east-2 --topic-arn arn:aws:sns:us-east-2:999999999999:vpn-monitor-topic \
          --protocol email --notification-endpoint my-email@example.com

     (then check your email and follow the confirmation instructions)

3. Next, deploy the `vpc` environment to create your VPC:

       cd vpc
       terraform init
       terraform apply

   and generate the detailed output file needed for the following step:

       terraform output -json > details.json.txt

4. Contact Technology Services to enable Enterprise VPC networking features.

   * Attach the `details.json.txt` file generated in the previous step.

   (The Core Services Transit Gateways _accept_ new attachments automatically, but will not _route_ to them until explicitly provisioned.)

5. By default, recursive DNS queries from instances within your VPC will be handled by [AmazonProvidedDNS](http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_DHCP_Options.html#AmazonDNS).  If you wish to use one of the other options documented in [Amazon Web Services Recursive DNS Guide for Illinois](https://answers.uillinois.edu/illinois/page.php?id=74081),

   * Edit `vpc/terraform.tfvars` to set `rdns_option` and `core_services_resolvers`

   * Deploy the `vpc` environment again (as above).

   _Note:_ be sure to read and understand [`modules/rdns-forwarder/README.md`](modules/rdns-forwarder/README.md) before deploying Option 3.



### Example Service

If you like, you can now deploy the `example-service` environment to launch an EC2 instance in one of your new public-facing subnets (note that you will need to edit `example-service/backend.tf` and `example-service/terraform.tfvars` first).

    cd example-service
    terraform init
    terraform apply

If you supplied values for `ssh_ipv4_cidr_blocks` and `ssh_public_key`, you should now be able to connect to the public IPv4 address of the instance (output by Terraform as `public_ip`) with e.g.

    ssh -i identity_file ec2-user@a.b.c.d

When you're done testing the example service environment, clean it up with `terraform destroy`.

Notice that the `example-service` code is _not_ tightly coupled to the `vpc` code (or Terraform state); it depends only upon finding an actual VPC and Subnet with the expected tag:Name values in your AWS account.



## Where To Go From Here
------------------------

After your VPC is deployed, the next logical step is to write additional infrastructure-as-code to deploy service-oriented resources into it (as illustrated by `example-service/`).  A few helpful hints:

  * In general, IaC for service-oriented resources does _not_ need to reside in the same source control repository as the IaC for your shared networking resources; on the contrary, it is often advantageous to maintain them separately.

  * Don't change the name (i.e. tag:Name) of a VPC or Subnet once you deploy it.  This allows service IaC environments to reference VPC and Subnet objects by tag:Name, with the expectation that those values will remain stable even if the objects themselves must be destroyed and rebuilt (resulting in new IDs and ARNs).

  * Multiple IaC environments for the same AWS account can share the same S3 bucket for Terraform state, **provided that each environment's backend configuration stanza specifies a different `key` value**.

    Of course you can name them however you like, but this example code suggests the following pattern:

        key = "Shared Networking/global/terraform.tfstate"
        key = "Shared Networking/vpc/terraform.tfstate"

    where 'Shared Networking' is meant to uniquely identify this IaC _repository_, and 'global' or 'vpc' the specific environment directory within this repository.

    Note that the key for `example-service` does _not_ begin with 'Shared Networking' because it's a separate piece of IaC which would normally reside in its own repository.


### Multiple VPCs

To create a second VPC in the same AWS account, just copy the `vpc/` environment directory (**excluding** the `vpc/.terraform/` subdirectory, if any) to e.g. `another-vpc/` and modify the necessary values in the new files.

**IMPORTANT**: **don't forget to change `key`** in the backend configuration stanza of `another-vpc/backend.tf` before running Terraform in the new environment!

    .
    ├── bootstrap/ (optional)
    ├── global/
    ├── vpc/
    └── another-vpc/

You may find it convenient to name the VPC environment directories after the VPCs themselves (e.g. "foobar1-vpc").


#### Multiple Regions

To create your new VPC in a different region, simply edit the `region` variable value in e.g. `another-vpc/terraform.tfvars`.

* Do _not_ modify the hardcoded region names in `another-vpc/backend.tf`; this is the region of the S3 bucket for Terraform state, which does not depend on the region(s) of your VPCs.

* You _may_ need to add more per-region singleton resources in `global/main.tf` (following the established patterns).


### Multiple AWS accounts

If you wish to keep IaC for several different AWS accounts in the same repository, put the code for each AWS account in a separate top-level directory with its own set of environments, e.g.

    .
    ├── account1/
    │   ├── bootstrap/ (optional)
    │   ├── global/
    │   └── vpc/
    └── account2/
        ├── bootstrap/ (optional)
        ├── global/
        └── vpc/

Note that each AWS account will need its own separate S3 bucket for Terraform state.


### Destroying VPCs

The example `vpc/main.tf` uses [`prevent_destroy`](https://www.terraform.io/docs/language/meta-arguments/lifecycle.html#prevent_destroy) to guard against inadvertent destruction of certain resources; if you really need to destroy your entire VPC, you must first comment out each occurrence of this flag.  **Please note: if you destroy and subsequently recreate your VPC, you will need to contact Technology Services again to re-enable Enterprise Networking features for the new VPC.**

Additionally, Terraform cannot successfully destroy a VPC until all other resources that depend on that VPC have been removed.  Unfortunately, the error message returned by the [AWS API method](https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_DeleteVpc.html) and printed by Terraform in this case does not provide any indication of _which_ resources are the obstacle:

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

What this means (using hypothetical version numbers) is that if you base your own live IaC on the example environment code from release `v1.2.3`, and later run `terraform get -update` (or `terraform init` on a different workstation),
* You will automatically receive any module changes released as `v1.2.4` (which should be safe), because they appear on the `v1.2` branch.
* You will _not_ automatically receive any module changes released as `v1.3.*` or `v2.0.*` (since these changes might be incompatible with your usage and/or involve refactoring that could cause Terraform to unexpectedly destroy and recreate existing resources).

Upgrading existing deployments to a new MAJOR.MINOR version is discussed in [`UPGRADING.md`](UPGRADING.md)



## Known Issues
---------------

* none
