# Upgrading Hints

**WARNING**: upgrading existing IaC deployments to a new version of aws-enterprise-vpc in place is non-trivial, and may disrupt services in your VPC!

The safer and more comfortable alternative is to create a new VPC (see "Multiple VPCs" in [README.md]), migrate your applications, and then decommission the old VPC.

In practice, in-place upgrades are often achievable _if_ you are careful and understand what you're doing, but this requires significantly more expertise than the original deployment.  This document is a "word to the wise", not a reliable formula.

The basic idea:
  1. Before doing anything else, re-run `terraform plan` in each environment; there should be no changes.
  2. Update your IaC environments to reflect recent changes in the corresponding example files (being sure to preserve your unique customizations).  Carefully proofread the diff between your new IaC and the latest example.
  3. Upgrade your workstation's installation of Terraform if needed.
  3. Run `terraform init -upgrade`
  4. Run `terraform plan` and VERY CAREFULLY read what it wants to change, paying particular attention to any resources which will be destroyed and created (as opposed to updated in-place).
  5. Check the notes below for hints to whittle down this change set, e.g. by renaming resources in your terraform state to reflect code refactoring.
  6. If and when you're comfortable that the plan will not cause unacceptable disruption, apply it.  When that's done, run an extra apply (which shouldn't need to do anything) just to make sure everything is stable.



## from 0.8 to 0.9

This migration is tricky because several resources have changed from `count` to `for_each`.  Note that some of these will need to be fixed before you can even run `terraform plan` successfully, e.g. to resolve "Error: Invalid function argument" due to "aws_vpc_endpoint.gateway is tuple with 2 elements"

* comment out `amazon_side_asn = 64512` to avoid rebuilding an existing vgw

* refactor rtb resources

    terraform state mv module.public1-a-net.aws_route_table.rtb module.public1-a-net.module.subnet.aws_route_table.rtb
    terraform state mv module.public1-b-net.aws_route_table.rtb module.public1-b-net.module.subnet.aws_route_table.rtb
    terraform state mv module.campus1-a-net.aws_route_table.rtb module.campus1-a-net.module.subnet.aws_route_table.rtb
    terraform state mv module.campus1-b-net.aws_route_table.rtb module.campus1-b-net.module.subnet.aws_route_table.rtb
    terraform state mv module.private1-a-net.aws_route_table.rtb module.private1-a-net.module.subnet.aws_route_table.rtb
    terraform state mv module.private1-b-net.aws_route_table.rtb module.private1-b-net.module.subnet.aws_route_table.rtb

  and dummy_depends_on resources (which are harmless but clutter up the plan)

    terraform state mv module.public1-a-net.null_resource.dummy_depends_on module.public1-a-net.module.subnet.null_resource.dummy_depends_on
    terraform state mv module.public1-b-net.null_resource.dummy_depends_on module.public1-b-net.module.subnet.null_resource.dummy_depends_on
    terraform state mv module.campus1-a-net.null_resource.dummy_depends_on module.campus1-a-net.module.subnet.null_resource.dummy_depends_on
    terraform state mv module.campus1-b-net.null_resource.dummy_depends_on module.campus1-b-net.module.subnet.null_resource.dummy_depends_on
    terraform state mv module.private1-a-net.null_resource.dummy_depends_on module.private1-a-net.module.subnet.null_resource.dummy_depends_on
    terraform state mv module.private1-b-net.null_resource.dummy_depends_on module.private1-b-net.module.subnet.null_resource.dummy_depends_on

* refactor from count to for_each (NB: replace "pcx-CHANGEME" appropriately)

    terraform state mv aws_vpc_endpoint.gateway[0] 'aws_vpc_endpoint.gateway["com.amazonaws.us-east-2.dynamodb"]'
    terraform state mv aws_vpc_endpoint.gateway[1] 'aws_vpc_endpoint.gateway["com.amazonaws.us-east-2.s3"]'

    terraform state mv module.public1-a-net.module.subnet.aws_vpc_endpoint_route_table_association.endpoint_rta[0] 'module.public1-a-net.module.subnet.aws_vpc_endpoint_route_table_association.endpoint_rta["com.amazonaws.us-east-2.dynamodb"]'
    terraform state mv module.public1-a-net.module.subnet.aws_vpc_endpoint_route_table_association.endpoint_rta[1] 'module.public1-a-net.module.subnet.aws_vpc_endpoint_route_table_association.endpoint_rta["com.amazonaws.us-east-2.s3"]'
    terraform state mv module.public1-b-net.module.subnet.aws_vpc_endpoint_route_table_association.endpoint_rta[0] 'module.public1-b-net.module.subnet.aws_vpc_endpoint_route_table_association.endpoint_rta["com.amazonaws.us-east-2.dynamodb"]'
    terraform state mv module.public1-b-net.module.subnet.aws_vpc_endpoint_route_table_association.endpoint_rta[1] 'module.public1-b-net.module.subnet.aws_vpc_endpoint_route_table_association.endpoint_rta["com.amazonaws.us-east-2.s3"]'

    terraform state mv module.campus1-a-net.module.subnet.aws_vpc_endpoint_route_table_association.endpoint_rta[0] 'module.campus1-a-net.module.subnet.aws_vpc_endpoint_route_table_association.endpoint_rta["com.amazonaws.us-east-2.dynamodb"]'
    terraform state mv module.campus1-a-net.module.subnet.aws_vpc_endpoint_route_table_association.endpoint_rta[1] 'module.campus1-a-net.module.subnet.aws_vpc_endpoint_route_table_association.endpoint_rta["com.amazonaws.us-east-2.s3"]'
    terraform state mv module.campus1-b-net.module.subnet.aws_vpc_endpoint_route_table_association.endpoint_rta[0] 'module.campus1-b-net.module.subnet.aws_vpc_endpoint_route_table_association.endpoint_rta["com.amazonaws.us-east-2.dynamodb"]'
    terraform state mv module.campus1-b-net.module.subnet.aws_vpc_endpoint_route_table_association.endpoint_rta[1] 'module.campus1-b-net.module.subnet.aws_vpc_endpoint_route_table_association.endpoint_rta["com.amazonaws.us-east-2.s3"]'

    terraform state mv module.private1-a-net.module.subnet.aws_vpc_endpoint_route_table_association.endpoint_rta[0] 'module.private1-a-net.module.subnet.aws_vpc_endpoint_route_table_association.endpoint_rta["com.amazonaws.us-east-2.dynamodb"]'
    terraform state mv module.private1-a-net.module.subnet.aws_vpc_endpoint_route_table_association.endpoint_rta[1] 'module.private1-a-net.module.subnet.aws_vpc_endpoint_route_table_association.endpoint_rta["com.amazonaws.us-east-2.s3"]'
    terraform state mv module.private1-b-net.module.subnet.aws_vpc_endpoint_route_table_association.endpoint_rta[0] 'module.private1-b-net.module.subnet.aws_vpc_endpoint_route_table_association.endpoint_rta["com.amazonaws.us-east-2.dynamodb"]'
    terraform state mv module.private1-b-net.module.subnet.aws_vpc_endpoint_route_table_association.endpoint_rta[1] 'module.private1-b-net.module.subnet.aws_vpc_endpoint_route_table_association.endpoint_rta["com.amazonaws.us-east-2.s3"]'

    terraform state mv aws_vpc_peering_connection_accepter.pcx[0] 'aws_vpc_peering_connection_accepter.pcx["pcx-CHANGEME"]'

    terraform state mv module.public1-a-net.module.subnet.aws_route.pcx[0] 'module.public1-a-net.module.subnet.aws_route.pcx["pcx-CHANGEME"]'
    terraform state mv module.public1-b-net.module.subnet.aws_route.pcx[0] 'module.public1-b-net.module.subnet.aws_route.pcx["pcx-CHANGEME"]'
    terraform state mv module.campus1-a-net.module.subnet.aws_route.pcx[0] 'module.campus1-a-net.module.subnet.aws_route.pcx["pcx-CHANGEME"]'
    terraform state mv module.campus1-b-net.module.subnet.aws_route.pcx[0] 'module.campus1-b-net.module.subnet.aws_route.pcx["pcx-CHANGEME"]'
    terraform state mv module.private1-a-net.module.subnet.aws_route.pcx[0] 'module.private1-a-net.module.subnet.aws_route.pcx["pcx-CHANGEME"]'
    terraform state mv module.private1-b-net.module.subnet.aws_route.pcx[0] 'module.private1-b-net.module.subnet.aws_route.pcx["pcx-CHANGEME"]'

* Unfortunately [https://github.com/hashicorp/terraform/issues/22301] prevents refactoring with `terraform state mv` commands in the case where there is only a single instance, which for a typical VPC inclues the pcx-related resources above.  As of this writing, the only seamless workaround is to perform manual surgery on the state file:

    terraform state pull > DANGER.tfstate

    cp DANGER.tfstate DANGER.tfstate.backup

    vim DANGER.tfstate

      * Locate the stanza corresponding to each resource you need to mv.  Inside the single instance of that resource, immediately above `"schema_version": 0,`, insert the following line:

          "index_key": "pcx-CHANGEME",

      * Locate "serial" near the top of the file and increase its value by 1.

    terraform state push DANGER.tfstate

    terraform plan

* If using rdns option 3,

    terraform state mv aws_vpc_dhcp_options_association.dhcp_assoc aws_vpc_dhcp_options_association.dhcp_assoc_option3

  and be careful to replace only one instance at a time!  The easiest way to do this is with a targeted apply, e.g.

    terraform apply -target module.rdns-a
