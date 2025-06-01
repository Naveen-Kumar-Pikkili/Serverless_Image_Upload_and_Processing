#!/bin/bash

STACK_NAME=$1
TEMPLATE_FILE=$2
REGION=$3
S3_BUCKET=$4
S3_KEY=$5

echo "Deploying CloudFormation stack: $STACK_NAME"
echo "Using template file: $TEMPLATE_FILE"
echo "AWS Region: $REGION"

# Check if stack exists
if aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "✅ Stack exists. Attempting to update it..."
    aws cloudformation update-stack \
        --stack-name "$STACK_NAME" \
        --template-body "file://$TEMPLATE_FILE" \
        --parameters ParameterKey=LambdaS3Bucket,ParameterValue="$S3_BUCKET" ParameterKey=LambdaS3Key,ParameterValue="$S3_KEY" \
        --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
        --region "$REGION"

    aws cloudformation wait stack-update-complete --stack-name "$STACK_NAME" --region "$REGION" && echo "✅ Stack update complete." || echo "❌ Stack update failed."
else
    echo "Stack does not exist. Creating new stack..."
    aws cloudformation create-stack \
        --stack-name "$STACK_NAME" \
        --template-body "file://$TEMPLATE_FILE" \
        --parameters ParameterKey=LambdaS3Bucket,ParameterValue="$S3_BUCKET" ParameterKey=LambdaS3Key,ParameterValue="$S3_KEY" \
        --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
        --region "$REGION"

    aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME" --region "$REGION" && echo "✅ Stack creation complete." || echo "❌ Stack creation failed."
fi
