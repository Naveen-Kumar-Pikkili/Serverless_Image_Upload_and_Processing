pipeline {
    agent any

    environment {
        AWS_REGION = 'us-east-1'
        LAMBDA_FUNCTION_NAME = 'Image-Upload'
        CF_STACK_NAME = 'ImageUploadStack'
        CF_TEMPLATE_FILE = 'cloudformation.yaml'
        FRONTEND_DIR = 'frontend'
        LAMBDA_DIR = 'backend'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Package Lambda Function') {
            steps {
                dir("${env.LAMBDA_DIR}") {
                    sh '''
                        rm -rf package lambda-function.zip
                        pip install -r requirements.txt -t package/
                        cp lambda_function.py package/
                        cd package
                        zip -r ../lambda-function.zip .
                    '''
                }
            }
        }

        stage('Deploy Lambda Code') {
            steps {
                sh """
                    aws lambda update-function-code \
                        --function-name ${env.LAMBDA_FUNCTION_NAME} \
                        --zip-file fileb://${env.LAMBDA_DIR}/lambda-function.zip \
                        --region ${env.AWS_REGION}
                """
            }
        }

        stage('Deploy CloudFormation Stack') {
            steps {
                sh """
                    if aws cloudformation describe-stacks --stack-name $CF_STACK_NAME --region $AWS_REGION; then
                        aws cloudformation update-stack \
                            --stack-name $CF_STACK_NAME \
                            --template-body file://$CF_TEMPLATE_FILE \
                            --capabilities CAPABILITY_NAMED_IAM \
                            --region $AWS_REGION
                        aws cloudformation wait stack-update-complete --stack-name $CF_STACK_NAME --region $AWS_REGION
                    else
                        aws cloudformation create-stack \
                            --stack-name $CF_STACK_NAME \
                            --template-body file://$CF_TEMPLATE_FILE \
                            --capabilities CAPABILITY_NAMED_IAM \
                            --region $AWS_REGION
                        aws cloudformation wait stack-create-complete --stack-name $CF_STACK_NAME --region $AWS_REGION
                    fi
                """
            }
        }

        stage('Deploy Frontend (Optional)') {
            when {
                expression { fileExists("${env.FRONTEND_DIR}/index.html") }
            }
            steps {
                sh """
                    aws s3 sync ${env.FRONTEND_DIR}/ s3://<your-frontend-s3-bucket>/ --delete
                """
            }
        }
    }

    post {
        success {
            echo '✅ Deployment complete!'
        }
        failure {
            echo '❌ Deployment failed. Check the console logs.'
        }
    }
}
