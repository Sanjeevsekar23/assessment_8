pipeline {
    agent any

    parameters {
        booleanParam(name: 'SIMULATE_FAULTY_RELEASE', defaultValue: false,
            description: 'Build an image missing its readiness endpoint to test automatic rollback.')
    }

    environment {
        IMAGE_NAME = 'student-placement-portal'
        DEPLOYMENT_NAME = 'student-placement-portal'
        CONTAINER_NAME = 'portal'
        KUBECONFIG_CREDENTIAL_ID = 'placement-kubeconfig'
        DOCKERHUB_CREDENTIAL_ID = 'dockerhub-credentials'
    }

    stages {
        stage('Build image') {
            steps {
                script {
                    def faultyArg = params.SIMULATE_FAULTY_RELEASE ? 'true' : 'false'
                    env.IMAGE_TAG = "${env.BUILD_NUMBER}"
                    withCredentials([usernamePassword(credentialsId: env.DOCKERHUB_CREDENTIAL_ID,
                        usernameVariable: 'DOCKERHUB_USER', passwordVariable: 'DOCKERHUB_TOKEN')]) {
                        env.IMAGE_REPOSITORY = "docker.io/${DOCKERHUB_USER}/${env.IMAGE_NAME}"
                        sh "docker build --build-arg APP_FAULTY=${faultyArg} -t ${env.IMAGE_REPOSITORY}:${env.IMAGE_TAG} ."
                    }
                }
            }
        }

        stage('Push image') {
            steps {
                withCredentials([usernamePassword(credentialsId: env.DOCKERHUB_CREDENTIAL_ID,
                    usernameVariable: 'DOCKERHUB_USER', passwordVariable: 'DOCKERHUB_TOKEN')]) {
                    sh '''
                        set +x
                        printf '%s' "$DOCKERHUB_TOKEN" | docker login --username "$DOCKERHUB_USER" --password-stdin
                        docker push "$IMAGE_REPOSITORY:$IMAGE_TAG"
                        docker logout
                    '''
                }
            }
        }

        stage('Deploy and verify rollout') {
            steps {
                script {
                    withCredentials([file(credentialsId: env.KUBECONFIG_CREDENTIAL_ID, variable: 'KUBECONFIG')]) {
                        sh "sed 's|docker.io/your-dockerhub-username/student-placement-portal:latest|${env.IMAGE_REPOSITORY}:${env.IMAGE_TAG}|' deployment.yaml | kubectl apply -f -"
                        try {
                            sh "kubectl rollout status deployment/${env.DEPLOYMENT_NAME} --timeout=120s"
                        } catch (err) {
                            echo 'Rollout failed. Restoring the previous stable Deployment revision.'
                            sh "kubectl rollout undo deployment/${env.DEPLOYMENT_NAME}"
                            sh "kubectl rollout status deployment/${env.DEPLOYMENT_NAME} --timeout=120s"
                            sh 'kubectl get pods -l app=student-placement-portal -o wide'
                            error('Candidate release failed; previous stable release was restored.')
                        }
                        sh 'kubectl get pods -l app=student-placement-portal -o wide'
                    }
                }
            }
        }

        stage('Verify restored or deployed app') {
            when {
                expression { return !params.SIMULATE_FAULTY_RELEASE }
            }
            steps {
                withCredentials([file(credentialsId: env.KUBECONFIG_CREDENTIAL_ID, variable: 'KUBECONFIG')]) {
                    sh '''
                        set -eu
                        kubectl port-forward service/student-placement-portal 18080:80 >/tmp/placement-port-forward.log 2>&1 &
                        FORWARD_PID=$!
                        trap 'kill "$FORWARD_PID" 2>/dev/null || true' EXIT
                        ATTEMPT=0
                        until curl --fail --silent http://127.0.0.1:18080/healthz >/dev/null; do
                            ATTEMPT=$((ATTEMPT + 1))
                            if [ "$ATTEMPT" -ge 20 ]; then
                                cat /tmp/placement-port-forward.log
                                exit 1
                            fi
                            sleep 1
                        done
                        curl --fail --silent http://127.0.0.1:18080/ | grep -q 'Your next chapter starts here.'
                        kubectl get pods -l app=student-placement-portal
                    '''
                }
            }
        }
    }
}