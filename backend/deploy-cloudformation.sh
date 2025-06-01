#!/bin/bash

STACK_NAME="${1:-ImageUploadStack}"
TEMPLATE_FILE="${2:-../cloudformation.yaml}"
REGION="${3:-us-east-1}"

echo "🚀 Deploying CloudFormation stack: $STACK_NAME"
echo "📄 Template file: $TEMPLATE_FILE"
echo "🌍 AWS Region: $REGION"

# Get current stack status
STACK_STATUS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" \
    --query "Stacks[0].StackStatus" --output text 2>/dev/null)

# Handle ROLLBACK_COMPLETE
if [ "$STACK_STATUS" == "ROLLBACK_COMPLETE" ]; then
    echo "⚠️ Stack is in ROLLBACK_COMPLETE. Deleting and recreating..."
    aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$REGION"
    echo "⏳ Waiting for stack deletion to complete..."
    aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" --region "$REGION"
    echo "✅ Stack deleted. Creating new stack..."
    
    aws cloudformation create-stack \
        --stack-name "$STACK_NAME" \
        --template-body "file://$TEMPLATE_FILE" \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "$REGION" || { echo "❌ Stack creation failed."; exit 1; }

    aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME" --region "$REGION"
    echo "✅ Stack created successfully!"
    exit 0
fi

# If stack does not exist
if [ -z "$STACK_STATUS" ]; then
    echo "🆕 Stack does not exist. Creating..."
    aws cloudformation create-stack \
        --stack-name "$STACK_NAME" \
        --template-body "file://$TEMPLATE_FILE" \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "$REGION" || { echo "❌ Stack creation failed."; exit 1; }

    aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME" --region "$REGION"
    echo "✅ Stack created successfully!"
    exit 0
fi

# If stack exists and is updatable
echo "🔄 Stack exists with status: $STACK_STATUS. Attempting update..."
UPDATE_OUTPUT=$(aws cloudformation update-stack \
    --stack-name "$STACK_NAME" \
    --template-body "file://$TEMPLATE_FILE" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "$REGION" 2>&1)

if echo "$UPDATE_OUTPUT" | grep -q "No updates are to be performed"; then
    echo "⚠️ No updates to perform."
else
    echo "⏳ Waiting for stack update to complete..."
    aws cloudformation wait stack-update-complete --stack-name "$STACK_NAME" --region "$REGION" && \
    echo "✅ Stack updated successfully!"
fi
