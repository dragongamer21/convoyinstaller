#!/bin/bash

# =================================================================
# Convoy Panel - Cloudflare Tunnel Automated Installer
# Optimized for DragonCloud Official Chatbot Use
# =================================================================

set -e

# Setup Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}Starting Convoy Panel Installation with Cloudflare Tunnel...${NC}"

# 1. Ask for Cloudflare Token
echo -e "${YELLOW}Please enter your Cloudflare Tunnel Token:${NC}"
read -r CF_TOKEN

if [ -z "$CF_TOKEN" ]; then
    echo -e "${YELLOW}No token provided. Script aborted.${NC}"
    exit 1
fi

# 2. Update System & Install Docker
echo -e "${GREEN}Installing Docker and system dependencies...${NC}"
apt update && apt install -y curl git tar sed
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
fi

# 3. Download and Extract Convoy Panel
echo -e "${GREEN}Downloading Convoy Panel source...${NC}"
mkdir -p /var/www/convoy
cd /var/www/convoy
curl -L https://github.com/convoypanel/panel/releases/latest/download/panel.tar.gz | tar -xzv

# 4. Environment Configuration
echo -e "${GREEN}Configuring environment...${NC}"
cp .env.example .env

# Generate a secure APP_KEY inside a temporary container
APP_KEY=$(docker run --rm php:8.1-cli php -r "echo 'base64:'.base64_encode(random_bytes(32));")
sed -i "s|APP_KEY=|APP_KEY=$APP_KEY|g" .env
sed -i 's|DB_HOST=127.0.0.1|DB_HOST=mysql|g' .env

# 5. Create integrated Docker Compose
# This connects the Panel and the Cloudflare Tunnel in one network
echo -e "${GREEN}Creating Docker orchestration...${NC}"
cat <<EOF > docker-compose.yml
version: '3.8'
services:
  # Convoy Web Panel
  panel:
    image: convoypanel/panel:latest
    restart: always
    environment:
      - APP_ENV=production
      - APP_DEBUG=false
    env_file: .env
    depends_on:
      - mysql
      - redis

  # MySQL Database
  mysql:
    image: mysql:8.0
    restart: always
    environment:
      - MYSQL_DATABASE=convoy
      - MYSQL_ALLOW_EMPTY_PASSWORD=yes
    volumes:
      - ./data/mysql:/var/lib/mysql

  # Redis Cache
  redis:
    image: redis:alpine
    restart: always

  # Cloudflare Tunnel Connector
  tunnel:
    image: cloudflare/cloudflared:latest
    restart: always
    command: tunnel --no-autoupdate run --token ${CF_TOKEN}
EOF

# 6. Start Containers
echo -e "${GREEN}Launching services...${NC}"
docker compose up -d

# 7. Final Database Setup
echo -e "${GREEN}Running final migrations...${NC}"
sleep 10 # Give MySQL time to wake up
docker compose exec panel php artisan migrate --seed --force

echo -e "----------------------------------------------------"
echo -e "${GREEN}INSTALLATION SUCCESSFUL!${NC}"
echo -e "----------------------------------------------------"
echo -e "1. Go to Cloudflare Zero Trust Dashboard."
echo -e "2. Navigate to your Tunnel -> Public Hostname."
echo -e "3. Add a hostname (e.g. panel.yourdomain.com)."
echo -e "4. Service Type: ${BLUE}HTTP${NC}"
echo -e "5. URL: ${BLUE}panel:80${NC}"
echo -e "----------------------------------------------------"
