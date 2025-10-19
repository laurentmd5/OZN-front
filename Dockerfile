# Définition des arguments de construction (ARG)
ARG NGINX_PORT=8090
ARG FLUTTER_VERSION=3.35.6
ARG CONTAINER_USER=oznapp
ARG CONTAINER_UID=1001
ARG BUILD_VERSION=1.0.0

# ====================================================================
# STAGE 1: Build l'application Flutter
# ====================================================================
FROM instrumentisto/flutter:${FLUTTER_VERSION} as builder

# RÉDÉFINIR les ARG dans ce stage
ARG BUILD_VERSION
ARG FLUTTER_VERSION

WORKDIR /app

# Copie des fichiers de configuration et de dépendances
COPY pubspec.yaml pubspec.lock ./

# Installation des outils nécessaires
RUN apt-get update && apt-get install -y --no-install-recommends bash curl && rm -rf /var/lib/apt/lists/*

# Logique de réessai pour flutter pub get
RUN set -e; \
    RETRY_COUNT=0; \
    MAX_RETRIES=3; \
    echo "📦 Installing Flutter dependencies with retry logic..."; \
    until flutter pub get --verbose; do \
        RETRY_COUNT=$((RETRY_COUNT+1)); \
        if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then \
            echo "❌ Failed to get dependencies after $MAX_RETRIES attempts."; \
            exit 1; \
        fi; \
        echo "⚠️ pub get failed. Retrying in 10 seconds (Attempt $RETRY_COUNT of $MAX_RETRIES)..."; \
        sleep 10; \
    done; \
    echo "✅ Dependencies installed successfully"

# Copie du reste du code source
COPY . .

# Construction de l'application Flutter pour le web - VERSION CORRIGÉE
RUN set -eux; \
    echo "🔨 Building Flutter application for Web..."; \
    echo "Build version: ${BUILD_VERSION}"; \
    flutter build web --release \
        --dart-define=APP_BUILD_VERSION="${BUILD_VERSION}" \
        --web-renderer html \
        --base-href /; \
    echo "✅ Flutter build completed"

# ====================================================================
# STAGE 2: Production (Image NGINX légère)
# ====================================================================
FROM nginx:alpine

# RÉDÉFINIR les ARG dans ce stage
ARG NGINX_PORT
ARG CONTAINER_USER
ARG CONTAINER_UID
ARG BUILD_VERSION

# Création d'un groupe et d'un utilisateur non-root pour des raisons de sécurité
RUN set -eux; \
    addgroup -g ${CONTAINER_UID} ${CONTAINER_USER}; \
    adduser -u ${CONTAINER_UID} -G ${CONTAINER_USER} -D ${CONTAINER_USER}; \
    mkdir -p /var/cache/nginx/client_temp /var/run /var/log/nginx /tmp; \
    chown -R ${CONTAINER_USER}:${CONTAINER_USER} /var/cache/nginx /var/run /var/log/nginx /tmp; \
    chmod -R 775 /var/cache/nginx /var/run /var/log/nginx /tmp

# Copie de la configuration NGINX
COPY nginx.conf /etc/nginx/nginx.conf

# Copie des artefacts de construction depuis le stage 'builder'
COPY --from=builder /app/build/web /usr/share/nginx/html

# Copie du script de healthcheck
COPY healthcheck.sh /healthcheck.sh
RUN chmod +x /healthcheck.sh

# Configuration de l'utilisateur par défaut
USER ${CONTAINER_USER}
WORKDIR /usr/share/nginx/html

# Port exposé
EXPOSE ${NGINX_PORT}

# Commande par défaut pour démarrer NGINX
CMD ["nginx", "-g", "daemon off;"]
