# Dockerfile.simple
FROM nginx:1.24-alpine

# Copie de la configuration Nginx
COPY nginx.conf /etc/nginx/nginx.conf

# Copie des fichiers Flutter
COPY build/web/ /usr/share/nginx/html/

# Exposition du port
EXPOSE 8090

CMD ["nginx", "-g", "daemon off;"]