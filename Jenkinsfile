pipeline {
    agent any

    environment {
        AWS_REGION = 'us-east-1'
        LAMBDA_FUNCTION_NAME = 'image-processing-function-vpikkili'
        CF_STACK_NAME = 'ImageUploadStack'
        CF_TEMPLATE_FILE = 'cloudformation.yaml'
        LAMBDA_DIR = 'backend'
        FRONTEND_DIR = 'frontend'
    }

    stages {
        stage('Clone GitHub Repository') {
            steps {
                git branch: 'main', url: 'https://github.com/Naveen-Kumar-Pikkili/Serverless_Image_Upload_and_Processing.git'
            }
        }

        stage('Deploy CloudFormation Stack (via Script)') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                    dir("${env.LAMBDA_DIR}") {
                        sh '''
                            chmod +x deploy-cloudformation.sh
                            ./deploy-cloudformation.sh "${CF_STACK_NAME}" "../${CF_TEMPLATE_FILE}" "${AWS_REGION}"
                        '''
                    }
                }
            }
        }

        stage('Update Frontend API URL and API Key') {
            steps {
                script {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                        
                        // Fetch API URL
                        def apiUrl = sh(
                            script: """aws cloudformation describe-stacks --stack-name ${CF_STACK_NAME} --query "Stacks[0].Outputs[?OutputKey=='APIInvokeURL'].OutputValue" --output text --region ${AWS_REGION}""",
                            returnStdout: true
                        ).trim()

                        echo "API URL fetched from CloudFormation: ${apiUrl}"

                        // Fetch API Key
                        def apiKey = sh(
                            script: """aws cloudformation describe-stacks --stack-name ${CF_STACK_NAME} --query "Stacks[0].Outputs[?OutputKey=='ApiKeyValue'].OutputValue" --output text --region ${AWS_REGION}""",
                            returnStdout: true
                        ).trim()

                        echo "API Key fetched from CloudFormation: ${apiKey}"

                        // Replace placeholders in upload.js
                        sh """
                            sed -i 's|API_URL_PLACEHOLDER|${apiUrl}|g' ${FRONTEND_DIR}/upload.js
                            sed -i 's|API_KEY_PLACEHOLDER|${apiKey}|g' ${FRONTEND_DIR}/upload.js
                        """
                    }
                }
            }
        }

        stage('Package Lambda Function') {
            steps {
                dir("${LAMBDA_DIR}") {
                    sh '''
                        docker run --rm \
                            -v "$(pwd)":/var/task \
                            -w /var/task python:3.9 /bin/bash -c "
                                apt-get update && \
                                apt-get install -y gcc libjpeg-dev zlib1g-dev zip jq && \
                                rm -rf package lambda-function.zip && \
                                mkdir -p package && \
                                pip install Pillow==9.5.0 -t package/ && \
                                cp lambda_function.py package/ && \
                                cd package && \
                                zip -r ../lambda-function.zip .
                            "
                    '''
                }
            }
        }

        stage('Deploy Lambda Code') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                    sh """
                        aws lambda update-function-code \
                            --function-name ${LAMBDA_FUNCTION_NAME} \
                            --zip-file fileb://${LAMBDA_DIR}/lambda-function.zip \
                            --region ${AWS_REGION}
                    """
                }
            }
        }
    }

    post {
        success {
            echo '✅ Lambda & CloudFormation deployment complete!'
        }
        failure {
            echo '❌ Deployment failed. Check Jenkins logs for errors.'
        }
    }
}
