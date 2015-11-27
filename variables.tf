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

variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_key_path" {}
variable "aws_key_name" {}
variable "aws_region" {
  default = "us-west-2"
}
variable "network" {
	default = "10.10"
}
variable "cf_admin_pass" {}
variable "cf_domain" {}
variable "cf_client_pass" {
  default = "c1oudc0w"
}

variable "aws_centos_ami" {
    default = {
        us-east-1 = "ami-00a11e68"
        us-west-1 = "ami-ba3c3bff"
        us-west-2 = "ami-11125e21"
        ap-northeast-1 = "ami-9392dc92"
        ap-southeast-1 = "ami-dcbeed8e"
        ap-southeast-2 = "ami-89e88db3"
        eu-central-1 = "ami-e4d6ecf9"
        eu-west-1 = "ami-04a00d73"
        sa-east-1 = "ami-73ee416e"
    }
}

variable "aws_ubuntu_ami" {
    default = {
        us-east-1 = "ami-98aa1cf0"
        us-west-1 = "ami-736e6536"
        us-west-2 = "ami-37501207"
        ap-northeast-1 = "ami-df4b60de"
        ap-southeast-1 = "ami-2ce7c07e"
        ap-southeast-2 = "ami-1f117325"
        eu-central-1 = "ami-423c0a5f"
        eu-west-1 = "ami-f6b11181"
        sa-east-1 = "ami-71d2676c"
    }
}

variable "hadoop_worker_count" {
        default = "5"
}

variable "hadoop_instance_type" {
        default = "m3.2xlarge"
}

variable "ansible_repo_path" {
        default = "platform-ansible"
}

variable "install_docker_services" {
  default = "false"
}

variable "install_logsearch" {
  default = "false"
}

variable "cf_size" {
  default = "tiny"
}

variable "offline_java_buildpack" {
  default = "true"
}

# tag values, key order: Project,IAP,Environment
variable "aws_tags" {
  default = "Foo Bar,00000,Development"
}

variable "cf_boshworkspace_version" {
  default = "cf-207"
}
variable "cf_release_version" {
  default = "207"
}
variable "deployment_size" {
 default = "small"
}

variable "debug" {
 default = "false"
}

variable "private_cf_domains" {
 default = ""
}

variable "env_name" {
  default = "trustedanalytics"
}

variable "db-lb_instance_count" {
  default = "0"
}
variable "db-lb_instance_type" {
  default = "m3.medium"
}
variable "mysql-cluster_backup_fs_size" {
  default = "250"
}
variable "mysql-cluster_backup_instance_type" {
  default = "m3.xlarge"
}
variable "mysql-cluster_db_fs_size" {
  default = "100"
}
variable "mysql-cluster_db_instance_type" {
  default = "r3.large"
}
variable "mysql-cluster_size" {
  default = "none"
}

variable "os_timeout" { default = "1200" }

variable "git_account_url" {
  default = "github.com/trustedanalytics"
}

variable "gh_auth" {
  default = ""
}
