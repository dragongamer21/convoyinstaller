#!/bin/bash

# Convoy Panel - DragonCloud Custom Domain Installer
set -e

# 1. Ask for your domain
echo -e "\033[0;34mEnter the domain you added to Cloudflare (e.g., convoy.yourdomain.com):\033[0m"
read -r USER_DOMAIN

if [ -z "$USER_DOMAIN" ]; then
    echo "Domain is required to continue."
    exit 1
fi

echo "Setting up Convoy for https://$USER_DOMAIN..."

# 2. Setup Directory & Download
mkdir -p /var/www/convoy
cd /var/www/convoy
curl -L https://github.com/convoypanel/panel/releases/latest/download/panel.tar.gz | tar -xzv

# 3. FIX: Install Dependencies with PHP 8.3 Compatibility
echo "Installing PHP dependencies..."
docker run --rm \
    -v $(pwd):/app \
    -w /app \
    composer:2.7-php8.3 install --no-dev --optimize-autoloader --ignore-platform-reqs

# 4. Environment Config with your Domain
cp .env.example .env
sed -i "s|APP_URL=http://localhost|APP_URL=https://$USER_DOMAIN|g" .env
sed -i 's|DB_HOST=127.0.0.1|DB_HOST=mysql|g' .env
# Force HTTPS for Cloudflare
echo "TRUSTED_PROXIES=*" >> .env

# 5. Create Docker Compose
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
echo "Waiting 20 seconds for Database..."
sleep 20

docker compose exec panel php artisan key:generate --force
docker compose exec panel php artisan migrate --seed --force

echo "----------------------------------------------------"
echo -e "\033[0;32mSUCCESS! Convoy is ready.\033[0m"
echo "----------------------------------------------------"
echo "Step 1: Go to Cloudflare Zero Trust -> Tunnels"
echo "Step 2: Edit your existing Tunnel"
echo "Step 3: Add Hostname: $USER_DOMAIN"
echo "Step 4: Service Type: HTTP"
echo "Step 5: URL: localhost:8080"
echo "----------------------------------------------------"
