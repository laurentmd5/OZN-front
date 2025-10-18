# ====================================================================
# ÉTAPE 1: FLUTTER BUILDER (Compilation de l'application Flutter)
# ====================================================================
FROM debian:bullseye-slim AS flutter-builder

# Arguments de build
ARG FLUTTER_VERSION=3.19.5
ARG CONTAINER_USER=flutter
ARG CONTAINER_UID=1000
ARG BUILD_VERSION=1.0.0

# Labels pour traçabilité
LABEL stage="builder"
LABEL description="Flutter build environment"
LABEL version="${BUILD_VERSION}"

# Installation des dépendances système avec gestion d'erreur
RUN set -eux; \
    apt-get update && apt-get install -y --no-install-recommends \
    curl \
    unzip \
    git \
    xz-utils \
    ca-certificates \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Installation de Flutter
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
    PUB_CACHE="/home/${CONTAINER_USER}/.pub-cache"

# Vérification et configuration de Flutter
RUN set -eux; \
    flutter --version; \
    flutter doctor -v || true; \
    flutter config --no-analytics; \
    # Ajout du répertoire Flutter comme sûr pour éviter les problèmes Git
    git config --global --add safe.directory /usr/local/flutter

# Création de l'utilisateur non-root
RUN groupadd -r ${CONTAINER_USER} && \
    useradd -r -g ${CONTAINER_USER} -m -d /home/${CONTAINER_USER} -u ${CONTAINER_UID} ${CONTAINER_USER} && \
    mkdir -p /home/${CONTAINER_USER}/.config/flutter && \
    chown -R ${CONTAINER_USER}:${CONTAINER_USER} /home/${CONTAINER_USER}

# Configuration des permissions pour Flutter
RUN chown -R ${CONTAINER_USER}:${CONTAINER_USER} /usr/local/flutter

USER ${CONTAINER_USER}
WORKDIR /home/${CONTAINER_USER}/app

# Copie des fichiers de dépendances (dans l'ordre préféré pour le cache)
COPY --chown=${CONTAINER_USER}:${CONTAINER_USER} pubspec.yaml ./
COPY --chown=${CONTAINER_USER}:${CONTAINER_USER} pubspec.lock* ./

# Installation des dépendances (crucial pour le cache Docker)
RUN set -eux; \
    echo "📦 Installing Flutter dependencies..."; \
    flutter pub get --verbose || { \
        echo "❌ Failed to get dependencies"; \
        exit 1; \
    }; \
    echo "✅ Dependencies installed successfully"

# Copie du code source complet
COPY --chown=${CONTAINER_USER}:${CONTAINER_USER} . ./

# Build Flutter Web (avec les bonnes flags)
RUN set -eux; \
    echo "🏗️ Building Flutter web application..."; \
    \
    flutter config --enable-web; \
    \
    flutter build web \
        --release \
        --pwa-strategy none \
        --dart-define=BUILD_ENV=production \
        --dart-define=BUILD_VERSION=${BUILD_VERSION} \
        --verbose || { \
            echo "❌ Flutter build failed"; \
            exit 1; \
        }; \
    \
    echo "✅ Flutter build completed"

# ====================================================================
# ÉTAPE 2: PRODUCTION RUNTIME (Service NGINX)
# ====================================================================
FROM nginx:1.24-alpine

# Arguments de build (doivent être redéfinis)
ARG NGINX_PORT=8090
ARG CONTAINER_USER=oznapp
ARG CONTAINER_UID=1001
ARG BUILD_VERSION=1.0.0

# Labels
LABEL maintainer="laurentmd5" \
      description="OZN Flutter Web Application - Production" \
      version="${BUILD_VERSION}"

# Configuration du port
ENV NGINX_PORT=${NGINX_PORT}

# Mise à jour de sécurité et installation des outils de base
RUN set -eux; \
    apk update && \
    apk upgrade --no-cache && \
    apk add --no-cache \
        curl \
        bash \
        tzdata \
        # Installation de 'gettext' pour la substitution de variables dans nginx.conf (optionnel mais bon pour la robustesse)
        gettext && \
    rm -rf /var/cache/apk/*

# Création de l'utilisateur non-root (oznapp)
RUN set -eux; \
    addgroup -g ${CONTAINER_UID} -S ${CONTAINER_USER} && \
    adduser -S -D -H -u ${CONTAINER_UID} -h /usr/share/nginx/html -s /sbin/nologin -G ${CONTAINER_USER} ${CONTAINER_USER}

# Préparation de la configuration NGINX
COPY nginx.conf /etc/nginx/templates/default.conf.template

# Copie des fichiers Flutter depuis le builder
COPY --from=flutter-builder --chown=${CONTAINER_USER}:${CONTAINER_USER} \
    /home/${CONTAINER_USER}/app/build/web/ /usr/share/nginx/html/

# Vérification du contenu copié
RUN set -eux; \
    echo "🔍 Verifying deployment files..."; \
    if [ ! -f /usr/share/nginx/html/index.html ]; then \
        echo "❌ Deployment verification failed: index.html not found"; \
        ls -la /usr/share/nginx/html/; \
        exit 1; \
    fi; \
    echo "✅ Deployment files verified"

# Configuration des permissions pour l'exécution sécurisée
RUN set -eux; \
    chmod -R 755 /usr/share/nginx/html && \
    find /usr/share/nginx/html -type f -exec chmod 644 {} \; && \
    chown -R ${CONTAINER_USER}:${CONTAINER_USER} /var/cache/nginx && \
    chown -R ${CONTAINER_USER}:${CONTAINER_USER} /var/run && \
    touch /var/run/nginx.pid && \
    chown ${CONTAINER_USER}:${CONTAINER_USER} /var/run/nginx.pid

# Création du script de health check
# Utilise la variable d'environnement ${NGINX_PORT}
RUN set -eux; \
    echo '#!/bin/sh' > /healthcheck.sh && \
    echo 'set -e' >> /healthcheck.sh && \
    echo "timeout 10s curl -f -s http://localhost:\${NGINX_PORT}/ > /dev/null || exit 1" >> /healthcheck.sh && \
    echo 'exit 0' >> /healthcheck.sh && \
    chmod 755 /healthcheck.sh

# Exposition du port
EXPOSE ${NGINX_PORT}

# Configuration du health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD /healthcheck.sh

# Changement vers l'utilisateur non-root
USER ${CONTAINER_USER}

# Le point d'entrée utilise `envsubst` pour remplacer la variable NGINX_PORT
CMD ["/bin/sh", "-c", "envsubst '$NGINX_PORT' < /etc/nginx/templates/default.conf.template > /etc/nginx/conf.d/default.conf && exec nginx -g 'daemon off;'"]
