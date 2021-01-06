#!/bin/bash

source /opt/seedbox-compose/includes/functions.sh
source /opt/seedbox-compose/includes/variables.sh

## Variable
ansible-playbook /opt/seedbox-compose/includes/dockerapps/templates/ansible/ansible.yml
SEEDUSER=$(cat /tmp/name)
DOMAIN=$(cat ${TMPDOMAIN})
SEEDGROUP=$(cat /tmp/group)
rm /tmp/name ${TMPDOMAIN} /tmp/group

    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"
    	echo -e "${CCYAN}    /!\ Réinstallation Docker - traefik - Réinitialisation des Apllis /!\    ${CEND}"
    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"
	echo ""

## Désinstallation Docker
apt-get remove --purge docker*
rm -rf /var/lib/docker
rm -rf /etc/docker
apt-get autoremove && apt-get autoclean

## Réinstallation docker
ansible-playbook /opt/seedbox-compose/includes/config/roles/docker/tasks/main.yml

## suppression des yml dans /opt/seedbox/conf
rm /opt/seedbox/conf/* > /dev/null 2>&1

## reinstallation traefik
install_traefik

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

