pipeline {

    agent {
        docker {
            image 'aws-jenkins-agent:v1'  // Your custom AWS image
            args '--entrypoint="" --user=root -v /var/run/docker.sock:/var/run/docker.sock'
        }
    }

    environment {
        AWS_REGION     = "us-east-1"
        AWS_ACCOUNT_ID = "901718802466"
        ECR_REPO_NAME  = "my-app-repo"
        IMAGE_NAME     = "my-app"
        ECR_REGISTRY   = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        IMAGE_TAG      = "${env.BUILD_NUMBER}"   // FIXED → this variable must exist
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Authenticate to AWS') {
            steps {
                sh '''
                    echo "==== AWS Identity ===="
                    aws sts get-caller-identity
                    echo "🔐 Setting up AWS credentials..."

                    mkdir -p .aws 

                    cat > .aws/credentials <<EOF
                    [default]
                    aws_access_key_id=$AWS_ACCESS_KEY_ID
                    aws_secret_access_key=$AWS_SECRET_ACCESS_KEY
                    EOF


                    cat > .aws/config <<EOF
                    [default]
                    region = $AWS_REGION
                    output = json
                    EOF

                    aws sts get-caller-identity

                '''
            }
        }
}

