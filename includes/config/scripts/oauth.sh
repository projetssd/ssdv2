#!/bin/bash

source ${SETTINGS_SOURCE}/includes/functions.sh
source ${SETTINGS_SOURCE}/includes/variables.sh

## Variable
ansible-playbook ${SETTINGS_SOURCE}/includes/dockerapps/templates/ansible/ansible.yml
DOMAIN=$(cat ${TMPDOMAIN})
SEEDGROUP=$(cat ${TMPGROUP})
rm ${TMPNAME} ${TMPDOMAIN} ${TMPGROUP}
oauth_client=$1
oauth_secret=$2
email=$3

echo -e "${BLUE}###" $(gettext "Google OAuth2 avec Traefik – Secure SSO pour les services Docker") "###${NC}"
echo ""
echo -e "${CCYAN}------------------------------------------------------------------${CEND}"
echo -e "${CCYAN}"$(gettext "Protocole d'identification via Google OAuth2")    "${CEND}"
echo -e "${CCYAN}"$(gettext "Securisation SSO pour les services Docker")       "${CEND}"
echo -e "${CCYAN}------------------------------------------------------------------${CEND}"
echo ""
echo -e "${CRED}------------------------------------------------------------------${CEND}"
echo -e "${CRED}"IMPORTANT: $(gettext "Au préalable créer un projet et vos identifiants")"${CEND}"
echo -e "${CRED}https://github.com/laster13/patxav/wiki 		             ${CEND}"
echo -e "${CRED}------------------------------------------------------------------${CEND}"
echo ""

while [ -z "$oauth_client" ]; do
    >&2 echo -n -e "${BWHITE}Oauth_client: ${CEND}"
    read oauth_client
    manage_account_yml oauth.client $oauth_client
done

while [ -z "$oauth_secret" ]; do
    >&2 echo -n -e "${BWHITE}Oauth_secret: ${CEND}"
    read oauth_secret
    manage_account_yml oauth.secret $oauth_secret
done

while [ -z "$email" ]; do
    echo >&2 -n -e "${BWHITE}"$(gettext "Compte Gmail utilisé(s), séparés d'une virgule si plusieurs:") "${CEND}"
    read email
    manage_account_yml oauth.account $email
done

openssl=$(openssl rand -hex 16)
manage_account_yml oauth.openssl $openssl

## suppression des yml dans ${SETTINGS_STORAGE}/conf
rm ${SETTINGS_STORAGE}/conf/* > /dev/null 2>&1


## suppression container
docker rm -f $(docker ps -aq) > /dev/null 2>&1

## supression Authelia si installé
rm -rf ${SETTINGS_STORAGE}/docker/${USER}/authelia > /dev/null 2>&1
rm ${SETTINGS_STORAGE}/conf/authelia.yml > /dev/null 2>&1

## reinstallation traefik
echo ""
install_traefik

echo ""
## reinstallation watchtower
install_watchtower
echo ""

## reinstallation application
echo -e "${BLUE}###" $(gettext "REINITIALISATION DES APPLICATIONS") "###${NC}"
echo -e " ${BWHITE}*" $(gettext "Les fichiers de configuration ne seront pas effacés")"${NC}"

relance_tous_services

rm $SERVICESUSER${USER}
    echo -e "${CRED}---------------------------------------------------------------${CEND}"
    echo -e "${CRED}"$(gettext "MISE A JOUR DU SERVEUR EFFECTUEE AVEC SUCCES")"${CEND}"
    echo -e "${CRED}---------------------------------------------------------------${CEND}"
    echo ""
    echo -e "${CRED}---------------------------------------------------------------${CEND}"
    echo -e "${CCYAN}"    IMPORTANT:	$(gettext "Avant la 1ere connexion")"${CEND}"
    echo -e "${CCYAN}"    		- $(gettext "Nettoyer l'historique de votre navigateur")"${CEND}"
    echo -e "${CCYAN}"   		- $(gettext "déconnection de tout compte google")"${CEND}"
    echo -e "${CRED}---------------------------------------------------------------${CEND}"
    echo ""
    echo -e "\n $(gettext "Appuyer sur") ${CCYAN}[$(gettext "ENTREE")]${CEND} $(gettext "pour continuer")"
    read -r
