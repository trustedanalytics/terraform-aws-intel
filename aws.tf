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

resource "aws_subnet" "cloudera" {
  vpc_id = "${var.aws_vpc_id}"
  cidr_block = "${var.network}.10.0/24"
  tags {
    Project = "${var.tags_Project}"
    IAP = "${var.tags_IAP}"
    Environment = "${var.tags_Environment}"
  }
}

module "consul" {
  source = "git::git@github.com:trustedanalytics/terraform-aws-consul.git"
  aws_centos_ami = "${var.aws_centos_ami}"
  aws_key_name = "${var.aws_key_name}"
  aws_access_key = "${var.aws_access_key}"
  aws_secret_key = "${var.aws_secret_key}"
  aws_region = "${var.aws_region}"
  tags_IAP = "${var.tags_IAP}"
  tags_Project = "${var.tags_Project}"
  tags_Environment = "${var.tags_Environment}"
  subnet_id = "${aws_subnet.cloudera.id}"
  security_group = "${var.security_group}"
}

resource "aws_route_table_association" "cloudera-private" {
  subnet_id = "${aws_subnet.cloudera.id}"
  route_table_id = "${var.aws_route_table_private_id}"
}

resource "aws_instance" "cdh-manager" {
  ami = "${lookup(var.aws_centos_ami, var.aws_region)}"
  instance_type = "${var.hadoop_instance_type}"
  key_name = "${var.aws_key_name}"
  associate_public_ip_address = false
  security_groups = ["${var.security_group}"]
  subnet_id = "${aws_subnet.cloudera.id}"
  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = "50"
    volume_type = "gp2"
  }

  tags {
    Project = "${var.tags_Project}"
    IAP = "${var.tags_IAP}"
    Environment = "${var.tags_Environment}"
  }

  tags {
   Name = "cdh-manager"
  }

  connection {
    user = "ec2-user"
    key_file = "${var.aws_key_path}"
  }
}

resource "aws_instance" "cdh-master" {
  count = "3"
  ami = "${lookup(var.aws_centos_ami, var.aws_region)}"
  instance_type = "${var.hadoop_instance_type}"
  key_name = "${var.aws_key_name}"
  associate_public_ip_address = false
  security_groups = ["${var.security_group}"]
  subnet_id = "${aws_subnet.cloudera.id}"
  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = "50"
    volume_type = "gp2"
  }

  ephemeral_block_device {
    device_name = "/dev/sdb"
    virtual_name = "ephemeral0"
  }

  ephemeral_block_device {
    device_name = "/dev/sdc"
    virtual_name = "ephemeral1"
  }

  tags {
    Project = "${var.tags_Project}"
    IAP = "${var.tags_IAP}"
    Environment = "${var.tags_Environment}"
  }

  tags {
   Name = "cdh-master-${count.index}"
  }

}
resource "aws_instance" "cdh-worker" {
  count = "${var.hadoop_worker_count}"
  ami = "${lookup(var.aws_centos_ami, var.aws_region)}"
  instance_type = "${var.hadoop_instance_type}"
  key_name = "${var.aws_key_name}"
  associate_public_ip_address = false
  security_groups = ["${var.security_group}"]
  subnet_id = "${aws_subnet.cloudera.id}"
  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = "50"
    volume_type = "gp2"
  }

  ephemeral_block_device {
    device_name = "/dev/sdb"
    virtual_name = "ephemeral0"
  }

  ephemeral_block_device {
    device_name = "/dev/sdc"
    virtual_name = "ephemeral1"
  }

  tags {
    Project = "${var.tags_Project}"
    IAP = "${var.tags_IAP}"
    Environment = "${var.tags_Environment}"
  }

  tags {
   Name = "cdh-worker-${count.index}"
  }

}

resource "aws_instance" "cloudera-launcher" {
  ami = "${lookup(var.aws_centos_ami, var.aws_region)}"
  instance_type = "t2.small"
  #depends_on = ["aws_instance.cdh-manager", "aws_instance.cdh-master", "aws_instance.cdh-worker"]
  key_name = "${var.aws_key_name}"
  associate_public_ip_address = true
  security_groups = ["${var.security_group}"]
  subnet_id = "${var.aws_subnet_bastion}"

  provisioner "file" {
    source = "${path.module}/provision.sh"
    destination = "/home/ec2-user/provision.sh"
  }
  
  provisioner "file" {
    source = "${var.aws_key_path}"
    destination = "/home/ec2-user/.ssh/id_rsa"
  }

  provisioner "file" {
    source = "${var.ansible_repo_path}"
    destination = "/home/ec2-user/ansible-cdh"
  }

  provisioner "remote-exec" {
    inline = [
        "chmod +x /home/ec2-user/provision.sh",
        "/home/ec2-user/provision.sh"
    ]
  }

  tags {
    Project = "${var.tags_Project}"
    IAP = "${var.tags_IAP}"
    Environment = "${var.tags_Environment}"
  }

  tags {
    Name = "cdh-launcher"
  }

  connection {
    user = "ec2-user"
    key_file = "${var.aws_key_path}"
  }
}

output "aws_cdh_cidr" {
  value = "${aws_subnet.cloudera.cidr_block}"
}

output "consul_masters" {
  value = "${module.consul.consul_masters}"
}
