#!/bin/bash


## Variable
ansible-playbook ${SETTINGS_SOURCE}/includes/dockerapps/templates/ansible/ansible.yml
#SEEDUSER=$(cat ${TMPNAME})
DOMAIN=$(cat ${TMPDOMAIN})
SEEDGROUP=$(cat ${TMPGROUP})
rm ${TMPNAME} ${TMPDOMAIN} ${TMPGROUP}

    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"
    	echo -e "${CCYAN}    /!\ Auth Basique avec Traefik – Secure pour les services Docker /!\      ${CEND}"
    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"
	echo ""

## suppression des yml dans ${SETTINGS_STORAGE}/conf
rm ${SETTINGS_STORAGE}/conf/* > /dev/null 2>&1

## suppression container
docker rm -f $(docker ps -aq) > /dev/null 2>&1

## supression Authelia si installé
rm -rf ${SETTINGS_STORAGE}/docker/${USER}/authelia > /dev/null 2>&1
rm ${SETTINGS_STORAGE}/conf/authelia.yml > /dev/null 2>&1
sed -i '/authelia/d' /home/${USER}/resume > /dev/null 2>&1

## reinstallation traefik
install_traefik

echo ""
## reinstallation watchtower
install_watchtower
echo ""

## reinstallation application
echo -e "${BLUE}### REINITIALISATION DES APPLICATIONS ###${NC}"
echo -e " ${BWHITE}* Les fichiers de configuration ne seront pas effacés${NC}"
while read line; do echo $line | cut -d'.' -f1; done < /home/${USER}/resume > $SERVICESPERUSER
rm /home/${USER}/resume
install_services

rm $SERVICESUSER${USER}
    	echo -e "${CRED}---------------------------------------------------------------${CEND}"
    	echo -e "${CRED}     /!\ MISE A JOUR DU SERVEUR EFFECTUEE AVEC SUCCES /!\      ${CEND}"
    	echo -e "${CRED}---------------------------------------------------------------${CEND}"

echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
read -r

