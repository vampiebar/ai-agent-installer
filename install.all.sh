#!/bin/bash

DIALOG=${DIALOG=dialog}

function install_drogon() {
    bash "$(dirname "$0")/modules/install_drogon.sh"
}

function run_init() {
    sudo bash "$(dirname "$0")/modules/init.sh"
}

$DIALOG --title "OLLAMA Drogon Installer" --checklist "Select components to install:" 15 50 5 \
1 "Install Drogon Framework" on \
2 "Create user 'vampie' and set up sudo access" on \
2> temp_choices.txt

choices=$(<temp_choices.txt)
rm -f temp_choices.txt

for choice in $choices; do
    case $choice in
        1) install_drogon ;;
        2) run_init ;;
    esac
done

$DIALOG --msgbox "Installation complete!" 10 40
clear
