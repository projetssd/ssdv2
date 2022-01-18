#!/bin/bash
clear
source /opt/seedbox-compose/includes/functions.sh
source /opt/seedbox-compose/includes/variables.sh

echo -e "${CRED}----------------------------------------------${CEND}"
echo -e "${CRED}     /!\ Changement du nom de Domaine /!\     ${CEND}"
echo -e "${CRED}----------------------------------------------${CEND}"
echo ""
CONTACTEMAIL=$(whiptail --title "Adresse Email" --inputbox \
  "Merci de taper votre adresse Email :" 7 50 3>&1 1>&2 2>&3)
manage_account_yml user.mail $CONTACTEMAIL
###sed -i "/mail:/c\   mail: $CONTACTEMAIL" /opt/seedbox/variables/account.yml

DOMAIN=$(whiptail --title "Votre nom de Domaine" --inputbox \
  "Merci de taper le nouveau nom de Domaine :" 7 50 3>&1 1>&2 2>&3)
manage_account_yml user.domain $DOMAIN
###sed -i "/domain:/c\   domain: $DOMAIN" /opt/seedbox/variables/account.yml
echo ""

echo -e " ${BWHITE}* Supression Containers docker${NC}"
docker rm -f $(docker ps -aq) >/dev/null 2>&1

## suppression des yml dans /opt/seedbox/conf
rm /opt/seedbox/conf/* >/dev/null 2>&1

## suppression traefik
rm -rf /opt/seedbox/docker/traefik >/dev/null 2>&1

## supression portainer
rm -rf /opt/seedbox/docker/portainer

## reinstallation traefik
install_traefik
install_watchtower

## reinstallation application
echo -e "${BLUE}### REINITIALISATION DES APPLICATIONS ###${NC}"
echo -e " ${BWHITE}* Les fichiers de configuration ne seront pas effacés${NC}"
ansible-playbook /opt/seedbox-compose/includes/dockerapps/templates/ansible/ansible.yml

rm ${TMPNAME}
while read line; do echo $line | cut -d'.' -f1; done </home/${USER}/resume >$SERVICESUSER${USER}
rm /home/${USER}/resume
install_services
rm $SERVICESUSER${USER}

## restauration plex_dupefinder
PLEXDUPE=/home/${USER}/scripts/plex_dupefinder/plex_dupefinder.py
if [[ -e "$PLEXDUPE" ]]; then
  rm -rf /home/${USER}/scripts/plex_dupefinder >/dev/null 2>&1
  rm /usr/local/bin/plexdupes >/dev/null 2>&1
  ansible-playbook /opt/seedbox-compose/includes/config/roles/plex_dupefinder/tasks/main.yml
fi

## restauration cloudplow
CLOUDPLOWSERVICE=/etc/systemd/system/cloudplow.service
if [[ -e "$CLOUDPLOWSERVICE" ]]; then
  service cloudplow stop
  rm -rf /home/${USER}/scripts/cloudplow
  rm /usr/local/bin/cloudplow
  ansible-playbook /opt/seedbox-compose/includes/config/roles/cloudplow/tasks/main.yml
fi

## restauration plex_autoscan
PLEXSCANSERVICE=/etc/systemd/system/plex_autoscan.service
if [[ -e "$PLEXSCANSERVICE" ]]; then
  service plex_autoscan stop
  rm -rf /home/${USER}/scripts/plex_autoscan
  ansible-playbook /opt/seedbox-compose/includes/config/roles/plex_autoscan/tasks/main.yml
fi

echo -e "${CRED}---------------------------------------------------------------${CEND}"
echo -e "${CRED}     /!\ MISE A JOUR DU SERVEUR EFFECTUEE AVEC SUCCES /!\     ${CEND}"
echo -e "${CRED}---------------------------------------------------------------${CEND}"
echo ""
echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour revenir au menu principal..."
read -r
