#!/bin/bash

# =================================================================
# Convoy Panel - Final "Production-Ready" Installer
# Designed for DragonCloud Official Setup
# =================================================================

set -e

DOMAIN="convoy.dragoncl.qzz.io"

echo -e "\033[0;34m[1/4] Preparing environment for $DOMAIN...\033[0m"

# 1. Setup Directory
mkdir -p /var/www/convoy
cd /var/www/convoy

# 2. Download the PRODUCTION build (This contains the vendor folder)
echo -e "\033[0;34m[2/4] Downloading production files...\033[0m"
curl -L https://github.com/convoypanel/panel/releases/latest/download/panel.tar.gz | tar -xzv

# 3. Environment Config
echo -e "\033[0;34m[3/4] Configuring .env...\033[0m"
cp .env.example .env
sed -i "s|APP_URL=http://localhost|APP_URL=https://$DOMAIN|g" .env
sed -i 's|DB_HOST=127.0.0.1|DB_HOST=mysql|g' .env
sed -i 's|REDIS_HOST=127.0.0.1|REDIS_HOST=redis|g' .env
echo "TRUSTED_PROXIES=*" >> .env

# 4. Create Docker Compose with a Generic PHP Image
# This avoids the "Access Denied" error because we use standard official images
echo -e "\033[0;34m[4/4] Creating services...\033[0m"
cat <<EOF > docker-compose.yml
services:
  panel:
    image: bitnami/laravel:latest
    restart: always
    ports:
      - "127.0.0.1:8080:8000"
    volumes:
      - ./:/app
    env_file: .env
    depends_on:
      - mysql
      - redis

  mysql:
    image: mysql:8.0
    restart: always
    environment:
      - MYSQL_DATABASE=convoy
      - MYSQL_ALLOW_EMPTY_PASSWORD=yes
    volumes:
      - convoy-db:/var/lib/mysql

  redis:
    image: redis:alpine
    restart: always

volumes:
  convoy-db:
EOF

# 5. Start and Initialize
docker compose up -d

echo "Waiting 45 seconds for systems to sync..."
sleep 45

# Initialize App using the bitnami/laravel environment
docker compose exec -t panel php artisan key:generate --force
docker compose exec -t panel php artisan migrate --seed --force

echo "----------------------------------------------------"
echo -e "\033[0;32mSUCCESS! Convoy is running.\033[0m"
echo "----------------------------------------------------"
echo "Point your Tunnel ($DOMAIN) to http://localhost:8080"
echo "----------------------------------------------------"
echo "CREATE ADMIN ACCOUNT:"
echo "docker compose exec -it panel php artisan convoy:user"
echo "----------------------------------------------------"
