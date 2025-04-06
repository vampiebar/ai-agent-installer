#!/bin/bash
# install_all.sh - Main installer script with a dialog-based checklist

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "This installer must be run as root. Please run with sudo."
    exit 1
fi

# Ensure 'dialog' is installed; if not, install it
if ! command -v dialog &>/dev/null; then
    echo "Dialog utility not found. Installing dialog..."
    apt-get update -y && apt-get install -y dialog sudo \
        || { echo "Error: Failed to install 'dialog' package."; exit 1; }
fi

# Display a dialog checklist with three pre-selected options:
# 1. Install P123 AI GW 
CHOICES=$(dialog --stdout --clear \
    --backtitle "P123 AI Agent Installer" --title "Installation Options" \
    --checklist "Select components to install:" 15 60 5 \
    "AIAGENTGW" "Install P123 AI AGENT GW" ON \
    "AITRASUBS" "Install P123 Training Subsystem" ON \
    "CONFDOMAIN" "Configure Domain" ON \
    )

# If the user cancels the dialog, exit the script
if [ $? -ne 0 ]; then
    echo "Installation canceled by user."
    exit 1
fi

# If no option was selected, exit gracefully
if [[ -z "$CHOICES" ]]; then
    echo "No components selected. Exiting."
    exit 0
fi

# Process selections
if echo "$CHOICES" | grep -qw "AIAGENTGW"; then
    echo "Install P123 AI AGENT GW..."
    bash modules/install_ai_agent_gw.sh
    if [ $? -eq 0 ]; then
        echo "P123 AI AGENT GW installation completed successfully."
    else
        echo "Error: P123 AI AGENT GW installation failed. Please check the output above."
        exit 1
    fi
fi

if echo "$CHOICES" | grep -qw "AITRASUBS"; then
    echo "Install P123 AI Training Subsystem..."
    bash modules/install_ai_training_subsystem.sh
    if [ $? -eq 0 ]; then
        echo "P123 AI Training Subsystem installation completed successfully."
    else
        echo "Error: P123 AI Training Subsystem installation failed. Please check the output above."
        exit 1
    fi
fi

if echo "$CHOICES" | grep -qw "CONFDOMAIN"; then
    echo "Configuring domain..."
    bash modules/configure_domain.sh
    if [ $? -eq 0 ]; then
        echo "P123 Domain configuration completed successfully."
    else
        echo "Error: P123 Domain configuration failed. Please check the output above."
        exit 1
    fi
fi


echo "All selected installations have finished."

