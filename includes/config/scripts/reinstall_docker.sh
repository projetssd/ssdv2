#!/bin/bash

## Variable
ansible-playbook ${SETTINGS_SOURCE}e/includes/dockerapps/templates/ansible/ansible.yml

DOMAIN=$(cat ${TMPDOMAIN})
SEEDGROUP=$(cat ${TMPGROUP})
rm ${TMPNAME} ${TMPDOMAIN} ${TMPGROUP}

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
ansible-playbook ${SETTINGS_SOURCE}/includes/config/roles/docker/tasks/main.yml

## suppression des yml dans /opt/seedbox/conf
rm /opt/seedbox/conf/* >/dev/null 2>&1

## reinstallation traefik
install_traefik

echo ""
## reinstallation watchtower
install_watchtower
echo ""

## reinstallation application
echo -e "${BLUE}### REINITIALISATION DES APPLICATIONS ###${NC}"
echo -e " ${BWHITE}* Les fichiers de configuration ne seront pas effacés${NC}"
while read line; do echo $line | cut -d'.' -f1; done </home/${USER}/resume >$SERVICESPERUSER
rm /home/${USER}/resume
install_services

rm $SERVICESUSER${USER}
echo -e "${CRED}---------------------------------------------------------------${CEND}"
echo -e "${CRED}     /!\ MISE A JOUR DU SERVEUR EFFECTUEE AVEC SUCCES /!\      ${CEND}"
echo -e "${CRED}---------------------------------------------------------------${CEND}"

echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
read -r
