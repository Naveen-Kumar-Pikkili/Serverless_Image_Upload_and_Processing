#!/bin/bash
set -e

STACK_NAME=${CF_STACK_NAME:-"ImageUploadStack"}
TEMPLATE_FILE=${CF_TEMPLATE_FILE:-"cloudformation.yaml"}
AWS_REGION=${AWS_REGION:-"us-east-1"}

echo "Deploying CloudFormation stack: $STACK_NAME"
echo "Using template file: $TEMPLATE_FILE"
echo "AWS Region: $AWS_REGION"

# Deploy the stack
DEPLOY_OUTPUT=$(aws cloudformation deploy \
    --stack-name "$STACK_NAME" \
    --template-file "$TEMPLATE_FILE" \
    --region "$AWS_REGION" \
    --capabilities CAPABILITY_NAMED_IAM 2>&1)

echo "$DEPLOY_OUTPUT"

# Check output for update or no change message
if echo "$DEPLOY_OUTPUT" | grep -q "No updates are to be performed"; then
    echo "✅ No changes detected - stack is up to date."
elif echo "$DEPLOY_OUTPUT" | grep -q "Successfully created/updated stack"; then
    echo "✅ Stack created or updated successfully."
else
    echo "⚠️ Deployment output did not match expected patterns."
fi
