provider "aws" {
	access_key = "${var.aws_access_key}"
	secret_key = "${var.aws_secret_key}"
	region = "${var.aws_region}"
}

module "cf-install" {
  source = "github.com/cloudfoundry-community/terraform-aws-cf-install"
  network = "${var.network}"
  aws_key_name = "${var.aws_key_name}"
  aws_access_key = "${var.aws_access_key}"
  aws_secret_key = "${var.aws_secret_key}"
  aws_region = "${var.aws_region}"
  aws_key_path = "${var.aws_key_path}"
  cf_admin_pass = "WQXng43TEfj"
}

module "cloudera" {
  source = "github.com/teancom/terraform-aws-cloudera"
  network = "${var.network}"
  aws_centos_ami = "${lookup(var.aws_centos_ami, var.aws_region)}"
  aws_key_name = "${var.aws_key_name}"
  aws_key_path = "${var.aws_key_path}"
  aws_access_key = "${var.aws_access_key}"
  aws_secret_key = "${var.aws_secret_key}"
  aws_vpc_id = "${module.cf-install.aws_vpc_id}"
  aws_route_table_private_id = "${module.cf-install.aws_route_table_private_id}"
  aws_subnet_bastion = "${module.cf-install.aws_subnet_bastion}"
  hadoop_instance_count = "${var.hadoop_instance_count}" 
  hadoop_instance_type = "${var.hadoop_instance_type}" 
}
