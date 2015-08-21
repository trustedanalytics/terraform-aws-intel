# terraform-aws-intel

This project aims to create one click deploy for Cloud Foundry and Cloudera in AWS VPC.


## Deploy Cloud Foundry

The one step that isn't automated is the creation of SSH keys. Waiting for feature to be added to terraform.
An AWS SSH Key need to be created in desired region prior to running the following commands.

**NOTE**: You **must** be using at least terraform 0.3.6 for this to work. It is recommended to use latest supported version: 0.5.3.

```bash
mkdir terraform-cf
cd terraform-cf
terraform apply github.com/trustedanalytics/terraform-aws-intel
```

See terraform.tfvars.example for an example answer file.
