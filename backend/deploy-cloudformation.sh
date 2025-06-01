#!/bin/bash

STACK_NAME=${1:-ImageUploadStack}
TEMPLATE_FILE=${2:-../cloudformation.yaml}
REGION=${3:-us-east-1}

echo "Deploying CloudFormation stack: $STACK_NAME"
echo "Using template file: $TEMPLATE_FILE"
echo "AWS Region: $REGION"

# Check stack status
STACK_STATUS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" \
    --query "Stacks[0].StackStatus" --output text 2>/dev/null)

if [ "$STACK_STATUS" == "ROLLBACK_COMPLETE" ]; then
    echo "⚠️ Stack is in ROLLBACK_COMPLETE state. Deleting and recreating..."
    aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$REGION"
    echo "⏳ Waiting for stack to be deleted..."
    aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" --region "$REGION"
    echo "✅ Stack deleted. Recreating..."
    aws cloudformation create-stack \
        --stack-name "$STACK_NAME" \
        --template-body file://$TEMPLATE_FILE \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "$REGION"
    aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME" --region "$REGION"
    echo "✅ Stack created successfully!"
    exit 0
fi

if [ -z "$STACK_STATUS" ]; then
    echo "❌ Stack does not exist. Creating stack..."
    aws cloudformation create-stack \
        --stack-name "$STACK_NAME" \
        --template-body file://$TEMPLATE_FILE \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "$REGION"
    aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME" --region "$REGION"
    echo "✅ Stack created successfully!"
else
    echo "✅ Stack exists with status: $STACK_STATUS. Attempting update..."
    aws cloudformation update-stack \
        --stack-name "$STACK_NAME" \
        --template-body file://$TEMPLATE_FILE \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "$REGION" || echo "⚠️ No updates to perform or update failed."
fi
