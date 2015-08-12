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

AWS_KEY_PATH=$(eval echo `awk '/aws_key_path/{gsub(/"/,"");print $3}' terraform.tfvars`)
REGION=$(awk '/aws_region/{gsub(/"/,"");print $3}' terraform.tfvars)
REGION_DOMAIN=$(tshow_resource_property aws_instance.cdh-manager private_dns |cut -f2- -d.)

rm $FILE

for name in cdh-worker cdh-manager cdh-master consul-master cloudera-launcher zabbix-proxy; do
  echo "[$name]" >> $FILE
  grep -q "use_custom_dns: true" ${ANSIBLE_PATH}/defaults/env.yml 2> /dev/null
  if [[ $? -eq 0 ]]; then
    ENVNAME=$(awk '/env_name/ { print $2 }' ${ANSIBLE_PATH}/defaults/env.yml)
    extract_private_ip $name | awk "{ printf(\"${name}-%d.node.${ENVNAME}.consul ansible_ssh_host=%s\n\", NR-1, \$1); }" >> $FILE
  else
    extract_private_ip $name | awk "{ bak=\$1; gsub(\"\\\\.\", \"-\", \$1); printf(\"ip-%s.${REGION_DOMAIN} ansible_ssh_host=%s\n\", \$1, bak);  }" >> $FILE
  fi
  echo >> $FILE
done

echo -e "[cdh-all-nodes:children]\ncdh-master\ncdh-worker" >> $FILE
echo -e "[cdh-all:children]\ncdh-all-nodes\ncdh-manager" >> $FILE

DNS=$(extract_public_dns cloudera-launcher)
scp -i "${AWS_KEY_PATH}" -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $FILE ec2-user@$DNS:~/ansible-cdh/inventory/cdh
ssh -i "${AWS_KEY_PATH}" -t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -A ec2-user@$DNS -L 7180:$(extract_private_ip cdh-manager):7180
#export ANSIBLE_HOST_KEY_CHECKING=False; cd ansible-cdh; ansible-playbook site.yml -f 10 -i inventory/cdh -sv
