# ================================
# Stage 1: Build Flutter Application
# ================================
FROM debian:bullseye-slim AS flutter-builder

# Labels pour traçabilité
LABEL stage="builder"
LABEL description="Flutter build environment"

# Installation des dépendances système avec gestion d'erreur
RUN set -eux; \
    apt-get update && apt-get install -y --no-install-recommends \
    curl \
    unzip \
    git \
    xz-utils \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Installation de Flutter avec vérification
ARG FLUTTER_VERSION=3.19.5
RUN set -eux; \
    echo "📥 Downloading Flutter ${FLUTTER_VERSION}..."; \
    curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    -o flutter.tar.xz; \
    \
    echo "📦 Extracting Flutter..."; \
    tar -xf flutter.tar.xz -C /usr/local; \
    rm flutter.tar.xz; \
    \
    echo "✅ Flutter installation completed"

# Configuration de l'environnement Flutter
ENV PATH="$PATH:/usr/local/flutter/bin" \
    FLUTTER_ROOT="/usr/local/flutter" \
    PUB_CACHE="/home/flutter/.pub-cache"

# Vérification de l'installation Flutter
RUN set -eux; \
    flutter --version; \
    flutter doctor -v || true; \
    flutter config --no-analytics; \
    git config --global --add safe.directory /usr/local/flutter

# Création d'un utilisateur non-root
RUN groupadd -r flutter && \
    useradd -r -g flutter -m -d /home/flutter flutter && \
    mkdir -p /home/flutter/.config/flutter && \
    chown -R flutter:flutter /home/flutter

# Configuration des permissions
RUN chown -R flutter:flutter /usr/local/flutter

USER flutter
WORKDIR /home/flutter/app

# Configuration Git pour l'utilisateur flutter
RUN git config --global --add safe.directory /usr/local/flutter

# Copie du fichier de dépendances
COPY --chown=flutter:flutter pubspec.yaml pubspec.lock* ./

# Installation des dépendances avec gestion d'erreur
RUN set -eux; \
    echo "📦 Installing Flutter dependencies..."; \
    flutter pub get --verbose || { \
        echo "❌ Failed to get dependencies"; \
        exit 1; \
    }; \
    echo "✅ Dependencies installed successfully"

# Copie du code source
COPY --chown=flutter:flutter lib/ ./lib/
COPY --chown=flutter:flutter web/ ./web/

# Copie conditionnelle des assets (ne échoue pas si absent)
COPY --chown=flutter:flutter assets/ ./assets/ 2>/dev/null || \
    echo "ℹ️  No assets directory found (optional)"

# Build Flutter avec vérifications (SANS --web-renderer pour Flutter 3.19+)
RUN set -eux; \
    echo "🏗️  Building Flutter web application..."; \
    \
    flutter config --enable-web; \
    \
    flutter build web \
        --release \
        --pwa-strategy none \
        --dart-define=BUILD_ENV=production \
        --dart-define=BUILD_VERSION=1.0.0 \
        --verbose || { \
            echo "❌ Flutter build failed"; \
            exit 1; \
        }; \
    \
    echo "🔍 Verifying build output..."; \
    if [ ! -f "build/web/index.html" ]; then \
        echo "❌ Build verification failed: index.html not found"; \
        exit 1; \
    fi; \
    \
    if [ ! -f "build/web/flutter.js" ]; then \
        echo "❌ Build verification failed: flutter.js not found"; \
        exit 1; \
    fi; \
    \
    echo "✅ Flutter build completed and verified"; \
    ls -lah build/web/

# ================================
# Stage 2: Production Runtime
# ================================
FROM nginx:1.24-alpine

# Labels pour métadonnées
LABEL maintainer="laurentmd5" \
      description="OZN Flutter Web Application - Production" \
      version="1.0.0" \
      security.scan="required"

# Arguments de build
ARG NGINX_PORT=8090
ENV NGINX_PORT=${NGINX_PORT}

# Mise à jour de sécurité
RUN set -eux; \
    apk update && \
    apk upgrade --no-cache && \
    apk add --no-cache \
        curl \
        bash \
        tzdata && \
    rm -rf /var/cache/apk/*

# Création de l'utilisateur non-root
RUN set -eux; \
    addgroup -g 1001 -S oznapp && \
    adduser -S -D -H -u 1001 -h /usr/share/nginx/html -s /sbin/nologin -G oznapp oznapp

# Copie de la configuration Nginx
COPY --chown=root:root nginx.conf /etc/nginx/nginx.conf

# Validation de la configuration Nginx
RUN set -eux; \
    if [ ! -f /etc/nginx/nginx.conf ]; then \
        echo "❌ nginx.conf not found"; \
        exit 1; \
    fi; \
    nginx -t || { \
        echo "❌ Nginx configuration test failed"; \
        exit 1; \
    }; \
    echo "✅ Nginx configuration validated"

# Copie des fichiers Flutter depuis le builder
COPY --from=flutter-builder --chown=oznapp:oznapp \
    /home/flutter/app/build/web/ /usr/share/nginx/html/

# Vérification du contenu copié
RUN set -eux; \
    echo "🔍 Verifying deployment files..."; \
    if [ ! -f /usr/share/nginx/html/index.html ]; then \
        echo "❌ Deployment verification failed: index.html not found"; \
        ls -la /usr/share/nginx/html/; \
        exit 1; \
    fi; \
    echo "✅ Deployment files verified"; \
    ls -lah /usr/share/nginx/html/

# Configuration des permissions
RUN set -eux; \
    chmod -R 755 /usr/share/nginx/html && \
    find /usr/share/nginx/html -type f -exec chmod 644 {} \; && \
    chown -R oznapp:oznapp /var/cache/nginx && \
    chown -R oznapp:oznapp /var/run && \
    touch /var/run/nginx.pid && \
    chown oznapp:oznapp /var/run/nginx.pid

# Suppression des fichiers sensibles
RUN set -eux; \
    find /usr/share/nginx/html -name "*.map" -delete 2>/dev/null || true && \
    rm -rf /docker-entrypoint.d/*.sh 2>/dev/null || true

# Création du script de health check
RUN set -eux; \
    echo '#!/bin/sh' > /healthcheck.sh && \
    echo 'set -e' >> /healthcheck.sh && \
    echo 'timeout 10s curl -f -s http://localhost:${NGINX_PORT}/ > /dev/null || exit 1' >> /healthcheck.sh && \
    echo 'exit 0' >> /healthcheck.sh && \
    chmod 755 /healthcheck.sh

# Exposition du port
EXPOSE ${NGINX_PORT}

# Configuration du health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD /healthcheck.sh

# Changement vers l'utilisateur non-root
USER oznapp

# Point d'entrée
STOPSIGNAL SIGQUIT

CMD ["nginx", "-g", "daemon off;"]