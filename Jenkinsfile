pipeline {
    agent any

    environment {
        REGISTRY = 'docker.io/ngxquang12'
        DOCKER_IMAGE = 'spring-boot-template'
        APP_PORT = '8080'
        CONTAINER_NAME = 'spring-boot-app'

        DOCKER_CREDENTIALS_ID = 'dockerhub-creds'
        DEPLOY_SSH_CREDENTIALS_ID = 'deploy-ssh-key'
        DEPLOY_SERVER_CREDENTIALS_ID = 'deploy-server-host'
    }

    options {
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out source code...'
                checkout scm
            }
        }

        stage('Unit Test') {
            steps {
                echo 'Running unit tests...'
                sh './gradlew clean test --no-daemon'
            }
            post {
                always {
                    junit '**/build/test-results/test/*.xml'
                    publishHTML([
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'build/reports/tests/test',
                        reportFiles: 'index.html',
                        reportName: 'Unit Test Report'
                    ])
                }
            }
        }

        stage('Build') {
            steps {
                echo 'Building the project...'
                sh './gradlew clean bootJar --no-daemon'
            }
        }

        stage('Build Docker Image') {
            steps {
                echo 'Building Docker image...'
                script {
                    def shortSha = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    env.IMAGE_TAG = "${env.BUILD_NUMBER}-${shortSha}"

                    sh """
                        docker build -t ${REGISTRY}/${DOCKER_IMAGE}:${IMAGE_TAG} .
                        docker tag ${REGISTRY}/${DOCKER_IMAGE}:${IMAGE_TAG} ${REGISTRY}/${DOCKER_IMAGE}:latest
                    """
                }
            }
        }

        stage('Push to Registry') {
            steps {
                echo 'Pushing Docker image to registry...'
                script {
                    withCredentials([usernamePassword(
                        credentialsId: DOCKER_CREDENTIALS_ID,
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )]) {
                        sh """
                            set -e
                            echo \${DOCKER_PASS} | docker login -u \${DOCKER_USER} --password-stdin ${REGISTRY}
                            docker push ${REGISTRY}/${DOCKER_IMAGE}:${IMAGE_TAG}
                            docker push ${REGISTRY}/${DOCKER_IMAGE}:latest
                            docker logout ${REGISTRY}
                        """
                    }
                }
            }
        }



        stage('Deploy to Server') {
            steps {
                echo 'Deploying to server...'
                script {
                    withCredentials([
                        sshUserPrivateKey(credentialsId: DEPLOY_SSH_CREDENTIALS_ID, keyFileVariable: 'SSH_KEY'),
                        string(credentialsId: DEPLOY_SERVER_CREDENTIALS_ID, variable: 'DEPLOY_SERVER'),
                        usernamePassword(
                            credentialsId: DOCKER_CREDENTIALS_ID,
                            usernameVariable: 'DOCKER_USER',
                            passwordVariable: 'DOCKER_PASS'
                        )
                    ]) {
                        sh """
                            ssh -i \${SSH_KEY} -o StrictHostKeyChecking=no \${DEPLOY_SERVER} << 'ENDSSH'
                                set -e
                                
                                # Login to Docker registry
                                echo \${DOCKER_PASS} | docker login -u \${DOCKER_USER} --password-stdin ${REGISTRY}

                                # Pull latest image
                                docker pull ${REGISTRY}/${DOCKER_IMAGE}:${IMAGE_TAG}

                                # Stop and remove old container
                                docker stop ${CONTAINER_NAME} 2>/dev/null || true
                                docker rm ${CONTAINER_NAME} 2>/dev/null || true

                                # Run new container
                                docker run -d \\
                                    --name ${CONTAINER_NAME} \\
                                    -p ${APP_PORT}:8080 \\
                                    --restart unless-stopped \\
                                    -e SPRING_PROFILES_ACTIVE=prod \\
                                    ${REGISTRY}/${DOCKER_IMAGE}:${IMAGE_TAG}

                                # Cleanup old images (keep last 3)
                                docker images ${REGISTRY}/${DOCKER_IMAGE} --format "{{.Tag}}" | grep -v "latest" | tail -n +4 | xargs -r -I {} docker rmi ${REGISTRY}/${DOCKER_IMAGE}:{} 2>/dev/null || true

                                # Logout
                                docker logout ${REGISTRY}
ENDSSH
                        """
                    }
                }
            }
        }


        stage('Health Check') {
            steps {
                echo 'Performing health check...'
                script {
                    withCredentials([
                        sshUserPrivateKey(credentialsId: "${DEPLOY_SSH_CREDENTIALS_ID}", keyFileVariable: 'SSH_KEY'),
                        string(credentialsId: "${DEPLOY_SERVER_CREDENTIALS_ID}", variable: 'DEPLOY_SERVER')
                    ]) {
                        sh """
                            ssh -i \${SSH_KEY} -o StrictHostKeyChecking=no \${DEPLOY_SERVER} << 'ENDSSH'
                                # Wait for container to start
                                echo "Waiting for application to start..."
                                sleep 15
                                
                                # Check if container is running
                                if docker ps | grep -q ${CONTAINER_NAME}; then
                                    echo "Container ${CONTAINER_NAME} is running"
                                    docker ps | grep ${CONTAINER_NAME}
                                else
                                    echo "Container ${CONTAINER_NAME} is not running"
                                    echo "Container logs:"
                                    docker logs ${CONTAINER_NAME}
                                    exit 1
                                fi
                                
                                # Check application health endpoint (uncomment if you have /actuator/health)
                                # if curl -f http://localhost:${APP_PORT}/actuator/health > /dev/null 2>&1; then
                                #     echo " Application health check passed"
                                # else
                                #     echo "Application health check failed"
                                #     exit 1
                                # fi
ENDSSH
                        """
                    }
                }
            }
        }
    }

    post {
        success {
            echo 'Pipeline completed successfully!'
            echo "Deployed: ${REGISTRY}/${DOCKER_IMAGE}:${IMAGE_TAG}"
        }
        failure {
            echo 'Pipeline failed!'
        }
        always {
            echo 'Cleaning up local Docker images...'
            sh """
                docker rmi ${REGISTRY}/${DOCKER_IMAGE}:${IMAGE_TAG} 2>/dev/null || true
                docker rmi ${REGISTRY}/${DOCKER_IMAGE}:latest 2>/dev/null || true
            """
            cleanWs()
        }
    }
}