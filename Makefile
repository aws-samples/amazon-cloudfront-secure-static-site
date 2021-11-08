SHELL := /bin/bash

pre-deploy:
ifndef TEMP_BUCKET
	$(error TEMP_BUCKET is undefined)
endif
ifndef ADMIN_EMAIL
	$(error ADMIN_EMAIL is undefined)
endif
ifndef SUBNETS
	$(error SUBNETS is undefined)
endif
ifndef SEC_GROUPS
	$(error SEC_GROUPS is undefined)
endif

pre-run:
ifndef ROLE_NAME
	$(error ROLE_NAME is undefined)
endif

setup-predeploy:
	virtualenv venv
	source venv/bin/activate
	pip install cfn-flip==1.2.2

clean:
	rm -rf *.zip source/witch/nodejs/node_modules/

test-cfn:
	cfn_nag templates/*.yaml --blacklist-path ci/cfn_nag_blacklist.yaml

version:
	@echo $(shell cfn-flip templates/main.yaml | python -c 'import sys, json; print(json.load(sys.stdin)["Mappings"]["Solution"]["Constants"]["Version"])')

package:
	zip -r packaged.zip templates backend cfn-publish.config build.zip -x **/__pycache* -x *settings.js

build-static:
	cd source/witch/ && npm install --prefix nodejs mime-types && cp witch.js nodejs/node_modules/

package-static:
	make build-static
	cd source/witch && zip -r ../../witch.zip nodejs

package-function:
	make clean
	make package-static
	cd source/secured-headers/ && zip -r ../../s-headers.zip index.js

deploy-cfn:
	make package-function
	aws cloudformation package --template-file templates/main.yaml --s3-bucket $(TEMP_BUCKET) --output-template-file packaged.template
	aws cloudformation deploy --template-file ./packaged.template --stack-name $(STACK_NAME) --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
		--parameter-overrides  DomainName=$(DOMAIN_NAME) SubDomain=$(SUBDOMAIN_NAME)

remove-cfn:
	aws cloudformation delete-stack --stack-name $(STACK_NAME)
