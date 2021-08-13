SHELL=/bin/bash -euxo pipefail

.DEFAULT: validate

STACK_NAME					?=b2bperimeter
AWS_ACCOUNT_ID				?=085941769644
AWS_REGION					?=ap-southeast-2
DEPLOYMENT_BUCKET_NAME		?=dot-${AWS_ACCOUNT_ID}-${AWS_REGION}-deployments-${STACK_NAME}
STACK_FILE_NAME				?=stack.yaml

STUBS_STACK_NAME			?=b2bperimeter-stubs
STUBS_STACK_FILE_NAME		?=stack.yaml

OUTPUT_FOLDER_NAME			?=.out

setup:
	rm -rf ./.out && mkdir ./.out && mkdir ./.out/stubs

	-aws s3api create-bucket --bucket ${DEPLOYMENT_BUCKET_NAME} --region ap-southeast-2 --create-bucket-configuration LocationConstraint=ap-southeast-2

cfn-lint:
	cfn-lint files/*.yaml files/*.yml

cfn-nag:
	cfn_nag_scan --input-path files

validate: cfn-lint cfn-nag

package:
	aws cloudformation package \
		--template-file files/${STACK_FILE_NAME} \
		--s3-bucket ${DEPLOYMENT_BUCKET_NAME} \
		--output-template-file ${OUTPUT_FOLDER_NAME}/${STACK_FILE_NAME}

deploy: package
	aws s3 cp ./files s3://${DEPLOYMENT_BUCKET_NAME} --recursive

	aws cloudformation deploy \
		--stack-name ${STACK_NAME} \
		--template-file ${OUTPUT_FOLDER_NAME}/${STACK_FILE_NAME} \
		--capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
		--no-fail-on-empty-changeset

package-stubs: validate
	aws cloudformation package \
		--template-file files/stubs/${STUBS_STACK_FILE_NAME} \
		--s3-bucket ${DEPLOYMENT_BUCKET_NAME} \
		--output-template-file ${OUTPUT_FOLDER_NAME}/stubs/${STUBS_STACK_FILE_NAME}

deploy-stubs: package-stubs
	aws s3 cp ./files/stubs s3://${DEPLOYMENT_BUCKET_NAME}/stubs/ --recursive

	aws cloudformation deploy \
		--stack-name ${STUBS_STACK_NAME} \
		--template-file ${OUTPUT_FOLDER_NAME}/stubs/${STUBS_STACK_FILE_NAME} \
		--capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
		--no-fail-on-empty-changeset

clean:
	-aws cloudformation delete-stack \
		--stack-name ${STACK_NAME}

clean-stubs:
	-aws cloudformation delete-stack \
		--stack-name ${STUBS_STACK_NAME}

clean-all: clean clean-stubs
