# Stage 1: Build Flutter
FROM debian:bullseye-slim as flutter-builder

# Installation des dépendances système
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    git \
    xz-utils \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Installation de Flutter
RUN curl -L https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.19.5-stable.tar.xz -o flutter.tar.xz \
    && tar -xf flutter.tar.xz -C /usr/local \
    && rm flutter.tar.xz

ENV PATH="$PATH:/usr/local/flutter/bin"

# Création d'un utilisateur non-root pour le build
RUN groupadd -r flutter && useradd -r -g flutter flutter
USER flutter
WORKDIR /home/flutter/app

# Copie des fichiers du projet
COPY --chown=flutter:flutter pubspec.yaml pubspec.yaml
COPY --chown=flutter:flutter lib/ lib/
COPY --chown=flutter:flutter assets/ assets/ 2>/dev/null || true

# Résolution des dépendances
RUN flutter pub get

# Build Flutter web en mode release
RUN flutter config --enable-web \
    && flutter build web --release --pwa-strategy none \
    --dart-define=BUILD_ENV=production \
    --dart-define=BUILD_VERSION=1.0.0

# Stage 2: Production image sécurisée
FROM nginx:1.24-alpine

LABEL maintainer="laurentmd5"
LABEL description="OZN Flutter Web Application - Secure Production"
LABEL version="1.0.0"
LABEL security.scan="true"

# Variables d'environnement
ARG NGINX_PORT=8090
ENV NGINX_PORT=${NGINX_PORT}

# Création d'un utilisateur non-root
RUN addgroup -g 1001 -S oznapp && \
    adduser -S -D -H -u 1001 -G oznapp -s /sbin/nologin oznapp

# Mise à jour de sécurité
RUN apk update && apk upgrade --no-cache

# Installation de curl pour health check
RUN apk add --no-cache curl

# Copie de la configuration Nginx sécurisée
COPY nginx.conf /etc/nginx/nginx.conf

# Script de health check sécurisé
RUN echo '#!/bin/sh' > /healthcheck.sh && \
    echo 'timeout 10s curl -f -s http://localhost:${NGINX_PORT}/ > /dev/null' >> /healthcheck.sh && \
    chmod 755 /healthcheck.sh

# Copie des fichiers Flutter depuis le stage builder
COPY --from=flutter-builder --chown=oznapp:oznapp /home/flutter/app/build/web/ /usr/share/nginx/html/

# Sécurisation des permissions
RUN chmod -R 755 /usr/share/nginx/html && \
    chmod 644 /usr/share/nginx/html/*.html 2>/dev/null || true && \
    chmod 644 /usr/share/nginx/html/*.js 2>/dev/null || true && \
    chmod 644 /usr/share/nginx/html/*.css 2>/dev/null || true && \
    chown -R oznapp:oznapp /var/cache/nginx && \
    chown -R oznapp:oznapp /var/run

# Nettoyage des fichiers sensibles
RUN rm -f /docker-entrypoint.d/*.sh && \
    find /usr/share/nginx/html -name "*.map" -delete 2>/dev/null || true

# Exposition du port
EXPOSE ${NGINX_PORT}

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD /healthcheck.sh

# Utilisation de l'utilisateur non-root
USER oznapp

# Commande de démarrage
CMD ["nginx", "-g", "daemon off;"]