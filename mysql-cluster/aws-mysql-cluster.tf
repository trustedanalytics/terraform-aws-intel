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

#notes:
# - "cidr_blocks" are used instead of "security_groups" in aws_security_group resources in ingress rules because of https://github.com/hashicorp/terraform/issues/2857

provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region = "${var.aws_region}"
}

resource "aws_subnet" "mysql-cluster_db" {
  vpc_id = "${var.aws_vpc_id}"
  cidr_block = "${var.network}.21.0/24"
  tags {
    Environment = "${var.tags_Environment}"
    IAP = "${var.tags_IAP}"
    Name = "mysql-cluster_db"
    Project = "${var.tags_Project}"
  }
}

resource "aws_route_table_association" "mysql-cluster_db_private" {
  subnet_id = "${aws_subnet.mysql-cluster_db.id}"
  route_table_id = "${var.aws_route_table_private_id}"
}

resource "aws_security_group" "mysql-cluster_db" {
  name = "sg_mysql-cluster_db"
  description = "Allow traffic to mysql-cluster db instances"
  vpc_id = "${var.aws_vpc_id}"
  tags {
    Environment = "${var.tags_Environment}"
    IAP = "${var.tags_IAP}"
    Name = "mysql-cluster_db"
    Project = "${var.tags_Project}"
  }
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["${var.bastion_subnet_cidr}"]
  }
  ingress {
    from_port = 0
    to_port = 65535
    protocol = "tcp"
    cidr_blocks = ["${var.bastion_subnet_cidr}", "${var.cdh_cidr}", "${var.cf_subnet_a_cidr}", "${var.cf_subnet_b_cidr}", "${var.db-lb_cidr}"]
  }
  ingress {
    from_port = 0
    to_port = 65535
    protocol = "udp"
    cidr_blocks = ["${var.bastion_subnet_cidr}", "${var.cdh_cidr}", "${var.cf_subnet_a_cidr}", "${var.cf_subnet_b_cidr}", "${var.db-lb_cidr}"]
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = -1
    to_port = -1
    protocol = "icmp"
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

resource "aws_instance" "mysql-cluster_backup" {
  count = "${lookup(var.mysql-cluster_backup_instance_count, var.mysql-cluster_size)}"
  ami = "${lookup(var.aws_centos_ami, var.aws_region)}"
  instance_type = "${var.mysql-cluster_backup_instance_type}"
  key_name = "${var.aws_key_name}"
  associate_public_ip_address = false
  security_groups = ["${aws_security_group.mysql-cluster_db.id}"]
  subnet_id = "${aws_subnet.mysql-cluster_db.id}"
  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = "10"
    volume_type = "gp2"
  }
  ebs_block_device {
    device_name = "/dev/sdf"
    volume_size = "${var.mysql-cluster_backup_fs_size}"
    volume_type = "gp2"
  }
  tags {
    Environment = "${var.tags_Environment}"
    IAP = "${var.tags_IAP}"
    Name = "mysql-cluster_backup"
    Project = "${var.tags_Project}"
  }
}

resource "aws_instance" "mysql-cluster_db" {
  count = "${lookup(var.mysql-cluster_db_instance_count, var.mysql-cluster_size)}"
  ami = "${lookup(var.aws_centos_ami, var.aws_region)}"
  instance_type = "${var.mysql-cluster_db_instance_type}"
  key_name = "${var.aws_key_name}"
  associate_public_ip_address = false
  security_groups = ["${aws_security_group.mysql-cluster_db.id}"]
  subnet_id = "${aws_subnet.mysql-cluster_db.id}"
  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = "10"
    volume_type = "gp2"
  }
  ebs_block_device {
    device_name = "/dev/sdf"
    volume_size = "${var.mysql-cluster_backup_fs_size}"
    volume_type = "gp2"
  }
  tags {
    Environment = "${var.tags_Environment}"
    IAP = "${var.tags_IAP}"
    Name = "mysql-cluster_db-${count.index}"
    Project = "${var.tags_Project}"
  }
}

output "aws_security_group_mysql-cluster_db_id" {
  value = "${aws_security_group.mysql-cluster_db.id}"
}

output "aws_security_group_mysql-cluster_db_name" {
  value = "${aws_security_group.mysql-cluster_db.name}"
}

output "aws_subnet_mysql-cluster_db_cidr" {
  value = "${aws_subnet.mysql-cluster_db.cidr_block}"
}

output "aws_instance_mysql-cluster_backup_ids" {
  value = "${join(" ", aws_instance.mysql-cluster_backup.*.id)}"
}

output "aws_instance_mysql-cluster_db_ids" {
  value = "${join(" ", aws_instance.mysql-cluster_db.*.id)}"
}
