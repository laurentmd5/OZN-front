pipeline {
    agent any

    environment {
        APP_NAME = 'ozn-flutter-app'
        APP_PORT = '8090'

        DOCKER_REGISTRY = 'laurentmd5'
        DOCKER_IMAGE = "${APP_NAME}"
        DOCKER_TAG = "${env.BUILD_NUMBER}"

        TRIVY_CACHE_DIR = '/tmp/trivy-cache-${BUILD_NUMBER}'
        SAST_REPORTS_DIR = 'reports/sast'
        ZAP_REPORTS_DIR = 'reports/zap'

        DEPLOY_SERVER = 'devops@localhost'
        DEPLOY_PATH = '/home/devops/apps'
        SSH_CREDENTIALS_ID = 'ubuntu-server-ssh'

        ZAP_HOST = 'localhost'
        ZAP_PORT = '8090'
        ZAP_TIMEOUT = '300'
    }

    stages {
        stage('Checkout Code') {
            steps {
                git branch: 'main', url: 'https://github.com/laurentmd5/OZN-front.git', credentialsId: 'my-token', poll: false
            }
        }

        stage('Setup Flutter') {
            steps {
                sh '''
                flutter --version
                flutter pub get
                '''
            }
        }

        stage('Flutter Analyze') {
            steps {
                sh '''
                flutter analyze --no-pub --current-package || echo "⚠️ Warnings"
                flutter analyze --no-pub --current-package --fatal-warnings > ${SAST_REPORTS_DIR}/flutter_analysis_detailed.txt || true
                '''
            }
        }

        stage('SAST Checks') {
            steps {
                sh '''
                mkdir -p ${SAST_REPORTS_DIR}/metrics ${SAST_REPORTS_DIR}/security
                dart pub global activate dart_code_metrics 2>/dev/null || true
                export PATH="$PATH:$HOME/.pub-cache/bin"
                metrics analyze lib --reporter=html --output-directory=${SAST_REPORTS_DIR}/metrics || true
                find lib/ -name "*.dart" -exec grep -n -E "password.*=.*['\\\"][^'\\\"]*['\\\"]" {} \\; > ${SAST_REPORTS_DIR}/security/hardcoded-passwords.txt
                find lib/ -name "*.dart" -exec grep -n -i -E "api[_-]?key|secret[_-]?key|token.*=.*['\\\"][^'\\\"]*['\\\"]" {} \\; > ${SAST_REPORTS_DIR}/security/api-secrets.txt
                '''
            }
        }

        stage('Build Flutter Web') {
            steps {
                sh '''
                flutter clean
                flutter build web --release
                ls -la build/web/
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                docker build --build-arg NGINX_PORT=${APP_PORT} \
                  -t ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG} \
                  -t ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest .
                docker images | grep ${DOCKER_REGISTRY} || true
                '''
            }
        }

        stage('Container Security Scan') {
            steps {
                sh '''
                mkdir -p ${TRIVY_CACHE_DIR}
                trivy --cache-dir ${TRIVY_CACHE_DIR} image --exit-code 0 --severity HIGH,CRITICAL \
                      --format table ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest || echo "⚠️ Vulnerabilities found"
                trivy --cache-dir ${TRIVY_CACHE_DIR} image --exit-code 0 --severity HIGH,CRITICAL \
                      --format json -o reports/trivy-scan.json ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest
                '''
            }
        }

        stage('Deploy to Ubuntu Server') {
            steps {
                script {
                    withCredentials([sshUserPrivateKey(credentialsId: SSH_CREDENTIALS_ID, usernameVariable: 'SSH_USER', keyFileVariable: 'SSH_KEY')]) {
                        sh """
                        ssh -i \$SSH_KEY -o StrictHostKeyChecking=no ${DEPLOY_SERVER} '
                          mkdir -p ${DEPLOY_PATH}
                          cd ${DEPLOY_PATH}
                          docker stop ${APP_NAME} 2>/dev/null || true
                          docker rm ${APP_NAME} 2>/dev/null || true
                          docker pull ${DOCKER_REGISTRY}/${APP_NAME}:latest
                          docker run -d --name ${APP_NAME} -p ${APP_PORT}:${APP_PORT} --restart unless-stopped --security-opt=no-new-privileges:true ${DOCKER_REGISTRY}/${APP_NAME}:latest
                        '
                        """
                    }
                }
            }
        }

        stage('OWASP ZAP DAST Scan') {
            steps {
                script {
                    withCredentials([sshUserPrivateKey(credentialsId: SSH_CREDENTIALS_ID, usernameVariable: 'SSH_USER', keyFileVariable: 'SSH_KEY')]) {
                        sh """
                        ssh -i \$SSH_KEY -o StrictHostKeyChecking=no ${DEPLOY_SERVER} '
                          docker run --rm -v /home/devops/zap-reports:/zap/wrk/:rw -t owasp/zap2docker-stable zap-baseline.py \
                          -t http://${ZAP_HOST}:${ZAP_PORT} -r zap-report.html -J zap-report.json -x zap-report.xml -a -T ${ZAP_TIMEOUT} || echo "⚠️ ZAP findings"
                        '
                        """
                    }
                }
            }
        }

        stage('Advanced ZAP API Scan') {
            steps {
                script {
                    withCredentials([sshUserPrivateKey(credentialsId: SSH_CREDENTIALS_ID, usernameVariable: 'SSH_USER', keyFileVariable: 'SSH_KEY')]) {
                        sh """
                        ssh -i \$SSH_KEY -o StrictHostKeyChecking=no ${DEPLOY_SERVER} '
                          docker run --rm -v /home/devops/zap-reports:/zap/wrk/:rw -t owasp/zap2docker-stable zap-api-scan.py \
                          -t http://${ZAP_HOST}:${ZAP_PORT} -f openapi -r api-scan-report.html -J api-scan-report.json -x api-scan-report.xml -a -T ${ZAP_TIMEOUT} || echo "⚠️ ZAP API findings"
                        '
                        """
                    }
                }
            }
        }

        stage('Post-Deployment Security') {
            steps {
                script {
                    withCredentials([sshUserPrivateKey(credentialsId: SSH_CREDENTIALS_ID, usernameVariable: 'SSH_USER', keyFileVariable: 'SSH_KEY')]) {
                        sh """
                        ssh -i \$SSH_KEY -o StrictHostKeyChecking=no ${DEPLOY_SERVER} '
                          trivy container --exit-code 0 ${APP_NAME} || echo "⚠️ Container vulnerabilities"
                          curl -s -I http://localhost:${APP_PORT}/ | grep -E "(X-Frame-Options|X-Content-Type-Options|X-XSS-Protection)" || echo "⚠️ Security headers missing"
                        '
                        """
                    }
                }
            }
        }

        stage('Performance Tests') {
            steps {
                script {
                    withCredentials([sshUserPrivateKey(credentialsId: SSH_CREDENTIALS_ID, usernameVariable: 'SSH_USER', keyFileVariable: 'SSH_KEY')]) {
                        sh """
                        ssh -i \$SSH_KEY -o StrictHostKeyChecking=no ${DEPLOY_SERVER} '
                          for i in {1..5}; do curl -s -o /dev/null http://localhost:${APP_PORT}/ || true; done
                          docker stats ${APP_NAME} --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" || true
                        '
                        """
                    }
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'reports/**/*, build/web/', fingerprint: true
            sh 'docker system prune -f || true'
        }
        success { sh 'echo "🎉 Pipeline SUCCESS!"' }
        failure { sh 'echo "❌ Pipeline FAILED!"' }
    }
}
