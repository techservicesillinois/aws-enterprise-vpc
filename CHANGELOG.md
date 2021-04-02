# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- attach to Transit Gateway shared from the Core Services account
- routes from VPC to Transit Gateway based on shared prefix lists (but must re-run Terraform when the prefix list changes)
- support Amazon-assigned IPv6 (but disabled by default) for public- and private-facing subnets
- convenient IAM Role for creating Flow Logs
- demonstrate cloud-init in example-service
- vpn-connection now supports Transit Gateway (as well as VPN Gateway)
- accept Resource Access Manager (RAM) shares from other accounts

### Changed
- requires Terraform 0.14.x
- default vpc/main.tf now omits NAT gateways (to save money) leaving private-facing subnets with no outbound Internet access
- update example-service to Amazon Linux 2, t3.nano
- vpn-connection CloudWatch Alarm uses native metrics instead of old custom "VPNStatus" metrics
- SNS topics for VPN monitoring alerts are now per-region
- pcx_ids (in subnet modules) is now map instead of list, and dependencies are implicit

### Deprecated
- campus-facing VPN connections from each VPC (use Transit Gateway instead)

### Removed
- old custom "VPNStatus" metrics solution (Lambda deployed via CloudFormation)



## [0.9.0] - 2019-10-30

### Added
- explicitly specify private ASN for aws_vpn_gateway
- new Interface VPC Endpoint for SNS
- apply tags to more resources: VPC Endpoints, rdns-forwarder IAM role, vpn-connection Alarm
- optional top-level var.tags in each environment

### Changed
- requires Terraform 0.12.x (and AWS provider 2.x)
- generates details.json instead of details.txt
- vpc.* outputs renamed to vpc_*
- vpn-connection config output is no longer wrapped in here-document delimiters
- use for_each instead of count (for pcx_ids and endpoints)
- create aws_route_table in subnet-common instead of subclasses
- rdns-forwarder: use ec2_metadata_facts instead of deprecated alias ec2_facts

### Fixed
- vpc/rdns: avoid temporarily leaving VPC with no associated DHCP options set when reverting to Option 1



## [0.8.2] - 2018-11-02

### Changed
- update GitHub links to reflect renaming our GitHub organization from cites-illinois to techservicesillinois
- rdns-forwarder: update running v0.8 instances in-place to new GitHub URL



## [0.8.1] - 2018-03-07

### Added
- prevent accidental destruction of VPC and VPN connections
- all modules now accept input variables for common and per-resource custom tags
- support Interface VPC Endpoints (disabled by default)

### Changed
- refactor VPC Endpoints from vpc/main.tf to separate vpc/endpoints.tf



## [0.8.0] - 2018-02-01

### Added
- cleanly support multiple VPC environments in different regions (leveraging one global environment)
- new Gateway VPC Endpoint for DynamoDB
- apply tags to more resources: nat-gateway and EIP, rdns-forwarder EBS volume and SG
- rdns-forwarder: add an explicit "forward first" to each zone statement for clarity
- vpn-connection: expose distinct alarm_actions, insufficient_data_actions, ok_actions

### Changed
- requires Terraform 0.11.x
- deploy VPN Monitoring in us-east-2 instead of us-east-1
- vpn-connection: alarm is now OK if at least one tunnel is UP (instead of requiring both), specify `alarm_requires_both_tunnels` to override
