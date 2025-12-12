
pipeline {

    agent {
        docker {
            image 'aws-jenkins-agent:v1'
           args '''
            --entrypoint="" --user=root 
            -v /var/run/docker.sock:/var/run/docker.sock
            -v /var/lib/jenkins/.kube:/root/.kube
            -v /var/lib/jenkins/.aws:/root/.aws
            -v /root/AWS_DR:/root/AWS_DR
        '''
        }
    }

    environment {
        AWS_REGION     = "us-east-1"
        AWS_ACCOUNT_ID = "901718802466"
        ECR_REPO_NAME  = "my-app-repo"
        IMAGE_NAME     = "my-app"
        ECR_REGISTRY   = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        IMAGE_TAG      = "${env.BUILD_NUMBER}"
	    DEPLOY_DIR     = "/root/AWS_DR"
        EKS_CLUSTER_NAME = "my-eks-cluster"
        EKS_NODE_GROUP   = "my-eks-nodegroup"
        EKS_VERSION      = "1.30"
        SUBNETS          = "subnet-0dea288dae3c103be subnet-088e403558a50bb7a"
        SEC_GROUP        = "sg-02700ae462c9b668e"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Authenticate to AWS') {
            steps {
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']
                ]) {
                    sh '''
                        echo "==== AWS Identity (Before setting creds) ===="
                        aws sts get-caller-identity || true

                        echo "==== Writing AWS Credentials ===="

                        mkdir -p ~/.aws

                        cat > ~/.aws/credentials <<EOF
[default]
aws_access_key_id=$AWS_ACCESS_KEY_ID
aws_secret_access_key=$AWS_SECRET_ACCESS_KEY
EOF

                        cat > ~/.aws/config <<EOF
[default]
region = $AWS_REGION
output = json
EOF

                        echo "==== AWS Identity (After setting creds) ===="
                        aws sts get-caller-identity
                    '''
                }
            }
        }

	stage('Create ECR Repo If Not Exists') {
    steps {
        withCredentials([
            [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']
        ]) {

            sh '''
                echo "==== Checking ECR Repository ===="

                EXISTS=$(aws ecr describe-repositories \
                    --repository-names "$ECR_REPO_NAME" \
                    --region "$AWS_REGION" \
                    --query "repositories[0].repositoryName" \
                    --output text 2>/dev/null || true)

                if [ "$EXISTS" = "None" ] || [ -z "$EXISTS" ]; then
                    echo "Repository does NOT exist. Creating: $ECR_REPO_NAME"

                    aws ecr create-repository \
                        --repository-name "$ECR_REPO_NAME" \
                        --image-tag-mutability MUTABLE \
                        --region "$AWS_REGION"

                    echo "==== ECR Repository created successfully ===="
                else
                    echo "==== ECR Repository already exists: $EXISTS ===="
                fi
            '''
        }
    }
}

	stage('Login to ECR') {
    steps {
        withCredentials([
            [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']
        ]) {
            sh '''
                echo "Logging in to Amazon ECR..."

                aws ecr get-login-password --region $AWS_REGION | \
                    docker login --username AWS --password-stdin $ECR_REGISTRY

                echo "==== ECR Login Successful ===="
            '''
        }
    }
}

	stage('Build Docker Image') {
    steps {
        sh '''
            echo "==== Building Docker Image ===="

            docker build -t $IMAGE_NAME:$IMAGE_TAG .
        '''
    }
}


	stage('Tag Docker Image') {
    steps {
        sh '''
            echo "==== Tagging Docker Image ===="

            docker tag $IMAGE_NAME:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPO_NAME:$IMAGE_TAG
        '''
    }
}

	stage('Push Docker Image') {
    steps {
        sh '''
            echo "==== Pushing Docker Image to ECR ===="

            docker push $ECR_REGISTRY/$ECR_REPO_NAME:$IMAGE_TAG

            echo "==== Docker Image Pushed Successfully ===="
        '''
    }
}

	stage('Update Deployment YAML') {
    steps {
        sshagent(['git-key']) {

            sh '''
                echo "==== Setting up SSH known_hosts ===="
                mkdir -p ~/.ssh
                ssh-keyscan github.com >> ~/.ssh/known_hosts
                chmod 644 ~/.ssh/known_hosts

                echo "==== Cloning repo for deployment ===="

                if [ -d "$DEPLOY_DIR" ]; then
                    cd $DEPLOY_DIR
                    git reset --hard
                    git pull origin main
                else
                    git clone git@github.com:SanthaprakashMahendran/aws-testing-dr.git $DEPLOY_DIR
                    cd $DEPLOY_DIR
                fi

                echo "==== Updating container image in deployment.yaml (AWS ECR) ===="

                NEW_IMAGE="$ECR_REGISTRY/$ECR_REPO_NAME/$IMAGE_NAME:$IMAGE_TAG"
                echo "Using Image: $NEW_IMAGE"

                sed -i "s|image: .*|image: $NEW_IMAGE|" deployment.yaml

                echo "==== Committing updated deployment.yaml to Git ===="
                git config user.name "jenkins"
                git config user.email "jenkins@example.com"
                git add deployment.yaml
                git commit -m "Update image to $IMAGE_TAG" || echo "No changes to commit"
                git push origin main
            '''
        }
    }
}
	
    stage('Create EKS Cluster If Not Exists') {
    steps {
        withCredentials([
            [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']
        ]) {
            sh '''
                echo "==== Checking if EKS cluster exists ===="
                STATUS=$(aws eks describe-cluster \
                    --name $EKS_CLUSTER_NAME \
                    --region $AWS_REGION \
                    --query "cluster.status" \
                    --output text 2>/dev/null || true)

                if [ "$STATUS" = "ACTIVE" ]; then
                    echo "==== EKS Cluster already exists ===="
                    exit 0
                fi

                echo "==== Creating EKS Cluster: $EKS_CLUSTER_NAME ===="

                aws eks create-cluster \
                    --name $EKS_CLUSTER_NAME \
                    --region $AWS_REGION \
                    --kubernetes-version "$EKS_VERSION" \
                    --role-arn arn:aws:iam::$AWS_ACCOUNT_ID:role/EKS-ClusterRole \
                    --resources-vpc-config subnetIds=${SUBNETS// /,},securityGroupIds=$SEC_GROUP,endpointPublicAccess=true

                echo "==== Waiting for EKS Control Plane ===="
                aws eks wait cluster-active \
                    --name $EKS_CLUSTER_NAME \
                    --region $AWS_REGION
            '''
        }
    }
}

        stage('Create Node Group If Not Exists') {
    steps {
        withCredentials([
            [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']
        ]) {
            sh '''
                echo "==== Checking if Node Group exists ===="

                NG_STATUS=$(aws eks describe-nodegroup \
                    --cluster-name $EKS_CLUSTER_NAME \
                    --nodegroup-name $EKS_NODE_GROUP \
                    --region $AWS_REGION \
                    --query "nodegroup.status" \
                    --output text 2>/dev/null || true)

                if [ "$NG_STATUS" = "ACTIVE" ]; then
                    echo "==== Node Group already exists ===="
                    exit 0
                fi

                echo "==== Creating Node Group: $EKS_NODE_GROUP ===="

                aws eks create-nodegroup \
                    --cluster-name $EKS_CLUSTER_NAME \
                    --nodegroup-name $EKS_NODE_GROUP \
                    --scaling-config minSize=1,maxSize=3,desiredSize=1 \
                    --subnets $SUBNETS \
                    --instance-types t3.medium \
                    --node-role arn:aws:iam::$AWS_ACCOUNT_ID:role/EKS-NodeRole \
                    --region $AWS_REGION

                echo "==== Waiting for Node Group to be active ===="
                aws eks wait nodegroup-active \
                    --cluster-name $EKS_CLUSTER_NAME \
                    --nodegroup-name $EKS_NODE_GROUP \
                    --region $AWS_REGION
            '''
        }
    }
}

        stage('Configure kubectl for EKS') {
    steps {
        withCredentials([
            [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']
        ]) {
            sh '''
                echo "==== Updating kubeconfig ===="

                aws eks update-kubeconfig \
                    --region $AWS_REGION \
                    --name $EKS_CLUSTER_NAME

                kubectl get nodes
            '''
        }
    }
}



        stage('Deploy to EKS') {
    steps {
        sh '''
            echo "==== Applying Deployment to EKS ===="

            cd $DEPLOY_DIR
            kubectl apply -f deployment.yaml

            echo "==== Waiting for rollout ===="
            kubectl rollout status deployment/my-app-deployment
        '''
    }
}

        

    } // stages

} // pipeline
