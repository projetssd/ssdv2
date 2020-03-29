#!/bin/bash

source includes/functions.sh
source includes/variables.sh

## Variable
SEEDUSER=$(cat /etc/passwd | tail -1 | cut -d: -f1)
DOMAIN=$(cat /home/$SEEDUSER/resume | tail -1 | cut -d. -f2-3)
SERVICESPERUSER="$SERVICESUSER$SEEDUSER"

    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"
    	echo -e "${CCYAN}    /!\ Auth Basique avec Traefik – Secure pour les services Docker /!\      ${CEND}"
    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"
	echo ""

## suppression des yml dans /opt/seedbox/conf
rm /opt/seedbox/conf/* > /dev/null 2>&1

## suppression container
docker rm -f $(docker ps -aq) > /dev/null 2>&1

## reinstallation traefik, portainer
install_traefik
install_portainer

echo ""
## reinstallation watchtower
install_watchtower
echo ""

## reinstallation application
echo -e "${BLUE}### REINITIALISATION DES APPLICATIONS ###${NC}"
echo -e " ${BWHITE}* Les fichiers de configuration ne seront pas effacés${NC}"
while read line; do echo $line | cut -d'.' -f1; done < /home/$SEEDUSER/resume > $SERVICESPERUSER
rm /home/$SEEDUSER/resume
install_services
ansible-vault encrypt /opt/seedbox/variables/account.yml > /dev/null 2>&1

rm $SERVICESUSER$SEEDUSER
    	echo -e "${CRED}---------------------------------------------------------------${CEND}"
    	echo -e "${CRED}     /!\ MISE A JOUR DU SERVEUR EFFECTUEE AVEC SUCCES /!\      ${CEND}"
    	echo -e "${CRED}---------------------------------------------------------------${CEND}"

echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
read -r

