#!/bin/bash

# Convoy Panel - Specialized for convoy.dragoncl.qzz.io
set -e

DOMAIN="convoy.dragoncl.qzz.io"

echo -e "\033[0;34mPreparing Convoy Panel for $DOMAIN...\033[0m"

# 1. Setup Directory & Clean previous attempts
mkdir -p /var/www/convoy
cd /var/www/convoy

# 2. Download Convoy
echo "Downloading Panel files..."
curl -L https://github.com/convoypanel/panel/releases/latest/download/panel.tar.gz | tar -xzv

# 3. FIX: Install Dependencies with PHP 8.3 Compatibility
# This solves the vendor/autoload.php error
echo "Installing PHP dependencies (PHP 8.3 mode)..."
docker run --rm \
    -v $(pwd):/app \
    -w /app \
    composer:2.7-php8.3 install --no-dev --optimize-autoloader --ignore-platform-reqs

# 4. Environment Config (Configured for your specific Cloudflare domain)
cp .env.example .env
sed -i "s|APP_URL=http://localhost|APP_URL=https://$DOMAIN|g" .env
sed -i 's|DB_HOST=127.0.0.1|DB_HOST=mysql|g' .env

# Essential for Cloudflare: Tells Laravel to trust the tunnel proxy for HTTPS
echo "TRUSTED_PROXIES=*" >> .env

# 5. Create Docker Compose (Internal port 8080)
cat <<EOF > docker-compose.yml
version: '3.8'
services:
  panel:
    image: convoypanel/panel:latest
    restart: always
    ports:
      - "127.0.0.1:8080:80"
    volumes:
      - ./:/app
    env_file: .env
    depends_on:
      - mysql

  mysql:
    image: mysql:8.0
    restart: always
    environment:
      - MYSQL_DATABASE=convoy
      - MYSQL_ALLOW_EMPTY_PASSWORD=yes
    volumes:
      - ./data/mysql:/var/lib/mysql

  redis:
    image: redis:alpine
    restart: always
EOF

# 6. Start & Initialize
docker compose up -d
echo "Waiting 20 seconds for database to initialize..."
sleep 20

# Final Laravel Commands
docker compose exec panel php artisan key:generate --force
docker compose exec panel php artisan migrate --seed --force

echo "----------------------------------------------------"
echo -e "\033[0;32mDONE! Convoy is running internally on port 8080.\033[0m"
echo "----------------------------------------------------"
echo "Since your Tunnel is already active:"
echo "1. Go to your Cloudflare Tunnel settings for this VPS."
echo "2. Add/Update Public Hostname: $DOMAIN"
echo "3. Set Service: HTTP // URL: localhost:8080"
echo "----------------------------------------------------"
echo "The panel should now be live at https://$DOMAIN"
