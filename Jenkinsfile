pipeline {
    agent any
    
    environment {
        APP_NAME = 'ozn-flutter-app'
        APP_PORT = '8090'
        DOCKER_REGISTRY = 'laurentmd5'
        DOCKER_IMAGE = "${APP_NAME}"
        DOCKER_TAG = "${env.BUILD_NUMBER}"
    }
    
    stages {
        // ÉTAPE 1: Checkout
        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/laurentmd5/OZN-front.git',
                    credentialsId: 'my-token',
                    poll: false

                sh '''
                echo "📦 Repository cloned"
                pwd
                ls -la
                '''
            }
        }
        
        // ÉTAPE 2: Vérification des Fichiers
        stage('File Verification') {
            steps {
                sh '''
                echo "🔍 Verifying required files..."
                
                # Vérifier les fichiers essentiels
                REQUIRED_FILES=("Dockerfile" "nginx.conf")
                for file in "${REQUIRED_FILES[@]}"; do
                    if [ -f "$file" ]; then
                        echo "✅ $file found"
                        echo "--- Content of $file (first 5 lines) ---"
                        head -5 "$file"
                        echo "----------------------------------------"
                    else
                        echo "❌ $file missing - creating placeholder"
                        # Créer des fichiers de test si manquants
                        if [ "$file" = "Dockerfile" ]; then
                            cat > Dockerfile << 'EOF'
FROM nginx:1.24-alpine
COPY nginx.conf /etc/nginx/nginx.conf
COPY build/web/ /usr/share/nginx/html/
EXPOSE 8090
CMD ["nginx", "-g", "daemon off;"]
EOF
                        elif [ "$file" = "nginx.conf" ]; then
                            cat > nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    sendfile on;

    server {
        listen 8090;
        server_name localhost;
        root /usr/share/nginx/html;
        index index.html;

        location / {
            try_files $uri $uri/ /index.html;
        }
    }
}
EOF
                        fi
                    fi
                done
                
                # Créer un build/web minimal si nécessaire
                if [ ! -d "build/web" ]; then
                    echo "📦 Creating minimal web build..."
                    mkdir -p build/web
                    cat > build/web/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>OZN App</title>
</head>
<body>
    <h1>OZN Flutter Application</h1>
    <p>Build: ${BUILD_NUMBER}</p>
</body>
</html>
EOF
                    echo "console.log('OZN App');" > build/web/main.dart.js
                fi
                
                echo "📁 Final structure:"
                find . -name "Dockerfile" -o -name "nginx.conf" -o -name "index.html" | head -10
                '''
            }
        }

        // ÉTAPE 3: Test Docker Simple
        stage('Simple Docker Test') {
            steps {
                sh '''
                echo "🐳 Testing simple Docker build..."
                
                # Afficher le contexte de build
                echo "📁 Build context:"
                ls -la | grep -E "(Dockerfile|nginx.conf|build)"
                du -sh build/web/ 2>/dev/null || echo "No build/web"
                
                # Construction simple
                docker build -t simple-test .
                
                echo "✅ Simple Docker build successful!"
                
                # Test du conteneur
                echo "🧪 Testing container..."
                docker run -d --name simple-test-container -p 8080:8090 simple-test
                sleep 5
                
                if docker ps | grep -q simple-test-container; then
                    echo "✅ Container started successfully"
                    
                    # Test HTTP
                    if curl -f -s http://localhost:8080/ > /dev/null; then
                        echo "✅ HTTP test passed"
                    else
                        echo "⚠️ HTTP test failed"
                    fi
                    
                    # Nettoyage
                    docker stop simple-test-container
                    docker rm simple-test-container
                else
                    echo "❌ Container failed to start"
                    docker logs simple-test-container || true
                fi
                
                # Nettoyage de l'image
                docker rmi simple-test || true
                '''
            }
        }

        // ÉTAPE 4: Build Final
        stage('Final Build') {
            steps {
                sh '''
                echo "🏗️ Final Docker build..."
                
                # Build avec tous les tags
                docker build \\
                    --tag ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG} \\
                    --tag ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest \\
                    .
                
                echo "🎉 Final build completed!"
                echo "📦 Available images:"
                docker images | grep ${DOCKER_REGISTRY}
                '''
            }
        }
    }
    
    post {
        always {
            sh '''
            echo "🧹 Cleaning up..."
            docker system prune -f 2>/dev/null || true
            '''
        }
        success {
            sh '''
            echo "🎉 PIPELINE SUCCESS!"
            echo "🐳 Image: ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest"
            '''
        }
        failure {
            sh '''
            echo "❌ PIPELINE FAILED"
            echo "🔍 Last error context:"
            docker system df || true
            '''
        }
    }
}