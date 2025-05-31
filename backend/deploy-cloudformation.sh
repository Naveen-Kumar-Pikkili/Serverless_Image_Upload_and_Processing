echo "Stack exists. Checking for template changes..."

aws cloudformation get-template \
    --stack-name "${STACK_NAME}" \
    --region "${AWS_REGION}" \
    --query 'TemplateBody' \
    --output text > deployed-template.yaml

if diff ../${TEMPLATE_FILE} deployed-template.yaml > /dev/null; then
    echo "No changes detected in CloudFormation template. Skipping update."
else
    echo "Template changes detected. Updating CloudFormation stack..."
    aws cloudformation update-stack \
        --stack-name "${STACK_NAME}" \
        --template-body file://../${TEMPLATE_FILE} \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "${AWS_REGION}"

    aws cloudformation wait stack-update-complete \
        --stack-name "${STACK_NAME}" \
        --region "${AWS_REGION}"
fi

rm deployed-template.yaml
