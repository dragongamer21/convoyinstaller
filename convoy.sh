#!/bin/bash

# =================================================================
# Convoy Panel - DragonCloud Final Stable Installer
# Target Domain: convoy.dragoncl.qzz.io
# =================================================================

set -e

DOMAIN="convoy.dragoncl.qzz.io"

echo -e "\033[0;34m[1/5] Preparing environment for $DOMAIN...\033[0m"

# 1. Setup Directory
mkdir -p /var/www/convoy
cd /var/www/convoy

# 2. Download Source
echo -e "\033[0;34m[2/5] Downloading official source...\033[0m"
curl -L https://github.com/convoypanel/panel/releases/latest/download/panel.tar.gz | tar -xzv

# 3. Create .env with specific Cloudflare Fixes
echo -e "\033[0;34m[3/5] Configuring environment variables...\033[0m"
cp .env.example .env
sed -i "s|APP_URL=http://localhost|APP_URL=https://$DOMAIN|g" .env
sed -i 's|DB_HOST=127.0.0.1|DB_HOST=mysql|g' .env
sed -i 's|REDIS_HOST=127.0.0.1|REDIS_HOST=redis|g' .env

# Essential: This fixes "Mixed Content" issues on Cloudflare
echo "TRUSTED_PROXIES=*" >> .env

# 4. Create the Docker Compose
echo -e "\033[0;34m[4/5] Creating Docker orchestration...\033[0m"
cat <<EOF > docker-compose.yml
version: '3.8'
services:
  panel:
    image: convoypanel/panel:latest
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

# 5. Launch and Finalize
echo -e "\033[0;34m[5/5] Launching containers and building database...\033[0m"
docker compose up -d

# Wait for database
echo "Waiting for services to settle (30 seconds)..."
sleep 30

# Initialize App
docker compose exec -it panel php artisan key:generate --force
docker compose exec -it panel php artisan migrate --seed --force

echo "----------------------------------------------------"
echo -e "\033[0;32mSUCCESS! Convoy is now fully installed.\033[0m"
echo "----------------------------------------------------"
echo "Your Tunnel Address: https://$DOMAIN"
echo "Tunnel Destination: http://localhost:8080"
echo "----------------------------------------------------"
echo "RUN THIS COMMAND TO CREATE YOUR ADMIN ACCOUNT:"
echo "docker compose exec -it panel php artisan convoy:user"
echo "----------------------------------------------------"
