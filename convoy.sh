#!/bin/bash

# Convoy + Cloudflare Tunnel One-Click Installer
# Official Helper for DragonCloud Users

set -e

# Configuration - PASTE YOUR TOKEN HERE
echo -n "Enter your Cloudflare Tunnel Token: "
read -r CF_TOKEN

if [ -z "$CF_TOKEN" ]; then
    echo "Error: Token is required."
    exit 1
fi

echo "Starting Installation..."

# 1. Install Docker & Dependencies
apt update && apt install -y curl git
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# 2. Setup Convoy Panel
mkdir -p /var/www/convoy
cd /var/www/convoy
curl -L https://github.com/convoypanel/panel/releases/latest/download/panel.tar.gz | tar -xzv

cp .env.example .env
# Set basic APP_URL (Cloudflare will handle the actual domain)
sed -i 's|APP_URL=http://localhost|APP_URL=https://your-domain.com|g' .env

# Generate Key using Docker
docker run --rm -v $(pwd):/app -w /app php:8.1-cli php artisan key:generate

# 3. Create a combined Docker Compose
# This includes the Panel and the Cloudflare Tunnel connector
cat <<EOF > docker-compose.yml
version: '3.8'
services:
  # Convoy Panel Service
  panel:
    image: convoypanel/panel:latest
    restart: always
    env_file: .env
    # No ports exposed to the public internet! 
    # Cloudflare connects to this internally.

  # Cloudflare Tunnel Connector
  tunnel:
    image: cloudflare/cloudflared:latest
    restart: always
    command: tunnel --no-autoupdate run --token ${CF_TOKEN}
EOF

# 4. Start Everything
docker compose up -d

echo "----------------------------------------------------"
echo "DONE! Convoy is running behind a Cloudflare Tunnel."
echo "FINAL STEP: Go to Cloudflare Dashboard -> Tunnels"
echo "1. Edit your tunnel."
echo "2. Add a Public Hostname (e.g., convoy.yourdomain.com)."
echo "3. Set Service Type to: HTTP"
echo "4. Set URL to: panel:80 (The name of the service in Docker)"
echo "----------------------------------------------------"
