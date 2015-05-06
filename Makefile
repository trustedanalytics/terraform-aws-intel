.PHONY: all update plan apply destroy provision

all: update plan apply provision

update:
	./bin/update

plan:
	terraform get -update
	terraform plan -module-depth=-1 -var-file terraform.tfvars -out terraform.tfplan

apply:
	terraform apply -var-file terraform.tfvars

destroy:
	terraform plan -destroy -var-file terraform.tfvars -out terraform.tfplan
	terraform apply terraform.tfplan

clean:
	rm -f terraform.tfplan
	rm -f terraform.tfstate
	rm -fR .terraform/

provision:
	./bin/provision
