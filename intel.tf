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

# vim: ts=2:tw=78: et:

provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region = "${var.aws_region}"
}

module "cf-install" {
  source = "./cf-install"
  network = "${var.network}"
  aws_key_name = "${var.aws_key_name}"
  aws_access_key = "${var.aws_access_key}"
  aws_secret_key = "${var.aws_secret_key}"
  aws_region = "${var.aws_region}"
  aws_key_path = "${var.aws_key_path}"
  cf_admin_pass = "${var.cf_admin_pass}"
  cf_client_pass = "${var.cf_client_pass}"
  install_docker_services = "${var.install_docker_services}"
  cf_size = "${var.cf_size}"
  aws_tags = "${var.aws_tags}"
  deployment_size = "${var.deployment_size}"
  cf_release_version = "${var.cf_release_version}"
  cf_boshworkspace_version = "${var.cf_boshworkspace_version}"
  cf_domain = "${var.cf_domain}"
  debug = "${var.debug}"
  private_cf_domains = "${var.private_cf_domains}"
  additional_cf_sg_allow_1 = "${module.cloudera.aws_cdh_cidr}"
  offline_java_buildpack = "${var.offline_java_buildpack}"
  os_timeout = "${var.os_timeout}"
  git_account_url = "${var.git_account_url}"
  gh_auth = "${var.gh_auth}"
}

module "cloudera" {
  source = "./cdh"
  network = "${var.network}"
  aws_centos_ami = "${var.aws_centos_ami}"
  aws_key_name = "${var.aws_key_name}"
  aws_key_path = "${var.aws_key_path}"
  aws_access_key = "${var.aws_access_key}"
  aws_secret_key = "${var.aws_secret_key}"
  aws_vpc_id = "${module.cf-install.aws_vpc_id}"
  aws_region = "${var.aws_region}"
  aws_route_table_private_id = "${module.cf-install.aws_route_table_private_id}"
  aws_subnet_bastion = "${module.cf-install.aws_subnet_bastion}"
  hadoop_worker_count = "${var.hadoop_worker_count}"
  hadoop_instance_type = "${var.hadoop_instance_type}"
  ansible_repo_path = "${var.ansible_repo_path}"
  security_group = "${module.cf-install.cf_sg_id}"
  tags_IAP = "${module.cf-install.tags.IAP}"
  tags_Project = "${module.cf-install.tags.Project}"
  tags_Environment = "${module.cf-install.tags.Environment}"
}

resource "aws_subnet" "db-lb" {
  vpc_id = "${module.cf-install.aws_vpc_id}"
  cidr_block = "${var.network}.20.0/24"
  tags {
    Environment = "${module.cf-install.tags.Environment}"
    IAP = "${module.cf-install.tags.IAP}"
    Name = "db-lb"
    Project = "${module.cf-install.tags.Project}"
  }
}

resource "aws_route_table_association" "db-lb_private" {
  subnet_id = "${aws_subnet.db-lb.id}"
  route_table_id = "${module.cf-install.aws_route_table_private_id}"
}

resource "aws_security_group" "db-lb" {
  name = "sg_db-lb"
  description = "Allow traffic to db-cluster loadbalancer"
  vpc_id = "${module.cf-install.aws_vpc_id}"
  tags {
    Environment = "${module.cf-install.tags.Environment}"
    IAP = "${module.cf-install.tags.IAP}"
    Name = "db-lb"
    Project = "${module.cf-install.tags.Project}"
  }
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["${var.network}.0.0/24"]
  }
  ingress {
    from_port = 0
    to_port = 65535
    protocol = "tcp"
    cidr_blocks = ["${var.network}.3.0/24", "${var.network}.4.0/24", "${var.network}.0.0/24"]
  }
  ingress {
    from_port = 0
    to_port = 65535
    protocol = "udp"
    cidr_blocks = ["${var.network}.3.0/24", "${var.network}.4.0/24", "${var.network}.0.0/24"]
  }
  ingress {
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 0
    to_port = 65535
    protocol = "tcp"
    self = "true"
  }
  ingress {
    from_port = 0
    to_port = 65535
    protocol = "udp"
    self = "true"
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "db-lb" {
  count = "${var.db-lb_instance_count}"
  ami = "${lookup(var.aws_centos_ami, var.aws_region)}"
  instance_type = "${var.db-lb_instance_type}"
  key_name = "${var.aws_key_name}"
  associate_public_ip_address = false
  security_groups = ["${aws_security_group.db-lb.id}"]
  subnet_id = "${aws_subnet.db-lb.id}"
  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = "10"
    volume_type = "gp2"
  }
  tags {
    Environment = "${module.cf-install.tags.Environment}"
    IAP = "${module.cf-install.tags.IAP}"
    Name = "db-lb-${count.index}"
    Project = "${module.cf-install.tags.Project}"
  }
}

module "mysql-cluster" {
  source = "./mysql-cluster"
  network = "${var.network}"
  aws_centos_ami = "${var.aws_centos_ami}"
  aws_key_name = "${var.aws_key_name}"
  aws_access_key = "${var.aws_access_key}"
  aws_secret_key = "${var.aws_secret_key}"
  aws_vpc_id = "${module.cf-install.aws_vpc_id}"
  aws_region = "${var.aws_region}"
  aws_route_table_private_id = "${module.cf-install.aws_route_table_private_id}"
  bastion_subnet_cidr = "${var.network}.0.0/24"
  cdh_cidr = "${module.cloudera.aws_cdh_cidr}"
  cf_subnet_a_cidr = "${var.network}.3.0/24"
  cf_subnet_b_cidr = "${var.network}.4.0/24"
  db-lb_cidr = "${aws_subnet.db-lb.cidr_block}"
  mysql-cluster_backup_fs_size = "${var.mysql-cluster_backup_fs_size}"
  mysql-cluster_backup_instance_type = "${var.mysql-cluster_backup_instance_type}"
  mysql-cluster_db_fs_size = "${var.mysql-cluster_db_fs_size}"
  mysql-cluster_db_instance_type = "${var.mysql-cluster_db_instance_type}"
  mysql-cluster_size = "${var.mysql-cluster_size}"
  tags_IAP = "${module.cf-install.tags.IAP}"
  tags_Project = "${module.cf-install.tags.Project}"
  tags_Environment = "${module.cf-install.tags.Environment}"
}

output "aws_access_key" {
  value = "${module.cf-install.aws_access_key}"
}

output "aws_secret_key" {
  value = "${module.cf-install.aws_secret_key}"
}

output "aws_region" {
  value = "${module.cf-install.aws_region}"
}

output "bosh_subnet" {
  value = "${module.cf-install.bosh_subnet}"
}

output "ipmask" {
  value = "${module.cf-install.ipmask}"
}

output "cf_api_id" {
  value = "${module.cf-install.cf_api_id}"
}

output "cf_subnet1" {
  value = "${module.cf-install.cf_subnet1}"
}

output "cf_subnet1_az" {
  value = "${module.cf-install.cf_subnet1_az}"
}

output "cf_subnet2" {
  value = "${module.cf-install.cf_subnet2}"
}

output "cf_subnet2_az" {
  value = "${module.cf-install.cf_subnet2_az}"
}

output "bastion_az" {
  value = "${module.cf-install.bastion_az}"
}

output "bastion_id" {
  value = "${module.cf-install.bastion_id}"
}

output "lb_subnet1" {
  value = "${module.cf-install.lb_subnet1}"
}

output "cf_sg" {
  value = "${module.cf-install.cf_sg}"
}

output "cf_boshworkspace_version" {
  value = "${module.cf-install.cf_boshworkspace_version}"
}

output "cf_size" {
  value = "${module.cf-install.cf_size}"
}

output "docker_subnet" {
  value = "${module.cf-install.docker_subnet}"
}

output "install_docker_services" {
  value = "${module.cf-install.install_docker_services}"
}

output "bastion_ip" {
  value = "${module.cf-install.bastion_ip}"
}

output "cf_domain" {
  value = "${module.cf-install.cf_domain}"
}

output "cf_api" {
  value = "${module.cf-install.cf_api}"
}

output "aws_subnet_docker_id" {
  value = "${module.cf-install.aws_subnet_docker_id}"
}

output "aws_vpc_id" {
  value = "${module.cf-install.aws_vpc_id}"
}

output "aws_internet_gateway_id" {
  value = "${module.cf-install.aws_internet_gateway_id}"
}

output "aws_route_table_public_id" {
  value = "${module.cf-install.aws_route_table_public_id}"
}

output "aws_route_table_private_id" {
  value = "${module.cf-install.aws_route_table_private_id}"
}

output "aws_subnet_bastion" {
  value = "${module.cf-install.aws_subnet_bastion}"
}

output "aws_subnet_bastion_availability_zone" {
  value = "${module.cf-install.aws_subnet_bastion_availability_zone}"
}

output "cf_admin_pass" {
  value = "${module.cf-install.cf_admin_pass}"
}

output "cf_client_pass" {
  value = "${var.cf_client_pass}"
}

output "aws_key_path" {
  value = "${module.cf-install.aws_key_path}"
}

output "cf_release_version" {
	value = "${module.cf-install.cf_release_version}"
}

output "backbone_z1_count" { value = "${module.cf-install.backbone_z1_count}" }
output "api_z1_count"      { value = "${module.cf-install.api_z1_count}" }
output "services_z1_count" { value = "${module.cf-install.services_z1_count}" }
output "health_z1_count"   { value = "${module.cf-install.health_z1_count}" }
output "runner_z1_count"   { value = "${module.cf-install.runner_z1_count}" }
output "backbone_z2_count" { value = "${module.cf-install.backbone_z2_count}" }
output "api_z2_count"      { value = "${module.cf-install.api_z2_count}" }
output "services_z2_count" { value = "${module.cf-install.services_z2_count}" }
output "health_z2_count"   { value = "${module.cf-install.health_z2_count}" }
output "runner_z2_count"   { value = "${module.cf-install.runner_z2_count}" }

output "debug" {
	value = "${module.cf-install.debug}"
}

output "private_cf_domains" {
  value = "${module.cf-install.private_cf_domains}"
}

output "additional_cf_sg_allows" {
  value = "${module.cf-install.additional_cf_sg_allows}"
}

output "consul_masters" {
  value = "${module.cloudera.consul_masters}"
}

output "env_name" {
  value = "${var.env_name}"
}

output "install_logsearch" {
  value = "${var.install_logsearch}"
}

output "ls_subnet1" {
  value = "${module.cf-install.ls_subnet1}"
}

output "ls_subnet1_az" {
  value = "${module.cf-install.ls_subnet1_az}"
}

output "aws_security_group_db-lb_id" {
  value = "${aws_security_group.db-lb.id}"
}

output "aws_security_group_db-lb_name" {
  value = "${aws_security_group.db-lb.name}"
}

output "aws_subnet_db-lb_cidr" {
  value = "${aws_subnet.db-lb.cidr_block}"
}

output "aws_instance_db-lb_ids" {
  value = "${join(" ", aws_instance.db-lb.*.id)}"
}

output "aws_security_group_mysql-cluster_db_id" {
  value = "${module.mysql-cluster.aws_security_group_mysql-cluster_db_id}"
}

output "aws_security_group_mysql-cluster_db_name" {
  value = "${module.mysql-cluster.aws_security_group_mysql-cluster_db_name}"
}

output "aws_subnet_mysql-cluster_db_cidr" {
  value = "${module.mysql-cluster.aws_subnet_mysql-cluster_db_cidr}"
}

output "aws_instance_mysql-cluster_backup_ids" {
  value = "${module.mysql-cluster.aws_instance_mysql-cluster_backup_ids}"
}

output "aws_instance_mysql-cluster_db_ids" {
  value = "${module.mysql-cluster.aws_instance_mysql-cluster_db_ids}"
}

output "aws_security_group_cf_id" {
  value = "${module.cf-install.aws_security_group_cf_id}"
}

output "offline_java_buildpack" {
  value = "${module.cf-install.offline_java_buildpack}"
}

output "os_timeout" {
  value = "${module.cf-install.os_timeout}"
}

output "git_account_url" {
  value = "${module.cf-install.git_account_url}"
}

output "gh_auth" {
  value  = "${module.cf-install.gh_auth}"
}

output "quay_username" {
  value = "${var.quay_username}"
}

output "quay_pass" {
  value = "${var.quay_pass}"
}
