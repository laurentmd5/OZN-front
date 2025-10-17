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
                git branch: 'main',
                    url: 'https://github.com/laurentmd5/OZN-front.git',
                    credentialsId: 'my-token',
                    poll: false

                sh '''
                echo "📦 Repository: https://github.com/laurentmd5/OZN-front.git"
                echo "📝 Branch: main"
                echo "🔍 Structure du projet:"
                find . -name "pubspec.yaml" -o -name "*.dart" | head -10
                ls -la lib/ pubspec.yaml
                '''
            }
        }

        stage('Setup Flutter') {
            steps {
                sh '''
                echo "🔧 Setting up Flutter environment..."
                flutter --version || { echo "❌ Flutter non disponible"; exit 1; }
                flutter pub get || { echo "❌ Erreur dependencies"; exit 1; }
                '''
            }
        }

        stage('Flutter Analyze') {
            steps {
                sh '''
                echo "🔍 Running Flutter Analyze..."
                mkdir -p ${SAST_REPORTS_DIR}
                flutter analyze --no-pub --current-package || echo "⚠️ Flutter analyze completed with warnings"
                flutter analyze --no-pub --current-package --fatal-warnings > ${SAST_REPORTS_DIR}/flutter_analysis_detailed.txt || true
                echo "✅ Flutter Analyze completed"
                '''
            }
        }

        stage('SAST') {
            steps {
                sh '''
                echo "🛡️ Running SAST checks..."
                mkdir -p ${SAST_REPORTS_DIR}/metrics
                mkdir -p ${SAST_REPORTS_DIR}/security

                # Dart Code Metrics
                dart pub global activate dart_code_metrics 2>/dev/null || true
                export PATH="$PATH:$HOME/.pub-cache/bin"
                metrics analyze lib --reporter=html --output-directory=${SAST_REPORTS_DIR}/metrics || true

                # Security Rules Scan
                find lib/ -name "*.dart" -exec grep -n -E "password.*=.*['\\\"][^'\\\"]*['\\\"]" {} \\; > ${SAST_REPORTS_DIR}/security/hardcoded-passwords.txt
                find lib/ -name "*.dart" -exec grep -n -i -E "api[_-]?key|secret[_-]?key|token.*=.*['\\\"][^'\\\"]*['\\\"]" {} \\; > ${SAST_REPORTS_DIR}/security/api-secrets.txt

                if [ -s ${SAST_REPORTS_DIR}/security/hardcoded-passwords.txt ]; then
                    echo "❌ Hardcoded passwords detected!"
                fi
                if [ -s ${SAST_REPORTS_DIR}/security/api-secrets.txt ]; then
                    echo "❌ Hardcoded API keys found"
                fi

                echo "✅ SAST checks completed (non-blocking)"
                '''
            }
        }

        stage('Build Flutter') {
            steps {
                sh '''
                echo "🏗️ Building Flutter Web Application..."
                flutter clean
                flutter build web --release
                echo "✅ Build completed"
                ls -la build/web/
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                echo "🐳 Building Docker Image for Registry: ${DOCKER_REGISTRY}"
                docker build \
                  --build-arg NGINX_PORT=${APP_PORT} \
                  --tag ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG} \
                  --tag ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest \
                  --label "build.number=${BUILD_NUMBER}" \
                  --label "version=1.0.0" \
                  --label "maintainer=laurentmd5" \
                  .
                echo "✅ Docker images built and tagged for registry: ${DOCKER_REGISTRY}"
                docker images | grep ${DOCKER_REGISTRY} || true
                '''
            }
        }

        stage('Container Security Scan') {
            steps {
                sh '''
                echo "🛡️ Container Security Scan with Trivy..."
                mkdir -p ${TRIVY_CACHE_DIR}
                trivy --cache-dir ${TRIVY_CACHE_DIR} image \
                  --exit-code 0 \
                  --severity HIGH,CRITICAL \
                  --format table \
                  ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest || echo "⚠️ Vulnerabilities found"
                trivy --cache-dir ${TRIVY_CACHE_DIR} image \
                  --exit-code 0 \
                  --severity HIGH,CRITICAL \
                  --format json \
                  -o reports/trivy-scan.json \
                  ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest
                '''
            }
        }

        stage('Deploy to Ubuntu Server') {
            steps {
                script {
                    withCredentials([sshUserPrivateKey(
                        credentialsId: "${SSH_CREDENTIALS_ID}",
                        usernameVariable: 'SSH_USER',
                        keyFileVariable: 'SSH_KEY'
                    )]) {
                        sh """
                        echo "🚀 Deploying to Ubuntu Server: ${DEPLOY_SERVER}"
                        ssh -i \$SSH_KEY -o StrictHostKeyChecking=no ${DEPLOY_SERVER} "
                            sudo mkdir -p ${DEPLOY_PATH}
                            sudo chown -R devops:devops ${DEPLOY_PATH}
                            cd ${DEPLOY_PATH}
                            docker stop ${APP_NAME} 2>/dev/null || true
                            docker rm ${APP_NAME} 2>/dev/null || true
                            docker pull ${DOCKER_REGISTRY}/${APP_NAME}:latest
                            docker run -d --name ${APP_NAME} -p ${APP_PORT}:${APP_PORT} --restart unless-stopped --security-opt=no-new-privileges:true ${DOCKER_REGISTRY}/${APP_NAME}:latest
                            sleep 15
                            docker ps --filter 'name=${APP_NAME}' --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
                            if curl -f -s http://localhost:${APP_PORT}/health > /dev/null; then
                                echo '✅ Health check PASSED'
                            else
                                echo '❌ Health check FAILED'
                                docker logs ${APP_NAME} --tail 20
                                exit 1
                            fi
                        "
                        """
                    }
                }
            }
        }

        stage('OWASP ZAP DAST Scan') {
            steps {
                script {
                    withCredentials([sshUserPrivateKey(
                        credentialsId: "${SSH_CREDENTIALS_ID}",
                        usernameVariable: 'SSH_USER',
                        keyFileVariable: 'SSH_KEY'
                    )]) {
                        sh """
                        echo "🕷️ Starting OWASP ZAP DAST Scan..."
                        mkdir -p ${ZAP_REPORTS_DIR}
                        ssh -i \$SSH_KEY -o StrictHostKeyChecking=no ${DEPLOY_SERVER} "
                            docker run --rm -v /home/devops/zap-reports:/zap/wrk/:rw -t owasp/zap2docker-stable zap-baseline.py \
                              -t http://${ZAP_HOST}:${ZAP_PORT} -c zap-baseline.conf -r zap-report.html -J zap-report.json -x zap-report.xml -a -m 5 -T ${ZAP_TIMEOUT} || echo '⚠️ ZAP scan completed with findings'
                        "
                        """
                    }
                }
            }
        }

        stage('Advanced ZAP API Scan') {
            steps {
                script {
                    withCredentials([sshUserPrivateKey(
                        credentialsId: "${SSH_CREDENTIALS_ID}",
                        usernameVariable: 'SSH_USER',
                        keyFileVariable: 'SSH_KEY'
                    )]) {
                        sh """
                        echo "🔬 Advanced OWASP ZAP API Scan..."
                        ssh -i \$SSH_KEY -o StrictHostKeyChecking=no ${DEPLOY_SERVER} "
                            docker run --rm -v /home/devops/zap-reports:/zap/wrk/:rw -t owasp/zap2docker-stable zap-api-scan.py \
                              -t http://${ZAP_HOST}:${ZAP_PORT} -f openapi -r api-scan-report.html -J api-scan-report.json -x api-scan-report.xml -a -T ${ZAP_TIMEOUT} || echo '⚠️ ZAP API scan completed with findings'
                        "
                        """
                    }
                }
            }
        }

        stage('Post-Deployment Security') {
            steps {
                script {
                    withCredentials([sshUserPrivateKey(
                        credentialsId: "${SSH_CREDENTIALS_ID}",
                        usernameVariable: 'SSH_USER',
                        keyFileVariable: 'SSH_KEY'
                    )]) {
                        sh """
                        echo "🔍 Post-Deployment Security Verification..."
                        ssh -i \$SSH_KEY -o StrictHostKeyChecking=no ${DEPLOY_SERVER} "
                            trivy container --exit-code 0 ${APP_NAME} || echo '⚠️ Container vulnerabilities found'
                            netstat -tulpn | grep ${APP_PORT} && echo '✅ Port ${APP_PORT} secured' || echo '❌ Port issue'
                            curl -s -I http://localhost:${APP_PORT}/ | grep -E '(X-Frame-Options|X-Content-Type-Options|X-XSS-Protection)' || echo '⚠️ Security headers missing'
                            which nmap && nmap -sV --script ssl-enum-ciphers -p ${APP_PORT} localhost || echo 'ℹ️ nmap not available'
                        "
                        """
                    }
                }
            }
        }

        stage('Performance Tests') {
            steps {
                script {
                    withCredentials([sshUserPrivateKey(
                        credentialsId: "${SSH_CREDENTIALS_ID}",
                        usernameVariable: 'SSH_USER',
                        keyFileVariable: 'SSH_KEY'
                    )]) {
                        sh """
                        echo "⚡ Performance and Load Testing..."
                        ssh -i \$SSH_KEY -o StrictHostKeyChecking=no ${DEPLOY_SERVER} "
                            if command -v ab >/dev/null 2>&1; then
                                ab -n 100 -c 10 http://localhost:${APP_PORT}/ > performance-test.txt 2>&1 || echo '⚠️ Performance test issues'
                            else
                                for i in {1..10}; do time curl -s -o /dev/null http://localhost:${APP_PORT}/ || true; done
                            fi
                            docker stats ${APP_NAME} --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}' || true
                        "
                        """
                    }
                }
            }
        }
    }

    post {
        always {
            sh '''
            echo "📊 Gathering all reports..."
            mkdir -p reports
            ls -la reports/ 2>/dev/null || true
            echo "🧹 Cleaning up..."
            docker system prune -f 2>/dev/null || true
            rm -rf ${TRIVY_CACHE_DIR} 2>/dev/null || true
            '''
            archiveArtifacts artifacts: 'reports/**/*, coverage/lcov.info, build/web/', fingerprint: true
            publishHTML(target: [
                reportDir: 'reports/sast/metrics',
                reportFiles: 'index.html',
                reportName: 'Dart Code Metrics'
            ])
        }
        success {
            sh """
            echo "🎉 DEVSECOPS PIPELINE SUCCESS!"
            echo "🌐 Application: http://${DEPLOY_SERVER}:${APP_PORT}"
            echo "🐳 Registry: ${DOCKER_REGISTRY}"
            echo "📦 Image: ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest"
            """
        }
        failure {
            sh """
            echo "❌ DEVSECOPS PIPELINE FAILED"
            echo "🔍 Check SAST, container vulnerabilities, ZAP findings, deployment issues, performance problems"
            """
        }
    }
}
