#!/bin/bash
clear
echo -e "${CRED}----------------------------------------------${CEND}"
echo -e "${CRED}     /!\ Changement du nom de Domaine /!\     ${CEND}"
echo -e "${CRED}----------------------------------------------${CEND}"
echo ""
CONTACTEMAIL=$(whiptail --title "Adresse Email" --inputbox \
  "Merci de taper votre adresse Email :" 7 50 3>&1 1>&2 2>&3)
manage_account_yml user.mail $CONTACTEMAIL

DOMAIN=$(whiptail --title "Votre nom de Domaine" --inputbox \
  "Merci de taper le nouveau nom de Domaine :" 7 50 3>&1 1>&2 2>&3)
manage_account_yml user.domain $DOMAIN
echo ""

echo -e " ${BWHITE}* Supression Containers docker${NC}"
docker rm -f $(docker ps -aq) >/dev/null 2>&1

## suppression des yml dans ${SETTINGS_STORAGE}/conf
rm ${SETTINGS_STORAGE}/conf/* >/dev/null 2>&1

## suppression traefik
rm -rf ${SETTINGS_STORAGE}/docker/traefik >/dev/null 2>&1

## supression portainer
rm -rf ${SETTINGS_STORAGE}/docker/portainer

## reinstallation traefik
install_traefik
install_watchtower

## reinstallation application
echo -e "${BLUE}### REINITIALISATION DES APPLICATIONS ###${NC}"
echo -e " ${BWHITE}* Les fichiers de configuration ne seront pas effacés${NC}"
ansible-playbook ${SETTINGS_SOURCE}/includes/dockerapps/templates/ansible/ansible.yml

relance_tous_services


## restauration plex_dupefinder
PLEXDUPE=/home/${USER}/scripts/plex_dupefinder/plex_dupefinder.py
if [[ -e "$PLEXDUPE" ]]; then
  rm -rf /home/${USER}/scripts/plex_dupefinder >/dev/null 2>&1
  rm /usr/local/bin/plexdupes >/dev/null 2>&1
  ansible-playbook ${SETTINGS_SOURCE}/includes/config/roles/plex_dupefinder/tasks/main.yml
fi

## restauration cloudplow
CLOUDPLOWSERVICE=/etc/systemd/system/cloudplow.service
if [[ -e "$CLOUDPLOWSERVICE" ]]; then
  service cloudplow stop
  rm -rf /home/${USER}/scripts/cloudplow
  rm /usr/local/bin/cloudplow
  ansible-playbook ${SETTINGS_SOURCE}/includes/config/roles/cloudplow/tasks/main.yml
fi

## restauration plex_autoscan
PLEXSCANSERVICE=/etc/systemd/system/plex_autoscan.service
if [[ -e "$PLEXSCANSERVICE" ]]; then
  service plex_autoscan stop
  rm -rf /home/${USER}/scripts/plex_autoscan
  ansible-playbook ${SETTINGS_SOURCE}/includes/config/roles/plex_autoscan/tasks/main.yml
fi

echo -e "${CRED}---------------------------------------------------------------${CEND}"
echo -e "${CRED}     /!\ MISE A JOUR DU SERVEUR EFFECTUEE AVEC SUCCES /!\     ${CEND}"
echo -e "${CRED}---------------------------------------------------------------${CEND}"
echo ""
echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour revenir au menu principal..."
read -r
