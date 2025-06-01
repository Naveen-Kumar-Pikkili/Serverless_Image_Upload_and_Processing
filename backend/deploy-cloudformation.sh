#!/bin/bash
set -euo pipefail

STACK_NAME="ImageUploadStack"
TEMPLATE_FILE="../cloudformation.yaml"
AWS_REGION="us-east-1"

echo "Deploying CloudFormation stack: $STACK_NAME"
echo "Using template file: $TEMPLATE_FILE"
echo "AWS Region: $AWS_REGION"

if ! aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
    echo "❌ Stack does not exist. Creating stack..."
    aws cloudformation create-stack \
        --stack-name "$STACK_NAME" \
        --template-body file://"$TEMPLATE_FILE" \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "$AWS_REGION"

    echo "Waiting for stack creation to complete..."
    aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME" --region "$AWS_REGION"
    echo "✅ Stack created successfully."
else
    echo "✅ Stack exists. Attempting to update it..."
    set +e
    UPDATE_OUTPUT=$(aws cloudformation update-stack \
        --stack-name "$STACK_NAME" \
        --template-body file://"$TEMPLATE_FILE" \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "$AWS_REGION" 2>&1)
    UPDATE_EXIT_CODE=$?
    set -e

    if [[ $UPDATE_EXIT_CODE -ne 0 ]]; then
        if echo "$UPDATE_OUTPUT" | grep -q 'No updates are to be performed'; then
            echo "ℹ️ No updates to perform on the stack."
            exit 0
        else
            echo "❌ Stack update failed:"
            echo "$UPDATE_OUTPUT"
            exit $UPDATE_EXIT_CODE
        fi
    fi

    echo "Waiting for stack update to complete..."
    aws cloudformation wait stack-update-complete --stack-name "$STACK_NAME" --region "$AWS_REGION"
    echo "✅ Stack updated successfully."
fi
