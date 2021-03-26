SHELL := /bin/bash

.PHONY : help init deploy test clean delete
.DEFAULT: help

# Check for .custom.mk file if exists
CUSTOM_FILE ?= .custom.mk
ifneq ("$(wildcard $(CUSTOM_FILE))","")
    include $(CUSTOM_FILE)
endif

help:
	@echo "deploy       package and deploy solution solution stack to console"
	@echo "delete       delete local generated files and clouldformation stack"

# Install local dependencies
init: venv

# virtualenv setup
venv: venv/bin/activate

# virtualenv setup
venv/bin/activate: requirements.txt
	test -d .venv || virtualenv .venv
	pip install -U pip
	pip install -Ur requirements.txt
	. .venv/bin/activate



test-cfn:
	cfn_nag templates/*.yaml --blacklist-path ci/cfn_nag_blacklist.yaml


version:
	@echo $(shell cfn-flip templates/main.yaml | python -c 'import sys, json; print(json.load(sys.stdin)["Mappings"]["Solution"]["Constants"]["Version"])')

package-layers:
	cd source/lambda-layers ; \
	for i in `ls -d *` ; do \
		cd $$i ; \
		pip install -r requirements.txt -t ./python/ ; \
		zip -q -r9 ../$$i.zip python ; \
		cd .. ; \
	done

package: init
	make package-function
	zip -r packaged.zip templates backend cfn-publish.config build.zip -x **/__pycache* -x *settings.js


package-python:
	@cd source/python && \
	for fn in *; do \
		cd $$fn; \
		printf "\n--> Installing %s requirements...\n" $${fn}; \
		pip install -r requirements.txt --target . --upgrade; \
		cd -; \
	done

package-function:
	make clean
	make package-python
	cd source/modify-response/ && zip -r ../../index.zip index.py


delete:
	@printf "\n--> Deleting %s stack...\n" $(STACK_NAME)
	@aws cloudformation delete-stack --stack-name $(STACK_NAME)
	@printf "\n--> $(STACK_NAME) deletion has been submitted, check AWS CloudFormation Console for an update..."

deploy: init package-function



	@printf "\n--> Packaging and uploading templates to the %s bucket ...\n" $(BUCKET_NAME)
	@aws cloudformation package \
		--template-file ./templates/main.yaml \
      	--s3-bucket $(BUCKET_NAME) \
		--region $(AWS_REGION) \
      	--output-template-file ./templates/packaged.template

	@printf "\n--> Deploying %s template...\n" $(STACK_NAME)

	#aws secretsmanager create-secret --name github-access-token --secret-string <github-personal-access-token>

	@aws cloudformation deploy \
	--template-file ./templates/packaged.template \
	--stack-name $(STACK_NAME) \
	--region $(AWS_REGION) \
	--capabilities CAPABILITY_AUTO_EXPAND CAPABILITY_NAMED_IAM CAPABILITY_IAM \
	--parameter-overrides \
            SubDomain=$(SUB_DOMAIN) \
            DomainName=$(DOMAIN_NAME) \
			Repository=$(REPOSITORY) \
			Branch=$(BRANCH) \
			WithDomainName=$(USE_DOMAIN_NAME) \
			ModifyOriginResponse=$(MODIFY_ORIGIN_RESPONSE)

layers: init package-layers


	@printf "\n--> Packaging and uploading templates to the %s bucket ...\n" $(BUCKET_NAME)
	@aws cloudformation package \
		--template-file ./templates/lambda-layers.yaml \
      	--s3-bucket $(BUCKET_NAME) \
		--region $(AWS_REGION) \
      	--output-template-file ./templates/packaged_layers.template

	@printf "\n--> Deploying %s template...\n" $(STACK_NAME)

	@aws cloudformation deploy \
	--template-file ./templates/packaged_layers.template \
	--stack-name $(STACK_NAME)-layers \
	--region $(AWS_REGION) \
	--capabilities CAPABILITY_AUTO_EXPAND CAPABILITY_NAMED_IAM CAPABILITY_IAM \
