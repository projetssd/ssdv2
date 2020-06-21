#!/bin/bash

source includes/functions.sh
source includes/variables.sh

## Variable
ansible-playbook /opt/seedbox-compose/includes/dockerapps/templates/ansible/ansible.yml
SEEDUSER=$(cat /tmp/name)
DOMAIN=$(cat /tmp/domain)
SEEDGROUP=$(cat /tmp/group)
rm /tmp/name /tmp/domain /tmp/group
INSTALLEDFILE="/home/$SEEDUSER/resume"
SERVICESPERUSER="$SERVICESUSER$SEEDUSER"

    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"
    	echo -e "${CCYAN}   /!\ Authelia avec Traefik – Secure SSO pour les services Docker /!\       ${CEND}"
    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"
	echo ""
    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"
    	echo -e "${CRED}    IMPORTANT: 	https://github.com/laster13/patxav/wiki			      ${CEND}"
    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"
	echo ""

## suppression des yml dans /opt/seedbox/conf
rm /opt/seedbox/conf/* > /dev/null 2>&1

## reinstall traefik
docker rm -f traefik > /dev/null 2>&1
rm -rf /opt/seedbox/docker/traefik/rules > /dev/null 2>&1
install_traefik

echo ""

## reinstallation application
echo -e "${BLUE}### REINITIALISATION DES APPLICATIONS ###${NC}"
echo -e " ${BWHITE}* Les fichiers de configuration ne seront pas effacés${NC}"
while read line; do echo $line | cut -d'.' -f1 | sed '/authelia/d'; done < /home/$SEEDUSER/resume > $SERVICESPERUSER
mv /home/$SEEDUSER/resume /tmp
install_services
echo "authelia.$DOMAIN" >> $INSTALLEDFILE
rm $SERVICESUSER$SEEDUSER
    	echo -e "${CRED}---------------------------------------------------------------${CEND}"
    	echo -e "${CRED}     /!\ MISE A JOUR DU SERVEUR EFFECTUEE AVEC SUCCES /!\      ${CEND}"
    	echo -e "${CRED}---------------------------------------------------------------${CEND}"
	echo ""
    	echo -e "${CRED}---------------------------------------------------------------${CEND}"
    	echo -e "${CCYAN}    IMPORTANT:	Avant la 1ere connexion			       ${CEND}"
    	echo -e "${CCYAN}    		- Nettoyer l'historique de votre navigateur    ${CEND}"
    	echo -e "${CRED}---------------------------------------------------------------${CEND}"
	echo ""

echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
read -r

