#!/bin/bash

# Convoy Panel - Dependency Fix & Cloudflare Link
# For DragonCloud Environment

set -e

echo "Starting Convoy Panel Installation with Dependency Fix..."

# 1. Setup Directory
mkdir -p /var/www/convoy
cd /var/www/convoy

# 2. Download Convoy
echo "Downloading files..."
curl -L https://github.com/convoypanel/panel/releases/latest/download/panel.tar.gz | tar -xzv

# 3. FIX: Install Composer Dependencies
# This runs composer inside a container to create the /vendor folder
echo "Installing PHP dependencies (this may take a minute)..."
docker run --rm \
    -v $(pwd):/app \
    -w /app \
    composer install --no-dev --optimize-autoloader

# 4. Environment Config
echo "Configuring .env..."
cp .env.example .env
APP_KEY=$(docker run --rm php:8.1-cli php -r "echo 'base64:'.base64_encode(random_bytes(32));")
sed -i "s|APP_KEY=|APP_KEY=$APP_KEY|g" .env
sed -i 's|DB_HOST=127.0.0.1|DB_HOST=mysql|g' .env

# 5. Create Docker Compose (Targeting localhost:8080 for your Tunnel)
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

# 6. Start & Migrate
echo "Starting containers..."
docker compose up -d

echo "Waiting for MySQL to be ready..."
sleep 20

# Generate keys and migrate
docker compose exec panel php artisan key:generate --force
docker compose exec panel php artisan migrate --seed --force

echo "----------------------------------------------------"
echo "SUCCESS! The 'vendor/autoload.php' error is resolved."
echo "Point your Cloudflare Tunnel to: http://localhost:8080"
echo "----------------------------------------------------"
