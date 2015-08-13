SHELL = /bin/bash
.PHONY: all update plan apply destroy provision

all: update plan apply provision

update:
	$(eval has_upstream := $(shell git rev-parse @{u} >/dev/null 2>&1; echo $$?))
	if [ $(has_upstream) -eq 0 ]; then git pull; fi
	# Update submodule pointers; Clean out any submodule changes
	git submodule sync
	git submodule foreach --recursive 'git submodule sync; git clean -d --force --force'
	# Update submodule content, checkout if necessary
	git submodule update --init --recursive --force
	git clean -ffd

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
	pushd cf-install; export STATE_FILE="../terraform.tfstate"; make provision; popd
