#!/bin/bash
# install_db.sh - Installs PostgreSQL 17 on Ubuntu 24.04 and performs basic setup

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root (use sudo)."
    exit 1
fi

# Check if PostgreSQL 17 is already installed
if dpkg -l | grep -qw "postgresql-17"; then
    echo "PostgreSQL 17 is already installed. Skipping re-installation."
    exit 0
fi

echo "Updating package list..."
apt-get update -y || { echo "Error: 'apt-get update' failed."; exit 1; }

echo "Installing required packages (curl, gnupg2)..."
apt-get install -y curl gnupg2 software-properties-common >/dev/null 2>&1 \
    || { echo "Error: Failed to install prerequisite packages."; exit 1; }

echo "Adding PostgreSQL APT repository for Ubuntu $(lsb_release -cs)..."
sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' \
    || { echo "Error: Could not add the PostgreSQL repository."; exit 1; }

echo "Importing PostgreSQL repository signing key..."
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg \
    || { echo "Error: Failed to import PostgreSQL signing key."; exit 1; }

echo "Updating package list (with PostgreSQL repository)..."
apt-get update -y || { echo "Error: 'apt-get update' failed after adding PostgreSQL repository."; exit 1; }

echo "Installing PostgreSQL 17..."
DEBIAN_FRONTEND=noninteractive apt-get install -y postgresql-17 postgresql-client-17 \
    || { echo "Error: PostgreSQL 17 installation failed."; exit 1; }

echo "Enabling PostgreSQL service to start on boot..."
systemctl enable postgresql || { echo "Error: Failed to enable PostgreSQL service."; exit 1; }

echo "Starting PostgreSQL service..."
systemctl start postgresql || { echo "Error: Failed to start PostgreSQL service."; exit 1; }

# Basic configuration notice (user can manually set postgres password or allow remote access if needed)
echo "PostgreSQL 17 installation is complete."
echo "You can verify by checking the version: \`psql --version\` (should show PostgreSQL 17)."
echo "For security, consider setting a password for the 'postgres' user and editing the configuration to allow remote access if required."


