# This file supplies values for the variables defined in *.tf
#
# Copyright (c) 2021 Board of Trustees University of Illinois

# Your 12-digit AWS account number
#account_id = "999999999999" #FIXME

# must match hardcoded region in backend stanzas
region = "us-east-2"

# must match hardcoded dynamodb_table in backend stanzas
dynamodb_table = "terraform"

# must match hardcoded bucket in backend stanzas and be unique to your AWS
# account; try replacing uiuc-tech-services-sandbox with the friendly name of
# your account
#bucket = "terraform.uiuc-tech-services-sandbox.aws.illinois.edu" #FIXME

# Optional custom tags for all taggable resources
#tags = {
#  Contact = "example@illinois.edu"
#}
