#!/bin/bash
source ${SETTINGS_SOURCE}/profile.sh
clear 
logo

echo -e "${CRED}----------------------------------------------${CEND}"
echo -e "${CCYAN}"$(gettext "Changement du nom de Domaine")  "${CEND}"
echo -e "${CRED}----------------------------------------------${CEND}"
echo ""

echo -e " ${BWHITE}* Supression Containers docker${NC}"
docker rm -f $(docker ps -aq) >/dev/null 2>&1

echo -e " ${BWHITE}* Supression Traefik${NC}"
rm -rf ${SETTINGS_STORAGE}/docker/traefik >/dev/null 2>&1

echo -e " ${BWHITE}* Nouveau Domaine${NC}"
manage_account_yml cloudflare.login " "
manage_account_yml cloudflare.api " "
echo >&2 -n -e "${BLUE}"$(gettext "Nouveau Domaine :") "${CEND}"
read DOMAINE
manage_account_yml user.domain "${DOMAINE}"

echo -e " ${BWHITE}* Installation Cloudflare${NC}"
cloudflare

echo -e " ${BWHITE}* Installation Traefik${NC}"
install_traefik

echo -e " ${BWHITE}* Réinitialisation des services avec le nouveau domaine${NC}"
relance_tous_services

echo -e "${CRED}------------------------------------------------${CEND}"
echo -e "${CCYAN}"$(gettext "Mise à jour du domaine effectuée")"${CEND}"
echo -e "${CRED}------------------------------------------------${CEND}"
echo ""
echo -e "\n"$(gettext "Appuyer sur")"${CCYAN} ["$(gettext "ENTREE")"]${CEND}" $(gettext "pour continuer")
read -r


