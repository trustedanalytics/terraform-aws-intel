.PHONY: all plan apply destroy update

TFLAGS = --verbose
TFBIN = terraform
TERRAFORM = $(TFBIN) $(TFLAGS)

all: plan apply

terraform.tfplan: terraform.tfvars *.tf
	$(TERRAFORM) plan -module-depth=-1 -var-file terraform.tfvars -out $@

update:
	$(TERRAFORM) get -update

plan: update terraform.tfplan

apply:
	terraform apply -var-file terraform.tfvars

destroy:
	$(TERRAFORM) plan -destroy -var-file terraform.tfvars -out terraform.tfplan
	$(TERRAFORM) apply terraform.tfplan

clean:
	rm -f terraform.tfplan
	rm -f terraform.tfstate
	rm -fR .terraform/
