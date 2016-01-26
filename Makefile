SHELL = /bin/bash
.PHONY: all update plan apply destroy provision

include *.mk

all: update plan apply provision

update:
	git pull

ifneq ($(wildcard platform-ansible),)
	cd platform-ansible && git pull origin ${PLATFORM_ANSIBLE_BRANCH}
else
	git clone -b ${PLATFORM_ANSIBLE_BRANCH} ${PLATFORM_ANSIBLE_REPOSITORY} platform-ansible
endif

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
	rm -fr platform-ansible

provision:
	pushd cf-install; export STATE_FILE="../terraform.tfstate"; make provision; popd
	scripts/get_ips.sh
