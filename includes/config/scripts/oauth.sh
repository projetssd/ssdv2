#!/bin/bash

source includes/functions.sh
source includes/variables.sh

## Variable
SEEDUSER=$(ls /opt/seedbox/media* | cut -d '-' -f2)
DOMAIN=$(cat /home/$SEEDUSER/resume | tail -1 | cut -d. -f2-3)
SERVICESPERUSER="$SERVICESUSER$SEEDUSER"
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
ansible-vault decrypt /opt/seedbox/variables/account.yml > /dev/null 2>&1

while [ -z "$oauth_client" ]; do
    >&2 echo -n -e "${BWHITE}Oauth_client: ${CEND}"
    read oauth_client
    sed -i "/client:/c\   client: $oauth_client" /opt/seedbox/variables/account.yml
done

while [ -z "$oauth_secret" ]; do
    >&2 echo -n -e "${BWHITE}Oauth_secret: ${CEND}"
    read oauth_secret
    sed -i "/secret:/c\   secret: $oauth_secret" /opt/seedbox/variables/account.yml
done

while [ -z "$email" ]; do
    >&2 echo -n -e "${BWHITE}Compte Gmail utilisé(s), séparés d'une virgule si plusieurs: ${CEND}"
    read email
    sed -i "/account:/c\   account: $email" /opt/seedbox/variables/account.yml
done

openssl=$(openssl rand -hex 16)
sed -i "/openssl:/c\   openssl: $openssl" /opt/seedbox/variables/account.yml

## suppression des yml dans /opt/seedbox/conf
rm /opt/seedbox/conf/*


## suppression container
docker rm -f $(docker ps -aq) > /dev/null 2>&1

## reinstallation traefik, portainer
echo ""
install_traefik
install_portainer

echo ""
## reinstallation watchtower
install_watchtower
echo ""

## reinstallation application
echo -e "${BLUE}### REINITIALISATION DES APPLICATIONS ###${NC}"
echo -e " ${BWHITE}* Les fichiers de configuration ne seront pas effacés${NC}"
while read line; do echo $line | cut -d'.' -f1; done < /home/$SEEDUSER/resume > $SERVICESPERUSER
mv /home/$SEEDUSER/resume /tmp
install_services
mv /tmp/resume /home/$SEEDUSER/
rm $SERVICESUSER$SEEDUSER
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
ansible-vault encrypt /opt/seedbox/variables/account.yml > /dev/null 2>&1

echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
read -r

