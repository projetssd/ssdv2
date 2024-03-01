#!/bin/bash

source ${SETTINGS_SOURCE}/profile.sh
clear 
logo

echo -e "${CRED}----------------------------------------${CEND}"
echo -e "${CCYAN}"$(gettext "Mise en place Cloudflare")"${CEND}"
echo -e "${CRED}----------------------------------------${CEND}"
echo ""

echo -e " ${BWHITE}* Supression Containers docker${NC}"
docker rm -f $(docker ps -aq) >/dev/null 2>&1

echo -e " ${BWHITE}* Installation Cloudflare${NC}"
manage_account_yml cloudflare.login " "
manage_account_yml cloudflare.api " "
cloudflare

echo -e " ${BWHITE}* Installation Traefik${NC}"
install_traefik

echo -e " ${BWHITE}* Réinitialisation des services avec Cloudflare${NC}"
relance_tous_services

echo -e "${CRED}------------------------------------------------${CEND}"
echo -e "${CCYAN}"$(gettext "Mise à jour Cloudflare effectuée")"${CEND}"
echo -e "${CRED}------------------------------------------------${CEND}"
echo ""
echo -e "\n"$(gettext "Appuyer sur")"${CCYAN} ["$(gettext "ENTREE")"]${CEND}" $(gettext "pour continuer")
read -r

