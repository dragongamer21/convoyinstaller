#!/bin/bash

# =================================================================
# Convoy Panel - TOTAL WIPE & REINSTALL
# Target: https://convoy.dragoncl.qzz.io
# =================================================================

set -e
DOMAIN="convoy.dragoncl.qzz.io"

echo -e "\033[1;31m[1/6] DESTRUCTIVE WIPE: REMOVING ALL PREVIOUS DATA...\033[0m"
# Stop and delete everything related to previous runs
docker compose -f /var/www/convoy/docker-compose.yml down -v --remove-orphans &>/dev/null || true
rm -rf /var/www/convoy

# Create fresh directory
mkdir -p /var/www/convoy
cd /var/www/convoy

echo -e "\033[1;33m[2/6] DOWNLOADING CLEAN PRODUCTION SOURCE...\033[0m"
curl -L https://github.com/convoypanel/panel/releases/latest/download/panel.tar.gz | tar -xzv

echo -e "\033[1;33m[3/6] WRITING CLEAN CONFIGURATION...\033[0m"
cp .env.example .env
sed -i "s|APP_URL=http://localhost|APP_URL=https://$DOMAIN|g" .env
sed -i 's|DB_HOST=127.0.0.1|DB_HOST=mysql|g' .env
sed -i 's|REDIS_HOST=127.0.0.1|REDIS_HOST=redis|g' .env
echo "TRUSTED_PROXIES=*" >> .env
# Fix folder permissions immediately
chmod -R 775 storage bootstrap/cache

echo -e "\033[1;33m[4/6] STARTING ISOLATED SERVICES...\033[0m"
cat <<EOF > docker-compose.yml
services:
  panel:
    image: php:8.2-apache
    restart: always
    ports:
      - "127.0.0.1:8080:80"
    volumes:
      - ./:/var/www/html
    env_file: .env
    depends_on:
      - mysql
    command: >
      sh -c "sed -i 's|/var/www/html|/var/www/html/public|g' /etc/apache2/sites-available/000-default.conf && 
             a2enmod rewrite && 
             docker-php-ext-install pdo_mysql &&
             apache2-foreground"
  mysql:
    image: mysql:8.0
    restart: always
    environment:
      - MYSQL_DATABASE=convoy
      - MYSQL_ALLOW_EMPTY_PASSWORD=yes
    volumes:
      - convoy-db-fresh:/var/lib/mysql
  redis:
    image: redis:alpine
    restart: always
volumes:
  convoy-db-fresh:
EOF

docker compose up -d

echo -e "\033[1;33m[5/6] WAITING FOR DATABASE INITIALIZATION...\033[0m"
# Wait until MySQL is ready
until docker compose exec mysql mysqladmin ping -h "localhost" --silent; do
    echo "MySQL is starting... (this takes ~20-30 seconds)"
    sleep 5
done

echo -e "\033[1;33m[6/6] FINALIZING APP & MIGRATIONS...\033[0m"
docker compose exec -t panel php artisan key:generate --force
docker compose exec -t panel php artisan migrate --seed --force

echo "----------------------------------------------------"
echo -e "\033[1;32m[✔] INSTALLATION SUCCESSFUL!\033[0m"
echo "----------------------------------------------------"
echo -e "URL: \033[1;36mhttps://$DOMAIN\033[0m"
echo -e "Local Port: \033[1;36m8080\033[0m"
echo "----------------------------------------------------"
echo "FINAL STEP: CREATE YOUR ADMIN LOGIN"
echo "Run: docker compose exec -it panel php artisan convoy:user"
