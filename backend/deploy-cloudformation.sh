#!/bin/bash

STACK_NAME=ImageUploadStack
TEMPLATE_FILE="../cloudformation.yaml"
REGION="us-east-1"

echo "Deploying CloudFormation stack: $STACK_NAME"
echo "Using template file: $TEMPLATE_FILE"
echo "AWS Region: $REGION"

# Check if stack exists
STACK_EXISTS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "❌ Stack does not exist. Creating stack..."
    aws cloudformation create-stack \
        --stack-name "$STACK_NAME" \
        --template-body file://"$TEMPLATE_FILE" \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "$REGION"

    echo "Waiting for stack creation to complete..."
    aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME" --region "$REGION"
    echo "✅ Stack creation complete!"
else
    # Check the current status
    STACK_STATUS=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query "Stacks[0].StackStatus" \
        --output text)

    echo "✅ Stack exists. Current status: $STACK_STATUS"

    if [ "$STACK_STATUS" == "ROLLBACK_COMPLETE" ]; then
        echo "⚠️  Stack is in ROLLBACK_COMPLETE state. Deleting it..."
        aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$REGION"
        echo "Waiting for stack to be deleted..."
        aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" --region "$REGION"
        echo "🧹 Stack deleted. Recreating..."

        aws cloudformation create-stack \
            --stack-name "$STACK_NAME" \
            --template-body file://"$TEMPLATE_FILE" \
            --capabilities CAPABILITY_NAMED_IAM \
            --region "$REGION"
        
        echo "Waiting for stack creation to complete..."
        aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME" --region "$REGION"
        echo "✅ Stack recreated successfully!"
    else
        echo "📦 Attempting to update the stack..."
        aws cloudformation update-stack \
            --stack-name "$STACK_NAME" \
            --template-body file://"$TEMPLATE_FILE" \
            --capabilities CAPABILITY_NAMED_IAM \
            --region "$REGION"

        echo "Waiting for stack update to complete..."
        aws cloudformation wait stack-update-complete --stack-name "$STACK_NAME" --region "$REGION"
        echo "✅ Stack update complete!"
    fi
fi
