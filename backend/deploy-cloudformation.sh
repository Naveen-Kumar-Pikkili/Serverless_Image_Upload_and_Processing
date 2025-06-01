#!/bin/bash

STACK_NAME="ImageUploadStack"
TEMPLATE_FILE="../cloudformation.yaml"
REGION="us-east-1"

echo "Deploying CloudFormation stack: $STACK_NAME"
echo "Using template file: $TEMPLATE_FILE"
echo "AWS Region: $REGION"

# Ensure system clock is synced
echo "Syncing system time..."
sudo ntpdate -u pool.ntp.org || echo "Warning: Could not sync time, please check manually."

# Check if the stack exists
echo "Checking if stack exists..."
STACK_EXISTS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" 2>&1)

if echo "$STACK_EXISTS" | grep -q "does not exist"; then
    echo "❌ Stack does not exist. Creating stack..."
    aws cloudformation create-stack \
        --stack-name "$STACK_NAME" \
        --template-body file://"$TEMPLATE_FILE" \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "$REGION"

    echo "Waiting for stack creation to complete..."
    aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME" --region "$REGION"

    if [ $? -ne 0 ]; then
        echo "❌ Stack creation failed. Checking for rollback..."
        STATUS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" \
            --query "Stacks[0].StackStatus" --output text)

        if [[ "$STATUS" == "ROLLBACK_COMPLETE" ]]; then
            echo "⚠️ Stack in ROLLBACK_COMPLETE. Deleting before retry..."
            aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$REGION"
            aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" --region "$REGION"
            echo "✅ Stack deleted. Re-running script..."
            exec "$0"
        fi
        exit 1
    else
        echo "✅ Stack created successfully."
    fi

else
    echo "✅ Stack exists. Attempting to update it..."

    aws cloudformation update-stack \
        --stack-name "$STACK_NAME" \
        --template-body file://"$TEMPLATE_FILE" \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "$REGION" 2> update_error.txt

    UPDATE_EXIT_CODE=$?

    if grep -q "No updates are to be performed" update_error.txt; then
        echo "⚠️ No updates needed. Stack is already up to date."
        exit 0
    elif grep -q "Stack.*is in ROLLBACK_COMPLETE state and can not be updated" update_error.txt; then
        echo "⚠️ Stack is in ROLLBACK_COMPLETE. Deleting and recreating..."
        aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$REGION"
        aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" --region "$REGION"
        echo "✅ Stack deleted. Re-running script..."
        exec "$0"
    elif grep -q "Signature expired" update_error.txt; then
        echo "⚠️ Signature expired. Retrying after time sync..."
        sudo ntpdate -u pool.ntp.org
        echo "🔁 Retrying update..."
        exec "$0"
    elif [ $UPDATE_EXIT_CODE -ne 0 ]; then
        echo "❌ Stack update failed. See update_error.txt for details."
        cat update_error.txt
        exit 1
    fi

    echo "Waiting for stack update to complete..."
    aws cloudformation wait stack-update-complete --stack-name "$STACK_NAME" --region "$REGION"
    echo "✅ Stack updated successfully."
fi
