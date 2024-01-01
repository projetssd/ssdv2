#!/bin/bash


source ${SETTINGS_SOURCE}/includes/functions.sh
source ${SETTINGS_SOURCE}/includes/variables.sh

## Variable
ansible-playbook ${SETTINGS_SOURCE}/includes/dockerapps/templates/ansible/ansible.yml
#SEEDUSER=$(cat ${TMPNAME})
DOMAIN=$(cat ${TMPDOMAIN})
SEEDGROUP=$(cat ${TMPGROUP})
rm ${TMPNAME} ${TMPDOMAIN} ${TMPGROUP}

    	echo -e "${CRED}---------------------------------------------------------------------------${CEND}"
    	echo -e "${CCYAN}"$(gettext "Auth Basique avec Traefik – Secure pour les services Docker")"${CEND}"
    	echo -e "${CRED}---------------------------------------------------------------------------${CEND}"
	echo ""

## suppression des yml dans ${SETTINGS_STORAGE}/conf
rm ${SETTINGS_STORAGE}/conf/* > /dev/null 2>&1

## suppression container
docker rm -f $(docker ps -aq) > /dev/null 2>&1

## supression Authelia si installé
rm -rf ${SETTINGS_STORAGE}/docker/${USER}/authelia > /dev/null 2>&1
rm ${SETTINGS_STORAGE}/conf/authelia.yml > /dev/null 2>&1

## reinstallation traefik
install_traefik

echo ""
## reinstallation watchtower
install_watchtower
echo ""

## reinstallation application
echo -e "${BLUE}###" $(gettext "REINITIALISATION DES APPLICATIONS")" ###${NC}"
echo -e " ${BWHITE}*" $(gettext "Les volumes ne seront pas supprimés")"${NC}"

relance_tous_services


rm $SERVICESUSER${USER}
    	echo -e "${CRED}---------------------------------------------------------------${CEND}"
    	echo -e "${CRED}" $(gettext "MISE A JOUR DU SERVEUR EFFECTUEE AVEC SUCCES")    ${CEND}"
    	echo -e "${CRED}---------------------------------------------------------------${CEND}"

  echo -e "\n"$(gettext "Appuyer sur")"${CCYAN}["$(gettext "ENTREE")"]${CEND}" $(gettext "pour continuer")
  read -r

