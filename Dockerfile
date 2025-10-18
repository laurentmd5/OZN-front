# Définition des arguments de construction (ARG)
ARG NGINX_PORT
ARG FLUTTER_VERSION
ARG CONTAINER_USER
ARG CONTAINER_UID
ARG BUILD_VERSION

# ====================================================================
# STAGE 1: Build l'application Flutter
# Utilise l'image Flutter officielle de Docker Hub (ACCES PUBLIC)
# ====================================================================
# CORRECTION: Utilisation de l'image Flutter officielle et publique (pour éviter 'denied' error)
FROM flutter:${FLUTTER_VERSION} as builder

# Définition de l'utilisateur de construction et du répertoire de travail
WORKDIR /home/app

# Copie des fichiers de configuration et de dépendances
COPY pubspec.yaml pubspec.lock ./
COPY pubspec_overrides.yaml ./ || true
COPY .dart_tool/package_config.json .dart_tool/ || true

# Installation des outils nécessaires pour le script de réessai
RUN apt-get update && apt-get install -y --no-install-recommends bash curl && rm -rf /var/lib/apt/lists/*

# Logique de réessai pour flutter pub get (pour gérer les timeouts réseau)
RUN set +e; \
    RETRY_COUNT=0; \
    MAX_RETRIES=3; \
    echo "📦 Installing Flutter dependencies with retry logic..."; \
    until flutter pub get --verbose; do \
        RETRY_COUNT=$((RETRY_COUNT+1)); \
        if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then \
            echo "❌ Failed to get dependencies after $MAX_RETRIES attempts. Check network access to pub.dev."; \
            exit 1; \
        fi; \
        echo "⚠️ pub get failed. Retrying in 10 seconds (Attempt $RETRY_COUNT of $MAX_RETRIES)..."; \
        sleep 10; \
    done; \
    echo "✅ Dependencies installed successfully"; \
    set -e

# Copie du reste du code source
COPY . .

# Construction de l'application Flutter pour le web
# Utilise --dart-define pour injecter la version de build dans l'application
RUN set -eux; \
    echo "🔨 Building Flutter application for Web..."; \
    flutter build web --release \
        --dart-define=APP_BUILD_VERSION=${BUILD_VERSION} \
        --web-renderer html \
        --base-href /; \
    echo "✅ Flutter build completed"

# ====================================================================
# STAGE 2: Production (Image NGINX légère)
# Utilise une image NGINX allégée pour servir les fichiers statiques
# ====================================================================
FROM nginx:alpine as final

# Création d'un groupe et d'un utilisateur non-root pour des raisons de sécurité
RUN set -eux; \
    addgroup -g ${CONTAINER_UID} ${CONTAINER_USER}; \
    adduser -u ${CONTAINER_UID} -G ${CONTAINER_USER} -D ${CONTAINER_USER}; \
    # Créer le répertoire de logs Nginx accessible par l'utilisateur non-root
    mkdir -p /var/cache/nginx/client_temp /var/run /var/log/nginx /tmp; \
    chown -R ${CONTAINER_USER}:${CONTAINER_USER} /var/cache/nginx /var/run /var/log/nginx /tmp; \
    chmod -R 775 /var/cache/nginx /var/run /var/log/nginx /tmp

# Copie de la configuration NGINX
COPY nginx.conf /etc/nginx/nginx.conf

# Copie des artefacts de construction depuis le stage 'builder'
# Les fichiers statiques Flutter sont dans build/web
COPY --from=builder /home/app/build/web /usr/share/nginx/html

# Copie du script de healthcheck
COPY healthcheck.sh /healthcheck.sh
RUN chmod +x /healthcheck.sh

# Configuration de l'utilisateur par défaut et des permissions de travail
USER ${CONTAINER_USER}
WORKDIR /usr/share/nginx/html

# Port exposé et points de montage
EXPOSE ${NGINX_PORT}

# Commande par défaut pour démarrer NGINX
CMD ["nginx", "-g", "daemon off;"]
