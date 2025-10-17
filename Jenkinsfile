pipeline {
    agent any
    
    environment {
        // Configuration Application Flutter
        APP_NAME = 'ozn-flutter-app'
        APP_PORT = '8090'  // 🔄 Changé pour 8090
    
        // Configuration Docker
        DOCKER_REGISTRY = 'local'
        DOCKER_IMAGE = "${APP_NAME}"
        DOCKER_TAG = "${env.BUILD_NUMBER}"
        
        // Configuration Sécurité
        TRIVY_CACHE_DIR = '/tmp/trivy-cache-${BUILD_NUMBER}'
        SAST_REPORTS_DIR = 'reports/sast'
        
        // Configuration Serveur
        DEPLOY_SERVER = 'localhost'
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
                echo "=== Fichiers clés ==="
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
                flutter doctor -v
                
                echo "📦 Installation des dépendances..."
                flutter pub get || { echo "❌ Erreur dependencies"; exit 1; }
                
                echo "📊 Analyse statique initiale..."
                flutter analyze --no-pub || echo "⚠️ Analyse Flutter avec avertissements"
                '''
            }
        }

        // ÉTAPE 3: SAST RENFORCÉ - Static Application Security Testing
        stage('SAST Renforcé - Static Analysis') {
            parallel {
                stage('Flutter Analyze Avancé') {
                    steps {
                        sh '''
                        echo "🔍 SAST: Flutter Code Analysis Avancé..."
                        mkdir -p ${SAST_REPORTS_DIR}
                        
                        # Analyse détaillée avec tous les checks
                        flutter analyze --no-pub --write=${SAST_REPORTS_DIR}/flutter_analysis.json --fatal-infos
                        flutter analyze --no-pub --current-package --fatal-warnings > ${SAST_REPORTS_DIR}/flutter_analysis_detailed.txt
                        
                        # Analyse des lignes de code
                        find lib/ -name "*.dart" | xargs wc -l > ${SAST_REPORTS_DIR}/code_stats.txt
                        
                        echo "📊 Résultats analyse Flutter:"
                        cat ${SAST_REPORTS_DIR}/flutter_analysis_detailed.txt | head -20
                        '''
                    }
                }
                
                stage('Dart Code Metrics Étendu') {
                    steps {
                        sh '''
                        echo "📊 SAST: Dart Code Metrics Étendu..."
                        mkdir -p ${SAST_REPORTS_DIR}/metrics
                        
                        # Installation et exécution des métriques avancées
                        dart pub global activate dart_code_metrics 2>/dev/null || true
                        export PATH="$PATH:$HOME/.pub-cache/bin"
                        
                        # Analyse avec toutes les métriques
                        metrics analyze lib --reporter=html --output-directory=${SAST_REPORTS_DIR}/metrics --set-exit-on-violation-level=warning
                        metrics analyze lib --reporter=codeclimate --output-directory=${SAST_REPORTS_DIR}/metrics
                        metrics analyze lib --reporter=json --output-directory=${SAST_REPORTS_DIR}/metrics > ${SAST_REPORTS_DIR}/metrics_analysis.json
                        
                        # Vérification de la complexité cyclomatique
                        metrics check lib --cyclomatic-complexity=20 --number-of-arguments=5 --number-of-methods=50
                        '''
                    }
                }
                
                stage('Security Rules Scan Renforcé') {
                    steps {
                        sh '''
                        echo "🛡️ SAST: Security Rules Scan Renforcé..."
                        mkdir -p ${SAST_REPORTS_DIR}/security
                        
                        # Rapport de sécurité complet
                        echo "# RAPPORT DE SÉCURITÉ SAST - OZN Flutter App" > ${SAST_REPORTS_DIR}/security/security-audit.md
                        echo "Date: $(date)" >> ${SAST_REPORTS_DIR}/security/security-audit.md
                        echo "## Résultats des Scans de Sécurité\n" >> ${SAST_REPORTS_DIR}/security/security-audit.md
                        
                        # 1. Scan des secrets et informations sensibles
                        echo "### 1. Scan des Secrets et Informations Sensibles" >> ${SAST_REPORTS_DIR}/security/security-audit.md
                        
                        # Mots de passe en dur
                        find lib/ -name "*.dart" -exec grep -n -E "password.*=.*['\\\"][^'\\\"]*['\\\"]" {} \\; > ${SAST_REPORTS_DIR}/security/hardcoded-passwords.txt
                        if [ -s ${SAST_REPORTS_DIR}/security/hardcoded-passwords.txt ]; then
                            echo "❌ CRITICAL: Hardcoded passwords detected!" >> ${SAST_REPORTS_DIR}/security/security-audit.md
                            cat ${SAST_REPORTS_DIR}/security/hardcoded-passwords.txt >> ${SAST_REPORTS_DIR}/security/security-audit.md
                            echo "❌ Build failed: Hardcoded passwords found"
                            exit 1
                        else
                            echo "✅ PASS: No hardcoded passwords" >> ${SAST_REPORTS_DIR}/security/security-audit.md
                        fi
                        
                        # Clés API et tokens
                        find lib/ -name "*.dart" -exec grep -n -i -E "api[_-]?key|secret[_-]?key|token.*=.*['\\\"][^'\\\"]*['\\\"]|auth.*=.*['\\\"][^'\\\"]*['\\\"]" {} \\; > ${SAST_REPORTS_DIR}/security/api-secrets.txt
                        if [ -s ${SAST_REPORTS_DIR}/security/api-secrets.txt ]; then
                            echo "❌ HIGH: Possible API keys/secrets detected!" >> ${SAST_REPORTS_DIR}/security/security-audit.md
                            cat ${SAST_REPORTS_DIR}/security/api-secrets.txt >> ${SAST_REPORTS_DIR}/security/security-audit.md
                            echo "❌ Build failed: Hardcoded API keys found"
                            exit 1
                        else
                            echo "✅ PASS: No hardcoded API keys" >> ${SAST_REPORTS_DIR}/security/security-audit.md
                        fi
                        
                        # 2. Scan de sécurité des URLs et endpoints
                        echo "### 2. Scan des URLs et Endpoints" >> ${SAST_REPORTS_DIR}/security/security-audit.md
                        
                        # URLs HTTP non sécurisées
                        find lib/ -name "*.dart" -exec grep -n "http://" {} \\; | grep -v "https://" | grep -v "//" > ${SAST_REPORTS_DIR}/security/http-urls.txt
                        if [ -s ${SAST_REPORTS_DIR}/security/http-urls.txt ]; then
                            echo "⚠️ MEDIUM: HTTP URLs detected - should use HTTPS" >> ${SAST_REPORTS_DIR}/security/security-audit.md
                            cat ${SAST_REPORTS_DIR}/security/http-urls.txt >> ${SAST_REPORTS_DIR}/security/security-audit.md
                        else
                            echo "✅ PASS: No insecure HTTP URLs" >> ${SAST_REPORTS_DIR}/security/security-audit.md
                        fi
                        
                        # 3. Scan des pratiques de codage dangereuses
                        echo "### 3. Scan des Pratiques de Codage Dangereuses" >> ${SAST_REPORTS_DIR}/security/security-audit.md
                        
                        # Utilisation de eval ou de désérialisation non sécurisée
                        find lib/ -name "*.dart" -exec grep -n -i "eval\\|Function.apply.*'\\\".*\\\"'\\|fromJson.*untrusted" {} \\; > ${SAST_REPORTS_DIR}/security/dangerous-patterns.txt
                        if [ -s ${SAST_REPORTS_DIR}/security/dangerous-patterns.txt ]; then
                            echo "⚠️ HIGH: Dangerous coding patterns detected" >> ${SAST_REPORTS_DIR}/security/security-audit.md
                            cat ${SAST_REPORTS_DIR}/security/dangerous-patterns.txt >> ${SAST_REPORTS_DIR}/security/security-audit.md
                        else
                            echo "✅ PASS: No dangerous coding patterns" >> ${SAST_REPORTS_DIR}/security/security-audit.md
                        fi
                        
                        # 4. Scan des dépendances non sécurisées
                        echo "### 4. Scan des Imports et Dépendances" >> ${SAST_REPORTS_DIR}/security/security-audit.md
                        
                        # Imports non sécurisés
                        find lib/ -name "*.dart" -exec grep -n "import.*'dart:io'\\|import.*'dart:ffi'\\|import.*'package:ffi" {} \\; > ${SAST_REPORTS_DIR}/security/unsafe-imports.txt
                        if [ -s ${SAST_REPORTS_DIR}/security/unsafe-imports.txt ]; then
                            echo "ℹ️ INFO: Potentially unsafe imports detected" >> ${SAST_REPORTS_DIR}/security/security-audit.md
                            cat ${SAST_REPORTS_DIR}/security/unsafe-imports.txt >> ${SAST_REPORTS_DIR}/security/security-audit.md
                        else
                            echo "✅ PASS: No unsafe imports" >> ${SAST_REPORTS_DIR}/security/security-audit.md
                        fi
                        
                        # 5. Scan de la configuration
                        echo "### 5. Scan de la Configuration" >> ${SAST_REPORTS_DIR}/security/security-audit.md
                        
                        # Vérification des fichiers de configuration
                        if [ -f "pubspec.yaml" ]; then
                            grep -n -E "http://|insecure:|allow.*true" pubspec.yaml > ${SAST_REPORTS_DIR}/security/config-issues.txt || true
                            if [ -s ${SAST_REPORTS_DIR}/security/config-issues.txt ]; then
                                echo "⚠️ MEDIUM: Potential configuration issues" >> ${SAST_REPORTS_DIR}/security/security-audit.md
                                cat ${SAST_REPORTS_DIR}/security/config-issues.txt >> ${SAST_REPORTS_DIR}/security/security-audit.md
                            else
                                echo "✅ PASS: No configuration issues" >> ${SAST_REPORTS_DIR}/security/security-audit.md
                            fi
                        fi
                        
                        # 6. Scan de la gestion des erreurs
                        echo "### 6. Analyse de la Gestion des Erreurs" >> ${SAST_REPORTS_DIR}/security/security-audit.md
                        
                        # Catch vide ou générique
                        find lib/ -name "*.dart" -exec grep -n -A2 -B2 "catch[^}]*[{}]\\s*}" {} \\; > ${SAST_REPORTS_DIR}/security/empty-catch.txt
                        if [ -s ${SAST_REPORTS_DIR}/security/empty-catch.txt ]; then
                            echo "⚠️ MEDIUM: Empty or generic catch blocks detected" >> ${SAST_REPORTS_DIR}/security/security-audit.md
                            cat ${SAST_REPORTS_DIR}/security/empty-catch.txt | head -10 >> ${SAST_REPORTS_DIR}/security/security-audit.md
                        else
                            echo "✅ PASS: No empty catch blocks" >> ${SAST_REPORTS_DIR}/security/security-audit.md
                        fi
                        
                        echo "## Résumé du Scan SAST" >> ${SAST_REPORTS_DIR}/security/security-audit.md
                        echo "✅ Scan de sécurité SAST complété avec succès" >> ${SAST_REPORTS_DIR}/security/security-audit.md
                        
                        # Affichage du résumé
                        echo "📋 Résumé du Scan SAST:"
                        grep -E "✅ PASS|⚠️ MEDIUM|❌ HIGH|❌ CRITICAL" ${SAST_REPORTS_DIR}/security/security-audit.md
                        '''
                    }
                }
                
                stage('Analyse des Dépendances de Sécurité') {
                    steps {
                        sh '''
                        echo "📦 SAST: Analyse des Dépendances de Sécurité..."
                        mkdir -p ${SAST_REPORTS_DIR}/dependencies
                        
                        # Analyse des vulnérabilités des dépendances
                        flutter pub outdated --mode=null-safety > ${SAST_REPORTS_DIR}/dependencies/dependency-status.txt
                        
                        # Extraction des versions des dépendances
                        flutter pub deps --json > ${SAST_REPORTS_DIR}/dependencies/dependencies.json
                        
                        # Vérification des dépendances critiques
                        echo "### Dépendances Critiques à Vérifier:" > ${SAST_REPORTS_DIR}/dependencies/security-deps.md
                        grep -E "http|dio|shared_preferences|flutter_secure_storage" pubspec.yaml >> ${SAST_REPORTS_DIR}/dependencies/security-deps.md || true
                        
                        echo "📊 Analyse des dépendances complétée"
                        '''
                    }
                }
            }
            
            post {
                always {
                    sh '''
                    echo "📁 Archivage des rapports SAST..."
                    ls -la ${SAST_REPORTS_DIR}/ 2>/dev/null || true
                    '''
                }
            }
        }

        // ÉTAPE 4: SCAT - Software Composition Analysis
        stage('SCAT - Dependency Analysis') {
            steps {
                sh '''
                echo "📦 SCAT: Dependency Vulnerability Scan..."
                mkdir -p reports/scat
                
                # Analyse des dépendances obsolètes
                flutter pub outdated --mode=null-safety > reports/scat/dependency-outdated.txt
                echo "=== Dependencies Status ==="
                cat reports/scat/dependency-outdated.txt
                
                # Arbre des dépendances
                flutter pub deps --style=tree > reports/scat/dependency-tree.txt
                echo "=== Top Level Dependencies ==="
                grep -E "^[│ ]*[└├][─└├]" reports/scat/dependency-tree.txt | head -30
                
                # Audit des licences
                flutter pub deps --json > reports/scat/dependencies.json
                '''
            }
        }

        // ÉTAPE 5: Build Flutter Application
        stage('Build Flutter') {
            steps {
                sh '''
                echo "🏗️ Building Flutter Web Application..."
                
                # Nettoyage des builds précédents
                flutter clean
                
                # Build web
                flutter build web --release --web-renderer html --pwa-strategy none
                
                echo "✅ Build completed successfully"
                echo "=== Build Output ==="
                ls -la build/web/
                du -sh build/web/
                
                # Vérification des fichiers critiques
                if [ -f "build/web/index.html" ]; then
                    echo "✅ index.html present"
                else
                    echo "❌ index.html missing!"
                    exit 1
                fi
                '''
            }
        }

        // ÉTAPE 6: Quality & Security Tests
        stage('Quality Tests') {
            parallel {
                stage('Unit Tests') {
                    steps {
                        sh '''
                        echo "🧪 Running Unit Tests..."
                        mkdir -p coverage
                        
                        flutter test --coverage --test-randomize-ordering-seed=random
                        
                        # Génération rapport coverage
                        flutter pub global activate coverage 2>/dev/null || true
                        flutter pub global run coverage:format_coverage \
                          --lcov \
                          --in=coverage \
                          --out=coverage/lcov.info \
                          --report-on=lib
                          
                        echo "📊 Coverage generated"
                        '''
                    }
                }
                stage('Security Tests') {
                    steps {
                        sh '''
                        echo "🔐 Running Security Tests..."
                        mkdir -p reports/security-tests
                        
                        # Vérification des configurations Android
                        if [ -d "android" ]; then
                            echo "=== Android Manifest Analysis ===" > reports/security-tests/android-security.txt
                            find android/ -name "AndroidManifest.xml" -exec grep -H "permission" {} \\; >> reports/security-tests/android-security.txt
                            
                            if [ -f "android/app/src/main/AndroidManifest.xml" ]; then
                                grep -H "android:debuggable" android/app/src/main/AndroidManifest.xml >> reports/security-tests/android-security.txt || true
                                grep -H "android:allowBackup" android/app/src/main/AndroidManifest.xml >> reports/security-tests/android-security.txt || true
                            fi
                        fi
                        
                        # Vérification des configurations iOS
                        if [ -d "ios" ]; then
                            find ios/ -name "Info.plist" -exec echo "=== iOS Plist: {} ===" \\; >> reports/security-tests/ios-security.txt
                        fi
                        '''
                    }
                }
            }
        }

        // ÉTAPE 7: Build Docker Image avec Port 8090
        stage('Build Docker Image') {
            steps {
                sh '''
                echo "🐳 Building Secure Docker Image for Port ${APP_PORT}..."
                
                # Construction de l'image
                docker build \
                  --build-arg NGINX_PORT=${APP_PORT} \
                  --tag ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG} \
                  --tag ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest \
                  --label "build.number=${BUILD_NUMBER}" \
                  --label "version=1.0.0" \
                  --label "maintainer=devops-team" \
                  --label "port.exposed=${APP_PORT}" \
                  .
                  
                echo "✅ Docker images built successfully for port ${APP_PORT}"
                docker images | grep ${DOCKER_REGISTRY}
                '''
            }
        }

        // ÉTAPE 8: Container Security Scan
        stage('Container Security Scan') {
            steps {
                sh '''
                echo "🛡️ Container Security Scan with Trivy..."
                mkdir -p ${TRIVY_CACHE_DIR}
                
                # Scan de l'image avec gestion d'erreurs
                trivy --cache-dir ${TRIVY_CACHE_DIR} image \
                  --exit-code 0 \
                  --severity HIGH,CRITICAL \
                  --format table \
                  ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest || echo "⚠️ Vulnerabilities found"
                
                # Scan détaillé pour rapport
                trivy --cache-dir ${TRIVY_CACHE_DIR} image \
                  --exit-code 0 \
                  --severity HIGH,CRITICAL \
                  --format json \
                  -o reports/trivy-scan.json \
                  ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest
                  
                echo "📊 Container security scan completed"
                '''
            }
        }

        // ÉTAPE 9: DAST - Dynamic Application Security Testing
        stage('DAST - Dynamic Testing') {
            steps {
                sh '''
                echo "🎯 DAST: Dynamic Security Testing on Port ${APP_PORT}..."
                
                # Démarrage du conteneur de test
                docker run -d \
                  --name ${APP_NAME}-dast \
                  -p 8081:${APP_PORT} \
                  --rm \
                  ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest
                  
                sleep 15
                
                # Tests de santé et sécurité
                echo "🔍 Application Health Check..."
                curl -f -s -o /dev/null -w "HTTP Status: %{http_code}\\n" http://localhost:8081/ || echo "❌ Application not responding"
                
                echo "📋 Security Headers Check..."
                curl -s -I http://localhost:8081/ | grep -E "(X-Frame-Options|X-Content-Type-Options|X-XSS-Protection|Strict-Transport-Security)" || echo "⚠️ Security headers missing"
                
                # Test de contenu de base
                echo "🌐 Content Verification..."
                curl -s http://localhost:8081/ | grep -o "<title>[^<]*" | head -1 || echo "⚠️ No title found"
                
                # Nettoyage
                docker stop ${APP_NAME}-dast
                echo "✅ DAST testing completed"
                '''
            }
        }

        // ÉTAPE 10: Deploy to Production sur Port 8090
        stage('Deploy to Production') {
            steps {
                sh '''
                echo "🚀 Deploying to Production on Port ${APP_PORT}..."
                
                # Arrêt propre de l'ancien conteneur
                docker stop ${APP_NAME} 2>/dev/null || echo "ℹ️ No running container to stop"
                docker rm ${APP_NAME} 2>/dev/null || echo "ℹ️ No container to remove"
                
                # Nettoyage des ressources
                docker image prune -f 2>/dev/null || true
                
                # Déploiement sécurisé sur le port 8090
                docker run -d \
                  --name ${APP_NAME} \
                  -p ${APP_PORT}:${APP_PORT} \
                  --restart unless-stopped \
                  --security-opt=no-new-privileges:true \
                  --read-only \
                  --tmpfs /tmp \
                  --tmpfs /var/cache/nginx \
                  --tmpfs /var/run \
                  --label "deployed.at=$(date -Iseconds)" \
                  --label "version=${BUILD_NUMBER}" \
                  --label "port=${APP_PORT}" \
                  ${DOCKER_REGISTRY}/${APP_NAME}:latest
                  
                sleep 10
                
                echo "📊 Deployment Status:"
                docker ps --filter "name=${APP_NAME}" --format "table {{.Names}}\\t{{.Status}}\\t{{.Ports}}"
                
                # Health check final sur le port 8090
                echo "❤️ Final Health Check on Port ${APP_PORT}..."
                if curl -f -s http://localhost:${APP_PORT}/ > /dev/null; then
                    echo "✅ Production health check PASSED on port ${APP_PORT}"
                else
                    echo "❌ Production health check FAILED on port ${APP_PORT}"
                    docker logs ${APP_NAME} --tail 30
                    exit 1
                fi
                '''
            }
        }

        // ÉTAPE 11: Post-Deployment Verification
        stage('Post-Deployment Verification') {
            steps {
                sh '''
                echo "🔍 Post-Deployment Verification on Port ${APP_PORT}..."
                
                # Vérification du conteneur running
                echo "🐳 Running Container Inspection..."
                docker inspect ${APP_NAME} | jq -r '.[0].State.Status' | grep -q "running" && echo "✅ Container is running" || echo "❌ Container not running"
                
                # Vérification des ports
                echo "🔌 Port Binding Check..."
                docker port ${APP_NAME} | grep ${APP_PORT} && echo "✅ Port ${APP_PORT} binding correct" || echo "❌ Port ${APP_PORT} binding issue"
                
                # Test de charge basique
                echo "⚡ Basic Load Test on Port ${APP_PORT}..."
                for i in {1..5}; do
                    curl -s -o /dev/null -w "Request $i: %{http_code}\\n" http://localhost:${APP_PORT}/ || true
                    sleep 1
                done
                
                echo "✅ Post-deployment verification completed on port ${APP_PORT}"
                '''
            }
        }
    }
    
    post {
        always {
            sh '''
            echo "📊 Gathering reports..."
            mkdir -p reports
            ls -la reports/ 2>/dev/null || true
            ls -la coverage/ 2>/dev/null || true
            
            echo "🧹 Cleaning up temporary resources..."
            docker stop ${APP_NAME}-dast 2>/dev/null || true
            rm -rf ${TRIVY_CACHE_DIR} 2>/dev/null || true
            '''
            
            archiveArtifacts artifacts: 'reports/**/*, coverage/lcov.info, build/web/', fingerprint: true
            publishHTML(target: [
                reportDir: 'reports/sast/metrics',
                reportFiles: 'index.html',
                reportName: 'Dart Code Metrics'
            ])
            publishHTML(target: [
                reportDir: 'reports/sast/security',
                reportFiles: 'security-audit.md',
                reportName: 'Security Audit Report'
            ])
        }
        success {
            sh """
            echo "🎉 DEVSECOPS PIPELINE SUCCESS!"
            echo "🌐 Application URL: http://localhost:${APP_PORT}"
            echo "🌐 Network URL: http://\$(hostname -I | awk '{print \$1}'):${APP_PORT}"
            echo ""
            echo "📋 Security Reports:"
            echo "   ✅ SAST RENFORCÉ: Static Application Security Testing"
            echo "   ✅ SCAT: Software Composition Analysis" 
            echo "   ✅ DAST: Dynamic Application Security Testing"
            echo "   ✅ Container Security: Trivy Scan"
            echo "   ✅ Quality: Test Coverage & Metrics"
            """
        }
        failure {
            sh """
            echo "❌ DEVSECOPS PIPELINE FAILED"
            echo "🔍 Investigation required for:"
            echo "   - Code analysis errors"
            echo "   - Security violations"
            echo "   - Test failures"
            echo "   - Build issues"
            echo "   - Deployment problems"
            """
        }
    }
}
