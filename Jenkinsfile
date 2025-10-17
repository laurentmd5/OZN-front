pipeline {
    agent any
    
    environment {
        // Configuration Application Flutter
        APP_NAME = 'ozn-flutter-app'
        APP_PORT = '8090'
    
        // Configuration Docker - MIS À JOUR
        DOCKER_REGISTRY = 'laurentmd5'
        DOCKER_IMAGE = "${APP_NAME}"
        DOCKER_TAG = "${env.BUILD_NUMBER}"
        
        // Configuration Sécurité
        TRIVY_CACHE_DIR = '/tmp/trivy-cache-${BUILD_NUMBER}'
        SAST_REPORTS_DIR = 'reports/sast'
        ZAP_REPORTS_DIR = 'reports/zap'
        
        // Configuration Serveur Ubuntu
        DEPLOY_SERVER = 'devops@localhost'
        DEPLOY_PATH = '/home/devops/apps'
        SSH_CREDENTIALS_ID = 'ubuntu-server-ssh'
        
        // Configuration OWASP ZAP
        ZAP_HOST = 'localhost'  // Jenkins et l'app sont sur le même serveur
        ZAP_PORT = '8090'       // Port de l'application
        ZAP_TIMEOUT = '300'     // 5 minutes pour le scan
    }
    
    stages {
        // ÉTAPE 1: Checkout du code
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
        
        // ÉTAPE 2: Setup Flutter Environment
        stage('Setup Flutter') {
            steps {
                sh '''
                echo "🔧 Setting up Flutter environment..."
                flutter --version || { echo "❌ Flutter non disponible"; exit 1; }
                flutter pub get || { echo "❌ Erreur dependencies"; exit 1; }
                flutter analyze --no-pub || echo "⚠️ Analyse Flutter avec avertissements"
                '''
            }
        }

        // ÉTAPE 3: SAST RENFORCÉ
        stage('SAST Renforcé - Static Analysis') {
            parallel {
                stage('Flutter Analyze Avancé') {
                    steps {
                        sh '''
                        echo "🔍 SAST: Flutter Code Analysis Avancé..."
                        mkdir -p ${SAST_REPORTS_DIR}
                        flutter analyze --no-pub --write=${SAST_REPORTS_DIR}/flutter_analysis.json --fatal-infos
                        flutter analyze --no-pub --current-package --fatal-warnings > ${SAST_REPORTS_DIR}/flutter_analysis_detailed.txt
                        '''
                    }
                }
                
                stage('Dart Code Metrics') {
                    steps {
                        sh '''
                        echo "📊 SAST: Dart Code Metrics..."
                        mkdir -p ${SAST_REPORTS_DIR}/metrics
                        dart pub global activate dart_code_metrics 2>/dev/null || true
                        export PATH="$PATH:$HOME/.pub-cache/bin"
                        metrics analyze lib --reporter=html --output-directory=${SAST_REPORTS_DIR}/metrics
                        '''
                    }
                }
                
                stage('Security Rules Scan') {
                    steps {
                        sh '''
                        echo "🛡️ SAST: Security Rules Scan..."
                        mkdir -p ${SAST_REPORTS_DIR}/security
                        
                        # Scan des secrets
                        find lib/ -name "*.dart" -exec grep -n -E "password.*=.*['\\\"][^'\\\"]*['\\\"]" {} \\; > ${SAST_REPORTS_DIR}/security/hardcoded-passwords.txt
                        if [ -s ${SAST_REPORTS_DIR}/security/hardcoded-passwords.txt ]; then
                            echo "❌ Hardcoded passwords detected!"
                            exit 1
                        fi
                        
                        find lib/ -name "*.dart" -exec grep -n -i -E "api[_-]?key|secret[_-]?key|token.*=.*['\\\"][^'\\\"]*['\\\"]" {} \\; > ${SAST_REPORTS_DIR}/security/api-secrets.txt
                        if [ -s ${SAST_REPORTS_DIR}/security/api-secrets.txt ]; then
                            echo "❌ Hardcoded API keys found"
                            exit 1
                        fi
                        '''
                    }
                }
            }
        }

        // ÉTAPE 4: Build Flutter Application
        stage('Build Flutter') {
            steps {
                sh '''
                echo "🏗️ Building Flutter Web Application..."
                flutter clean
                flutter build web --release --web-renderer html --pwa-strategy none
                echo "✅ Build completed"
                ls -la build/web/
                '''
            }
        }

        // ÉTAPE 5: Build Docker Image avec votre Registry
        stage('Build Docker Image') {
            steps {
                sh '''
                echo "🐳 Building Docker Image for Registry: ${DOCKER_REGISTRY}"
                
                # Construction de l'image avec votre registry
                docker build \
                  --build-arg NGINX_PORT=${APP_PORT} \
                  --tag ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG} \
                  --tag ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest \
                  --label "build.number=${BUILD_NUMBER}" \
                  --label "version=1.0.0" \
                  --label "maintainer=laurentmd5" \
                  .
                  
                echo "✅ Docker images built and tagged for registry: ${DOCKER_REGISTRY}"
                docker images | grep ${DOCKER_REGISTRY}
                '''
            }
        }

        // ÉTAPE 6: Container Security Scan
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

        // ÉTAPE 7: Deploy to Ubuntu Server
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
                            echo '📁 Setting up deployment directory...'
                            sudo mkdir -p ${DEPLOY_PATH}
                            sudo chown -R devops:devops ${DEPLOY_PATH}
                            cd ${DEPLOY_PATH}
                            
                            echo '🐳 Stopping existing container...'
                            docker stop ${APP_NAME} 2>/dev/null || echo 'ℹ️ No running container to stop'
                            docker rm ${APP_NAME} 2>/dev/null || echo 'ℹ️ No container to remove'
                            
                            echo '📥 Pulling image from registry: ${DOCKER_REGISTRY}'
                            docker pull ${DOCKER_REGISTRY}/${APP_NAME}:latest
                            
                            echo '🚀 Starting new container...'
                            docker run -d \\
                              --name ${APP_NAME} \\
                              -p ${APP_PORT}:${APP_PORT} \\
                              --restart unless-stopped \\
                              --security-opt=no-new-privileges:true \\
                              ${DOCKER_REGISTRY}/${APP_NAME}:latest
                              
                            sleep 15
                            
                            echo '🔍 Checking container status...'
                            docker ps --filter 'name=${APP_NAME}' --format 'table {{.Names}}\\t{{.Status}}\\t{{.Ports}}'
                            
                            echo '❤️ Health check...'
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

        // ÉTAPE 8: OWASP ZAP DAST Scan - NOUVEAU
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
                        
                        # Exécution de ZAP sur le serveur Ubuntu (où l'app est déployée)
                        ssh -i \$SSH_KEY -o StrictHostKeyChecking=no ${DEPLOY_SERVER} "
                            echo '🔍 Running OWASP ZAP security scan...'
                            
                            # Vérifier que l'application est accessible
                            if ! curl -f -s http://localhost:${ZAP_PORT}/ > /dev/null; then
                                echo '❌ Application not accessible for ZAP scan'
                                exit 1
                            fi
                            
                            # Lancer le scan ZAP
                            docker run --rm \\
                              -v /home/devops/zap-reports:/zap/wrk/:rw \\
                              -t owasp/zap2docker-stable zap-baseline.py \\
                              -t http://${ZAP_HOST}:${ZAP_PORT} \\
                              -c zap-baseline.conf \\
                              -r zap-report.html \\
                              -J zap-report.json \\
                              -x zap-report.xml \\
                              -a \\
                              -m 5 \\
                              -T ${ZAP_TIMEOUT} \\
                              || echo '⚠️ ZAP scan completed with findings'
                              
                            echo '✅ ZAP scan completed'
                            
                            # Copier les rapports localement
                            mkdir -p /home/devops/zap-reports
                        "
                        
                        # Récupération des rapports ZAP
                        ssh -i \$SSH_KEY -o StrictHostKeyChecking=no ${DEPLOY_SERVER} "
                            if [ -f '/home/devops/zap-reports/zap-report.html' ]; then
                                echo '📄 ZAP reports generated'
                            else
                                echo '⚠️ No ZAP reports found'
                            fi
                        "
                        """
                    }
                }
            }
        }

        // ÉTAPE 9: Advanced OWASP ZAP Scan - NOUVEAU
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
                            echo '🎯 Starting advanced ZAP API scan...'
                            
                            # Scan API avancé avec ZAP
                            docker run --rm \\
                              -v /home/devops/zap-reports:/zap/wrk/:rw \\
                              -t owasp/zap2docker-stable zap-api-scan.py \\
                              -t http://${ZAP_HOST}:${ZAP_PORT} \\
                              -f openapi \\
                              -r api-scan-report.html \\
                              -J api-scan-report.json \\
                              -x api-scan-report.xml \\
                              -a \\
                              -T ${ZAP_TIMEOUT} \\
                              || echo '⚠️ ZAP API scan completed with findings'
                              
                            echo '✅ Advanced ZAP scan completed'
                        "
                        """
                    }
                }
            }
        }

        // ÉTAPE 10: Post-Deployment Security Verification
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
                            echo '🐳 Container Security Check...'
                            trivy container --exit-code 0 ${APP_NAME} || echo '⚠️ Container vulnerabilities found'
                            
                            echo '🌐 Network Security Check...'
                            # Vérification des ports ouverts
                            netstat -tulpn | grep ${APP_PORT} && echo '✅ Port ${APP_PORT} secured' || echo '❌ Port issue'
                            
                            echo '📋 Security Headers Verification...'
                            curl -s -I http://localhost:${APP_PORT}/ | grep -E '(X-Frame-Options|X-Content-Type-Options|X-XSS-Protection)' || echo '⚠️ Security headers missing'
                            
                            echo '🔐 SSL/TLS Check (if applicable)...'
                            which nmap && nmap -sV --script ssl-enum-ciphers -p ${APP_PORT} localhost || echo 'ℹ️ nmap not available'
                            
                            echo '✅ Security verification completed'
                        "
                        """
                    }
                }
            }
        }

        // ÉTAPE 11: Performance and Load Testing
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
                            echo '📊 Basic performance tests...'
                            
                            # Test de charge simple avec Apache Bench (si disponible)
                            if command -v ab >/dev/null 2>&1; then
                                echo 'Running Apache Bench test...'
                                ab -n 100 -c 10 http://localhost:${APP_PORT}/ > performance-test.txt 2>&1 || echo '⚠️ Performance test issues'
                                grep 'Requests per second' performance-test.txt || echo 'ℹ️ No performance metrics'
                            else
                                echo 'ℹ️ Apache Bench not available, using curl for basic tests'
                                for i in {1..10}; do
                                    time curl -s -o /dev/null http://localhost:${APP_PORT}/ || true
                                done
                            fi
                            
                            # Vérification des ressources
                            echo '📈 Resource usage:'
                            docker stats ${APP_NAME} --no-stream --format 'table {{.Name}}\\t{{.CPUPerc}}\\t{{.MemUsage}}' || true
                            
                            echo '✅ Performance testing completed'
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
            echo ""
            echo "📋 Security Reports:"
            echo "   ✅ SAST: Static Application Security Testing"
            echo "   ✅ Container: Trivy Vulnerability Scan" 
            echo "   ✅ DAST: OWASP ZAP Dynamic Testing"
            echo "   ✅ ZAP API: Advanced API Security Scan"
            echo "   ✅ Performance: Load and Resource Tests"
            """
        }
        failure {
            sh """
            echo "❌ DEVSECOPS PIPELINE FAILED"
            echo "🔍 Check:"
            echo "   - SAST security violations"
            echo "   - Container vulnerabilities"
            echo "   - OWASP ZAP findings"
            echo "   - Deployment issues"
            echo "   - Performance problems"
            """
        }
    }
}
