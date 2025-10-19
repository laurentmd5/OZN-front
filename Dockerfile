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

WORKDIR /app

# Copie des fichiers de configuration et de dépendances
COPY pubspec.yaml pubspec.lock ./

# Installation des outils nécessaires
RUN apt-get update && apt-get install -y --no-install-recommends bash curl && rm -rf /var/lib/apt/lists/*

# Installation SIMPLIFIÉE des dépendances Flutter
RUN echo "📦 Installing Flutter dependencies..." && \
    flutter pub get --verbose

# Copie du reste du code source
COPY . .

# Construction de l'application Flutter pour le web
RUN set -eux; \
    echo "🔨 Building Flutter application for Web..."; \
    flutter build web --release \
        --dart-define=APP_BUILD_VERSION="${BUILD_VERSION}" \
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

# Configuration de l'utilisateur par défaut
USER ${CONTAINER_USER}
WORKDIR /usr/share/nginx/html

# Port exposé
EXPOSE ${NGINX_PORT}

# Commande par défaut pour démarrer NGINX
CMD ["nginx", "-g", "daemon off;"]
