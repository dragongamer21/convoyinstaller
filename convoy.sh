#!/bin/bash

# =================================================================
# Convoy Panel - DragonCloud Final Fix (GHCR Version)
# Target Domain: convoy.dragoncl.qzz.io
# =================================================================

set -e

DOMAIN="convoy.dragoncl.qzz.io"

echo -e "\033[0;34m[1/4] Preparing environment for $DOMAIN...\033[0m"

# 1. Setup Directory
mkdir -p /var/www/convoy
cd /var/www/convoy

# 2. Download Source files
echo -e "\033[0;34m[2/4] Downloading source files...\033[0m"
curl -L https://github.com/convoypanel/panel/releases/latest/download/panel.tar.gz | tar -xzv

# 3. Environment Config
echo -e "\033[0;34m[3/4] Configuring .env for $DOMAIN...\033[0m"
cp .env.example .env
sed -i "s|APP_URL=http://localhost|APP_URL=https://$DOMAIN|g" .env
sed -i 's|DB_HOST=127.0.0.1|DB_HOST=mysql|g' .env
sed -i 's|REDIS_HOST=127.0.0.1|REDIS_HOST=redis|g' .env
echo "TRUSTED_PROXIES=*" >> .env

# 4. Create Docker Services (Using GHCR Image)
echo -e "\033[0;34m[4/4] Creating Docker services...\033[0m"
cat <<EOF > docker-compose.yml
services:
  panel:
    image: ghcr.io/convoypanel/panel:latest
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

# 5. Start and Initialize
# We pull specifically from GHCR to avoid Docker Hub 403 errors
docker compose pull
docker compose up -d

echo "Waiting 30 seconds for database to wake up..."
sleep 30

# Initialize App
docker compose exec -it panel php artisan key:generate --force
docker compose exec -it panel php artisan migrate --seed --force

echo "----------------------------------------------------"
echo -e "\033[0;32mSUCCESS! Convoy is running on port 8080.\033[0m"
echo "----------------------------------------------------"
echo "Cloudflare Status: Your tunnel is already linked!"
echo "Just ensure your tunnel points $DOMAIN to http://localhost:8080"
echo "----------------------------------------------------"
echo "SET UP YOUR LOGIN NOW:"
echo "docker compose exec -it panel php artisan convoy:user"
echo "----------------------------------------------------"
