#!/bin/bash

terraform show -no-color -module-depth=2  |awk '/:/{gsub(":",".");pfx=$0} !/:/{gsub("^  ","");print pfx$0}'| awk '/cf_api_id|bastion_ip|cdh-manager\.private_ip|launcher\.public_ip/ {print}'
