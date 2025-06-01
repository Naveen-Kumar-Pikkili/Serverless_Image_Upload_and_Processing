#!/bin/bash

set -e

STACK_NAME="ImageUploadStack"
TEMPLATE_FILE="../cloudformation.yaml"   # Adjusted path
AWS_REGION="us-east-1"

echo "Deploying CloudFormation stack: $STACK_NAME"
echo "Using template file: $TEMPLATE_FILE"
echo "AWS Region: $AWS_REGION"

if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "❌ ERROR: CloudFormation template '$TEMPLATE_FILE' not found in $(pwd)"
    exit 1
fi

# Check if stack exists
if aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" > /dev/null 2>&1; then
    echo "✅ Stack exists. Attempting to update it..."

    set +e
    UPDATE_OUTPUT=$(aws cloudformation deploy \
        --stack-name "$STACK_NAME" \
        --template-file "$TEMPLATE_FILE" \
        --region "$AWS_REGION" \
        --capabilities CAPABILITY_NAMED_IAM 2>&1)
    UPDATE_STATUS=$?
    set -e

    echo "$UPDATE_OUTPUT"

    if echo "$UPDATE_OUTPUT" | grep -q "No changes to deploy"; then
        echo "ℹ️  No updates to perform. Stack is already up to date."
    elif [ $UPDATE_STATUS -eq 0 ]; then
        echo "✅ Stack updated successfully."
    else
        echo "❌ Stack update failed."
        exit 1
    fi
else
    echo "⚠️  Stack does not exist. Creating it..."

    aws cloudformation deploy \
        --stack-name "$STACK_NAME" \
        --template-file "$TEMPLATE_FILE" \
        --region "$AWS_REGION" \
        --capabilities CAPABILITY_NAMED_IAM

    echo "✅ Stack created successfully."
fi
