# terraform-aws-intel

### Description

This project aims to create one click deploy for Cloud Foundry and Cloudera in
AWS VPC. This is for Intel internal use.

### Branches

*intel/master* is the default branch. There is no *master* branch, since there is no upstream.

## Deploy Cloud Foundry

The one step that isn't automated is the creation of SSH keys. Waiting for feature to be added to terraform.
An AWS SSH Key need to be created in desired region prior to running the following commands.

**NOTE**: You **must** being using at least terraform 0.3.6 for this to work.

```bash
mkdir terraform-cf
cd terraform-cf
terraform apply github.com/intel-data/terraform-aws-intel
```

See terraform.tfvars.example for an example answer file.
