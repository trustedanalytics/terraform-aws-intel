#!/bin/bash
# Copyright (c) 2015 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#

# Generate an ansible inventory based on the terraform status
# and upload it to the cloudera bastion host
FILE="cdh-inventory"
ENV_FILE="env.yml"
TERRASHOW="terraform show -no-color -module-depth=2"
ANSIBLE_PATH="./platform-ansible"

function tshow_resource_property {
  # pass unique resource name part for $1, property key for $2
  # for root properties, please use "Outputs" for $1
  $TERRASHOW |awk '{mark=0};/'${1}'/,/'${2}'/{mark=1};/'${2}'/{if(mark==1) print $3}'
}

function extract_private_ip {
  tshow_resource_property aws_instance.${1} private_ip
}

function extract_public_dns { 
  tshow_resource_property aws_instance.${1} public_dns
}

function show_env_name {
  $TERRASHOW | awk '/env_name/ { print $3 }'
}

AWS_KEY_PATH=$(eval echo `awk '/aws_key_path/{gsub(/"/,"");print $3}' terraform.tfvars`)
REGION=$(awk '/aws_region/{gsub(/"/,"");print $3}' terraform.tfvars)
REGION_DOMAIN=$(tshow_resource_property aws_instance.cdh-manager private_dns |cut -f2- -d.)

rm $FILE
rm $ENV_FILE

for name in cdh-worker cdh-manager cdh-master consul-master cloudera-launcher; do
  echo "[$name]" >> $FILE
  extract_private_ip $name | awk "{ printf(\"${name}-%d.node.$(show_env_name).consul ansible_ssh_host=%s\n\", NR-1, \$1); }" >> $FILE
  echo >> $FILE
done

echo -e "[cdh-all-nodes:children]\ncdh-master\ncdh-worker" >> $FILE
echo -e "[cdh-all:children]\ncdh-all-nodes\ncdh-manager" >> $FILE

echo -e "env_name: $(show_env_name)" >> $ENV_FILE
echo -e "use_custom_dns: true" >> $ENV_FILE

DNS=$(extract_public_dns cloudera-launcher)
scp -i "${AWS_KEY_PATH}" -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $FILE ec2-user@$DNS:~/ansible-cdh/inventory/cdh
scp -i "${AWS_KEY_PATH}" -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $ENV_FILE ec2-user@$DNS:~/ansible-cdh/defaults/env.yml

#don't ssh if started with --nossh
if [[ x"$1" != x"--nossh" ]]; then  
  ssh -i "${AWS_KEY_PATH}" -t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -A ec2-user@$DNS -L 7180:$(extract_private_ip cdh-manager):7180
fi
