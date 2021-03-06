﻿# DEVELOPER README for AWS Recursive DNS Forwarder

Testing updates to the rdns-forwarder module is tricky, because references to a specific git repository and branch appear in many places:

* TF module source path used to invoke the module (in the calling IaC)
* TF vars `ansible_pull_url` and `ansible_pull_checkout` (defaults specified in `module.tf`, may be overridden by the calling IaC)
* instance user data (templated from TF vars)
* file `/etc/ansible/host_vars/localhost.yml` on the instance (initialized from user data, subsequently mutable)
* other instance items produced by Ansible: cron task, shallow git clone

## Test deploying a new version from scratch

When testing a new version of this module, push it to a throwaway git branch first.

To deploy a new instance, write IaC which specifies the throwaway branch both in the module source and in `ansible_pull_checkout`.  It's also helpful to configure full updates every hour (instead of once a month) and enable SSH access for debugging.

  ```hcl
  resource "aws_key_pair" "test" {
    key_name_prefix = "test-"
    public_key      = "ssh-rsa AAAAB3NzaC1yc2..." #FIXME
  }

  module "rdns-test" {
    source = "git::https://github.com/techservicesillinois/aws-enterprise-vpc.git//modules/rdns-forwarder?ref=TESTBRANCH" #FIXME
    tags = {
      Name = "rdns-test"
    }
    instance_type           = "t4g.micro"
    instance_architecture   = "arm64"
    core_services_resolvers = ["10.224.1.50", "10.224.1.100"] #FIXME
    subnet_id               = module.public-facing-subnet["public1-a-net"].id
    private_ip              = "192.0.2.5" #FIXME
    zone_update_minute      = "5"
    # TESTING ONLY
    ansible_pull_checkout    = "TESTBRANCH" #FIXME
    full_update_day_of_month = "*"
    full_update_hour         = "*"
    full_update_minute       = "17"
    key_name                 = aws_key_pair.test.key_name
  }

  resource "aws_security_group_rule" "rdns-test-allow_ssh" {
    security_group_id = module.rdns-test.security_group_id
    type              = "ingress"
    protocol          = "tcp"
    from_port         = 22
    to_port           = 22
    cidr_blocks       = [var.vpc_cidr_block, "130.126.0.0/16"]
  }

  output "rdns-test" {
    value = module.rdns-test.private_ip
  }
  ```

## Test in-place updates intended for an existing release branch

Before pushing updates to an existing vX.Y release branch, test the impact it will have on an already-deployed instance:

1. Create and push a throwaway TESTBRANCH which duplicates the current release branch.
2. Deploy a from-scratch test instance based on TESTBRANCH (as above).
   * You may find it helpful to use e.g. `full_update_minute = "*/10"`
3. Push the proposed new changes to TESTBRANCH.
4. Wait for the test instance to perform a full update, and observe the effects.

### Updating ansible_pull settings of running instances

If necessary, we can push an update to an existing vX.Y release branch which will cause already-deployed instances to use a different `ansible_pull_url` and/or `ansible_pull_checkout` for future full updates (after the next one).  See `roles/rdns-forwarder/tasks/main.yml` for implementation details.

Testing this (with a throwaway TESTBRANCH, as above) requires that we observe *two* full update cycles after pushing to TESTBRANCH:

1. The first full update runs the modified TESTBRANCH playbook to update the host_vars file and cron task for next time.  Verify (as root)

       grep ansible_pull /etc/ansible/host_vars/localhost.yml
       crontab -l

2. The second full update checks out and runs the new target version of the playbook.  Verify (as root)

       git -C /root/aws-enterprise-vpc remote -v
       git -C /root/aws-enterprise-vpc branch -a

   in addition to any changes made by the new playbook.
