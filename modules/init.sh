#!/bin/bash

set -e

USERNAME="vampie"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "❌ This script must be run as root."
    exit 1
fi

# Check if user exists
if id "$USERNAME" &>/dev/null; then
    echo "✅ User '$USERNAME' already exists."
else
    echo "👤 Creating user '$USERNAME'..."
    useradd -m -s /bin/bash "$USERNAME"
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME
    chmod 0440 /etc/sudoers.d/$USERNAME
    echo "✅ User '$USERNAME' created and added to sudoers with NOPASSWD."
fi
