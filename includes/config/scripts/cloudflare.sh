#!/bin/bash
clear
source /opt/seedbox-compose/includes/functions.sh
source /opt/seedbox-compose/includes/variables.sh

## Variable
ansible-playbook /opt/seedbox-compose/includes/dockerapps/templates/ansible/ansible.yml
SEEDUSER=$(cat /tmp/name)
DOMAIN=$(cat /tmp/domain)
SEEDGROUP=$(cat /tmp/group)
rm /tmp/name /tmp/domain /tmp/group
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

## reinstallation traefik
install_traefik

echo ""
## reinstallation watchtower
install_watchtower
echo ""

## reinstallation application
echo -e "${BLUE}### REINITIALISATION DES APPLICATIONS ###${NC}"
echo -e " ${BWHITE}* Les fichiers de configuration ne seront pas effacés${NC}"
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

