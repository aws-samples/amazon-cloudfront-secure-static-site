#!/bin/bash

SCRIPTS_DIR=$(dirname "$0")
ROOT_DIR=$(dirname "$0")/..

source "$SCRIPTS_DIR/helpers.sh"

# Disable automatic pagination for AWS CLI commands
export AWS_PAGER=""

# TODO: extract configuration; parametrize input

NAME="aw1"
ENVIRONMENT="dev"  # dev | staging | prod
STACK_NAME="${NAME}-${ENVIRONMENT}"
REGION="us-east-1"
PACKAGE_BUCKET="${NAME}-cf-templates-${REGION}"

DOMAIN="andrejkolic.com"
SUBDOMAIN="${NAME}-${ENVIRONMENT}"
HOSTED_ZONE_ID="Z00295123IDZ7CVMX671W"

PARAMETER_DEFINITIONS="\
    DomainName=${DOMAIN} \
    SubDomain=${SUBDOMAIN} \
    HostedZoneId=${HOSTED_ZONE_ID} \
    Environment=${ENVIRONMENT} \
"

package_artifacts() {
    print_info "Packaging artifacts..."
    # Create the package bucket
    aws s3 mb s3://$PACKAGE_BUCKET --region $REGION

    # Package the solution’s artifacts as a CloudFormation template
    if ! aws cloudformation package \
        --region $REGION \
        --template-file ${ROOT_DIR}/templates/main.yaml \
        --s3-bucket $PACKAGE_BUCKET \
        --output-template-file ${ROOT_DIR}/packaged.template
    then
        print_error "Failed to package artifacts"
        exit 1
    fi
}

deploy_infrastructure() {
    print_info "Deploying infrastructure..."
    if ! aws cloudformation deploy \
        --region $REGION \
        --stack-name $STACK_NAME \
        --template-file ${ROOT_DIR}/packaged.template \
        --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
        --parameter-overrides $PARAMETER_DEFINITIONS \
        --tags Solution=ACFS3 Environment=$ENVIRONMENT
    then
        print_error "Failed to deploy infrastructure"
        exit 1
    fi
}

sync_site_content() {
    print_info "Syncing site content to S3..."

    # Replace this with your actual site build/output directory
    SITE_DIR="./www"

    # Get the S3 bucket name from CloudFormation outputs
    BUCKET_NAME=$(aws cloudformation describe-stacks \
        --region $REGION \
        --stack-name $STACK_NAME \
        --query "Stacks[0].Outputs[?OutputKey=='S3BucketRoot'].OutputValue" \
        --output text)

    if [ -z "$BUCKET_NAME" ]; then
        print_error "Could not retrieve S3 bucket name from stack outputs."
        exit 1
    fi

    print_info "BUCKET_NAME: $BUCKET_NAME"

    aws s3 sync "$SITE_DIR" "s3://$BUCKET_NAME" --delete

    print_success "Site content synced to s3://$BUCKET_NAME"
}

invalidate_cloudfront_cache() {
    print_info "Invalidating CloudFront cache..."

    # Get the CloudFront Distribution ID from CloudFormation outputs
    DISTRIBUTION_ID=$(aws cloudformation describe-stacks \
        --region $REGION \
        --stack-name $STACK_NAME \
        --query "Stacks[0].Outputs[?OutputKey=='CFDistributionId'].OutputValue" \
        --output text)

    if [ -z "$DISTRIBUTION_ID" ]; then
        print_error "Could not retrieve CloudFront Distribution ID from stack outputs."
        exit 1
    fi

    print_info "DISTRIBUTION_ID: $DISTRIBUTION_ID"

    # Invalidate all objects (you can change the path as needed)
    aws cloudfront create-invalidation \
        --distribution-id "$DISTRIBUTION_ID" \
        --paths "/*"

    print_success "CloudFront cache invalidation requested."
}

main() {
    print_info "Starting deployment process..."
    
    package_artifacts
    deploy_infrastructure

    print_success "Deployment completed successfully."
}

main

# sync_site_content
# invalidate_cloudfront_cache
