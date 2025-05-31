#!/bin/bash
set -e

AWS_REGION="us-east-1"
CF_STACK_NAME="ImageUploadStack"
CF_TEMPLATE_FILE="cloudformation.yaml"

echo "Checking if stack exists..."
if aws cloudformation describe-stacks --stack-name "$CF_STACK_NAME" --region "$AWS_REGION" > /dev/null 2>&1; then
    echo "Stack exists. Checking for template changes..."
    aws cloudformation get-template --stack-name "$CF_STACK_NAME" --region "$AWS_REGION" --query TemplateBody --output text > deployed-template.yaml
    
    if diff deployed-template.yaml "$CF_TEMPLATE_FILE" > /dev/null; then
        echo "No template changes detected. Skipping update."
        exit 0
    else
        echo "Template changes detected. Updating CloudFormation stack..."
        aws cloudformation update-stack \
            --stack-name "$CF_STACK_NAME" \
            --template-body file://"$CF_TEMPLATE_FILE" \
            --capabilities CAPABILITY_NAMED_IAM \
            --region "$AWS_REGION"
        aws cloudformation wait stack-update-complete \
            --stack-name "$CF_STACK_NAME" \
            --region "$AWS_REGION"
        echo "CloudFormation stack updated successfully."
    fi
else
    echo "Stack does not exist. Creating stack..."
    aws cloudformation create-stack \
        --stack-name "$CF_STACK_NAME" \
        --template-body file://"$CF_TEMPLATE_FILE" \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "$AWS_REGION"
    aws cloudformation wait stack-create-complete \
        --stack-name "$CF_STACK_NAME" \
        --region "$AWS_REGION"
    echo "CloudFormation stack created successfully."
fi
