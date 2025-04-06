#!/bin/bash
set -e

SERVICE_FILE="p123-ai-ws.service"
TARGET_PATH="/etc/systemd/system/$SERVICE_FILE"

echo "🛠 Installing systemd service for P123 AI WS..."

cp "$(dirname "$0")/$SERVICE_FILE" "$TARGET_PATH"
chmod 644 "$TARGET_PATH"

echo "🔄 Reloading systemd..."
systemctl daemon-reexec
systemctl daemon-reload

echo "✅ Enabling and starting p123-ai-ws service..."
systemctl enable p123-ai-ws
systemctl start p123-ai-ws

echo "✅ Service is active. Use 'screen -r P123_AI_WS' to attach."
