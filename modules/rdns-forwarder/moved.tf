# Refactored resource addresses
#
# Copyright (c) 2026 Board of Trustees University of Illinois

# since v0.11

moved {
  from = null_resource.instance_architecture
  to   = terraform_data.instance_architecture
}
