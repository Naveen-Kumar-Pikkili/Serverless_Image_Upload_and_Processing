#!/bin/bash

AWS_REGION="us-east-1"
CF_STACK_NAME="ImageUploadStack"
CF_TEMPLATE_PATH="../cloudformation.yaml"

echo "Checking if stack exists..."
if aws cloudformation describe-stacks --stack-name "$CF_STACK_NAME" --region "$AWS_REGION" &> /dev/null; then
    echo "Stack exists. Checking for template changes..."

    # Get current deployed template
    aws cloudformation get-template \
        --stack-name "$CF_STACK_NAME" \
        --region "$AWS_REGION" \
        --query 'TemplateBody' \
        --output json | jq -S . > deployed-template.json

    # Convert local template to sorted JSON
    jq -S . "$CF_TEMPLATE_PATH" > local-template.json

    # Compare the two templates
    if diff deployed-template.json local-template.json > /dev/null; then
        echo "No changes detected in CloudFormation template. Skipping update."
    else
        echo "Template changes detected. Updating CloudFormation stack..."
        aws cloudformation update-stack \
            --stack-name "$CF_STACK_NAME" \
            --template-body file://$CF_TEMPLATE_PATH \
            --capabilities CAPABILITY_NAMED_IAM \
            --region "$AWS_REGION"
        aws cloudformation wait stack-update-complete \
            --stack-name "$CF_STACK_NAME" \
            --region "$AWS_REGION"
    fi

    # Clean up temporary files
    rm deployed-template.json local-template.json

else
    echo "Creating CloudFormation stack..."
    aws cloudformation create-stack \
        --stack-name "$CF_STACK_NAME" \
        --template-body file://$CF_TEMPLATE_PATH \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "$AWS_REGION"
    aws cloudformation wait stack-create-complete \
        --stack-name "$CF_STACK_NAME" \
        --region "$AWS_REGION"
fi
