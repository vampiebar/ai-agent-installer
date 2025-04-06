#!/bin/bash
set -euo pipefail

#----------------------------------------------------------
# Step 1: Define Variables
#----------------------------------------------------------
WEBAPP_URL="https://raw.githubusercontent.com/cbrx-ai/cbrx-installer/refs/heads/main/cbrx-webapp-develop.zip"
WEBAPP_ZIP="cbrx-webapp-develop.zip"
WEBAPP_DIR="$PWD/cbrx-webapp-develop"

echo "Step 1: Installing Web App from $WEBAPP_URL"

#----------------------------------------------------------
# Step 2: Fix Missing Python Distutils & Required Dependencies
#----------------------------------------------------------
echo "Step 2: Checking for Python distutils..."
PYTHON_VERSION=$(python3 -c "import sys; print('.'.join(map(str, sys.version_info[:2])))" || echo "none")

if ! python3 -c "import distutils.util" 2>/dev/null; then
    echo "Step 2: Python distutils not found. Installing..."
    sudo apt-get update
    sudo apt-get install -y python3-setuptools python3-venv || {
        echo "Error: Failed to install python3-setuptools." >&2
        exit 1
    }
else
    echo "Step 2: Python distutils is already installed."
fi

echo "Step 2: Installing build tools for node-gyp..."
sudo apt-get install -y build-essential cmake python3-dev || {
    echo "Error: Failed to install required build tools." >&2
    exit 1
}

#----------------------------------------------------------
# Step 3: Download & Extract Web App
#----------------------------------------------------------
echo "Step 3: Downloading Web App..."
wget -q "$WEBAPP_URL" -O "$WEBAPP_ZIP" || { echo "Error: Failed to download Web App." >&2; exit 1; }

echo "Step 3: Extracting Web App..."
[ -d "$WEBAPP_DIR" ] && rm -rf "$WEBAPP_DIR"
unzip -q "$WEBAPP_ZIP" -d "$PWD" || { echo "Error: Failed to extract $WEBAPP_ZIP" >&2; exit 1; }
rm -f "$WEBAPP_ZIP"
echo "Step 3: Web App extracted to $WEBAPP_DIR"

#----------------------------------------------------------
# Step 4: Install Node.js & Yarn
#----------------------------------------------------------
echo "Step 4: Checking Node.js..."
if ! command -v node >/dev/null 2>&1; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

echo "Step 4: Checking Yarn..."
if ! command -v yarn >/dev/null 2>&1; then
    npm install -g yarn
fi

#----------------------------------------------------------
# Step 5: Build with Yarn
#----------------------------------------------------------
cd "$WEBAPP_DIR"
yarn global add node-gyp

if [ ! -f yarn.lock ]; then
    echo "Generating yarn.lock..."
    yarn install
fi

if grep -q "node-sass" package.json; then
    echo "Replacing node-sass with sass..."
    yarn remove node-sass && yarn add sass
fi

yarn install

#----------------------------------------------------------
# Step 6: Start with PM2
#----------------------------------------------------------
sudo yarn global add pm2
pm2 delete cbrx-webapp || true
pm2 start yarn --name "cbrx-webapp" -- dev
pm2 save
pm2 startup systemd -u "$USER" --hp "$HOME"

#----------------------------------------------------------
# Step 7: Install & Configure Nginx
#----------------------------------------------------------
echo "Installing Nginx..."
sudo apt-get install -y nginx

DEFAULT_NGINX_CONF="/etc/nginx/sites-available/default"

echo "Configuring default Nginx site..."

sudo tee "$DEFAULT_NGINX_CONF" > /dev/null <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    location / {
        proxy_pass http://127.0.0.1:3000;
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

sudo nginx -t
sudo systemctl reload nginx

#----------------------------------------------------------
# Step 8: Final Message
#----------------------------------------------------------
echo "✅ Web App running on port 3000"
echo "🌐 Access it via http://localhost/"
echo "🔁 API reverse proxy available at http://localhost/cbrx-api/"
echo "🔧 Managed with PM2. Run 'pm2 list' to view."
