#!/bin/bash

source includes/functions.sh
source includes/variables.sh

mkdir -p /var/rclone > /dev/null 2>&1
rm /var/rclone/* > /dev/null 2>&1

echo ""

echo -e "${BLUE}---------------------------------------------------------------------------${CEND}"
echo -e "${CGREEN} 🚀 SSD Clone - Client ID - Secret ID ~ https://github.com/laster13/patxav

  Visiter https://github.com/laster13/patxav/wiki pour créer le
  Client ID de votre nouveau project!${CEND}"
echo -e "${BLUE}---------------------------------------------------------------------------${CEND}"
echo ""

read -p $'\e[36m↘️ Coller le Client ID | Appuyer sur [Enter]: \e[0m' clientid < /dev/tty
read -p $'\e[36m↘️ Coller le Secret ID | Appuyer sur [Enter]: \e[0m' secretid < /dev/tty

echo -e "${BWHITE}
CLIENT ID
$clientid

SECRET ID
$secretid
${CEND}"

echo "$clientid" > /var/rclone/pgclone.public
echo "$secretid" > /var/rclone/pgclone.secret

pgclonepublic=$(cat /var/rclone/pgclone.public)
pgclonesecret=$(cat /var/rclone/pgclone.secret)

echo -e "${BLUE}-------------------------------------------------------------------${CEND}"
echo -e "${CGREEN} 🚀 Création du Shared Drive ~ https://github.com/laster13/patxav${CEND}"
echo -e "${BLUE}-------------------------------------------------------------------${CEND}"

echo ""
read -p $'\e[36m↘️ Quel nom souhaitez vous donner à votre Share Drive | Appuyer sur [Enter]? \e[0m' nom < /dev/tty
echo "$nom" > /var/rclone/pgclone.nom
nom=$(cat /var/rclone/pgclone.nom)

echo ""

echo -e "${BWHITE}
https://accounts.google.com/o/oauth2/auth?client_id=$pgclonepublic&redirect_uri=urn:ietf:wg:oauth:2.0:oob&scope=https://www.googleapis.com/auth/drive&response_type=code

NOTE: Copier/Coller l'URL dans votre navigateur | Utiliser le bon compte Google!${CEND}"
echo ""

read -p $'\e[36m↘️ Coller le Token | Appuyer sur [Enter]: \e[0m' token < /dev/tty

curl --request POST --data "code=$token&client_id=$pgclonepublic&client_secret=$pgclonesecret&redirect_uri=urn:ietf:wg:oauth:2.0:oob&grant_type=authorization_code" https://accounts.google.com/o/oauth2/token > /var/rclone/pgclone.info

accesstoken=$(cat /var/rclone/pgclone.info | grep access_token | awk '{print $2}')
ramdom=$(head /dev/urandom | tr -dc A-Za-z | head -c 8 > /var/rclone/pgclone.chaine)
chaine=$(cat /var/rclone/pgclone.chaine)

  curl --request POST \
    "https://www.googleapis.com/drive/v3/teamdrives?requestId='$chaine" \
    --header "Authorization: Bearer ${accesstoken}" \
    --header 'Accept: application/json' \
    --header 'Content-Type: application/json' \
    --data '{"name":"'$nom'","backgroundImageLink":"https://pgblitz.com/styles/io_dark/images/pgblitz4.png"}' \
    --compressed > /var/rclone/teamdrive.output

#####################
secret=$(cat /var/rclone/pgclone.secret)
public=$(cat /var/rclone/pgclone.public)
cat /var/rclone/teamdrive.output | grep "id" | awk '{ print $2 }' | cut -c2- | rev | cut -c3- | rev > /var/rclone/teamdrive.id
cat /var/rclone/teamdrive.output | grep "name" | awk '{ print $2 }' | cut -c2- | rev | cut -c2- | rev > /var/rclone/teamdrive.name
name=$(sed -n ${typed}p /var/rclone/teamdrive.name)
id=$(sed -n ${typed}p /var/rclone/teamdrive.id)
echo "$name" > /var/rclone/pgclone.teamdrive
echo "$id" > /var/rclone/pgclone.teamid
#####################

echo ""

echo -e "${BLUE}-----------------------------------------------------------${CEND}"
echo -e "${CGREEN} 🌎 Primary Password ~ https://github.com/laster13/patxav${CEND}"
echo -e "${BLUE}-----------------------------------------------------------${CEND}"

echo ""
read -p $'\e[36m↘️ Taper votre Password au choix | Appuyer [ENTER]: \e[0m' typed < /dev/tty

primarypassword=$typed

echo ""

echo -e "${BLUE}---------------------------------------------------------------${CEND}"
echo -e "${CGREEN} 🌎 SALT (SALT Password) ~ https://github.com/laster13/patxav${CEND}"
echo -e "${BLUE}---------------------------------------------------------------${CEND}"

echo -e "${BWHITE}
NOTE: Ne pas utiliser le même pot de passe!

Définissez un mot de passe SALT pour le cryptage des données! 
N'OUBLIEZ PAS le mot de passe! Sinon vous ne pourrez pas récupérer vos données!
C'est le principal risque du cryptage!${CEND}"

echo ""

read -p $'\e[36m↘️ Taper SALT Password | Appuyer [ENTER]: \e[0m' typed < /dev/tty

secondarypassword=$typed

echo ""

echo -e "${BLUE}----------------------------------------------------${CEND}"
echo -e "${CGREEN} 🌎 Passwords ~ https://github.com/laster13/patxav${CEND}"
echo -e "${BLUE}----------------------------------------------------${CEND}"

echo -e "${BWHITE}
Primary: $primarypassword
SALT   : $secondarypassword
${CEND}"

echo $primarypassword > /var/rclone/pgclone.password
echo $secondarypassword > /var/rclone/pgclone.salt

echo -e "${BLUE}-------------------------------------------------------------${CEND}"
echo -e "${CGREEN} 🌎 Procédure Complète ~ https://github.com/laster13/patxav${CEND}"
echo -e "${BLUE}-------------------------------------------------------------${CEND}"

echo ""
echo -e "${BWHITE}
💬  Password & SALT sont maintenant actifs, ne les oubliez pas!!${CEND}"

pgclonepublic=$(cat /var/rclone/pgclone.public)
pgclonesecret=$(cat /var/rclone/pgclone.secret)

echo ""

echo -e "${BLUE}------------------------------------------------------${CEND}"
echo -e "${CGREEN} 🚀 Google Auth ~ https://github.com/laster13/patxav${CEND}"
echo -e "${BLUE}------------------------------------------------------${CEND}"

echo -e "${BWHITE}
https://accounts.google.com/o/oauth2/auth?client_id=$pgclonepublic&redirect_uri=urn:ietf:wg:oauth:2.0:oob&scope=https://www.googleapis.com/auth/drive&response_type=code

Copiez et collez à nouveau l'URL dans le navigateur! Assurez-vous d'utiliser et de vous connecter avec
le bon compte Google!${CEND}"

echo ""

read -p $'\e[36m↘️ Coller le Token | Appuyer sur [Enter]: \e[0m' token < /dev/tty

  curl --request POST --data "code=$token&client_id=$pgclonepublic&client_secret=$pgclonesecret&redirect_uri=urn:ietf:wg:oauth:2.0:oob&grant_type=authorization_code" https://accounts.google.com/o/oauth2/token > /var/rclone/pgclone.info

  accesstoken=$(cat /var/rclone/pgclone.info | grep access_token | awk '{print $2}')
  refreshtoken=$(cat /var/rclone/pgclone.info | grep refresh_token | awk '{print $2}')
  rcdate=$(date +'%Y-%m-%d')
  rctime=$(date +"%H:%M:%S" --date="$givenDate 60 minutes")
  rczone=$(date +"%:z")
  final=$(echo "${rcdate}T${rctime}${rczone}")
  nom=$(cat /var/rclone/pgclone.nom)

########################

echo "" >> /root/.config/rclone/rclone.conf
echo "[$nom]" >> /root/.config/rclone/rclone.conf
echo "client_id = $pgclonepublic" >> /root/.config/rclone/rclone.conf
echo "client_secret = $pgclonesecret" >> /root/.config/rclone/rclone.conf
echo "type = drive" >> /root/.config/rclone/rclone.conf
echo "scope = drive" >> /root/.config/rclone/rclone.conf
echo -n "token = {\"access_token\":${accesstoken}\"token_type\":\"Bearer\",\"refresh_token\":${refreshtoken}\"expiry\":\"${final}\"}" >> /root/.config/rclone/rclone.conf
echo "" >> /root/.config/rclone/rclone.conf
teamid=$(cat /var/rclone/pgclone.teamid)
echo "team_drive = $teamid" >> /root/.config/rclone/rclone.conf
echo ""

## Ajout du crypt

PASSWORD=`cat /var/rclone/pgclone.password`
SALT=`cat /var/rclone/pgclone.salt`
ENC_PASSWORD=`rclone obscure "$PASSWORD"`
ENC_SALT=`rclone obscure "$SALT"`

echo "" >> /root/.config/rclone/rclone.conf
echo "[$name-crypt]" >> /root/.config/rclone/rclone.conf
echo "type = crypt" >> /root/.config/rclone/rclone.conf
echo "remote = $nom:/Medias" >> /root/.config/rclone/rclone.conf
echo "filename_encryption = standard" >> /root/.config/rclone/rclone.conf
echo "directory_name_encryption = true" >> /root/.config/rclone/rclone.conf
echo "password = $ENC_PASSWORD" >> /root/.config/rclone/rclone.conf
echo "password2 = $ENC_SALT" >> /root/.config/rclone/rclone.conf;

echo ""

echo -e "${BLUE}-------------------------------------------------------------${CEND}"
echo -e "${CGREEN} 🌎 Procédure Terminée ~ https://github.com/laster13/patxav${CEND}"
echo -e "${BLUE}-------------------------------------------------------------${CEND}"

echo -e "${BWHITE}
💬  [sharedrive] est maintenant créé et opérationnel! le rclone.conf également!${CEND}"


