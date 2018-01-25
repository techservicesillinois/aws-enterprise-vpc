# AWS Recursive DNS Forwarder

This directory provides both a Terraform module and an ansible-pull playbook to launch and configure an EC2 instance which will serve as a [**Recursive DNS Forwarder**](https://answers.uillinois.edu/illinois/page.php?id=74081) for your [Enterprise VPC](https://answers.uillinois.edu/illinois/page.php?id=71015).

RDNS Forwarders accept and answer recursive DNS queries _only_ from clients within your VPC.

  * If the query is for a University domain, your RDNS Forwarder forwards it to the **Core Services Resolvers** located in your peer Core Services VPC.  These resolvers are able to resolve DNS records in zones which are restricted to University clients only.

  * If the query is for any other domain, your RDNS Forwarder instead forwards it to [AmazonProvidedDNS](http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_DHCP_Options.html#AmazonDNS).  AmazonProvidedDNS offers some special features whose behavior is specific to your VPC (and therefore cannot be implemented by the Core Services Resolvers).


## Automated Updates

RDNS Forwarders are designed to run completely unattended.  They use cron and [ansible-pull](http://docs.ansible.com/ansible/playbooks_intro.html#ansible-pull) to perform two distinct types of automated self-updates:

  * Once per hour, the *zone configuration* (i.e. which individual zones' queries should be forwarded to the Core Services Resolvers as opposed to AmazonProvidedDNS) is updated to reflect the latest list of zones maintained by the [IP Address Management service](http://techservices.illinois.edu/services/ip-address-management), and `named` is instructed to reload the new configuration if it has changed.

  * Once per month, a *full update* is performed based on the ansible code published in this git repository.  This includes a `yum -y update` to get the latest versions of all installed system packages; note that [Amazon Linux is maintained as a rolling release](https://aws.amazon.com/amazon-linux-ami/faqs/#updates_frequency), so the available package updates are not limited to a specific AMI version.

    **The full update often involves a reboot, during which time the RDNS Forwarder will briefly stop answering queries.**

To avoid impacting other resources in your VPC, please observe the following recommendations:

  1. Deploy at least two RDNS Forwarders and configure them to perform their automated updates at different times.

  2. Periodically test (from within your VPC) that each of your RDNS Forwarders can successfully answer queries for at least one University domain and at least one non-University domain.

  3. If you ever need to destroy and recreate an RDNS Forwarder (e.g. to upgrade to a larger size instance, or to a new MAJOR.MINOR version branch of this repository),
     * Take down only one RDNS Forwarder at a time.
     * Test the other one first to make sure it is working as expected.
     * Be sure the other one is not scheduled to perform its automated full update during your maintenance window.


## Troubleshooting

If an RDNS Forwarder stops working, destroy and recreate it from scratch.

If a _newly created_ RDNS Forwarder (using the latest release of this repository) doesn't work, contact Technology Services for help.  Note that a newly created RDNS Forwarder may take up to 5 minutes to configure itself and begin answering queries.

System logs are published in [CloudWatch Logs](http://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/) to help with post-mortem analysis of problems.


## How to Deploy

The AWS Enterprise VPC Example environment code includes a working example of how to deploy RDNS Forwarders in `rdns.tf`.  This section explains the module usage in greater detail.

0. Make sure that:
   * your Enterprise VPC has a VPC peering connection to a Core Services VPC
   * you know the IPv4 addresses of the Core Services Resolvers within that particular Core Services VPC 

1. Within your Enterprise VPC Shared Networking infrastructure-as-code (IaC), use this module to deploy at least two RDNS Forwarders (for redundancy).  We suggest placing them in different public-facing Subnets in different Availability Zones, with staggered update times.  For example:

     ```hcl
     module "rdns-a" {
       source = "git::https://github.com/cites-illinois/aws-enterprise-vpc.git//modules/rdns-forwarder?ref=vX.Y" #FIXME
       tags = {
         Name = "${var.vpc_short_name}-rdns-a"
       }
       instance_type            = "t2.micro"
       core_services_resolvers  = ["10.224.1.50", "10.224.1.100"] #FIXME
       subnet_id                = "${module.public1-a-net.id}"
       private_ip               = "192.168.0.5" #FIXME
       zone_update_minute       = "5"
       full_update_day_of_month = "1"
     }

     module "rdns-b" {
       source = "git::https://github.com/cites-illinois/aws-enterprise-vpc.git//modules/rdns-forwarder?ref=vX.Y" #FIXME
       tags = {
           Name = "${var.vpc_short_name}-rdns-b"
       }
       instance_type            = "t2.micro"
       core_services_resolvers  = ["10.224.1.50", "10.224.1.100"] #FIXME
       subnet_id                = "${module.public1-b-net.id}"
       private_ip               = "192.168.1.5" #FIXME
       zone_update_minute       = "35"
       full_update_day_of_month = "15"
     }
     ```

   Notes:

     * Do not set `full_update_day_of_month` higher than 28!

     * You can also specify `full_update_hour` and `full_update_minute` if you want; the defaults correspond to 08:17 UTC.

     * Using a public-facing subnet is simplest, but a campus-facing or private-facing subnet will also work as long as it has outbound Internet connectivity (via a NAT Gateway).  If you do use a campus-facing or private-facing subnet, you must also specify `associate_public_ip_address = false` in the module parameters.

2. Deploy a custom [VPC DHCP Options Set](http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_DHCP_Options.html) which instructs other instances in your VPC to send their DNS queries to the private IP addresses of your RDNS Forwarders, and associate that DHCP Options Set with the VPC.

     ```hcl
     resource "aws_vpc_dhcp_options" "dhcp_options" {
       tags {
         Name = "${var.vpc_short_name}-dhcp"
       }
       domain_name_servers = ["${module.rdns-a.private_ip}", "${module.rdns-b.private_ip}"]
       domain_name         = "${var.region}.compute.internal"
     }

     resource "aws_vpc_dhcp_options_association" "dhcp_assoc" {
       vpc_id          = "${aws_vpc.vpc.id}"
       dhcp_options_id = "${aws_vpc_dhcp_options.dhcp_options.id}"
     }
     ```

   Note:

     * `domain_name` is not required, but makes your custom DHCP Options Set behave more like the default one.

     * If your VPC already contains active clients, it's a good idea to manually test your new RDNS Forwarder instances _before_ enabling the custom DHCP Options Set.

     * If you deploy RDNS Forwarders in your VPC and later decide to retire them, you will need to re-associate your VPC with the default DHCP Options Set (which directs clients to AmazonProvidedDNS).  After that, leave your RDNS Forwarder instances in place for a little while longer so they can continue to answer queries from running clients which have not yet picked up the new DHCP options.


## Known Issues

Wishlist:
- external notifications (SNS/email) in case of trouble
  - ansible failures
  - dig @localhost tests
- how to detect if RDNS Forwarder is oversubscribed (i.e. instance_type is too small)
