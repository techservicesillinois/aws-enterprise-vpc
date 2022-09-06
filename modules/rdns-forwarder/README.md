# AWS Recursive DNS Forwarder

This directory provides both a Terraform module and an ansible-pull playbook to launch and configure an [Amazon Linux 2](https://aws.amazon.com/amazon-linux-2/) EC2 instance which will serve as a [**Recursive DNS Forwarder**](https://answers.uillinois.edu/illinois/page.php?id=74081) for your [Enterprise VPC](https://answers.uillinois.edu/illinois/page.php?id=71015).

![RDNS Options diagram](https://answers.uillinois.edu/images/group180/74081/AWSRecursiveDNSOptions.png)

RDNS Forwarders accept and answer recursive DNS queries _only_ from clients within your VPC.

  * If the query is for a University domain, your RDNS Forwarder forwards it to the **Core Services Resolvers** located in a Core Services VPC.  These resolvers are able to resolve DNS records in zones which are restricted to University clients only.

  * If the query is for any other domain, your RDNS Forwarder instead forwards it to [AmazonProvidedDNS](https://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_DHCP_Options.html#AmazonDNS).  AmazonProvidedDNS offers some special features whose behavior is specific to your VPC and cannot be replicated by the Core Services Resolvers.


## Automated Updates

RDNS Forwarders are designed to run completely unattended.  They use cron and [ansible-pull](https://docs.ansible.com/ansible/latest/user_guide/playbooks_intro.html#ansible-pull) to perform two distinct types of automated self-updates:

  * Once per hour, the *zone configuration* (i.e. which individual zones' queries should be forwarded to the Core Services Resolvers instead of to AmazonProvidedDNS) is updated to reflect the latest list of zones maintained by the [IP Address Management service](https://techservices.illinois.edu/services/ip-address-management), and `named` is instructed to reload the new configuration if it has changed.

  * Once per month, a *full update* is performed based on the ansible code published in this git repository.  This includes a `yum -y update` to get the latest versions of all installed system packages [regardless of which Amazon Linux 2 AMI we started from](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/amazon-linux-ami-basics.html#repository-config).

    **The full update often involves a reboot, during which time the RDNS Forwarder will briefly stop answering queries.**

To avoid impacting other resources in your VPC, please observe the following recommendations:

  1. Deploy at least two RDNS Forwarders and configure them to perform their automated updates at different times.

  2. Periodically test (from within your VPC) that each of your RDNS Forwarders can successfully answer queries for at least one University domain and at least one non-University domain, and/or at least monitor the `tx-NOERROR` metric (explained below).

     * Pass `create_alarm = true` to automatically create a [CloudWatch alarm](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html) based on the `tx-NOERROR` metric.

  3. If you ever need to replace an RDNS Forwarder (e.g. to upgrade to a larger size instance, or to a new MAJOR.MINOR version branch of this repository),
     * Take down only one RDNS Forwarder at a time.
     * Test the other one first to make sure it is working as expected.
     * Be sure the other one is not scheduled to perform its automated full update during your maintenance window.


## Troubleshooting

If an existing RDNS Forwarder stops working, destroy and recreate it from scratch.

If a _newly created_ RDNS Forwarder (using the latest release of this repository) doesn't work, contact Technology Services for help.  Note that a newly created RDNS Forwarder may take up to 5 minutes to configure itself and begin answering queries.

System logs are published under log group `rdns-forwarder` in [CloudWatch Logs](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/) to help with post-mortem analysis of any problems.

Use [CloudWatch Metrics](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/working_with_metrics.html) to view the [default AWS/EC2 metrics](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/viewing_metrics_with_cloudwatch.html) plus some additional custom metrics published under namespace `rdns-forwarder`.  Of particular note:

  * collectd_bind_value `tx-NOERROR` counts the number of queries that resulted in a successful, non-empty answer.

    * This is a monotonically increasing counter, so use a DIFF() or RATE() [metric math function](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/using-metric-math.html#metric-math-syntax) to see the _new_ occurences per time period.

    * Periodic DNS queries to localhost from cron ensure that `tx-NOERROR` should increase at least once per minute while the RDNS Forwarder is functioning properly, even when no external clients are making queries.

    * Technical note: `tx-NOERROR` comes from [BIND nsstat](https://bind9.readthedocs.io/en/latest/reference.html#name-server-statistics-counters) QrySuccess, which counts "queries which return a NOERROR response with at least one answer RR."  This does _not_ include the "negative" responses of NXDOMAIN, or NOERROR with zero answer records (sometimes called "NXRRSET" but not technically a distinct [RCODE](https://datatracker.ietf.org/doc/html/rfc1035#section-4.1.1)); those responses also indicate successful and correct behavior on the part of the RDNS Forwarder, but are typically a small minority share compared to `tx-NOERROR`.

  * collectd_bind_value `tx-SERVFAIL` (from BIND nsstat QrySERVFAIL) counts the number of queries that resulted in SERVFAIL ([RCODE](https://datatracker.ietf.org/doc/html/rfc1035#section-4.1.1) 2).

    * SERVFAIL responses do not necessarily indicate a malfunction of the RDNS Forwarder; they often occur when the RDNS Forwarder is legitimately unable to answer a query for a particular domain name because of a problem with that domain's _authoritative_ DNS.  However, an excessive quantity of SERVFAIL responses may be a sign that something is wrong.


## How to Deploy

The AWS Enterprise VPC Example environment code includes a working example of how to deploy RDNS Forwarders in `rdns.tf`.  This section explains the module usage in greater detail.

0. Make sure that:
   * your Enterprise VPC has connectivity (via Transit Gateway or VPC peering connection) to a Core Services VPC
   * you know the IPv4 addresses of the Core Services Resolvers within that particular Core Services VPC 

1. Within your Enterprise VPC Shared Networking infrastructure-as-code (IaC), use this module to deploy at least two RDNS Forwarders (for redundancy).  We suggest placing them in different public-facing Subnets in different Availability Zones, with staggered update times.  For example:

     ```hcl
     module "rdns-a" {
       source = "git::https://github.com/techservicesillinois/aws-enterprise-vpc.git//modules/rdns-forwarder?ref=vX.Y" #FIXME
       tags = {
         Name = "${var.vpc_short_name}-rdns-a"
       }
       instance_type            = "t4g.micro"
       instance_architecture    = "arm64"
       encrypted                = true
       core_services_resolvers  = ["10.224.1.50", "10.224.1.100"] #FIXME
       subnet_id                = module.public-facing-subnet["public1-a-net"].id
       private_ip               = "192.0.2.4" #FIXME
       zone_update_minute       = "5"
       full_update_day_of_month = "1"
       create_alarm             = true
     }

     module "rdns-b" {
       source = "git::https://github.com/techservicesillinois/aws-enterprise-vpc.git//modules/rdns-forwarder?ref=vX.Y" #FIXME
       tags = {
           Name = "${var.vpc_short_name}-rdns-b"
       }
       instance_type            = "t4g.micro"
       instance_architecture    = "arm64"
       encrypted                = true
       core_services_resolvers  = ["10.224.1.50", "10.224.1.100"] #FIXME
       subnet_id                = module.public-facing-subnet["public1-b-net"].id
       private_ip               = "192.0.2.132" #FIXME
       zone_update_minute       = "35"
       full_update_day_of_month = "15"
       create_alarm             = true
     }
     ```

   Notes:

     * Do not set `full_update_day_of_month` higher than 28!

     * You can also specify `full_update_hour` and `full_update_minute` if you want; the defaults correspond to 08:17 UTC.

     * Using a public-facing subnet is simplest, but a campus-facing or private-facing subnet will also work if it has outbound Internet connectivity.  If you do use a campus-facing or private-facing subnet, you must also specify `associate_public_ip_address = false` in the module parameters.

2. Deploy a custom [VPC DHCP Options Set](https://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_DHCP_Options.html) which instructs other instances in your VPC to send their DNS queries to the private IP addresses of your RDNS Forwarders, and associate that DHCP Options Set with the VPC.

     ```hcl
     resource "aws_vpc_dhcp_options" "dhcp_options" {
       tags = {
         Name = "${var.vpc_short_name}-dhcp"
       }
       domain_name_servers = [module.rdns-a.private_ip, module.rdns-b.private_ip]
       domain_name         = "${var.region}.compute.internal"
     }

     resource "aws_vpc_dhcp_options_association" "dhcp_assoc" {
       vpc_id          = aws_vpc.vpc.id
       dhcp_options_id = aws_vpc_dhcp_options.dhcp_options.id
     }
     ```

   Note:

     * `domain_name` is not required, but makes your custom DHCP Options Set behave more like the default one.

     * If your VPC already contains active clients, it's a good idea to manually test your new RDNS Forwarder instances _before_ enabling the custom DHCP Options Set.

     * If you deploy RDNS Forwarders in your VPC and later decide to retire them, you will need to re-associate your VPC with the default DHCP Options Set (which directs clients to AmazonProvidedDNS).  After that, it's a good idea to leave the actual RDNS Forwarder instances in place for a while longer, so that they can continue to answer queries from clients which have not yet picked up the new DHCP options.


## Known Issues

Wishlist:
- external notifications (SNS/email) in case of trouble
  - ansible failures
  - dig @localhost tests
  - metrics suggest that RDNS Forwarder may be oversubscribed (i.e. instance_type is too small)
