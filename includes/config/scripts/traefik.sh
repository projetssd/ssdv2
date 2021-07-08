#!/bin/bash
clear
source /opt/seedbox-compose/includes/functions.sh
source /opt/seedbox-compose/includes/variables.sh


## Variable
ansible-playbook /opt/seedbox-compose/includes/dockerapps/templates/ansible/ansible.yml
DOMAIN=$(cat ${TMPDOMAIN})
SEEDGROUP=$(cat ${TMPGROUP})
rm ${TMPNAME} ${TMPDOMAIN} ${TMPGROUP}

    	echo -e "${CRED}---------------------------------------------------------------${CEND}"
    	echo -e "${CCYAN}     /!\ MISE A JOUR DU SERVEUR AVEC TRAEFIK V2.2 /!\         ${CEND}"
    	echo -e "${CRED}---------------------------------------------------------------${CEND}"
	echo ""

echo ""
echo -e "${BLUE}### SUPPRESSION FAIL2BAN ###${NC}"
apt remove --purge fail2ban -y > /dev/null 2>&1
rm -rf /etc/fail2ban > /dev/null 2>&1
checking_errors $?

echo ""
echo -e "${BLUE}### SUPPRESSION "/opt/seedbox/conf" ###${NC}"
## suppression des yml dans /opt/seedbox/conf
rm /opt/seedbox/conf/* > /dev/null 2>&1
checking_errors $?

echo ""
echo -e "${BLUE}### SUPPRESSION DES CONTAINERS ###${NC}"
## suppression container
docker rm -f $(docker ps -aq) > /dev/null 2>&1
checking_errors $?

echo ""
echo -e "${BLUE}### SUPPRESSION TRAEFIK 1.7 ###${NC}"
## suppression traefik
rm -rf /opt/seedbox/docker/traefik
checking_errors $?

echo ""
echo -e "${BLUE}### INSTALLATION TRAEFIK 2.2 ET PORTAINER ###${NC}"
## reinstallation traefik
install_traefik
checking_errors $?

echo ""
echo -e "${BLUE}### REINSTALLATION PORTAINER ###${NC}"
## reinstallation watchtower
install_watchtower
checking_errors $?

echo ""
echo -e "${BLUE}### REINSTALLATION FAIL2BAN ###${NC}"
## reinstallation fail2ban
ansible-playbook /opt/seedbox-compose/includes/config/roles/fail2ban/tasks/main.yml
checking_errors $?

echo ""
## reinstallation application
echo -e "${BLUE}### REINITIALISATION DES APPLICATIONS ###${NC}"
echo -e " ${BWHITE}* Les fichiers de configuration ne seront pas effacés${NC}"
while read line; do echo $line | cut -d'.' -f1; done < /home/${USER}/resume > $SERVICESUSER${USER}
rm /home/${USER}/resume
install_services

rm $SERVICESUSER${USER}
    	echo -e "${CRED}---------------------------------------------------------------${CEND}"
    	echo -e "${CCYAN}     /!\ MISE A JOUR DU SERVEUR EFFECTUEE AVEC SUCCES /!\     ${CEND}"
    	echo -e "${CRED}---------------------------------------------------------------${CEND}"
	echo ""
	echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour revenir au menu principal..."
	read -r

