# Dockerfile optimisé pour Flutter Web avec sécurité renforcée et port 8090
FROM nginx:1.24-alpine

# Métadonnées
LABEL maintainer="devops-team"
LABEL description="OZN Flutter Web Application"
LABEL version="1.0.0"

# Variables d'environnement avec port 8090
ARG NGINX_PORT=8090
ENV NGINX_PORT=${NGINX_PORT}
ENV APP_USER=oznapp
ENV APP_GROUP=oznapp
ENV APP_UID=1001
ENV APP_GID=1001

# Installation des outils de sécurité (tzdata sans version fixe)
RUN apk add --no-cache \
    curl \
    tzdata \
    && rm -rf /var/cache/apk/*

# Création de l'utilisateur non-root
RUN addgroup -g ${APP_GID} -S ${APP_GROUP} && \
    adduser -S -D -H -u ${APP_UID} -G ${APP_GROUP} -s /sbin/nologin ${APP_USER}

# Configuration Nginx sécurisé
COPY <<EOF /etc/nginx/nginx.conf
user oznapp oznapp;
worker_processes auto;
error_log /dev/stderr warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';
    
    access_log /dev/stdout main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 1M;

    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;

    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/xml+rss
        application/json;

    server {
        listen ${NGINX_PORT} default_server;
        listen [::]:${NGINX_PORT} default_server;
        server_name _;

        server_tokens off;
        root /usr/share/nginx/html;
        index index.html index.htm;

        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
            add_header Vary "Accept-Encoding";
        }

        location ~* \.html$ {
            expires -1;
            add_header Cache-Control "no-store, no-cache, must-revalidate";
        }

        location / {
            try_files \$uri \$uri/ /index.html;
            add_header Cache-Control "no-store, no-cache, must-revalidate";
        }

        location ~ /\. { deny all; access_log off; log_not_found off; }
        location ~* (\.env|\.git|\.htaccess|\.htpasswd|Dockerfile|docker-compose\.yml)$ {
            deny all;
            access_log off;
            log_not_found off;
        }

        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }

        location /robots.txt {
            return 200 "User-agent: *\nDisallow: /\n";
            add_header Content-Type text/plain;
        }
    }
}
EOF

# Copie du build Flutter Web
COPY --chown=oznapp:oznapp build/web /usr/share/nginx/html

# Permissions
RUN chmod -R 755 /usr/share/nginx/html && \
    chown -R oznapp:oznapp /usr/share/nginx/html && \
    chmod 644 /etc/nginx/nginx.conf

USER oznapp
EXPOSE ${NGINX_PORT}

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:${NGINX_PORT}/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
