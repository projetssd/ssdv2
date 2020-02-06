#!/bin/bash
clear
source includes/functions.sh
source includes/variables.sh

    	echo -e "${CRED}---------------------------------------------------------------${CEND}"
    	echo -e "${CRED}     /!\ MISE A JOUR DU SERVEUR AVEC CLOUDFLARE /!\            ${CEND}"
    	echo -e "${CRED}---------------------------------------------------------------${CEND}"
	echo ""

## Mise à jour du systeme
update_system

## INSTALLATION DES PACKAGES
install_base_packages

## suppression des yml dans /opt/seedbox/conf
rm /opt/seedbox/conf/*

## suppression traefik
docker rm -f traefik > /dev/null 2>&1
rm -rf /opt/seedbox/docker/traefik

## supression portainer
docker rm -f portainer > /dev/null 2>&1
rm -rf /opt/seedbox/docker/portainer

## cloudflare
echo ""
cloudflare

## reinstallation traefik, portainer
install_traefik
install_portainer

## reinstallation application
SEEDUSER=$(cat /opt/seedbox/variables/users)
SERVICESPERUSER="$SERVICESUSER$SEEDUSER"
while read line; do echo $line | cut -d'.' -f1; done < /home/$SEEDUSER/resume > $SERVICESUSER$SEEDUSER
mv /home/$SEEDUSER/resume /tmp
install_services
mv /tmp/resume /home/$SEEDUSER/
rm $SERVICESUSER$SEEDUSER
    	echo -e "${CRED}---------------------------------------------------------------${CEND}"
    	echo -e "${CRED}     /!\ MISE A JOUR DU SERVEUR EFFECTUEE AVEC SUCCES /!\     ${CEND}"
    	echo -e "${CRED}---------------------------------------------------------------${CEND}"
	echo ""
	echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour revenir au menu principal..."
	read -r

