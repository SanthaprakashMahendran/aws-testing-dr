pipeline {

    agent {
        docker {
            image 'gcp-image:fixed'
            args '''
                --entrypoint="" --user=root 
                -v /var/run/docker.sock:/var/run/docker.sock
                -v /var/lib/jenkins/.kube:/root/.kube
                -v /var/lib/jenkins/.config:/root/.config
		-v /root/DR:/root/DR
            '''
        }
    }

    environment {
        PROJECT_ID = "project-d1bd05ab-4df5-4a42-847"
        REGION     = "asia-south1"
        REPO_NAME  = "my-app-repo"
        IMAGE_NAME = "my-app"
        LOCATION   = "asia-south1"
        VERSION    = "${env.BUILD_NUMBER}"  // Jenkins build number
        DEPLOY_DIR = "/root/DR"
        KUBECONFIG = "/root/.kube/config"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Authenticate to GCP') {
            steps {
                sh '''
                    echo "==== Active GCP Account ===="
                    gcloud auth list

                    echo "==== Setting GCP Project ===="
                    gcloud config set project $PROJECT_ID

                    echo "==== Setting GCP region ===="
                    gcloud config set compute/region $REGION
                '''
            }
        }

        stage('Create Artifact Registry Repo (if not exists)') {
            steps {
                sh '''
                    echo "==== Checking Artifact Registry Repo ===="
                    gcloud artifacts repositories describe $REPO_NAME \
                      --location=$LOCATION || \
                    gcloud artifacts repositories create $REPO_NAME \
                      --repository-format=docker \
                      --location=$LOCATION \
                      --description="Docker repo for CI/CD"
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    echo "==== Building Docker Image ===="
                    docker build -t $LOCATION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/$IMAGE_NAME:$VERSION .
                '''
            }
        }

        stage('Push Docker Image to Artifact Registry') {
            steps {
                sh '''
                    echo "==== Configuring Docker Auth ===="
                    gcloud auth configure-docker $LOCATION-docker.pkg.dev -q

                    echo "==== Pushing Docker Image ===="
                    docker push $LOCATION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/$IMAGE_NAME:$VERSION
                '''
            }
        }

        stage('Update Deployment YAML') {
            steps {
                sshagent(['91a9a5b0-4af2-45dd-b4e3-40ea17976aad']) {
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
                            git clone git@github.com:SanthaprakashMahendran/testing-dr.git $DEPLOY_DIR
                            cd $DEPLOY_DIR
                        fi

                        echo "🔁 Updating image tag in deployment.yaml..."
                        sed -i "s|image: .*|image: $LOCATION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/$IMAGE_NAME:$VERSION|" deployment.yaml

                        echo "📦 Committing updated deployment.yaml to Git..."
                        git config user.name "jenkins"
                        git config user.email "jenkins@example.com"
                        git add deployment.yaml
                        git commit -m "Update image to $VERSION" || echo "No changes to commit"
                        git push origin main
                    '''
                }
            }
        }

	stage('Ensure GKE Cluster Exists') {
    steps {
        sh '''
            echo "==== Checking if GKE cluster exists ===="
            if gcloud container clusters describe my-gke-cluster --region=$REGION --project=$PROJECT_ID > /dev/null 2>&1; then
                echo "Cluster already exists. Skipping creation."
            else
                echo "Cluster does NOT exist. Creating GKE cluster..."
                gcloud container clusters create my-gke-cluster \
                    --project $PROJECT_ID \
                    --region $REGION \
                    --num-nodes 2 \
                    --machine-type e2-medium \
                    --disk-size 20GB \
                    --enable-ip-alias \
                    --release-channel regular
            fi

            echo "==== Fetching Cluster Credentials ===="
            gcloud container clusters get-credentials my-gke-cluster \
                --region $REGION \
                --project $PROJECT_ID
        '''
    }
}

        stage('Deploy to GKE') {
            steps {
                sh '''
                    echo "==== Deploying to GKE ===="
                    cd $DEPLOY_DIR
                    kubectl --kubeconfig=$KUBECONFIG get nodes
                    kubectl --kubeconfig=$KUBECONFIG apply -f deployment.yaml
                    kubectl --kubeconfig=$KUBECONFIG apply -f service.yaml
                '''
            }
        }
        
    }
}

