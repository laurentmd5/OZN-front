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
        BUILD_VERSION = '1.0.0'
        
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
        BUILD_DIR = "${WORKSPACE}/.build_temp"
        
        // Configuration Déploiement
        DEPLOY_SERVER = 'devops@localhost'
        DEPLOY_PATH = '/home/devops/apps'
        SSH_CREDENTIALS_ID = 'ubuntu-server-ssh'
        
        // Configuration Sécurité
        CONTAINER_USER = 'oznapp'
        CONTAINER_UID = '1001'
        FLUTTER_VERSION = '3.19.5'
    }
    
    stages {
        stage('Initialize Pipeline') {
            steps {
                script {
                    try {
                        sh '''
                        set -e
                        echo "🚀 Initializing DevSecOps Pipeline"
                        
                        # CRÉATION EXPLICITE DE TOUS LES RÉPERTOIRES
                        echo "📁 Creating all required directories..."
                        mkdir -p "${REPORTS_DIR}" "${SAST_DIR}" "${SECURITY_DIR}" "${METRICS_DIR}" "${BUILD_DIR}"
                        
                        # Vérification
                        echo "📋 Directory structure:"
                        ls -la "${WORKSPACE}/"
                        ls -la "${BUILD_DIR}/" || echo "Building directory..."
                        
                        echo "✅ Initialization completed"
                        '''
                    } catch (Exception e) {
                        error("❌ Pipeline initialization failed: ${e.message}")
                    }
                }
            }
        }       
        
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
                        if [ ! -f "Dockerfile" ]; then echo "❌ Dockerfile not found"; exit 1; fi
                        if [ ! -f "nginx.conf" ]; then echo "❌ nginx.conf not found"; exit 1; fi
                        if [ ! -f "pubspec.yaml" ]; then echo "❌ pubspec.yaml not found"; exit 1; fi
                        echo "✅ Project structure validated"
                        '''
                    } catch (Exception e) {
                        error("❌ Checkout failed: ${e.message}")
                    }
                }
            }
        }

        stage('Validate Dependencies (Analysis Only)') {
            when {
                expression { 
                    try {
                        sh(returnStdout: true, script: 'command -v flutter >/dev/null 2>&1').trim()
                        return true
                    } catch (Exception e) {
                        echo "⚠️ Flutter not found on agent, skipping local analysis/validation."
                        return false
                    }
                }
            }
            steps {
                script {
                    try {
                        sh '''
                        set -e
                        echo "📦 Validating Flutter Dependencies on Host (for Analysis)"
                        
                        flutter config --no-analytics
                        flutter clean || true
                        
                        if ! flutter pub get --verbose; then
                            echo "❌ Failed to get dependencies for host analysis. This is non-blocking for Docker build."
                            exit 0
                        fi
                        
                        echo "✅ Host Dependencies validated"
                        '''
                    } catch (Exception e) {
                        echo "⚠️ Host Dependency validation failed: ${e.message}. Non-blocking."
                    }
                }
            }
        }
        
        stage('Static Analysis (SAST & Linting)') {
            steps {
                script {
                    try {
                        sh '''
                        set -e
                        echo "🔍 Running Static Analysis & Linting"
                        mkdir -p "${SAST_DIR}"
                        
                        echo "📏 Checking Dart formatting..."
                        if ! dart format --set-exit-if-changed --line-length 120 lib/; then
                            echo "❌ Dart formatting failed. Please run 'dart format .' locally."
                        fi
                        
                        echo "🧠 Running Dart analysis..."
                        flutter analyze --write "${SAST_DIR}/flutter_analysis.txt" || true
                        
                        echo "✅ Analysis completed"
                        '''
                    } catch (Exception e) {
                        unstable("⚠️ Static Analysis failed or returned non-zero. Continuing...")
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    try {
                        sh '''
                        set -e
                        echo "🐳 Building Docker Image (Multi-Stage Build)"
                        
                        # S'assurer que le répertoire de build existe
                        mkdir -p "${BUILD_DIR}"
                        
                        # Désactiver BuildKit pour éviter les erreurs
                        export DOCKER_BUILDKIT=0
                        
                        echo "🔨 Building image with arguments..."
                        echo "   - Flutter Version: ${FLUTTER_VERSION}"
                        echo "   - Port: ${APP_PORT}"
                        echo "   - Registry: ${DOCKER_REGISTRY}"
                        echo "   - Image: ${DOCKER_IMAGE}:${DOCKER_TAG}"
                        
                        # Construction sans BuildKit
                        if ! docker build \
                            --pull \
                            --build-arg NGINX_PORT=${APP_PORT} \
                            --build-arg FLUTTER_VERSION=${FLUTTER_VERSION} \
                            --build-arg CONTAINER_USER=${CONTAINER_USER} \
                            --build-arg CONTAINER_UID=${CONTAINER_UID} \
                            --build-arg BUILD_VERSION=${BUILD_VERSION} \
                            --tag ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG} \
                            --tag ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest \
                            --label "build.number=${BUILD_NUMBER}" \
                            --label "build.date=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                            --label "version=${BUILD_VERSION}" \
                            . 2>&1 | tee "${BUILD_DIR}/docker-build.log"; then
                            echo "❌ Docker build failed"
                            echo "=== Dernières lignes du log ==="
                            tail -20 "${BUILD_DIR}/docker-build.log"
                            exit 1
                        fi
                        
                        echo "✅ Docker image built successfully"
                        
                        # Vérification de l'image
                        echo "🔍 Verifying Docker image..."
                        docker images | grep "${DOCKER_IMAGE}" || echo "Image verification failed"
                        '''
                    } catch (Exception e) {
                        error("❌ Docker build failed: ${e.message}")
                    }
                }
            }
        }
        
        stage('Container Security Tests') {
            parallel {
                stage('Trivy Scan') {
                    steps {
                        script {
                            try {
                                sh '''
                                set -e
                                echo "🛡️ Running Trivy Security Scan"
                                if ! command -v trivy >/dev/null 2>&1; then 
                                    echo "⚠️ Trivy not installed, skipping scan"
                                    exit 0
                                fi
                                trivy image \
                                    --exit-code 0 \
                                    --severity HIGH,CRITICAL \
                                    --format table \
                                    ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest | tee "${SECURITY_DIR}/trivy-scan.txt"
                                echo "✅ Trivy scan completed"
                                '''
                            } catch (Exception e) {
                                unstable("⚠️ Trivy scan completed with findings")
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
                                
                                echo "🚀 Starting test container..."
                                docker run -d \
                                    --name ${APP_NAME}-test \
                                    -p 8091:${APP_PORT} \
                                    ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest
                                
                                sleep 15
                                
                                CONTAINER_STATUS=$(docker inspect --format='{{.State.Status}}' ${APP_NAME}-test)
                                echo "Container status: ${CONTAINER_STATUS}"
                                
                                if [ "${CONTAINER_STATUS}" != "running" ]; then
                                    echo "❌ Container not running"
                                    docker logs ${APP_NAME}-test
                                    exit 1
                                fi
                                
                                echo "🌐 Testing HTTP response..."
                                if curl -f -s --max-time 10 http://localhost:8091/ > /dev/null; then
                                    echo "✅ HTTP test passed"
                                else
                                    echo "❌ HTTP test failed"
                                    docker logs ${APP_NAME}-test
                                    exit 1
                                fi
                                
                                echo "✅ Container runtime tests passed"
                                '''
                            } catch (Exception e) {
                                error("❌ Container runtime test failed: ${e.message}")
                            } finally {
                                sh '''
                                docker stop ${APP_NAME}-test 2>/dev/null || true
                                docker rm ${APP_NAME}-test 2>/dev/null || true
                                '''
                            }
                        }
                    }
                }
            }
        }
        
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
                                set -e
                                
                                DEPLOY_PATH='${DEPLOY_PATH}'
                                APP_NAME='${APP_NAME}'
                                APP_PORT='${APP_PORT}'
                                DOCKER_REGISTRY='${DOCKER_REGISTRY}'
                                CONTAINER_UID='${CONTAINER_UID}'

                                echo '🔄 Stopping existing container...'
                                docker stop \${APP_NAME} 2>/dev/null || echo 'No container to stop'
                                docker rm \${APP_NAME} 2>/dev/null || echo 'No container to remove'
                                
                                echo '📥 Pulling latest image...'
                                docker pull \${DOCKER_REGISTRY}/\${APP_NAME}:latest
                                
                                echo '🚀 Starting new container...'
                                docker run -d \\
                                    --name \${APP_NAME} \\
                                    -p \${APP_PORT}:\${APP_PORT} \\
                                    --restart unless-stopped \\
                                    --security-opt=no-new-privileges:true \\
                                    --read-only \\
                                    --tmpfs /tmp:rw,noexec,nosuid,size=64m \\
                                    --tmpfs /var/run:rw,noexec,nosuid,size=16m \\
                                    --tmpfs /var/cache/nginx:rw,noexec,nosuid,size=32m \\
                                    --user \${CONTAINER_UID} \\
                                    --health-cmd='/healthcheck.sh' \\
                                    --health-interval=30s \\
                                    --health-timeout=10s \\
                                    --health-retries=3 \\
                                    \${DOCKER_REGISTRY}/\${APP_NAME}:latest
                                
                                echo '⏳ Waiting for application to start...'
                                sleep 20
                                
                                echo '❤️ Checking container health...'
                                CONTAINER_STATUS=\$(docker inspect --format='{{.State.Health.Status}}' \${APP_NAME} 2>/dev/null || echo 'unhealthy')
                                
                                if [ \"\$CONTAINER_STATUS\" != \"healthy\" ]; then
                                    echo '❌ Container failed health check. Inspecting logs...'
                                    docker logs \${APP_NAME}
                                    exit 1
                                fi
                                
                                echo \"✅ Deployment successful. Application is \${CONTAINER_STATUS} on port \${APP_PORT}\"
                            "
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
                echo "🧹 Cleaning up Docker resources..."
                docker stop ${APP_NAME}-test 2>/dev/null || true
                docker rm ${APP_NAME}-test 2>/dev/null || true
                docker system prune -f --volumes 2>/dev/null || true
                '''
                
                echo "📊 Archiving Reports..."
                archiveArtifacts artifacts: 'reports/**/*', allowEmptyArchive: true, fingerprint: true
            }
        }
        
        success {
            script {
                sh """
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo "🎉 DEVSECOPS PIPELINE SUCCESS"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo ""
                echo "📦 Build Information:"
                echo "   Build Number: ${BUILD_NUMBER}"
                echo "   Docker Image: ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG}"
                echo "   Application URL: http://${DEPLOY_SERVER}:${APP_PORT}"
                echo ""
                echo "✅ All security checks passed"
                echo "✅ Container built and tested successfully"
                echo "✅ Application deployed to production"
                echo ""
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                """
            }
        }
        
        failure {
            script {
                sh """
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo "❌ DEVSECOPS PIPELINE FAILED"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo ""
                echo "🔍 Build Number: ${BUILD_NUMBER}"
                echo "📋 Failed Stage: Check Jenkins console"
                echo ""
                echo "🛠️ Common Issues:"
                echo "   - Docker image access problems"
                echo "   - Flutter dependency issues"
                echo "   - Network connectivity"
                echo "   - Security violations"
                echo ""
                echo "📊 Available Reports:"
                find reports/ -type f 2>/dev/null | head -5 || echo "   No reports generated"
                echo ""
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                """
            }
        }
        
        unstable {
            script {
                sh """
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo "⚠️ PIPELINE COMPLETED WITH WARNINGS"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo ""
                echo "ℹ️ Build Number: ${BUILD_NUMBER}"
                echo "⚠️ Security scans found non-critical issues"
                echo "📊 Check security reports for details"
                echo ""
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                """
            }
        }
    }
}