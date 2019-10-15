# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- explicitly specify private ASN for aws_vpn_gateway
- new Interface VPC Endpoint for SNS

### Changed
- requires Terraform 0.12.x (and AWS provider 2.x)
- vpc.* outputs renamed to vpc_*
- use for_each instead of count
- rdns-forwarder: use ec2_metadata_facts instead of deprecated alias ec2_facts


## [0.8.2] - 2018-11-02

### Changed
- update GitHub links to reflect renaming our GitHub organization from cites-illinois to techservicesillinois
- rdns-forwarder: update running v0.8 instances in-place to new GitHub URL


## [0.8.1] - 2018-03-07

### Added
- prevent accidental destruction of VPC and VPN connections
- all modules now accept input variables for common and per-resource custom tags
- add support for Interface VPC Endpoints (disabled by default)

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
