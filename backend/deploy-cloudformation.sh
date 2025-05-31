#!/bin/bash

set -e

echo "Checking if stack exists..."
if aws cloudformation describe-stacks --stack-name "$CF_STACK_NAME" --region "$AWS_REGION" > /dev/null 2>&1; then
    echo "Stack exists. Checking for template changes..."

    aws cloudformation get-template \
        --stack-name "$CF_STACK_NAME" \
        --region "$AWS_REGION" \
        --query 'TemplateBody' \
        --output text > deployed-template.yaml

    diff deployed-template.yaml "../$CF_TEMPLATE_FILE" > /dev/null
    if [ $? -eq 0 ]; then
        echo "No changes detected in CloudFormation template. Skipping update."
    else
        echo "Template changes detected. Updating CloudFormation stack..."
        set +e
        aws cloudformation update-stack \
            --stack-name "$CF_STACK_NAME" \
            --template-body file://"../$CF_TEMPLATE_FILE" \
            --capabilities CAPABILITY_NAMED_IAM \
            --region "$AWS_REGION" 2> error.log
        status=$?
        if grep -q "No updates are to be performed" error.log; then
            echo "✅ No updates needed."
            status=0
        fi
        set -e
        exit $status

        echo "Waiting for update to complete..."
        aws cloudformation wait stack-update-complete \
            --stack-name "$CF_STACK_NAME" \
            --region "$AWS_REGION"
    fi
    rm -f deployed-template.yaml error.log
else
    echo "Creating CloudFormation stack..."
    aws cloudformation create-stack \
        --stack-name "$CF_STACK_NAME" \
        --template-body file://"../$CF_TEMPLATE_FILE" \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "$AWS_REGION"

    echo "Waiting for creation to complete..."
    aws cloudformation wait stack-create-complete \
        --stack-name "$CF_STACK_NAME" \
        --region "$AWS_REGION"
fi
