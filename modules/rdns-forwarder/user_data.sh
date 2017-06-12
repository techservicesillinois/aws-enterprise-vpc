#!/bin/bash
#
# Copyright (c) 2017 Board of Trustees University of Illinois

# use Amazon DNS as a backup in case our resolvers are down, both now
echo "nameserver ${amazon_dns}" | sudo tee --append /etc/resolv.conf
# and in the future
echo "append domain-name-servers ${amazon_dns};" | sudo tee --append /etc/dhcp/dhclient.conf

# install ansible and git
sudo yum-config-manager --enable epel
sudo yum -y install ansible git

# Ansible provides implicit localhost, but adding it explicitly suppresses
# "[WARNING]: provided hosts list is empty, only localhost is available"
echo "localhost ansible_connection=local" | sudo tee --append /etc/ansible/hosts

# Ansible logging
sudo tee /root/.ansible.cfg <<EOF
[defaults]
log_path=${ansible_logfile}
EOF

# record host-specific variables for use within Ansible
sudo mkdir /etc/ansible/host_vars
sudo tee /etc/ansible/host_vars/localhost.yml <<EOF
---
vpc_cidr: ${vpc_cidr}
amazon_dns: ${amazon_dns}
forwarders:
${forwarders_list}
ansible_logfile: ${ansible_logfile}
ansible_pull_directory: ${ansible_pull_directory}
ansible_pull_url: ${ansible_pull_url}
ansible_pull_checkout: ${ansible_pull_checkout}
zone_update:
  minute: "${zone_update_minute}"
full_update:
  day: "${full_update_day_of_month}"
  hour: "${full_update_hour}"
  minute: "${full_update_minute}"
# override default behavior of using python2.6 (which can't find yum.py)
ansible_python_interpreter: /usr/bin/python
EOF

# initial ansible-pull
ansible-pull --url=${ansible_pull_url} --checkout=${ansible_pull_checkout} --directory=${ansible_pull_directory} modules/rdns-forwarder/local.yml
