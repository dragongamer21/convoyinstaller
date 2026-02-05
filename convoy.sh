#!/bin/bash

# =================================================================
# Convoy Panel - DragonCloud Clean Wipe & Fresh Install
# Target: https://convoy.dragoncl.qzz.io
# =================================================================

set -e
DOMAIN="convoy.dragoncl.qzz.io"

# --- Function for Loading Spinner ---
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

echo -e "\033[1;33m[1/6] WIPING OLD FILES...\033[0m"
docker compose -f /var/www/convoy/docker-compose.yml down --volumes --remove-orphans &>/dev/null || true
rm -rf /var/www/convoy
mkdir -p /var/www/convoy
cd /var/www/convoy

echo -e "\033[1;33m[2/6] DOWNLOADING FRESH SOURCE...\033[0m"
curl -L https://github.com/convoypanel/panel/releases/latest/download/panel.tar.gz | tar -xzv &
spinner $!

echo -e "\033[1;33m[3/6] GENERATING CONFIGURATION...\033[0m"
cp .env.example .env
sed -i "s|APP_URL=http://localhost|APP_URL=https://$DOMAIN|g" .env
sed -i 's|DB_HOST=127.0.0.1|DB_HOST=mysql|g' .env
sed -i 's|REDIS_HOST=127.0.0.1|REDIS_HOST=redis|g' .env
echo "TRUSTED_PROXIES=*" >> .env

echo -e "\033[1;33m[4/6] BUILDING SERVICES...\033[0m"
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
      - convoy-db:/var/lib/mysql
  redis:
    image: redis:alpine
    restart: always
volumes:
  convoy-db:
EOF

docker compose up -d &
spinner $!

echo -e "\033[1;33m[5/6] INITIALIZING DATABASE (Please wait)...\033[0m"
# Wait for MySQL to be ready for connections
until docker compose exec mysql mysqladmin ping -h "localhost" --silent; do
    printf "."
    sleep 2
done

docker compose exec -t panel php artisan key:generate --force
docker compose exec -t panel php artisan migrate --seed --force &
spinner $!

echo -e "\033[1;33m[6/6] VERIFYING CONNECTIVITY...\033[0m"
sleep 5
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080)

if [ "$HTTP_STATUS" -eq 200 ] || [ "$HTTP_STATUS" -eq 302 ]; then
    echo -e "\033[1;32m[✔] CONVOY IS ONLINE ON PORT 8080!\033[0m"
else
    echo -e "\033[1;31m[✘] CONVOY IS RUNNING BUT PORT 8080 IS NOT RESPONDING (Status: $HTTP_STATUS)\033[0m"
fi

echo "----------------------------------------------------"
echo -e "\033[1;36mDRAGONCLOUD INSTALLATION COMPLETE\033[0m"
echo "----------------------------------------------------"
echo "Point Cloudflare Tunnel to: http://localhost:8080"
echo "URL: https://$DOMAIN"
echo "----------------------------------------------------"
echo "NOW CREATE YOUR ADMIN USER:"
echo "docker compose exec -it panel php artisan convoy:user"
