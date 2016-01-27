variable "aws_access_key" {}
variable "aws_key_name" {}
variable "aws_region" {}
variable "aws_secret_key" {}
variable "security_group" {}
variable "subnet_id" {}
variable "tags_Environment" {}
variable "tags_IAP" {}
variable "tags_Project" {}
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
variable "instance_ips" {
  default = {
    "0" = "10.10.10.250"
    "1" = "10.10.10.251"
    "2" = "10.10.10.252"
  }
}
