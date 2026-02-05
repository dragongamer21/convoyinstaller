#!/bin/bash

# =================================================================
# Convoy Panel - DragonCloud "Bypass" Build Installer
# This version builds the image locally to avoid registry errors.
# =================================================================

set -e

DOMAIN="convoy.dragoncl.qzz.io"

echo -e "\033[0;34m[1/5] Cleaning old attempts and preparing...\033[0m"
rm -rf /var/www/convoy
mkdir -p /var/www/convoy
cd /var/www/convoy

# 1. Download the Source Code directly
echo -e "\033[0;34m[2/5] Downloading Convoy source code...\033[0m"
curl -L https://github.com/convoypanel/panel/archive/refs/heads/develop.tar.gz | tar -xzv --strip-components=1

# 2. Configuration
echo -e "\033[0;34m[3/5] Setting up environment...\033[0m"
cp .env.example .env
sed -i "s|APP_URL=http://localhost|APP_URL=https://$DOMAIN|g" .env
sed -i 's|DB_HOST=127.0.0.1|DB_HOST=mysql|g' .env
sed -i 's|REDIS_HOST=127.0.0.1|REDIS_HOST=redis|g' .env
echo "TRUSTED_PROXIES=*" >> .env

# 3. The "Bypass" Docker Compose (Uses 'build' instead of 'image')
cat <<EOF > docker-compose.yml
services:
  panel:
    build: 
      context: .
      dockerfile: Dockerfile
    restart: always
    ports:
      - "127.0.0.1:8080:80"
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

# 4. Build and Start (This fixes the 'Access Denied' error)
echo -e "\033[0;34m[4/5] Building Convoy locally (This takes 2-5 minutes)...\033[0m"
docker compose up -d --build

echo "Waiting for services to initialize..."
sleep 40

# 5. Final Setup
echo -e "\033[0;34m[5/5] Finalizing Database...\033[0m"
docker compose exec -t panel php artisan key:generate --force
docker compose exec -t panel php artisan migrate --seed --force

echo "----------------------------------------------------"
echo -e "\033[0;32mSUCCESS! NO REGISTRY NEEDED.\033[0m"
echo "----------------------------------------------------"
echo "Convoy built locally and is running on port 8080."
echo "Access: https://$DOMAIN"
echo "----------------------------------------------------"
echo "CREATE ADMIN ACCOUNT:"
echo "docker compose exec -it panel php artisan convoy:user"
echo "----------------------------------------------------"
