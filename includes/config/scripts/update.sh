#!/bin/bash

source includes/functions.sh
source includes/variables.sh

## Variables
SEEDUSER=$(cat /etc/passwd | tail -1 | cut -d: -f1)
DOMAIN=$(cat /home/$SEEDUSER/resume | tail -1 | cut -d. -f2-3)
SERVICESPERUSER="$SERVICESUSER$SEEDUSER"
cp /opt/seedbox-compose/includes/config/account.yml /opt/seedbox/variables

    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"
    	echo -e "${CCYAN}    /!\ Mise à jour - Chiffrement des Variables /!\			      ${CEND}"
    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"
	echo ""

if [[ -e "/opt/seedbox/variables/cloudflare_api" ]]; then api=$(cat /opt/seedbox/variables/cloudflare_api); sed -i "/api:/c\   api: $api" /opt/seedbox/variables/account.yml; fi
if [[ -e "/opt/seedbox/variables/cloudflare_email" ]]; then login=$(cat /opt/seedbox/variables/cloudflare_email); sed -i "/login:/c\   login: $login" /opt/seedbox/variables/account.yml; fi
if [[ -e "/opt/seedbox/variables/oauth_client" ]]; then client=$(cat /opt/seedbox/variables/oauth_client); sed -i "/client:/c\   client: $client" /opt/seedbox/variables/account.yml; fi
if [[ -e "/opt/seedbox/variables/oauth_secret" ]]; then secret=$(cat /opt/seedbox/variables/oauth_secret); sed -i "/secret:/c\   secret: $secret" /opt/seedbox/variables/account.yml; fi
if [[ -e "/opt/seedbox/variables/openssl" ]]; then openssl=$(cat /opt/seedbox/variables/openssl); sed -i "/openssl:/c\   openssl: $openssl" /opt/seedbox/variables/account.yml; fi
if [[ -e "/opt/seedbox/variables/email" ]]; then account=$(cat /opt/seedbox/variables/email); sed -i "/account:/c\   account: $account" /opt/seedbox/variables/account.yml; fi
if [[ -e "/opt/seedbox/variables/remote" ]]; then remote=$(cat /opt/seedbox/variables/remote); sed -i "/remote:/c\   remote: $remote" /opt/seedbox/variables/account.yml; fi
if [[ -e "/opt/seedbox/variables/remoteplex" ]]; then crypt=$(cat /opt/seedbox/variables/remoteplex); sed -i "/crypt:/c\   crypt: $crypt" /opt/seedbox/variables/account.yml; fi
if [[ -e "/opt/seedbox/variables/plexpass" ]]; then sesame=$(cat /opt/seedbox/variables/plexpass); sed -i "/sesame:/c\   sesame: $sesame" /opt/seedbox/variables/account.yml; fi
if [[ -e "/opt/seedbox/variables/plexuser" ]]; then ident=$(cat /opt/seedbox/variables/plexuser); sed -i "/ident:/c\   ident: $ident" /opt/seedbox/variables/account.yml; fi
if [[ -e "/opt/seedbox/variables/token" ]]; then token=$(cat /opt/seedbox/variables/token); sed -i "/token:/c\   token: $token" /opt/seedbox/variables/account.yml; fi
if [[ -e "/opt/seedbox/variables/remote" ]]; then remote=$(cat /opt/seedbox/variables/remote); sed -i "/remote:/c\   remote: $remote" /opt/seedbox/variables/account.yml; fi
if [[ -e "/opt/seedbox/variables/remoteplex" ]]; then crypt=$(cat /opt/seedbox/variables/remoteplex); sed -i "/crypt:/c\   crypt: $crypt" /opt/seedbox/variables/account.yml; fi


name=$(cat /opt/seedbox/variables/users)
domain=$(cat /opt/seedbox/variables/domain)
mail=$(cat /opt/seedbox/variables/mail)
group=$(cat /opt/seedbox/variables/group)
userid=$(cat /opt/seedbox/variables/userid)
groupid=$(cat /opt/seedbox/variables/groupid)
pass=$(cat /opt/seedbox/variables/pass)
htpwd=$(cat /opt/seedbox/passwd/.htpasswd-$SEEDUSER)


sed -i "/name:/c\   name: $name" /opt/seedbox/variables/account.yml
sed -i "/domain:/c\   domain: $domain" /opt/seedbox/variables/account.yml
sed -i "/mail:/c\   mail: $mail" /opt/seedbox/variables/account.yml
sed -i "/group:/c\   group: $group" /opt/seedbox/variables/account.yml
sed -i "/userid:/c\   userid: $userid" /opt/seedbox/variables/account.yml
sed -i "/groupid:/c\   groupid: $groupid" /opt/seedbox/variables/account.yml
sed -i "/pass:/c\   pass: $pass" /opt/seedbox/variables/account.yml
sed -i "/htpwd:/c\   htpwd: $htpwd" /opt/seedbox/variables/account.yml

## suppression des yml dans /opt/seedbox/conf
rm /opt/seedbox/conf/* > /dev/null 2>&1

## suppression container
docker rm -f $(docker ps -aq) > /dev/null 2>&1

## reinstallation traefik, portainer
install_traefik
install_portainer

echo ""
## reinstallation watchtower
install_watchtower
echo ""

## reinstallation application
while read line; do echo $line | cut -d'.' -f1; done < /home/$SEEDUSER/resume > $SERVICESPERUSER
rm /home/$SEEDUSER/resume
install_services

## supppression anciennes variables
cd /opt/seedbox/variables
find . -type f -not -name "account.yml" -exec rm {} \;
rm -rf /opt/seedbox/passwd

ansible-vault encrypt /opt/seedbox/variables/account.yml > /dev/null 2>&1

rm $SERVICESUSER$SEEDUSER
    	echo -e "${CRED}---------------------------------------------------------------${CEND}"
    	echo -e "${CRED}     /!\ MISE A JOUR DU SERVEUR EFFECTUEE AVEC SUCCES /!\      ${CEND}"
    	echo -e "${CRED}---------------------------------------------------------------${CEND}"

echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
read -r

