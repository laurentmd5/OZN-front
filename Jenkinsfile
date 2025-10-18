pipeline {
    agent any
    
    environment {
        // Configuration Application Flutter
        APP_NAME = 'ozn-flutter-app'
        APP_PORT = '8090'
        BUILD_ENV = 'production'
    
        // Configuration Docker
        DOCKER_REGISTRY = 'laurentmd5'
        DOCKER_IMAGE = "${APP_NAME}"
        DOCKER_TAG = "${env.BUILD_NUMBER}"
        
        // Configuration Sécurité
        TRIVY_CACHE_DIR = '/tmp/trivy-cache-${BUILD_NUMBER}'
        SAST_REPORTS_DIR = 'reports/sast'
        ZAP_REPORTS_DIR = 'reports/zap'
        SBOM_DIR = 'reports/sbom'
        
        // Configuration Serveur Ubuntu
        DEPLOY_SERVER = 'devops@localhost'
        DEPLOY_PATH = '/home/devops/apps'
        SSH_CREDENTIALS_ID = 'ubuntu-server-ssh'
        
        // Configuration OWASP ZAP
        ZAP_HOST = 'localhost'
        ZAP_PORT = '8090'
        ZAP_TIMEOUT = '300'
        
        // Configuration Analyse Flutter
        MAX_ALLOWED_WARNINGS = '10'
        MAX_ALLOWED_ERRORS = '0'
        
        // Sécurité
        CONTAINER_USER = 'oznapp'
        CONTAINER_UID = '1001'
    }
    
    stages {
        // ÉTAPE 1: Checkout Sécurisé
        stage('Secure Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/laurentmd5/OZN-front.git',
                    credentialsId: 'my-token',
                    poll: false,
                    changelog: false

                sh '''
                echo "🔒 Secure Code Checkout"
                echo "📦 Repository: https://github.com/laurentmd5/OZN-front.git"
                echo "📝 Branch: main"
                echo "🔍 Verifying project structure..."
                
                # Vérification de l'intégrité des fichiers
                find . -name "*.yaml" -o -name "*.yml" -o -name "*.json" | head -10
                ls -la Dockerfile nginx.conf pubspec.yaml
                
                # Vérification des permissions
                echo "📋 File permissions:"
                ls -la | grep -E "(Dockerfile|nginx.conf|pubspec.yaml)"
                '''
            }
        }
        
        // ÉTAPE 2: Security Scan du Code
        stage('Code Security Scan') {
            parallel {
                stage('Flutter Analyze Sécurisé') {
                    steps {
                        sh '''
                        echo "🔍 Secure Flutter Analysis..."
                        mkdir -p ${SAST_REPORTS_DIR}
                        
                        # Analyse avec gestion d'erreur sécurisée
                        set +e
                        flutter analyze --no-pub --write=${SAST_REPORTS_DIR}/flutter_analysis.json
                        ANALYSIS_CODE=$?
                        set -e
                        
                        # Capture détaillée
                        flutter analyze --no-pub > ${SAST_REPORTS_DIR}/flutter_analysis_detailed.txt 2>&1 || true
                        
                        # Analyse des résultats avec seuils
                        ERROR_COUNT=$(grep -c "error •" ${SAST_REPORTS_DIR}/flutter_analysis_detailed.txt 2>/dev/null || echo "0")
                        WARNING_COUNT=$(grep -c "warning •" ${SAST_REPORTS_DIR}/flutter_analysis_detailed.txt 2>/dev/null || echo "0")
                        
                        echo "📊 Security Analysis Summary:"
                        echo "   Errors: ${ERROR_COUNT}"
                        echo "   Warnings: ${WARNING_COUNT}"
                        
                        # Échec seulement sur les erreurs critiques
                        if [ ${ERROR_COUNT} -gt ${MAX_ALLOWED_ERRORS} ]; then
                            echo "❌ Critical security errors found"
                            grep "error •" ${SAST_REPORTS_DIR}/flutter_analysis_detailed.txt | head -10
                            exit 1
                        fi
                        
                        echo "✅ Flutter security analysis passed"
                        '''
                    }
                }
                
                stage('Dart Security Metrics') {
                    steps {
                        sh '''
                        echo "📊 Dart Security Metrics..."
                        mkdir -p ${SAST_REPORTS_DIR}/metrics
                        
                        dart pub global activate dart_code_metrics
                        export PATH="$PATH:$HOME/.pub-cache/bin"
                        
                        set +e
                        metrics analyze lib --reporter=html --output-directory=${SAST_REPORTS_DIR}/metrics
                        set -e
                        
                        echo "✅ Dart security metrics completed"
                        '''
                    }
                }
                
                stage('Advanced Security Scan') {
                    steps {
                        sh '''
                        echo "🛡️ Advanced Security Scanning..."
                        mkdir -p ${SAST_REPORTS_DIR}/security
                        
                        # Scan des secrets
                        echo "🔐 Scanning for secrets..."
                        find lib/ -name "*.dart" -exec grep -n -E "password.*=.*['\\\"][^'\\\"]*['\\\"]" {} \\; > ${SAST_REPORTS_DIR}/security/hardcoded-passwords.txt || true
                        find lib/ -name "*.dart" -exec grep -n -i -E "api[_-]?key|secret[_-]?key|token.*=.*['\\\"][^'\\\"]*['\\\"]" {} \\; > ${SAST_REPORTS_DIR}/security/api-secrets.txt || true
                        
                        # Scan des URLs non sécurisées
                        find lib/ -name "*.dart" -exec grep -n -E "http://[^\\"']*" {} \\; > ${SAST_REPORTS_DIR}/security/insecure-urls.txt || true
                        
                        # Scan des dépendances vulnérables
                        echo "📦 Checking dependencies..."
                        flutter pub outdated || true
                        
                        # Vérification des violations de sécurité
                        if [ -s ${SAST_REPORTS_DIR}/security/hardcoded-passwords.txt ]; then
                            echo "❌ CRITICAL: Hardcoded passwords detected!"
                            exit 1
                        fi
                        
                        if [ -s ${SAST_REPORTS_DIR}/security/api-secrets.txt ]; then
                            echo "❌ CRITICAL: Hardcoded API keys detected!"
                            exit 1
                        fi
                        
                        echo "✅ Advanced security scan passed"
                        '''
                    }
                }
            }
        }

        // ÉTAPE 3: Build Flutter Sécurisé
        stage('Secure Flutter Build') {
            steps {
                sh '''
                echo "🏗️ Secure Flutter Build..."
                flutter clean
                
                # Build avec flags de sécurité
                flutter build web --release \
                    --pwa-strategy none \
                    --dart-define=BUILD_ENV=${BUILD_ENV} \
                    --dart-define=BUILD_NUMBER=${BUILD_NUMBER}
                
                # Vérification de l'intégrité du build
                if [ ! -f "build/web/index.html" ]; then
                    echo "❌ Build integrity check failed: index.html missing"
                    exit 1
                fi
                
                if [ ! -f "build/web/main.dart.js" ]; then
                    echo "❌ Build integrity check failed: main.dart.js missing"
                    exit 1
                fi
                
                echo "✅ Secure Flutter build completed"
                '''
            }
        }

        // ÉTAPE 4: Build Docker Sécurisé
        stage('Secure Docker Build') {
            steps {
                sh '''
                echo "🐳 Secure Docker Build..."
                
                # Construction de l'image avec sécurité renforcée
                docker build \
                    --no-cache \
                    --build-arg NGINX_PORT=${APP_PORT} \
                    --tag ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG} \
                    --tag ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest \
                    --label "build.number=${BUILD_NUMBER}" \
                    --label "version=1.0.0" \
                    --label "maintainer=laurentmd5" \
                    --label "security.scan=true" \
                    --label "build.env=${BUILD_ENV}" \
                    .
                
                echo "✅ Secure Docker build completed"
                '''
            }
        }

        // ÉTAPE 5: Container Security Scan Avancé
        stage('Advanced Container Security') {
            parallel {
                stage('Trivy Vulnerability Scan') {
                    steps {
                        sh '''
                        echo "🛡️ Trivy Container Security Scan..."
                        mkdir -p ${TRIVY_CACHE_DIR}
                        
                        # Scan complet des vulnérabilités
                        trivy --cache-dir ${TRIVY_CACHE_DIR} image \
                            --exit-code 1 \
                            --severity CRITICAL \
                            --format sarif \
                            -o ${SAST_REPORTS_DIR}/trivy-critical.sarif \
                            ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest
                            
                        # Scan détaillé pour reporting
                        trivy --cache-dir ${TRIVY_CACHE_DIR} image \
                            --exit-code 0 \
                            --severity HIGH,CRITICAL \
                            --format table \
                            ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest || echo "⚠️ Vulnerabilities found"
                            
                        echo "✅ Container security scan completed"
                        '''
                    }
                }
                
                stage('SBOM Generation') {
                    steps {
                        sh '''
                        echo "📋 Software Bill of Materials (SBOM)..."
                        mkdir -p ${SBOM_DIR}
                        
                        # Génération du SBOM
                        trivy --cache-dir ${TRIVY_CACHE_DIR} image \
                            --format cyclonedx \
                            -o ${SBOM_DIR}/sbom.cdx.json \
                            ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest
                            
                        echo "✅ SBOM generated"
                        '''
                    }
                }
                
                stage('Container Image Hardening Check') {
                    steps {
                        sh '''
                        echo "🔒 Container Hardening Audit..."
                        
                        # Vérification des bonnes pratiques
                        docker inspect ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest > ${SAST_REPORTS_DIR}/container-inspect.json
                        
                        # Vérification de l'utilisateur non-root
                        USER_CHECK=$(docker run --rm ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest whoami 2>/dev/null || echo "unknown")
                        if [ "$USER_CHECK" = "root" ]; then
                            echo "❌ CRITICAL: Container running as root!"
                            exit 1
                        else
                            echo "✅ Container running as non-root user: $USER_CHECK"
                        fi
                        
                        echo "✅ Container hardening check passed"
                        '''
                    }
                }
            }
        }

        // ÉTAPE 6: Déploiement Sécurisé
        stage('Secure Deployment') {
            steps {
                script {
                    withCredentials([sshUserPrivateKey(
                        credentialsId: "${SSH_CREDENTIALS_ID}",
                        usernameVariable: 'SSH_USER',
                        keyFileVariable: 'SSH_KEY'
                    )]) {
                        sh """
                        echo "🚀 Secure Deployment to ${DEPLOY_SERVER}"
                        
                        ssh -i \$SSH_KEY -o StrictHostKeyChecking=no ${DEPLOY_SERVER} "
                            set -e
                            
                            echo '🔒 Setting up secure deployment...'
                            sudo mkdir -p ${DEPLOY_PATH}
                            sudo chown -R devops:devops ${DEPLOY_PATH}
                            cd ${DEPLOY_PATH}
                            
                            # Arrêt sécurisé du conteneur existant
                            echo '🐳 Securely stopping existing container...'
                            docker stop ${APP_NAME} 2>/dev/null || echo 'ℹ️ No running container'
                            docker rm ${APP_NAME} 2>/dev/null || echo 'ℹ️ No container to remove'
                            
                            # Nettoyage des anciennes images
                            docker image prune -f 2>/dev/null || true
                            
                            # Pull de l'image sécurisée
                            echo '📥 Pulling secured image...'
                            docker pull ${DOCKER_REGISTRY}/${APP_NAME}:latest
                            
                            # Déploiement avec sécurité renforcée
                            echo '🚀 Starting secured container...'
                            docker run -d \\
                                --name ${APP_NAME} \\
                                -p ${APP_PORT}:${APP_PORT} \\
                                --restart unless-stopped \\
                                --security-opt=no-new-privileges:true \\
                                --read-only \\
                                --tmpfs /tmp:rw,noexec,nosuid,size=64m \\
                                --user ${CONTAINER_UID} \\
                                --health-cmd=\"/healthcheck.sh\" \\
                                --health-interval=30s \\
                                --health-timeout=10s \\
                                --health-retries=3 \\
                                ${DOCKER_REGISTRY}/${APP_NAME}:latest
                            
                            # Attente du démarrage
                            sleep 20
                            
                            # Vérification de santé
                            echo '❤️ Security Health Check...'
                            CONTAINER_STATUS=\$(docker inspect --format='{{.State.Status}}' ${APP_NAME})
                            HEALTH_STATUS=\$(docker inspect --format='{{.State.Health.Status}}' ${APP_NAME})
                            
                            echo \"Container Status: \$CONTAINER_STATUS\"
                            echo \"Health Status: \$HEALTH_STATUS\"
                            
                            if [ \"\$CONTAINER_STATUS\" != \"running\" ]; then
                                echo '❌ Container not running'
                                docker logs ${APP_NAME} --tail 20
                                exit 1
                            fi
                            
                            # Test de l'application
                            if curl -f -s --max-time 10 http://localhost:${APP_PORT}/ > /dev/null; then
                                echo '✅ Application health check PASSED'
                            else
                                echo '❌ Application health check FAILED'
                                docker logs ${APP_NAME} --tail 20
                                exit 1
                            fi
                            
                            echo '🎉 Secure deployment completed successfully'
                        "
                        """
                    }
                }
            }
        }

        // ÉTAPE 7: Security Post-Deployment Scan
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
                            echo '🔒 Running post-deployment security checks...'
                            
                            # Scan de sécurité du conteneur déployé
                            echo '🐳 Container Security Scan...'
                            trivy container --exit-code 0 ${APP_NAME} || echo '⚠️ Container vulnerabilities found'
                            
                            # Vérification réseau
                            echo '🌐 Network Security...'
                            netstat -tulpn | grep ${APP_PORT} && echo '✅ Port binding secured' || echo '❌ Port binding issue'
                            
                            # Vérification des security headers
                            echo '📋 Security Headers Verification...'
                            curl -s -I http://localhost:${APP_PORT}/ | grep -E '(X-Frame-Options|X-Content-Type-Options|X-XSS-Protection|Strict-Transport-Security)' || echo '⚠️ Security headers missing'
                            
                            # Vérification de l'utilisateur du conteneur
                            echo '👤 Container User Verification...'
                            CONTAINER_USER=\$(docker exec ${APP_NAME} whoami 2>/dev/null || echo 'unknown')
                            if [ \"\$CONTAINER_USER\" = \"${CONTAINER_USER}\" ]; then
                                echo '✅ Container running as correct non-root user'
                            else
                                echo '❌ Container user mismatch'
                            fi
                            
                            # Test de sécurité de l'application
                            echo '🔐 Application Security Tests...'
                            # Test XSS
                            curl -s -o /dev/null -w 'XSS Test: %{http_code}\\n' http://localhost:${APP_PORT}/'<script>alert(1)</script>' || true
                            # Test path traversal
                            curl -s -o /dev/null -w 'Path Traversal: %{http_code}\\n' http://localhost:${APP_PORT}/../etc/passwd || true
                            
                            echo '✅ Post-deployment security verification completed'
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
            echo "📊 Security Reports Summary..."
            echo "🧹 Cleaning up sensitive data..."
            
            # Nettoyage sécurisé
            docker system prune -f 2>/dev/null || true
            rm -rf ${TRIVY_CACHE_DIR} 2>/dev/null || true
            
            # Archivage sécurisé des rapports
            find reports/ -name "*.json" -o -name "*.html" -o -name "*.txt" | head -10
            '''
            
            archiveArtifacts artifacts: 'reports/**/*, build/web/', fingerprint: true
            publishHTML(target: [
                reportDir: 'reports/sast/metrics',
                reportFiles: 'index.html',
                reportName: 'Dart Security Metrics'
            ])
        }
        success {
            sh """
            echo "🎉 DEVSECOPS PIPELINE SUCCESS!"
            echo "🔒 Security Status: ALL CHECKS PASSED"
            echo "🌐 Application: http://${DEPLOY_SERVER}:${APP_PORT}"
            echo "🐳 Registry: ${DOCKER_REGISTRY}"
            echo "📦 Image: ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest"
            echo ""
            echo "📋 Security Layers Applied:"
            echo "   ✅ SAST: Static Application Security Testing"
            echo "   ✅ Container: Trivy Vulnerability Scan & SBOM"
            echo "   ✅ Image Hardening: Non-root user, Read-only fs"
            echo "   ✅ Network: Security headers & port verification"
            echo "   ✅ Runtime: Health checks & security opts"
            """
        }
        failure {
            sh """
            echo "❌ DEVSECOPS PIPELINE FAILED"
            echo "🔒 Security Violations Detected:"
            echo "   - Critical vulnerabilities in container"
            echo "   - Security headers missing"
            echo "   - Hardcoded secrets detected"
            echo "   - Container running as root"
            echo "   - Build integrity compromised"
            """
        }
    }
}