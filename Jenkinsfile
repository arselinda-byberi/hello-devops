// Declarative pipeline (Groovy) following a Git Flow branching model:
//   feature/*  -> lint, test, build, smoke-test the image (no deploy)
//   develop    -> ... + push image + deploy to the "dev" namespace
//   main       -> ... + push image + manual approval + deploy to "prod"
//
// Requires a Multibranch Pipeline job and these Jenkins plugins:
//   Pipeline, Git, Docker Pipeline, JUnit, Timestamper

pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
        timeout(time: 30, unit: 'MINUTES')
    }

    environment {
        REGISTRY   = 'localhost:5000'
        APP_NAME   = 'hello-devops'
        IMAGE      = "${REGISTRY}/${APP_NAME}"
        CHART_PATH = 'helm/hello-devops'
    }

    stages {
        stage('Prepare') {
            steps {
                script {
                    // Unique, traceable tag: build number + short commit hash
                    def shortSha = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    env.IMAGE_TAG = "${env.BUILD_NUMBER}-${shortSha}"
                    currentBuild.displayName = "#${env.BUILD_NUMBER} ${env.BRANCH_NAME} ${shortSha}"
                }
                echo "Building ${env.IMAGE}:${env.IMAGE_TAG} from branch ${env.BRANCH_NAME}"
            }
        }

        stage('Lint & Unit tests') {
            agent {
                docker {
                    image 'python:3.12-slim'
                    reuseNode true
                }
            }
            steps {
                sh '''
                    python -m venv .venv
                    . .venv/bin/activate
                    pip install --quiet --no-cache-dir -r app/requirements-dev.txt
                    flake8 app --max-line-length=100
                    cd app && pytest -v --junitxml=../test-results.xml
                '''
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'test-results.xml'
                }
            }
        }

        stage('Lint Helm chart') {
            steps {
                sh """
                    helm lint ${env.CHART_PATH} -f ${env.CHART_PATH}/values-dev.yaml
                    helm lint ${env.CHART_PATH} -f ${env.CHART_PATH}/values-prod.yaml
                    helm template test ${env.CHART_PATH} -f ${env.CHART_PATH}/values-prod.yaml > /dev/null
                """
            }
        }

        stage('Build image') {
            steps {
                sh "docker build --build-arg APP_VERSION=${env.IMAGE_TAG} -t ${env.IMAGE}:${env.IMAGE_TAG} ."
            }
        }

        stage('Smoke test image') {
            steps {
                sh """
                    docker rm -f smoke-${env.BUILD_NUMBER} 2>/dev/null || true
                    docker run -d --name smoke-${env.BUILD_NUMBER} -p 18080:8080 ${env.IMAGE}:${env.IMAGE_TAG}
                    for i in \$(seq 1 15); do
                        if curl -fs http://localhost:18080/healthz; then echo ' -> healthy'; exit 0; fi
                        sleep 2
                    done
                    echo 'Container did not become healthy'
                    docker logs smoke-${env.BUILD_NUMBER}
                    exit 1
                """
            }
            post {
                always {
                    sh "docker rm -f smoke-${env.BUILD_NUMBER} || true"
                }
            }
        }

        stage('Push image') {
            when { anyOf { branch 'develop'; branch 'main' } }
            steps {
                sh "docker push ${env.IMAGE}:${env.IMAGE_TAG}"
            }
        }

        stage('Deploy to dev') {
            when { branch 'develop' }
            steps {
                deployWithHelm('dev')
            }
        }

        stage('Approve production') {
            when { branch 'main' }
            steps {
                timeout(time: 1, unit: 'HOURS') {
                    input message: "Deploy ${env.IMAGE_TAG} to production?", ok: 'Deploy'
                }
            }
        }

        stage('Deploy to prod') {
            when { branch 'main' }
            steps {
                deployWithHelm('prod')
            }
        }
    }

    post {
        success {
            echo "Pipeline succeeded for ${env.BRANCH_NAME} (${env.IMAGE_TAG})"
        }
        failure {
            echo "Pipeline FAILED for ${env.BRANCH_NAME}. Check the stage logs above."
        }
        always {
            // Keep the build host from filling its disk with dangling images
            sh 'docker image prune -f || true'
        }
    }
}

// Reusable Groovy function: deploy, wait for the rollout, roll back on failure
def deployWithHelm(String envName) {
    sh """
        helm upgrade --install ${env.APP_NAME} ${env.CHART_PATH} \
            --namespace ${envName} --create-namespace \
            -f ${env.CHART_PATH}/values-${envName}.yaml \
            --set image.repository=${env.IMAGE} \
            --set image.tag=${env.IMAGE_TAG} \
            --atomic --wait --timeout 3m
        kubectl -n ${envName} rollout status deployment/${env.APP_NAME}
        kubectl -n ${envName} get pods -l app.kubernetes.io/name=${env.APP_NAME} -o wide
    """
}
