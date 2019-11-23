#!/bin/bash

source includes/functions.sh
source includes/variables.sh

## Variable
DOMAIN=$(cat /opt/seedbox/variables/domain)
SEEDUSER=$(cat /opt/seedbox/variables/users)
SERVICESPERUSER="$SERVICESUSER$SEEDUSER"
INSTALLEDFILE="/home/$SEEDUSER/resume"

    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"
    	echo -e "${CCYAN}    /!\ Auth Basique avec Traefik – Secure pour les services Docker /!\      ${CEND}"
    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"
	echo ""

## suppression des yml dans /opt/seedbox/conf
rm /opt/seedbox/conf/* > /dev/null 2>&1

## suppression container
docker rm -f $(docker ps -aq) > /dev/null 2>&1

## reinstallation traefik, portainer
ansible-playbook /opt/seedbox-compose/includes/dockerapps/traefik.yml
install_portainer

echo ""
## reinstallation watchtower
install_watchtower
echo ""

## reinstallation application
while read line; do echo $line | cut -d'.' -f1; done < /home/$SEEDUSER/resume > $SERVICESPERUSER
mv /home/$SEEDUSER/resume /tmp
install_services
mv /tmp/resume /home/$SEEDUSER/
rm $SERVICESUSER$SEEDUSER
    	echo -e "${CRED}---------------------------------------------------------------${CEND}"
    	echo -e "${CRED}     /!\ MISE A JOUR DU SERVEUR EFFECTUEE AVEC SUCCES /!\      ${CEND}"
    	echo -e "${CRED}---------------------------------------------------------------${CEND}"

echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
read -r

