#!/bin/bash
set -euo pipefail

# Determine the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

REPO_URL="https://github.com/vampiebar/ai-agent-gw-2.git"
TARGET_DIR="$BASE_DIR/ai-agent-gw-2"

echo "🔧 Installing Drogon Framework (latest)..."
sudo apt update
sudo apt install -y git cmake g++ libjsoncpp-dev libssl-dev zlib1g-dev uuid-dev \
    libsqlite3-dev libmariadb-dev libpq-dev libhiredis-dev libcurl4-openssl-dev

echo "📦 Preparing to clone Drogon from GitHub..."

if [ -d "drogon" ]; then
    echo "⚠️  Existing drogon directory found. Removing it..."
    rm -rf drogon
fi

git clone --recurse-submodules https://github.com/drogonframework/drogon.git
cd drogon
mkdir -p build && cd build
cmake ..
make -j$(nproc)
sudo make install
cd "$BASE_DIR"
rm -rf drogon

echo "✅ Drogon installation complete."

echo "📁 Cloning AI Agent GW into $TARGET_DIR..."

if [ -d "$TARGET_DIR" ]; then
    echo "Directory already exists: $TARGET_DIR"
    echo "Pulling latest changes from develop branch..."
    git -C "$TARGET_DIR" checkout develop
    git -C "$TARGET_DIR" pull origin develop
else
    git clone --branch develop "$REPO_URL" "$TARGET_DIR"
fi

echo "✅ AI Agent GW cloned into $TARGET_DIR"

echo "🛠 Building AI Agent GW..."
cd "$TARGET_DIR"
cmake -S . -B build
cmake --build build -j$(nproc)
echo "✅ Build completed successfully."

echo "🎬 Launching AI Agent GW via screen..."

# Ensure 'screen' is installed
if ! command -v screen &>/dev/null; then
    echo "Installing 'screen' utility..."
    sudo apt install -y screen
fi

# Start app in screen session
screen -dmS "P123_AI_WS" ./build/ollama_drogon

echo "✅ AI Agent GW is now running in screen session: P123_AI_WS"
echo "👉 To attach: screen -r P123_AI_WS"
