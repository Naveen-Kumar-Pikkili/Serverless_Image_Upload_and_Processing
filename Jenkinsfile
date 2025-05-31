pipeline {
    agent any

    environment {
        AWS_REGION = 'us-east-1'
        LAMBDA_FUNCTION_NAME = 'ImageProcessingLambda_vpikkili'
        CF_STACK_NAME = 'ImageUploadStack'
        CF_TEMPLATE_FILE = 'cloudformation.yaml'      // in root
        LAMBDA_DIR = 'backend'                        // backend folder
    }

    stages {

        stage('Clone GitHub Repository') {
            steps {
                git branch: 'main', url: 'https://github.com/Naveen-Kumar-Pikkili/Serverless_Image_Upload_and_Processing.git'
            }
        }

        stage('Package Lambda Function') {
            steps {
                dir("${env.LAMBDA_DIR}") {
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
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials'
                ]]) {
                    sh """
                        aws lambda update-function-code \
                            --function-name ${env.LAMBDA_FUNCTION_NAME} \
                            --zip-file fileb://${env.LAMBDA_DIR}/lambda-function.zip \
                            --region ${env.AWS_REGION}
                    """
                }
            }
        }

        stage('Deploy CloudFormation Stack (via Script)') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials'
                ]]) {
                    dir("${env.LAMBDA_DIR}") {
                        sh '''
                            chmod +x deploy-cloudformation.sh
                            ./deploy-cloudformation.sh
                        '''
                    }
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
