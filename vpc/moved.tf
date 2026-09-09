# Refactored resource addresses
#
# Copyright (c) 2026 Board of Trustees University of Illinois

# since v0.11

moved {
  from = null_resource.vpn1
  to   = terraform_data.vpn1
}

moved {
  from = null_resource.vpn2
  to   = terraform_data.vpn2
}

moved {
  from = null_resource.rdns-a
  to   = terraform_data.rdns-a
}

moved {
  from = null_resource.rdns-b
  to   = terraform_data.rdns-b
}
