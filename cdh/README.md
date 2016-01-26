terraform-aws-cdh
========================

### Description

This creates a manager vm with floating ip and n number of vms that can be used for slave. This creates keypair and assumes that internal network is already created. After that, ansible scripts from the platform-ansible repo should be used to provision a running CDH instance.

Deploy CDH VMS
--------------------

### Prerequisites

This assumes you have VPC and subnet created for CDH. This is used to deploy CDH after CF has been created.  

### How to run

```bash
git clone https://github.com/trustedanalytics/terraform-aws-cdh
cd terraform-aws-cdh
cp terraform.tfvars.example terraform.tfvars
```

Next, edit `terraform.tfvars` using your text editor and fill out the variables with your own values (AWS credentials, AWS region, etc).

```bash
make plan
make apply
```
