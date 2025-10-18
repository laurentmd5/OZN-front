pipeline {
    agent any
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        timeout(time: 2, unit: 'HOURS')
        disableConcurrentBuilds()
    }
    
    environment {
        // Configuration Application
        APP_NAME = 'ozn-flutter-app'
        APP_PORT = '8090'
        BUILD_ENV = 'production'
        
        // Configuration Docker
        DOCKER_REGISTRY = 'laurentmd5'
        DOCKER_IMAGE = "${APP_NAME}"
        DOCKER_TAG = "${env.BUILD_NUMBER}"
        
        // Configuration Chemins
        WORKSPACE_DIR = "${WORKSPACE}"
        REPORTS_DIR = "${WORKSPACE}/reports"
        SAST_DIR = "${WORKSPACE}/reports/sast"
        SECURITY_DIR = "${WORKSPACE}/reports/security"
        METRICS_DIR = "${WORKSPACE}/reports/sast/metrics"
        BUILD_DIR = "${WORKSPACE}/build"
        
        // Configuration Déploiement
        DEPLOY_SERVER = 'devops@localhost'
        DEPLOY_PATH = '/home/devops/apps'
        SSH_CREDENTIALS_ID = 'ubuntu-server-ssh'
        
        // Configuration Sécurité
        CONTAINER_USER = 'oznapp'
        CONTAINER_UID = '1001'
    }
    
    stages {
        // ================================
        // ÉTAPE 1: Initialisation
        // ================================
        stage('Initialize Pipeline') {
            steps {
                script {
                    try {
                        sh '''
                        set -e
                        echo "🚀 Initializing DevSecOps Pipeline"
                        echo "========================================"
                        echo "Build Number: ${BUILD_NUMBER}"
                        echo "Job Name: ${JOB_NAME}"
                        echo "Workspace: ${WORKSPACE}"
                        echo "Docker Registry: ${DOCKER_REGISTRY}"
                        echo "========================================"
                        
                        mkdir -p "${REPORTS_DIR}" "${SAST_DIR}" "${SECURITY_DIR}" "${METRICS_DIR}" "${BUILD_DIR}"
                        echo "✅ Initialization completed"
                        '''
                    } catch (Exception e) {
                        error("❌ Pipeline initialization failed: ${e.message}")
                    }
                }
            }
        }

        // ================================
        // ÉTAPE 2: Checkout du Code
        // ================================
        stage('Secure Checkout') {
            steps {
                script {
                    try {
                        checkout([
                            $class: 'GitSCM',
                            branches: [[name: '*/main']],
                            userRemoteConfigs: [[
                                url: 'https://github.com/laurentmd5/OZN-front.git',
                                credentialsId: 'my-token'
                            ]],
                            extensions: [
                                [$class: 'CleanBeforeCheckout'],
                                [$class: 'CloneOption', depth: 1, noTags: false, shallow: true]
                            ]
                        ])
                        
                        sh '''
                        set -e
                        echo "🔒 Secure Code Checkout Completed"
                        if [ ! -f "pubspec.yaml" ]; then echo "❌ pubspec.yaml not found"; exit 1; fi
                        if [ ! -d "lib" ]; then echo "❌ lib directory not found"; exit 1; fi
                        if [ ! -f "Dockerfile" ]; then echo "❌ Dockerfile not found"; exit 1; fi
                        if [ ! -f "nginx.conf" ]; then echo "❌ nginx.conf not found"; exit 1; fi
                        echo "✅ Project structure validated"
                        '''
                    } catch (Exception e) {
                        error("❌ Checkout failed: ${e.message}")
                    }
                }
            }
        }

        // ================================
        // ÉTAPE 3: Validation des Dépendances
        // ================================
        stage('Validate Dependencies') {
            steps {
                script {
                    try {
                        sh '''
                        set -e
                        echo "📦 Validating Flutter Dependencies"
                        flutter --version
                        flutter doctor -v || true
                        flutter config --no-analytics
                        flutter config --enable-web
                        flutter clean || true
                        rm -rf .dart_tool build .packages 2>/dev/null || true
                        flutter pub get --verbose
                        echo "✅ Dependencies validated successfully"
                        '''
                    } catch (Exception e) {
                        error("❌ Dependency validation failed: ${e.message}")
                    }
                }
            }
        }

        // ================================
        // ÉTAPE 4: Analyse de Sécurité (simplifiée)
        // ================================
        stage('Security Analysis') {
            parallel {
                stage('Flutter Analysis') {
                    steps {
                        script {
                            try {
                                sh '''
                                set -e
                                echo "🔍 Running Flutter Basic Analysis"
                                mkdir -p "${SAST_DIR}"
                                set +e
                                flutter analyze --no-pub > "${SAST_DIR}/flutter_analysis.txt" 2>&1
                                ANALYSIS_EXIT_CODE=$?
                                set -e
                                ERROR_COUNT=$(grep -c "error •" "${SAST_DIR}/flutter_analysis.txt" 2>/dev/null || echo "0")
                                if [ ${ERROR_COUNT} -gt 0 ]; then
                                    echo "❌ Critical errors found"
                                    exit 1
                                fi
                                echo "✅ Flutter basic analysis passed"
                                '''
                            } catch (Exception e) {
                                unstable("⚠️ Flutter analysis completed with warnings")
                            }
                        }
                    }
                }

                stage('Security Scan') {
                    steps {
                        script {
                            try {
                                sh '''
                                set -e
                                echo "🛡️ Running Security Scans"
                                mkdir -p "${SECURITY_DIR}"
                                find lib/ -type f -name "*.dart" -exec grep -Hn -E "(password|api_key|secret|token)\\s*=\\s*['\"][^'\"]{8,}" {} \\; > "${SECURITY_DIR}/hardcoded-secrets.txt" 2>/dev/null || true
                                if [ -s "${SECURITY_DIR}/hardcoded-secrets.txt" ]; then
                                    echo "❌ Hardcoded secrets found"
                                    exit 1
                                fi
                                echo "✅ Security scan completed"
                                '''
                            } catch (Exception e) {
                                error("❌ Security scan failed: ${e.message}")
                            }
                        }
                    }
                }
            }
        }

        // ================================
        // ÉTAPE 5: Build Flutter
        // ================================
        stage('Build Flutter Application') {
            steps {
                script {
                    try {
                        sh '''
                        set -e
                        echo "🏗️ Building Flutter Application"
                        flutter build web --release --pwa-strategy none --dart-define=BUILD_ENV=${BUILD_ENV} --dart-define=BUILD_NUMBER=${BUILD_NUMBER} --verbose
                        if [ ! -f "build/web/index.html" ]; then
                            echo "❌ Build verification failed: index.html missing"
                            exit 1
                        fi
                        echo "✅ Flutter build completed successfully"
                        '''
                    } catch (Exception e) {
                        error("❌ Flutter build failed: ${e.message}")
                    }
                }
            }
        }

        // ================================
        // ÉTAPE 6: Build Docker
        // ================================
        stage('Build Docker Image') {
            steps {
                script {
                    try {
                        sh '''
                        set -e
                        echo "🐳 Building Docker Image"
                        docker build --no-cache \
                            --build-arg NGINX_PORT=${APP_PORT} \
                            --tag ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG} \
                            --tag ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest \
                            .
                        echo "✅ Docker image built successfully"
                        '''
                    } catch (Exception e) {
                        error("❌ Docker build failed: ${e.message}")
                    }
                }
            }
        }

        // ================================
        // ÉTAPE 7: Tests Sécurité Container
        // ================================
        stage('Container Security Tests') {
            parallel {
                stage('Trivy Scan') {
                    steps {
                        script {
                            try {
                                sh '''
                                set -e
                                echo "🛡️ Running Trivy Security Scan"
                                if command -v trivy >/dev/null 2>&1; then
                                    trivy image --exit-code 0 --severity HIGH,CRITICAL --format table ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest | tee "${SECURITY_DIR}/trivy-scan.txt"
                                else
                                    echo "⚠️ Trivy not installed, skipping"
                                fi
                                '''
                            } catch (Exception e) {
                                unstable("⚠️ Trivy scan completed with warnings")
                            }
                        }
                    }
                }

                stage('Container Runtime Test') {
                    steps {
                        script {
                            try {
                                sh '''
                                set -e
                                echo "🧪 Testing Container Runtime"
                                docker stop ${APP_NAME}-test 2>/dev/null || true
                                docker rm ${APP_NAME}-test 2>/dev/null || true
                                docker run -d --name ${APP_NAME}-test -p 8091:${APP_PORT} ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest
                                sleep 15
                                if ! curl -f -s --max-time 10 http://localhost:8091/ > /dev/null; then
                                    echo "❌ HTTP test failed"
                                    exit 1
                                fi
                                echo "✅ Container runtime tests passed"
                                '''
                            } catch (Exception e) {
                                error("❌ Container runtime test failed: ${e.message}")
                            } finally {
                                sh 'docker rm -f ${APP_NAME}-test 2>/dev/null || true'
                            }
                        }
                    }
                }
            }
        }

        // ================================
        // ÉTAPE 8: Déploiement
        // ================================
        stage('Deploy to Production') {
            when {
                expression { return currentBuild.result == null || currentBuild.result == 'SUCCESS' }
            }
            steps {
                script {
                    try {
                        withCredentials([sshUserPrivateKey(
                            credentialsId: "${SSH_CREDENTIALS_ID}",
                            usernameVariable: 'SSH_USER',
                            keyFileVariable: 'SSH_KEY'
                        )]) {
                            sh '''
                            set -e
                            echo "🚀 Deploying to Production"
                            ssh -i $SSH_KEY -o StrictHostKeyChecking=no ${DEPLOY_SERVER} "
                                docker stop ${APP_NAME} 2>/dev/null || true
                                docker rm ${APP_NAME} 2>/dev/null || true
                                docker pull ${DOCKER_REGISTRY}/${APP_NAME}:latest
                                docker run -d --name ${APP_NAME} -p ${APP_PORT}:${APP_PORT} --restart unless-stopped ${DOCKER_REGISTRY}/${APP_NAME}:latest
                            "
                            echo "✅ Deployment successful"
                            '''
                        }
                    } catch (Exception e) {
                        error("❌ Deployment failed: ${e.message}")
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                sh '''
                echo "🧹 Cleaning up..."
                docker system prune -f 2>/dev/null || true
                '''
                archiveArtifacts artifacts: 'reports/**/*', allowEmptyArchive: true, fingerprint: true
                publishHTML(target: [
                    reportDir: 'reports',
                    reportFiles: '**/*.html',
                    reportName: 'Security Reports',
                    keepAll: true,
                    alwaysLinkToLastBuild: true,
                    allowMissing: true
                ])
            }
        }
    }
}
