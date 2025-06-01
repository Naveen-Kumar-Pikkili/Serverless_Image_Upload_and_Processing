#!/bin/bash

set -euo pipefail

STACK_NAME="ImageUploadStack"
TEMPLATE_FILE="cloudformation.yaml"
AWS_REGION="us-east-1"

echo "Deploying CloudFormation stack: $STACK_NAME"
echo "Using template file: $TEMPLATE_FILE"
echo "AWS Region: $AWS_REGION"

# Check if the stack exists
if aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" > /dev/null 2>&1; then
    echo "✅ Stack exists. Attempting to update it..."

    UPDATE_OUTPUT=$(aws cloudformation deploy \
        --stack-name "$STACK_NAME" \
        --template-file "$TEMPLATE_FILE" \
        --region "$AWS_REGION" \
        --capabilities CAPABILITY_NAMED_IAM 2>&1)

    echo "$UPDATE_OUTPUT"

    if echo "$UPDATE_OUTPUT" | grep -q "No changes to deploy"; then
        echo "✅ No updates are to be performed."
    else
        echo "✅ Stack updated successfully."
    fi
else
    echo "🚀 Stack does not exist. Creating a new stack..."

    CREATE_OUTPUT=$(aws cloudformation deploy \
        --stack-name "$STACK_NAME" \
        --template-file "$TEMPLATE_FILE" \
        --region "$AWS_REGION" \
        --capabilities CAPABILITY_NAMED_IAM 2>&1)

    echo "$CREATE_OUTPUT"
    echo "✅ Stack created successfully."
fi
