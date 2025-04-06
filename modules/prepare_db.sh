#!/bin/bash
# prepare_db.sh - Downloads, unzips, and prepares the CBRX database dump.
# This script:
#   1. Downloads the zip file from GitHub.
#   2. Unzips it (ensuring 'unzip' is installed).
#   3. Changes into the 'cbrx-db-develop' directory.
#   4. Checks for the dump file (dump/cbrx_dump.sql).
#   5. Creates a PostgreSQL user 'cbrxuser' (if not exists).
#   6. If a database named 'cbrx1' exists, renames it to a backup name with an epoch timestamp.
#   7. Creates a new database 'cbrx1' owned by 'cbrxuser'.
#   8. Restores the custom-format dump file into the 'cbrx1' database using pg_restore.

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root. Please run with sudo."
    exit 1
fi

# Change to the script's directory (modules/) so relative paths work correctly
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR" || { echo "Error: Unable to change to script directory."; exit 1; }

# Download the zip file containing the database dump
ZIP_URL="https://raw.githubusercontent.com/cbrx-ai/cbrx-installer/refs/heads/main/cbrx-db-develop.zip"
ZIP_FILE="cbrx-db-develop.zip"
echo "Downloading database dump from $ZIP_URL..."
wget -L "$ZIP_URL" -O "$ZIP_FILE" || { echo "Error: Failed to download $ZIP_URL"; exit 1; }

# Ensure 'unzip' is installed; install if necessary
if ! command -v unzip >/dev/null 2>&1; then
    echo "Unzip utility not found. Installing unzip..."
    apt-get update -y && apt-get install -y unzip || { echo "Error: Could not install unzip."; exit 1; }
fi

# Unzip the downloaded file (overwrite any existing files)
echo "Unzipping $ZIP_FILE..."
unzip -o "$ZIP_FILE" || { echo "Error: Failed to unzip $ZIP_FILE"; exit 1; }

# Change into the expected directory created by the unzip
if [ -d "cbrx-db-develop" ]; then
    cd "cbrx-db-develop" || { echo "Error: Unable to change directory to 'cbrx-db-develop'."; exit 1; }
else
    echo "Error: Expected directory 'cbrx-db-develop' not found after unzipping."
    exit 1
fi

# Check if the expected dump file exists (assumed at dump/cbrx_dump.sql)
DUMP_FILE="dump/cbrx_dump.sql"
if [ ! -f "$DUMP_FILE" ]; then
    echo "Error: Dump file $DUMP_FILE not found in 'cbrx-db-develop'."
    exit 1
fi

# Create PostgreSQL user 'cbrxuser' if it does not already exist
echo "Creating PostgreSQL user 'cbrxuser' (if not exists)..."
sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='cbrxuser'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE USER cbrxuser WITH CREATEDB;" \
    || { echo "Error: Failed to create PostgreSQL user 'cbrxuser'."; exit 1; }

# If database 'cbrx1' exists, rename it to include an epoch timestamp as backup
echo "Checking if database 'cbrx1' exists..."
if sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='cbrx1'" | grep -q 1; then
    backup_db="cbrx1_$(date +%s)"
    echo "Database 'cbrx1' exists. Renaming it to '$backup_db' as a backup..."
    sudo -u postgres psql -c "ALTER DATABASE cbrx1 RENAME TO $backup_db;" \
        || { echo "Error: Failed to rename existing database 'cbrx1'."; exit 1; }
fi

# Create new database 'cbrx1' owned by 'cbrxuser'
echo "Creating new database 'cbrx1' owned by 'cbrxuser'..."
sudo -u postgres psql -c "CREATE DATABASE cbrx1 OWNER cbrxuser;" \
    || { echo "Error: Failed to create new database 'cbrx1'."; exit 1; }

# Restore the custom-format dump into the 'cbrx1' database using pg_restore
echo "Restoring custom-format dump file into database 'cbrx1' using pg_restore..."
sudo -u postgres pg_restore -d cbrx1 "$DUMP_FILE" \
    || { echo "Error: Failed to restore dump file into database 'cbrx1'."; exit 1; }

echo "Database preparation complete."

