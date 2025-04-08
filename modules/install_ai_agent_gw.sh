#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

REPO_URL="https://github.com/vampiebar/ai-agent-gw-2.git"
TARGET_DIR="$BASE_DIR/ai-agent-gw-2"

echo "🔧 Installing Drogon Framework (latest)..."
sudo apt update
sudo apt install -y git cmake g++ libjsoncpp-dev libssl-dev zlib1g-dev uuid-dev \
    libsqlite3-dev libmariadb-dev libpq-dev libhiredis-dev libcurl4-openssl-dev screen

echo "📦 Installing Ollama..."
bash "$SCRIPT_DIR/install_ollama_latest.sh"

echo "📦 Preparing to clone Drogon from GitHub..."
rm -rf drogon
git clone --recurse-submodules https://github.com/drogonframework/drogon.git
cd drogon && mkdir -p build && cd build
cmake ..
make -j$(nproc)
sudo make install
cd "$BASE_DIR"
rm -rf drogon

echo "✅ Drogon installation complete."

echo "📁 Cloning AI Agent GW into $TARGET_DIR..."
if [ -d "$TARGET_DIR" ]; then
    echo "Directory exists. Updating..."
    git -C "$TARGET_DIR" checkout develop
    git -C "$TARGET_DIR" pull origin develop
else
    git clone --branch develop "$REPO_URL" "$TARGET_DIR"
fi

echo "🛠 Building AI Agent GW..."
cd "$TARGET_DIR"
cmake -S . -B build
cmake --build build -j$(nproc)
echo "✅ Build completed."

echo "🎬 Starting AI Agent GW in screen session..."
screen -dmS "P123_AI_WS" ./build/ollama_drogon

# Safe systemd check
if pidof systemd &> /dev/null; then
    echo "🛠 Installing systemd service..."
    SERVICE_FILE="p123-ai-ws.service"
    TARGET_PATH="/etc/systemd/system/$SERVICE_FILE"
    sudo cp "$SCRIPT_DIR/$SERVICE_FILE" "$TARGET_PATH"
    sudo chmod 644 "$TARGET_PATH"
    sudo systemctl daemon-reexec
    sudo systemctl daemon-reload
    sudo systemctl enable p123-ai-ws
    sudo systemctl start p123-ai-ws
    echo "✅ systemd service 'p123-ai-ws' installed and running"
else
    echo "⚠️ Skipping systemd install: systemd is not the init system."
fi

echo "👉 Attach with: screen -r P123_AI_WS"
