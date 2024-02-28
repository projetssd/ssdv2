#!/bin/bash

source ${SETTINGS_SOURCE}/profile.sh
clear 
logo

echo -e "${CRED}---------------------------------------------------------------${CEND}"
echo -e "${CRED}"$(gettext "MISE A JOUR DU SERVEUR AVEC CLOUDFLARE")          "${CEND}"
echo -e "${CRED}---------------------------------------------------------------${CEND}"
echo ""

## suppression traefik
suppression_appli traefik

## Installation cloudflare
cloudflare

## reinstallation traefik
install_traefik

echo -e "${CRED}---------------------------------------------------------------${CEND}"
echo -e "${CRED}"$(gettext "MISE A JOUR DU SERVEUR CLOUDFLARE EFFECTUEE AVEC SUCCES")"${CEND}"
echo -e "${CRED}---------------------------------------------------------------${CEND}"
echo ""
echo -e "\n"$(gettext "Appuyer sur")"${CCYAN} ["$(gettext "ENTREE")"]${CEND}" $(gettext "pour continuer")
read -r

