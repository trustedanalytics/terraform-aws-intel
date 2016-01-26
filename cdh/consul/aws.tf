# vim: ts=2:tw=78: et:

resource "aws_instance" "consul-master" {
  count = "3"
  ami = "${lookup(var.aws_centos_ami, var.aws_region)}"
  private_ip = "${lookup(var.instance_ips, count.index)}"
  instance_type = "t2.medium"
  key_name = "${var.aws_key_name}"
  associate_public_ip_address = false
  security_groups = ["${var.security_group}"]
  subnet_id = "${var.subnet_id}"
  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = "10"
    volume_type = "gp2"
  }

  tags {
    Project = "${var.tags_Project}"
    IAP = "${var.tags_IAP}"
    Environment = "${var.tags_Environment}"
  }

  tags {
   Name = "consul-master-${count.index}"
  }
}

output "consul_masters" {
  value = "${join(",", aws_instance.consul-master.*.private_ip)}"
}
