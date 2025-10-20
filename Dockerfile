# --------------------------------------------------------------------
# Arguments de build
# --------------------------------------------------------------------
ARG NGINX_PORT=8090
ARG FLUTTER_VERSION=3.35.6
ARG CONTAINER_USER=oznapp
ARG CONTAINER_UID=1001
ARG BUILD_VERSION=1.0.0

# ====================================================================
# STAGE 1: Build l'application Flutter
# ====================================================================
FROM instrumentisto/flutter:${FLUTTER_VERSION} as builder

ARG BUILD_VERSION
WORKDIR /app

# Copier les fichiers de configuration et dépendances
COPY pubspec.yaml pubspec.lock ./

# Installer outils nécessaires
RUN apt-get update && apt-get install -y --no-install-recommends bash curl && rm -rf /var/lib/apt/lists/*

# Installer les dépendances Flutter
RUN echo "📦 Installing Flutter dependencies..." && flutter pub get --verbose

# Copier le code source
COPY . .

# Build Flutter Web
RUN set -eux; \
    echo "🔨 Building Flutter application for Web..."; \
    flutter build web --release \
        --dart-define=APP_BUILD_VERSION="${BUILD_VERSION}" \
        --base-href /; \
    echo "✅ Flutter build completed"

# ====================================================================
# STAGE 2: Production NGINX
# ====================================================================
FROM nginx:alpine

ARG NGINX_PORT
ARG CONTAINER_USER
ARG CONTAINER_UID

# Installer curl pour les healthchecks
RUN apk add --no-cache curl

# Créer utilisateur non-root et répertoires nécessaires
RUN set -eux; \
    addgroup -g ${CONTAINER_UID} ${CONTAINER_USER}; \
    adduser -u ${CONTAINER_UID} -G ${CONTAINER_USER} -D ${CONTAINER_USER}; \
    # Créer répertoires que NGINX doit écrire
    mkdir -p /var/cache/nginx/client_temp /var/log/nginx /tmp; \
    chown -R ${CONTAINER_USER}:${CONTAINER_USER} /var/cache/nginx /var/log/nginx /tmp /usr/share/nginx/html; \
    chmod -R 775 /var/cache/nginx /var/log/nginx /tmp /usr/share/nginx/html

# Copier configuration NGINX
COPY nginx.conf /etc/nginx/nginx.conf

# Remplacer le port dynamique
RUN sed -i "s/\${NGINX_PORT}/${NGINX_PORT}/g" /etc/nginx/nginx.conf

# Copier les fichiers Flutter construits
COPY --from=builder /app/build/web /usr/share/nginx/html

# Permissions utilisateur final
RUN chown -R ${CONTAINER_USER}:${CONTAINER_USER} /usr/share/nginx/html

# Supprimer la directive 'user' dans nginx.conf si présente pour éviter warnings
RUN sed -i '/^user /d' /etc/nginx/nginx.conf

# Créer un script d'entrée personnalisé
RUN echo '#!/bin/sh' > /docker-entrypoint-custom.sh && \
    echo 'set -e' >> /docker-entrypoint-custom.sh && \
    echo 'mkdir -p /var/run/nginx /var/cache/nginx /tmp' >> /docker-entrypoint-custom.sh && \
    echo 'exec nginx -g "daemon off;"' >> /docker-entrypoint-custom.sh && \
    chmod +x /docker-entrypoint-custom.sh && \
    chown ${CONTAINER_USER}:${CONTAINER_USER} /docker-entrypoint-custom.sh

# Passer à l'utilisateur non-root
USER ${CONTAINER_USER}

WORKDIR /usr/share/nginx/html

# Exposer le port NGINX
EXPOSE ${NGINX_PORT}

# Utiliser le script d'entrée personnalisé
ENTRYPOINT ["/docker-entrypoint-custom.sh"]
