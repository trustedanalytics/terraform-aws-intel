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

variable "aws_vpc_id" {}
variable "network" {}
variable "aws_route_table_private_id" {}
variable "aws_subnet_bastion" {}
variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_key_name" {}
variable "aws_key_path" {}
variable "ansible_repo_path" {}
variable "security_group" {}

variable "network" {
  default = "10.10"
}

variable "hadoop_instance_type" {
  default = "m3.xlarge"
}

variable "hadoop_worker_count" {
  default = 3
}

variable "aws_region" {
  default = "us-west-2"
}

variable "aws_centos_ami" {
    default = {
        us-east-1 = "ami-00a11e68"
        us-west-1 = "ami-4b3f350e"
        us-west-2 = "ami-11125e21"
        ap-northeast-1 = "ami-9392dc92"
        ap-southeast-1 = "ami-dcbeed8e"
        ap-southeast-2 = "ami-89e88db3"
        eu-west-1 = "ami-04a00d73"
        eu-central-1 = "ami-e4d6ecf9"
        sa-east-1 = "ami-73ee416e"
    }
}

variable "ansible_repo_path" {
  default = "/tmp"
}

variable "tags_Environment" {}

variable "tags_IAP" {}

variable "tags_Project" {}
