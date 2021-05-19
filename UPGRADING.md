# Upgrading Hints

**WARNING**: upgrading existing IaC deployments to a new version of `aws-enterprise-vpc` in place is non-trivial, and may disrupt services in your VPC!

The safer and more comfortable alternative is to create a new VPC (see "Multiple VPCs" in [README.md](README.md)), migrate your applications, and then decommission the old VPC.

In practice, in-place upgrades are often achievable _if_ you are careful and understand what you're doing, but this requires significantly more operator expertise than the original deployment.  **This document is a "word to the wise", not a foolproof recipe.**

The basic idea:
  1. Before doing anything else, re-run `terraform plan` in each environment; there should be no resource changes.
  2. Upgrade your workstation's installation of Terraform if needed.
  3. Update your IaC environments to reflect recent changes in the corresponding example files (being sure to preserve your unique customizations).  Carefully proofread the diff between your new IaC and the latest example.
  4. Run `terraform init -upgrade`
  5. Run `terraform plan` and VERY CAREFULLY read what it wants to change, paying particular attention to any resources which will be destroyed and created (as opposed to updated in-place).
  6. Check the notes below for hints to whittle down this change set, e.g. by renaming resources in your terraform state to reflect code refactoring.
  7. If and when you're confident that the plan will not cause unacceptable disruption, apply it.  When that's done, run an extra apply (which shouldn't need to do anything) just to make sure everything is stable.



## from v0.9 to v0.10

### Phase 1: upgrade Terraform software without changing resources

  NB: Terraform cannot upgrade an existing state directly from Terraform 0.12.x to 0.14 or greater, because 0.13 needs to apply some behind-the-scenes upgrades to the state file as described in <https://www.terraform.io/upgrade-guides/0-13.html#before-you-upgrade> and <https://www.terraform.io/upgrade-guides/0-14.html#before-you-upgrade>

  1. Re-run `terraform plan` in each environment (using your current Terraform 0.12.x); there should be no resource changes.
  2. Comment out `required_version` in global/main.tf and vpc/main.tf but do NOT make any other code changes.
  3. Upgrade to Terraform 0.13.x:
     - Install Terraform 0.13.x on your workstation.
     - In the global environment, `terraform init -upgrade -reconfigure` and then `terraform apply` using Terraform 0.13.x; there should be no resource changes (but it will upgrade the state file behind the scenes).
     - In the vpc environment, `terraform init -upgrade -reconfigure` and then `terraform apply` using Terraform 0.13.x; there should be no resource changes (but it will upgrade the state file behind the scenes).

  4. Upgrade to Terraform 0.14.x in the same fashion.
  5. Upgrade to Terraform 0.15.x in the same fashion.

### Phase 2: destroy old style vpn-connection CloudWatch Alarms

  6. In vpc/main.tf, comment out `create_alarm = true` in both `module "vpn1"` and `module "vpn2"`
  7. `terraform apply` (expected: 0 to add, 0 to change, 2 to destroy)

### Phase 3: upgrade your global environment to aws-enterprise-vpc v0.10

  8. Create global/backend.tf, reapplying appropriate customizations from your existing global/main.tf
  9. Replace your global/main.tf with a new reference copy (NB: preserving the old one in source control)
  10. `terraform init -upgrade`
  11. Run `terraform plan` and VERY CAREFULLY read what it wants to change.

      Expected changes:

        - aws_cloudformation_stack.vpn-monitor will be destroyed
        - aws_iam_role.flow_logs_role will be created
        - aws_iam_role_policy.flow_logs_role_inline1 will be created

      You may need to refactor:

          terraform state mv aws_sns_topic.vpn-monitor aws_sns_topic.vpn-monitor_us-east-2

  12. When confident, `terraform apply`

### Phase 4: upgrade your vpc environment to aws-enterprise-vpc v0.10, making minimal resource changes

  13. Create vpc/backend.tf, reapplying appropriate customizations from your existing vpc/main.tf
  14. Edit vpc/terraform.tfvars to keep your existing variables but add lots of new ones (based on the reference copy), applying appropriate customizations based on your existing main.tf, rdns.tf, and/or endpoints.tf

      - `vpc_cidr_block` and per-subnet `cidr_block` from main.tf
      - uncomment `private1-a-net` and `private1-b-net`
      - TEMPORARILY comment out `use_transit_gateway = true`
      - TEMPORARILY add `use_dedicated_vpn = true`
      - uncomment elements of `nat_gateways`
      - set `rdns_option = 3` if using RDNS Option 3 in rdns.tf
      - uncomment any elements of `interface_vpc_endpoint_service_names` which you had previously uncommented in endpoints.tf
      - if using any `interface_vpc_endpoint_service_names`, also change the values of `interface_vpc_endpoint_subnets` from public to private subnets

  15. Replace your vpc/main.tf with a new reference copy (NB: preserving the old one in source control)
  16. Replace your vpc/endpoints.tf with a new reference copy (NB: preserving the old one in source control)
  17. Replace your vpc/rdns.tf with a new reference copy (NB: preserving the old one in source control)
  18. If using RDNS Option 3, TEMPORARILY modify both `module "rdns-a"` and `module "rdns-b"` in rdns.tf to continue using v0.9 and avoid premature instance replacements:

          source = "git::https://github.com/techservicesillinois/aws-enterprise-vpc.git//modules/rdns-forwarder?ref=v0.9"
          instance_type           = "t2.micro"
          instance_architecture   = "x86_64"

  19. `terraform init -upgrade`
  20. Refactor:

          terraform state mv 'module.vpn1' 'module.vpn1[0]'
          terraform state mv 'module.vpn2' 'module.vpn2[0]'

          terraform state mv 'module.public1-a-net' 'module.public-facing-subnet["public1-a-net"]'
          terraform state mv 'module.public1-b-net' 'module.public-facing-subnet["public1-b-net"]'
          terraform state mv 'module.campus1-a-net' 'module.campus-facing-subnet["campus1-a-net"]'
          terraform state mv 'module.campus1-b-net' 'module.campus-facing-subnet["campus1-b-net"]'
          terraform state mv 'module.private1-a-net' 'module.private-facing-subnet["private1-a-net"]'
          terraform state mv 'module.private1-b-net' 'module.private-facing-subnet["private1-b-net"]'

          terraform state mv 'module.public-facing-subnet["public1-a-net"].aws_route.default' 'module.public-facing-subnet["public1-a-net"].aws_route.ipv4_default'
          terraform state mv 'module.public-facing-subnet["public1-b-net"].aws_route.default' 'module.public-facing-subnet["public1-b-net"].aws_route.ipv4_default'
          terraform state mv 'module.campus-facing-subnet["campus1-a-net"].aws_route.default' 'module.campus-facing-subnet["campus1-a-net"].aws_route.ipv4_default'
          terraform state mv 'module.campus-facing-subnet["campus1-b-net"].aws_route.default' 'module.campus-facing-subnet["campus1-b-net"].aws_route.ipv4_default'
          terraform state mv 'module.private-facing-subnet["private1-a-net"].aws_route.default' 'module.private-facing-subnet["private1-a-net"].aws_route.ipv4_default'
          terraform state mv 'module.private-facing-subnet["private1-b-net"].aws_route.default' 'module.private-facing-subnet["private1-b-net"].aws_route.ipv4_default'

      and depending on your VPC's region:

          terraform state mv 'module.nat-a' 'module.nat["us-east-2a"]'
          terraform state mv 'module.nat-b' 'module.nat["us-east-2b"]'

      and if using RDNS Option 3:

          terraform state mv 'module.rdns-a' 'module.rdns-a[0]'
          terraform state mv 'module.rdns-b' 'module.rdns-b[0]'

  21. Run `terraform plan` and VERY CAREFULLY read what it wants to change.

      Expected changes:

        - aws_egress_only_internet_gateway.eigw will be created
        - aws_vpn_gateway_attachment.vgw_attachment[0] will be created
        - aws_security_group_rule.endpoint_egress[0] must be replaced
        - null_resource.rdns-a[0] will be created
        - null_resource.rdns-b[0] will be created
        - null_resource.wait_for_vpc_peering_connection_accepter will be destroyed
        - (various) aws_route.ipv6_default[0] will be created
        - module.vpn1[0].aws_cloudwatch_metric_alarm.vpnstatus[0] will be created
        - module.vpn2[0].aws_cloudwatch_metric_alarm.vpnstatus[0] will be created
        - (various) null_resource.dummy_depends_on will be destroyed

  22. When confident, `terraform apply`

### Phase 5: if using RDNS Option 3, upgrade RDNS forwarders one at a time

  23. In vpc/rdns.tf,
      - comment out `prevent_destroy` for `resource "null_resource" "rdns-a"` only
      - modify `module "rdns-a"` to use v0.10 (and new instance shape, if desired):

            source = "git::https://github.com/techservicesillinois/aws-enterprise-vpc.git//modules/rdns-forwarder?ref=v0.10"
            instance_type           = "t4g.micro"
            instance_architecture   = "arm64"

  24. Run `terraform get -update` followed by `terraform apply` to replace the first RDNS forwarder.
  25. Wait 5 minutes, then test to make sure the new forwarder is working.
  26. In vpc/rdns.tf,
      - uncomment `prevent_destroy` for `resource "null_resource" "rdns-a"`
      - comment out `prevent_destroy` for `resource "null_resource" "rdns-b"` only
      - modify `module "rdns-b"` to use v0.10 (and new instance shape, if desired)
  27. Run `terraform get -update` followed by `terraform apply` to replace the second RDNS forwarder.
  28. Wait 5 minutes, then test to make sure the new forwarder is working.
  29. Uncomment `prevent_destroy` for `resource "null_resource" "rdns-b"`.

### Phase 6: create a Transit Gateway Attachment for your VPC, but *DO NOT* try to route any traffic through it yet

  30. Contact Technology Services to add your account to the appropriate resource share(s); be sure to provide your AWS account number and which region(s) you want to use for VPCs.
  31. In your global environment, edit global/terraform.tfvars to set `resource_share_arns`, then `terraform apply` to accept the resource share(s).
  32. In vpc/main.tf, TEMPORARILY comment out the 3 occurrences of `transit_gateway_id = local.transit_gateway_id_local` under `module "public-facing-subnet"`, `module "campus-facing-subnet"`, and `module "private-facing-subnet"`
  33. In vpc/terraform.tfvars, uncomment `use_transit_gateway = true`
  34. `terraform apply` (expected: 1 to add, 0 to change, 0 to destroy) to create your Transit Gateway Attachment (but NO routes)
  35. `terraform output -json > details.json` and send details.json to Technology Services to provision our side of your attachment.

      After this the Transit Gateway will be capable of routing traffic to your VPC, but actual traffic patterns will not change; the Core Services VPC will still prefer your existing VPC Peering Connection, and the campus network will still prefer your dedicated VPN connections.

### Phase 7: transition to using Transit Gateway

  36. Important: do NOT proceed until Technology Services confirms that your attachment is fully provisioned.
  37. Be sure the current versions of your IaC files are committed to source control.
  38. In vpc/main.tf,
      - uncomment the 3 occurrences of `transit_gateway_id = local.transit_gateway_id_local` under `module "public-facing-subnet"`, `module "campus-facing-subnet"`, and `module "private-facing-subnet"`
      - TEMPORARILY comment out `vpn_gateway_id = one(aws_vpn_gateway.vgw[*].id)` under `module "campus-facing-subnet"`
      - TEMPORARILY comment out `resource "aws_vpn_gateway_attachment" "vgw_attachment"` (entire stanza)
  39. In vpc/terraform.tfvars, comment out `pcx_ids`
  40. Run `terraform plan` and VERY CAREFULLY read what it wants to change.

      Expected changes:

        - aws_vpc_peering_connection_accepter.pcx["pcx-abcd1234"] will be destroyed
          (NB: per https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_peering_connection_accepter#removing-aws_vpc_peering_connection_accepter-from-your-configuration this does NOT actually destroy the Peering Connection)
        - aws_vpn_gateway_attachment.vgw_attachment[0] will be destroyed
          (this detaches the VPN Gateway from your VPC but leaves the VPN connections intact)
        - for each subnet, remove a route pointing toward the pcx
        - for each subnet, add a route pointing toward the tgw
        - for each campus-facing subnet, clear `propagating_vgws`

  41. DISRUPTIVE IMPACT STEP: when confident, `terraform apply`

      Expect an outage of up to 1 minute for campus-facing traffic while routing changes take effect.

      Once this is finished,
        - traffic from your campus-facing subnets to the campus network will use the Transit Gateway
        - traffic from the campus network to your campus-facing subnets will use the Transit Gateway
        - traffic from your VPC to the Core Services VPC will use the Transit Gateway
        - traffic from the Core Services VPC to your VPC will still use your VPC Peering Connection
          (this will change later on when Technology Services deprovisions the pcx from the Core Services side)

  42. Test connectivity to verify that everything is working as expected.

      If not, it is possible to roll back the changes from this phase, again incurring an outage of up to 1 minute (while the campus network re-learns to prefer your dedicated VPN connections).

### Phase 8: deprovision legacy connections no longer needed

  43. In vpc/terraform.tfvars, remove `use_dedicated_vpn = true`
  44. In vpc/main.tf:
      - uncomment `vpn_gateway_id = one(aws_vpn_gateway.vgw[*].id)` under `module "campus-facing-subnet"`
      - uncomment `resource "aws_vpn_gateway_attachment" "vgw_attachment"` (entire stanza)
      - comment out `prevent_destroy` for `resource "null_resource" "vpn1"` and `resource "null_resource" "vpn2"`
  45. `terraform apply` to irrevocably destroy the dedicated VPN connections (and VGW)
  46. Uncomment `prevent_destroy` for `resource "null_resource" "vpn1"` and `resource "null_resource" "vpn2"` (so your vpc/main.tf will match the reference copy again).
  47. Finally, contact Technology Services to deprovision the on-campus side of your dedicated VPN connections and the Core Services side of your VPC Peering Connection.



## from v0.8 to v0.9

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

  1. `terraform state pull > DANGER.tfstate`

  2. `cp DANGER.tfstate DANGER.tfstate.backup`

  3. `vim DANGER.tfstate`

     * Locate the stanza corresponding to each resource you need to mv.  Inside the single instance of that resource, immediately above `"schema_version": 0,`, insert the following line:

            "index_key": "pcx-CHANGEME",

     * Locate `"serial"` near the top of the file and increase its value by 1.

  4. `terraform state push DANGER.tfstate`

  5. `terraform plan`

* If using rdns option 3,

        terraform state mv aws_vpc_dhcp_options_association.dhcp_assoc aws_vpc_dhcp_options_association.dhcp_assoc_option3

  and be careful to replace only one instance at a time!  The easiest way to do this is with a targeted apply, e.g.

        terraform apply -target module.rdns-a



## from v0.7 to v0.8

The challenge here is migrating VPN monitoring from us-east-1 to us-east-2; Terraform gets confused when our configuration specifies a new provider for resources which already exist under a different provider, and plans to create the new resource _without_ destroying the old one (leaving the old one orphaned in the wild).  Our workaround is to rename the old resource to a name which no longer matches anything in the configuration.

NB: since we're creating a new SNS topic, you will also need to manually recreate any desired subscriptions (these are not handled by Terraform).

* global environment:

        terraform state mv module.cgw module.cgw_us-east-2

        terraform state mv aws_cloudformation_stack.vpn-monitor aws_cloudformation_stack.vpn-monitor-OLD
        terraform state mv aws_sns_topic.vpn-monitor aws_sns_topic.vpn-monitor-OLD

* vpc environment:

        terraform state mv module.vpn1.aws_cloudwatch_metric_alarm.vpnstatus module.vpn1.aws_cloudwatch_metric_alarm.vpnstatus-OLD
        terraform state mv module.vpn2.aws_cloudwatch_metric_alarm.vpnstatus module.vpn2.aws_cloudwatch_metric_alarm.vpnstatus-OLD
