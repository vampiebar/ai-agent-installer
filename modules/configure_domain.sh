#!/bin/bash
set -euo pipefail

# Step 1: Prompt for domain
if ! command -v dialog >/dev/null 2>&1; then
    sudo apt-get install -y dialog
fi

DOMAIN=$(dialog --inputbox "Enter your domain (e.g. icarusdb.com):" 8 60 2>&1 >/dev/tty)
clear

if [[ -z "$DOMAIN" ]]; then
    echo "❌ No domain entered. Exiting."
    exit 1
fi

echo "🌐 Domain entered: $DOMAIN"

# Step 2: DNS check
RESOLVED_IP=$(dig +short "$DOMAIN" | tail -n1)
PUBLIC_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip)

if [[ -z "$RESOLVED_IP" ]]; then
    echo "❌ DNS lookup failed. $DOMAIN does not resolve."
    exit 1
fi

if [[ "$RESOLVED_IP" != "$PUBLIC_IP" ]]; then
    echo "⚠️ WARNING: Domain resolves to $RESOLVED_IP but server IP is $PUBLIC_IP"
    dialog --yesno "DNS mismatch detected. Proceed anyway?" 8 50 || exit 1
fi

# Step 3: Open firewall
echo "🔓 Opening firewall for ports 80 and 443..."
if command -v ufw >/dev/null 2>&1; then
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw reload
elif command -v firewall-cmd >/dev/null 2>&1; then
    sudo firewall-cmd --add-port=80/tcp --permanent
    sudo firewall-cmd --add-port=443/tcp --permanent
    sudo firewall-cmd --reload
else
    echo "⚠️ No firewall tool found. Ensure ports 80 and 443 are open."
fi

# Step 4: Install Nginx and temporary config
echo "🔧 Setting up temporary Nginx config for Certbot..."
sudo apt-get install -y nginx

NGINX_CONF="/etc/nginx/sites-available/default"
sudo tee "$NGINX_CONF" > /dev/null <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name $DOMAIN;

    location / {
        return 200 "Temporary site for SSL setup\n";
        add_header Content-Type text/plain;
    }
}
EOF

sudo nginx -t && sudo systemctl reload nginx

# Step 5: Install certbot and request cert
if ! command -v certbot >/dev/null 2>&1; then
    sudo apt-get install -y certbot python3-certbot-nginx
fi

echo "🔐 Requesting Let's Encrypt certificate for $DOMAIN..."
if ! sudo certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "admin@$DOMAIN"; then
    echo "❌ Certbot failed. Check DNS and ensure port 80 is accessible."
    exit 1
fi

# Step 6: Update Nginx config to proxy to Vite port 5173 with escaped variables
echo "🔁 Updating Nginx config to proxy to Vite (port 5173)..."
sudo tee "$NGINX_CONF" > /dev/null <<EOF
server {
    listen 80;
    listen [::]:80;
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:5173;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }

    location /cbrx-api/ {
        proxy_pass http://localhost:8080/cbrx-api/;
        
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_connect_timeout 60s;
        proxy_read_timeout 60s;
        proxy_send_timeout 60s;
    }
}
EOF

sudo nginx -t && sudo systemctl reload nginx

# Step 7: Update frontend ws_global_url
STORES_JS="./cbrx-webapp-develop/src/lib/stores.js"
if [ -f "$STORES_JS" ]; then
    echo "🔁 Updating ws_global_url in stores.js"
    sed -i "s|writable('https://.*')|writable('https://$DOMAIN/cbrx-api/v1/ws/')|g" "$STORES_JS"
else
    echo "⚠️ $STORES_JS not found. Skipping ws_global_url update."
fi

# Step 8: Write Vite config with correct HMR domain
VITE_CONFIG="./cbrx-webapp-develop/vite.config.js"
if [ -f "$VITE_CONFIG" ]; then
    echo "🔧 Writing vite.config.js with domain-specific HMR settings..."
    cat > "$VITE_CONFIG" <<EOF
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
    plugins: [sveltekit()],
    server: {
        host: '0.0.0.0',
        port: 5173,
        strictPort: true,
        hmr: {
            clientPort: 443,
            protocol: 'wss',
            host: '$DOMAIN'
        }
    },
    ssr: {
        noExternal: ['@popperjs/core']
    }
});
EOF
else
    echo "❌ vite.config.js not found. Skipping."
    exit 1
fi

# Step 9: Ensure PM2 is installed and start Vite
if ! command -v pm2 >/dev/null 2>&1; then
    sudo yarn global add pm2
fi

cd ./cbrx-webapp-develop
pm2 delete cbrx-webapp || true
pm2 start yarn --name "cbrx-webapp" -- dev
pm2 save
pm2 startup systemd -u "$USER" --hp "$HOME"

echo "✅ Domain $DOMAIN is now SSL-secured and Vite is proxied via Nginx."
