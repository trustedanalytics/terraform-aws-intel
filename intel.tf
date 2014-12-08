provider "aws" {
	access_key = "${var.aws_access_key}"
	secret_key = "${var.aws_secret_key}"
	region = "${var.aws_region}"
}

module "cf" {
  source = "github.com/cloudfoundry-community/terraform-cf-aws-vpc"
  network = "${var.network}"
  aws_key_name = "${var.aws_key_name}"
  aws_access_key = "${var.aws_access_key}"
  aws_secret_key = "${var.aws_secret_key}"
  aws_region = "${var.aws_region}"
  aws_key_path = "${var.aws_key_path}"
}

module "cloudera" {
  source = "github.com/teancom/terraform-aws-cloudera"
  network = "${var.network}"
  aws_centos_ami = "${lookup(var.aws_centos_ami, var.aws_region)}"
  aws_key_name = "${var.aws_key_name}"
  aws_key_path = "${var.aws_key_path}"
  aws_access_key = "${var.aws_access_key}"
  aws_secret_key = "${var.aws_secret_key}"
  aws_vpc = "${module.cf.aws_default_vpc}"
  aws_route_table_private = "${module.cf.private_route_table}"
  aws_subnet_bastion = "${module.cf.bastion_subnet}"
  hadoop_instance_count = "${var.hadoop_instance_count}" 
  hadoop_instance_type = "${var.hadoop_instance_type}" 
}
