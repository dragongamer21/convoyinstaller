#!/bin/bash

# =================================================================
# Convoy + Proxmox "DragonCloud" Transformer
# Target Domain: convoy.dragoncl.qzz.io
# =================================================================

set -e

DOMAIN="convoy.dragoncl.qzz.io"
IP_ADDR=$(hostname -I | awk '{print $1}')

echo -e "\033[0;34m[1/6] Preparing Proxmox Installation...\033[0m"

# 1. Setup Hosts file (Required for Proxmox)
echo "$IP_ADDR $(hostname).dragoncloud.local $(hostname)" >> /etc/hosts

# 2. Add Proxmox Repository
echo "deb [arch=amd64] http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-install-repo.list
curl -fSsL https://enterprise.proxmox.com/proxmox-release-bookworm.gpg > /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg

# 3. Install Proxmox Kernel & Packages
apt update && apt install -y proxmox-ve postfix open-iscsi

echo -e "\033[0;32mProxmox Kernel Installed.\033[0m"

# 4. Setup Convoy Directory
mkdir -p /var/www/convoy
cd /var/www/convoy

# 5. Download and Configure Convoy
echo -e "\033[0;34m[4/6] Setting up Convoy Panel...\033[0m"
curl -L https://github.com/convoypanel/panel/releases/latest/download/panel.tar.gz | tar -xzv

cp .env.example .env
sed -i "s|APP_URL=http://localhost|APP_URL=https://$DOMAIN|g" .env
sed -i 's|DB_HOST=127.0.0.1|DB_HOST=mysql|g' .env
sed -i 's|REDIS_HOST=127.0.0.1|REDIS_HOST=redis|g' .env
echo "TRUSTED_PROXIES=*" >> .env

# 6. Create Docker Services
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
    environment: {MYSQL_DATABASE: convoy, MYSQL_ALLOW_EMPTY_PASSWORD: "yes"}
    volumes: [convoy-db:/var/lib/mysql]
  redis:
    image: redis:alpine
    restart: always
volumes:
  convoy-db:
EOF

docker compose up -d

# 7. Final Initialization
echo "Waiting for services..."
sleep 20
docker compose exec -it panel php artisan key:generate --force
docker compose exec -it panel php artisan migrate --seed --force

echo "----------------------------------------------------"
echo -e "\033[0;32mSYSTEM TRANSFORMATION COMPLETE\033[0m"
echo "----------------------------------------------------"
echo "1. Proxmox is installed. Access it (internally) or via Tunnel."
echo "2. Convoy is ready at https://$DOMAIN"
echo "3. IMPORTANT: You MUST reboot now to load the Proxmox Kernel!"
echo "   Command: 'reboot'"
echo "----------------------------------------------------"
