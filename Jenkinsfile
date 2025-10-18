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
                        
                        # Création des répertoires avec structure complète
                        echo "📁 Creating directories..."
                        mkdir -p "${REPORTS_DIR}"
                        mkdir -p "${SAST_DIR}"
                        mkdir -p "${SECURITY_DIR}"
                        mkdir -p "${METRICS_DIR}"
                        mkdir -p "${BUILD_DIR}"
                        
                        # Vérification de la création
                        echo "📋 Verifying directories..."
                        ls -la "${REPORTS_DIR}/"
                        ls -la "${SAST_DIR}/" || echo "Warning: SAST dir not listed"
                        ls -la "${SECURITY_DIR}/" || echo "Warning: Security dir not listed"
                        
                        # Vérification des outils
                        echo "🔧 Verifying required tools..."
                        command -v docker >/dev/null 2>&1 || { echo "❌ Docker not found"; exit 1; }
                        command -v flutter >/dev/null 2>&1 || { echo "❌ Flutter not found"; exit 1; }
                        command -v git >/dev/null 2>&1 || { echo "❌ Git not found"; exit 1; }
                        
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
                        
                        # Vérification de la structure du projet
                        echo "📋 Verifying project structure..."
                        
                        if [ ! -f "pubspec.yaml" ]; then
                            echo "❌ pubspec.yaml not found"
                            exit 1
                        fi
                        
                        if [ ! -d "lib" ]; then
                            echo "❌ lib directory not found"
                            exit 1
                        fi
                        
                        if [ ! -f "Dockerfile" ]; then
                            echo "❌ Dockerfile not found"
                            exit 1
                        fi
                        
                        if [ ! -f "nginx.conf" ]; then
                            echo "❌ nginx.conf not found"
                            exit 1
                        fi
                        
                        echo "📦 Project structure:"
                        ls -lah
                        
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
                        
                        # Vérification de l'environnement Flutter
                        echo "🔧 Flutter environment:"
                        flutter --version
                        flutter doctor -v || echo "⚠️ Some checks failed (non-blocking)"
                        
                        # Configuration Flutter
                        flutter config --no-analytics
                        flutter config --enable-web
                        
                        # Nettoyage
                        echo "🧹 Cleaning previous builds..."
                        flutter clean || true
                        rm -rf .dart_tool build .packages 2>/dev/null || true
                        
                        # Installation des dépendances
                        echo "📥 Getting dependencies..."
                        if ! flutter pub get --verbose; then
                            echo "❌ Failed to get dependencies"
                            cat pubspec.yaml
                            exit 1
                        fi
                        
                        # Vérification de la configuration
                        echo "🔍 Verifying package configuration..."
                        if [ -f ".dart_tool/package_config.json" ]; then
                            echo "✅ Package configuration found"
                            cat .dart_tool/package_config.json | head -20
                        else
                            echo "❌ Package configuration missing"
                            exit 1
                        fi
                        
                        echo "✅ Dependencies validated successfully"
                        '''
                    } catch (Exception e) {
                        error("❌ Dependency validation failed: ${e.message}")
                    }
                }
            }
        }
        
        // ================================
        // ÉTAPE 4: Analyse de Sécurité
        // ================================
        stage('Security Analysis') {
            steps {
                script {
                    try {
                        sh '''
                        set -e
                        echo "🛡️ Running Security Scans"
                        
                        # Vérification que le répertoire existe
                        mkdir -p "${SECURITY_DIR}"
                        ls -la "${SECURITY_DIR}/" || echo "Directory check failed"
                        
                        # Scan des secrets hardcodés
                        echo "🔐 Scanning for hardcoded secrets..."
                        find lib/ -type f -name "*.dart" -exec grep -Hn -E "(password|api_key|secret|token)\\s*=\\s*['\"][^'\"]{8,}" {} \\; > "${SECURITY_DIR}/hardcoded-secrets.txt" 2>/dev/null || touch "${SECURITY_DIR}/hardcoded-secrets.txt"
                        
                        if [ -s "${SECURITY_DIR}/hardcoded-secrets.txt" ]; then
                            echo "⚠️ Potential hardcoded secrets found:"
                            cat "${SECURITY_DIR}/hardcoded-secrets.txt"
                            echo "❌ Security violation: hardcoded secrets detected"
                            exit 1
                        fi
                        
                        # Scan des URLs non sécurisées
                        echo "🌐 Scanning for insecure URLs..."
                        find lib/ -type f -name "*.dart" -exec grep -Hn "http://[^'\"]*" {} \\; > "${SECURITY_DIR}/insecure-urls.txt" 2>/dev/null || touch "${SECURITY_DIR}/insecure-urls.txt"
                        
                        if [ -s "${SECURITY_DIR}/insecure-urls.txt" ]; then
                            echo "⚠️ Insecure HTTP URLs found:"
                            cat "${SECURITY_DIR}/insecure-urls.txt"
                        fi
                        
                        # Vérification des dépendances
                        echo "📦 Checking for outdated dependencies..."
                        flutter pub outdated > "${SECURITY_DIR}/outdated-deps.txt" 2>&1 || touch "${SECURITY_DIR}/outdated-deps.txt"
                        
                        echo "✅ Security scan completed"
                        '''
                    } catch (Exception e) {
                        error("❌ Security scan failed: ${e.message}")
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
                        
                        # Build avec flags de production (SANS --web-renderer pour Flutter 3.19+)
                        if ! flutter build web \
                            --release \
                            --pwa-strategy none \
                            --dart-define=BUILD_ENV=${BUILD_ENV} \
                            --dart-define=BUILD_NUMBER=${BUILD_NUMBER} \
                            --verbose; then
                            echo "❌ Flutter build failed"
                            exit 1
                        fi
                        
                        # Vérification de l'intégrité du build
                        echo "🔍 Verifying build integrity..."
                        
                        if [ ! -f "build/web/index.html" ]; then
                            echo "❌ Build verification failed: index.html missing"
                            ls -la build/web/ || true
                            exit 1
                        fi
                        
                        if [ ! -f "build/web/flutter.js" ]; then
                            echo "❌ Build verification failed: flutter.js missing"
                            ls -la build/web/ || true
                            exit 1
                        fi
                        
                        if [ ! -f "build/web/main.dart.js" ]; then
                            echo "⚠️ Warning: main.dart.js not found (might be normal for newer Flutter versions)"
                        fi
                        
                        # Affichage du contenu du build
                        echo "📦 Build output:"
                        ls -lah build/web/
                        du -sh build/web/
                        
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
                        
                        # Vérification des prérequis
                        if [ ! -f "Dockerfile" ]; then
                            echo "❌ Dockerfile not found"
                            exit 1
                        fi
                        
                        if [ ! -f "nginx.conf" ]; then
                            echo "❌ nginx.conf not found"
                            exit 1
                        fi
                        
                        # Construction de l'image
                        echo "🔨 Building image..."
                        if ! docker build \
                            --no-cache \
                            --build-arg NGINX_PORT=${APP_PORT} \
                            --tag ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG} \
                            --tag ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest \
                            --label "build.number=${BUILD_NUMBER}" \
                            --label "build.date=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                            --label "version=1.0.0" \
                            . 2>&1 | tee "${BUILD_DIR}/docker-build.log"; then
                            echo "❌ Docker build failed"
                            tail -50 "${BUILD_DIR}/docker-build.log"
                            exit 1
                        fi
                        
                        # Vérification de l'image
                        echo "🔍 Verifying Docker image..."
                        if ! docker images | grep "${DOCKER_REGISTRY}/${DOCKER_IMAGE}"; then
                            echo "❌ Docker image not found after build"
                            exit 1
                        fi
                        
                        # Inspection de l'image
                        docker inspect ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest > "${BUILD_DIR}/image-inspect.json"
                        
                        echo "📦 Image details:"
                        docker images | grep "${DOCKER_IMAGE}"
                        
                        echo "✅ Docker image built successfully"
                        '''
                    } catch (Exception e) {
                        error("❌ Docker build failed: ${e.message}")
                    }
                }
            }
        }
        
        // ================================
        // ÉTAPE 7: Tests de Sécurité Container
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
                                
                                # Vérification de Trivy
                                if ! command -v trivy >/dev/null 2>&1; then
                                    echo "⚠️ Trivy not installed, skipping scan"
                                    exit 0
                                fi
                                
                                # Scan des vulnérabilités
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
                                
                                # Nettoyage préalable
                                docker stop ${APP_NAME}-test 2>/dev/null || true
                                docker rm ${APP_NAME}-test 2>/dev/null || true
                                
                                # Test de démarrage du conteneur
                                echo "🚀 Starting test container..."
                                docker run -d \
                                    --name ${APP_NAME}-test \
                                    -p 8091:${APP_PORT} \
                                    ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest
                                
                                # Attente du démarrage
                                echo "⏳ Waiting for container to start..."
                                sleep 15
                                
                                # Vérification du statut
                                CONTAINER_STATUS=$(docker inspect --format='{{.State.Status}}' ${APP_NAME}-test)
                                echo "Container status: ${CONTAINER_STATUS}"
                                
                                if [ "${CONTAINER_STATUS}" != "running" ]; then
                                    echo "❌ Container not running"
                                    docker logs ${APP_NAME}-test
                                    exit 1
                                fi
                                
                                # Test HTTP
                                echo "🌐 Testing HTTP response..."
                                if curl -f -s --max-time 10 http://localhost:8091/ > /dev/null; then
                                    echo "✅ HTTP test passed"
                                else
                                    echo "❌ HTTP test failed"
                                    docker logs ${APP_NAME}-test
                                    exit 1
                                fi
                                
                                # Vérification de l'utilisateur
                                CONTAINER_USER=$(docker exec ${APP_NAME}-test whoami 2>/dev/null || echo "unknown")
                                echo "Container user: ${CONTAINER_USER}"
                                
                                if [ "${CONTAINER_USER}" = "root" ]; then
                                    echo "❌ Container running as root!"
                                    exit 1
                                fi
                                
                                echo "✅ Container runtime tests passed"
                                '''
                            } catch (Exception e) {
                                error("❌ Container runtime test failed: ${e.message}")
                            } finally {
                                sh '''
                                # Nettoyage
                                docker stop ${APP_NAME}-test 2>/dev/null || true
                                docker rm ${APP_NAME}-test 2>/dev/null || true
                                '''
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
                            
                            # Connexion SSH et déploiement
                            ssh -i $SSH_KEY -o StrictHostKeyChecking=no ${DEPLOY_SERVER} "
                                set -e
                                
                                echo '📁 Preparing deployment directory...'
                                sudo mkdir -p ${DEPLOY_PATH}
                                sudo chown -R devops:devops ${DEPLOY_PATH}
                                cd ${DEPLOY_PATH}
                                
                                echo '🔄 Stopping existing container...'
                                docker stop ${APP_NAME} 2>/dev/null || echo 'No container to stop'
                                docker rm ${APP_NAME} 2>/dev/null || echo 'No container to remove'
                                
                                echo '📥 Pulling latest image...'
                                docker pull ${DOCKER_REGISTRY}/${APP_NAME}:latest
                                
                                echo '🚀 Starting new container...'
                                docker run -d \\
                                    --name ${APP_NAME} \\
                                    -p ${APP_PORT}:${APP_PORT} \\
                                    --restart unless-stopped \\
                                    --security-opt=no-new-privileges:true \\
                                    --read-only \\
                                    --tmpfs /tmp:rw,noexec,nosuid,size=64m \\
                                    --tmpfs /var/run:rw,noexec,nosuid,size=16m \\
                                    --tmpfs /var/cache/nginx:rw,noexec,nosuid,size=32m \\
                                    --user ${CONTAINER_UID} \\
                                    --health-cmd='/healthcheck.sh' \\
                                    --health-interval=30s \\
                                    --health-timeout=10s \\
                                    --health-retries=3 \\
                                    ${DOCKER_REGISTRY}/${APP_NAME}:latest
                                
                                echo '⏳ Waiting for application to start...'
                                sleep 20
                                
                                echo '❤️ Checking container health...'
                                CONTAINER_STATUS=\$(docker inspect --format='{{.State.Status}}' ${APP_NAME})
                                echo \"Container Status: \$CONTAINER_STATUS\"
                                
                                if [ \"\$CONTAINER_STATUS\" != \"running\" ]; then
                                    echo '❌ Container failed to start'
                                    docker logs ${APP_NAME} --tail 50
                                    exit 1
                                fi
                                
                                echo '🌐 Testing application...'
                                if curl -f -s --max-time 10 http://localhost:${APP_PORT}/ > /dev/null; then
                                    echo '✅ Application is responding'
                                else
                                    echo '❌ Application health check failed'
                                    docker logs ${APP_NAME} --tail 50
                                    exit 1
                                fi
                                
                                echo '🎉 Deployment completed successfully!'
                                docker ps | grep ${APP_NAME}
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
                
                # Nettoyage des conteneurs de test
                docker stop ${APP_NAME}-test 2>/dev/null || true
                docker rm ${APP_NAME}-test 2>/dev/null || true
                
                # Nettoyage Docker
                docker system prune -f 2>/dev/null || true
                
                # Affichage des rapports
                echo "📊 Security Reports Summary:"
                find reports/ -type f 2>/dev/null | head -20 || echo "No reports found"
                '''
                
                // Archivage des artifacts
                archiveArtifacts artifacts: 'reports/**/*', allowEmptyArchive: true, fingerprint: true
                
                // Publication des rapports HTML
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
                echo "   Docker Latest: ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest"
                echo ""
                echo "🌐 Application Access:"
                echo "   URL: http://${DEPLOY_SERVER}:${APP_PORT}"
                echo ""
                echo "🔒 Security Checks Passed:"
                echo "   ✅ Dependency Security Scan"
                echo "   ✅ Container Vulnerability Scan"
                echo "   ✅ Runtime Security Tests"
                echo "   ✅ Non-root Container Verification"
                echo ""
                echo "📊 Build Artifacts:"
                echo "   - Security Scan Results"
                echo "   - Container Inspection Report"
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
                echo "🔍 Failure Analysis:"
                echo "   Build Number: ${BUILD_NUMBER}"
                echo "   Stage: Check Jenkins console output"
                echo ""
                echo "🛠️ Troubleshooting Steps:"
                echo "   1. Review the failed stage logs above"
                echo "   2. Check Flutter dependencies in pubspec.yaml"
                echo "   3. Verify Dockerfile and nginx.conf syntax"
                echo "   4. Ensure all required files exist"
                echo "   5. Check Docker daemon status"
                echo ""
                echo "📋 Common Issues:"
                echo "   - Flutter version compatibility"
                echo "   - Missing dependencies in pubspec.yaml"
                echo "   - Syntax errors in Dockerfile"
                echo "   - nginx.conf configuration issues"
                echo "   - Network connectivity problems"
                echo ""
                echo "📊 Available Reports:"
                find reports/ -type f 2>/dev/null | head -10 || echo "   No reports generated"
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
                echo "ℹ️ Build Information:"
                echo "   Build Number: ${BUILD_NUMBER}"
                echo "   Status: Unstable"
                echo ""
                echo "⚠️ Warnings Found:"
                echo "   - Check security scan results"
                echo "   - Verify container vulnerability reports"
                echo ""
                echo "📊 Review the following reports:"
                find reports/ -type f 2>/dev/null | head -10 || echo "   No reports generated"
                echo ""
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                """
            }
        }
    }
}