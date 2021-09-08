#!/bin/bash

source /opt/seedbox-compose/includes/functions.sh
source /opt/seedbox-compose/includes/variables.sh

## Variable
ansible-playbook /opt/seedbox-compose/includes/dockerapps/templates/ansible/ansible.yml
DOMAIN=$(cat ${TMPDOMAIN})
SEEDGROUP=$(cat ${TMPGROUP})
rm ${TMPNAME} ${TMPDOMAIN} ${TMPGROUP}
oauth_client=$1
oauth_secret=$2
email=$3

    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"
    	echo -e "${CCYAN}   /!\ Google OAuth avec Traefik – Secure SSO pour les services Docker /!\   ${CEND}"
    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"
	echo ""
    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"
    	echo -e "${CRED}    IMPORTANT: Au préalable créer un projet et vos identifiants		      ${CEND}"
    	echo -e "${CRED}    https://github.com/laster13/patxav/wiki				      ${CEND}"
    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"
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
    >&2 echo -n -e "${BWHITE}Compte Gmail utilisé(s), séparés d'une virgule si plusieurs: ${CEND}"
    read email
    manage_account_yml oauth.account $email
done

openssl=$(openssl rand -hex 16)
manage_account_yml oauth.openssl $openssl

## suppression des yml dans /opt/seedbox/conf
rm /opt/seedbox/conf/*


## suppression container
docker rm -f $(docker ps -aq) > /dev/null 2>&1

## supression Authelia si installé
rm -rf /opt/seedbox/docker/${USER}/authelia > /dev/null 2>&1
rm /opt/seedbox/conf/authelia.yml > /dev/null 2>&1
sed -i '/authelia/d' /home/${USER}/resume > /dev/null 2>&1

## reinstallation traefik
echo ""
install_traefik

echo ""
## reinstallation watchtower
install_watchtower
echo ""

## reinstallation application
echo -e "${BLUE}### REINITIALISATION DES APPLICATIONS ###${NC}"
echo -e " ${BWHITE}* Les fichiers de configuration ne seront pas effacés${NC}"
sort -u /home/${USER}/resume |grep -v notfound > /tmp/resume
cp /tmp/resume /home/${USER}/resume
sort -u "${CONFDIR}/resume" | grep -v notfound > /tmp/resume
    cp /tmp/resume "${CONFDIR}/resume"
while read line; do echo $line | awk '{print $1}'; done < "${CONFDIR}/resume" > $SERVICESPERUSER
mv /home/${USER}/resume /tmp
install_services
mv /tmp/resume /home/${USER}/
rm $SERVICESUSER${USER}
    	echo -e "${CRED}---------------------------------------------------------------${CEND}"
    	echo -e "${CRED}     /!\ MISE A JOUR DU SERVEUR EFFECTUEE AVEC SUCCES /!\      ${CEND}"
    	echo -e "${CRED}---------------------------------------------------------------${CEND}"
	echo ""
    	echo -e "${CRED}---------------------------------------------------------------${CEND}"
    	echo -e "${CCYAN}    IMPORTANT:	Avant la 1ere connexion			       ${CEND}"
    	echo -e "${CCYAN}    		- Nettoyer l'historique de votre navigateur    ${CEND}"
    	echo -e "${CCYAN}    		- déconnection de tout compte google	       ${CEND}"
    	echo -e "${CRED}---------------------------------------------------------------${CEND}"
	echo ""

echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
read -r

