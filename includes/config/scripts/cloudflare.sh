#!/bin/bash
clear
source includes/functions.sh
source includes/variables.sh

## Variable
SEEDUSER=$(cat /etc/passwd | tail -1 | cut -d: -f1)
DOMAIN=$(cat /home/$SEEDUSER/resume | tail -1 | cut -d. -f2-3)
SERVICESPERUSER="$SERVICESUSER$SEEDUSER"

    	echo -e "${CRED}---------------------------------------------------------------${CEND}"
    	echo -e "${CRED}     /!\ MISE A JOUR DU SERVEUR AVEC CLOUDFLARE /!\            ${CEND}"
    	echo -e "${CRED}---------------------------------------------------------------${CEND}"
	echo ""

## suppression des yml dans /opt/seedbox/conf
rm /opt/seedbox/conf/* > /dev/null 2>&1

## suppression container
docker rm -f $(docker ps -aq) > /dev/null 2>&1

## suppression traefik
rm -rf /opt/seedbox/docker/traefik

## cloudflare
echo ""
cloudflare

## reinstallation traefik, portainer
install_traefik
install_portainer

echo ""
## reinstallation watchtower
install_watchtower
echo ""

## reinstallation application
while read line; do echo $line | cut -d'.' -f1; done < /home/$SEEDUSER/resume > $SERVICESUSER$SEEDUSER
rm /home/$SEEDUSER/resume
install_services
ansible-vault encrypt /opt/seedbox/variables/account.yml > /dev/null 2>&1

rm $SERVICESUSER$SEEDUSER
    	echo -e "${CRED}---------------------------------------------------------------${CEND}"
    	echo -e "${CRED}     /!\ MISE A JOUR DU SERVEUR EFFECTUEE AVEC SUCCES /!\     ${CEND}"
    	echo -e "${CRED}---------------------------------------------------------------${CEND}"
	echo ""
	echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour revenir au menu principal..."
	read -r

