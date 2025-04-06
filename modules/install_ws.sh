#!/bin/bash
set -euo pipefail

#----------------------------------------------------------
# Step 1: Determine the real user and home directory
#----------------------------------------------------------
if [ "$EUID" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
    REAL_USER="$SUDO_USER"
    REAL_HOME=$(eval echo "~$REAL_USER")
else
    REAL_USER="$(whoami)"
    REAL_HOME="$HOME"
fi

echo "Step 1: Running installation as real user: $REAL_USER (home: $REAL_HOME)"

#----------------------------------------------------------
# Step 2: Define directories and URLs (under REAL_HOME/CBRX)
#----------------------------------------------------------
BASE_DIR="$REAL_HOME/CBRX"
GF_URL="https://download.eclipse.org/ee4j/glassfish/glassfish-7.0.22.zip"
GF_ZIP="$BASE_DIR/glassfish-7.0.22.zip"
GLASSFISH_DIR="$BASE_DIR/glassfish7"

WS_URL="https://raw.githubusercontent.com/cbrx-ai/cbrx-installer/refs/heads/main/cbrx-ws-develop.zip"
WS_ZIP="$BASE_DIR/cbrx-ws-develop.zip"
WS_DIR="$BASE_DIR/cbrx-ws-develop"
WAR_FILE="$WS_DIR/target/cbrx-api.war"

mkdir -p "$BASE_DIR"
echo "Step 2: BASE_DIR set to $BASE_DIR"

sudo apt install -y maven

#----------------------------------------------------------
# Step 3: Check for required utilities (wget, unzip, mvn)
#----------------------------------------------------------
for util in wget unzip mvn; do
    if ! command -v "$util" >/dev/null 2>&1; then
        echo "Error: Required utility '$util' is not installed. Please install it and rerun this script." >&2
        exit 1
    fi
done
echo "Step 3: Required utilities are installed."

#----------------------------------------------------------
# Step 4: Install GlassFish 7.0.22 if not already installed in $GLASSFISH_DIR
#----------------------------------------------------------
if [ ! -d "$GLASSFISH_DIR" ]; then
    echo "Step 4: GlassFish 7.0.22 not found in $GLASSFISH_DIR. Installing GlassFish..."
    wget -q "$GF_URL" -O "$GF_ZIP" || { echo "Error: Failed to download GlassFish from $GF_URL" >&2; exit 1; }
    echo "Step 4: Extracting GlassFish to $BASE_DIR..."
    if ! unzip -q "$GF_ZIP" -d "$BASE_DIR"; then
        echo "Error: Failed to extract GlassFish zip" >&2
        exit 1
    fi

    # Set proper ownership
    echo "Step 4: Changing ownership of $BASE_DIR to $REAL_USER..."
    sudo chmod -R a+rwx /home/cbrx/CBRX/glassfish7
    echo "CHMOD CHOWN FINISHED"
    # Locate the extracted GlassFish directory
    # GF_EXTRACTED=$(find "$BASE_DIR" -maxdepth 1 -type d -iname "glassfish*" | grep -vi "glassfish7" | head -n 1)
    # if [ -z "$GF_EXTRACTED" ]; then
    #    echo "Error: Expected GlassFish directory not found after extraction." >&2
    #    exit 1
    # fi
    # echo "Step 4: Found extracted GlassFish directory: $GF_EXTRACTED"
    # mv "$GF_EXTRACTED" "$GLASSFISH_DIR"
    chown -R "$REAL_USER":"$REAL_USER" "$GLASSFISH_DIR"
    echo "Step 4: GlassFish installed at $GLASSFISH_DIR with owner $REAL_USER."
else
    echo "Step 4: GlassFish is already installed at $GLASSFISH_DIR."
fi

# Set full path to asadmin
ASADMIN="$GLASSFISH_DIR/bin/asadmin"

#----------------------------------------------------------
# Step 5: Create GlassFish service using asadmin create-service
#----------------------------------------------------------
echo "Step 5: Creating GlassFish service using asadmin..."
sudo "$ASADMIN" create-service --name glassfish

echo "Step 5: GlassFish service created successfully."

#----------------------------------------------------------
# Step 6: Start and Enable the GlassFish service
#----------------------------------------------------------
echo "Step 6: Starting and enabling GlassFish service..."
#sudo systemctl start glassfish
#sudo systemctl enable glassfish
sudo  /etc/init.d/GlassFish_domain1 start
echo "Step 6: GlassFish service started and enabled."

#----------------------------------------------------------
# Step 7: Download and extract CBRX Web Service source code
#----------------------------------------------------------
echo "Step 7: Downloading CBRX Web Service source code..."
wget -q "$WS_URL" -O "$WS_ZIP" || { echo "Error: Failed to download $WS_URL" >&2; exit 1; }

echo "Step 7: Extracting web service source to $WS_DIR..."
if [ -d "$WS_DIR" ]; then
    echo "Step 7: Removing existing directory $WS_DIR..."
    rm -rf "$WS_DIR"
fi
if ! unzip -q "$WS_ZIP" -d "$BASE_DIR"; then
    echo "Error: Failed to extract $WS_ZIP" >&2
    exit 1
fi
if [ ! -d "$WS_DIR" ]; then
    WS_EXTRACTED=$(find "$BASE_DIR" -maxdepth 1 -type d -iname "cbrx-ws-develop*" | head -n 1)
    if [ -z "$WS_EXTRACTED" ]; then
        echo "Error: Expected CBRX Web Service directory not found after extraction." >&2
        exit 1
    fi
    mv "$WS_EXTRACTED" "$WS_DIR"
fi
chown -R "$REAL_USER":"$REAL_USER" "$WS_DIR"
echo "Step 7: CBRX Web Service source extracted to $WS_DIR."

#----------------------------------------------------------
# Step 8: Ensure Maven is installed
#----------------------------------------------------------
echo "Step 8: Checking for Maven..."
if ! command -v mvn >/dev/null 2>&1; then
    echo "Step 8: Maven not found, installing..."
    sudo apt-get update && sudo apt-get install -y maven || { echo "Error: Maven installation failed." >&2; exit 1; }
else
    echo "Step 8: Maven is already installed."
fi

#----------------------------------------------------------
# Step 9: Build the application with Maven
#----------------------------------------------------------
echo "Step 9: Building the application with Maven..."
cd "$WS_DIR" || { echo "Error: Directory $WS_DIR not found" >&2; exit 1; }
sudo -u "$REAL_USER" mvn clean install -DskipTests || { echo "Error: Maven build failed." >&2; exit 1; }
if [ ! -f "$WAR_FILE" ]; then
    echo "Error: Build did not produce $WAR_FILE" >&2
    exit 1
fi
echo "Step 9: Build successful. WAR file generated at $WAR_FILE."

#----------------------------------------------------------
# Step 10: Deploy the WAR to GlassFish using asadmin
#----------------------------------------------------------
echo "Step 10: Deploying WAR to GlassFish using $ASADMIN..."
if "$ASADMIN" list-applications | grep -qi "cbrx-api"; then
    sudo -u "$REAL_USER" "$ASADMIN" undeploy cbrx-api || { echo "Error: GlassFish deployment failed." >&2; exit 1; }
else
    echo "Module 'cbrx-api' is not deployed. Skipping undeploy."
fi

sudo -u "$REAL_USER" "$ASADMIN" deploy --force "$WAR_FILE" || { echo "Error: GlassFish deployment failed." >&2; exit 1; }
echo "Step 10: Deployment successful."

echo "=== CBRX Web Service installation and deployment completed successfully. ==="
echo "To check the service status, run: systemctl status glassfish"
echo "To start/stop the service manually, run: systemctl [start|stop] glassfish"
echo "If you want the service to start at boot even when you're not logged in, run: loginctl enable-linger $REAL_USER"

