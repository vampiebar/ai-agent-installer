#!/bin/bash

DIALOG=${DIALOG=dialog}

function install_drogon() {
    bash "$(dirname "$0")/modules/install_drogon.sh"
}

$DIALOG --title "OLLAMA Drogon Installer" --checklist "Select components to install:" 15 50 5 \
1 "Install Drogon Framework" on \
2> temp_choices.txt

choices=$(<temp_choices.txt)
rm -f temp_choices.txt

for choice in $choices; do
    case $choice in
        1) install_drogon ;;
    esac
done

$DIALOG --msgbox "Installation complete!" 10 40
clear
