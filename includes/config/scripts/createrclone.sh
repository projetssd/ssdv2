#!/bin/bash
source "${SETTINGS_SOURCE}/includes/functions.sh"
# shellcheck source=${BASEDIR}/includes/variables.sh
source "${SETTINGS_SOURCE}/includes/variables.sh"
RCLONE_CONFIG_FILE=${HOME}/.config/rclone/rclone.conf

TMPDIR=$(mktemp -d)

create_dir ${HOME}/.config/rclone
touch ${RCLONE_CONFIG_FILE}

echo ""

echo -e "${BLUE}---------------------------------------------------------------------------${CEND}"
echo -e "${CGREEN} 🚀 SSD Clone - Client ID - Secret ID ~ https://github.com/projetssd/ssdv2

  Visiter https://github.com/projetssd/ssdv2/wiki pour créer le
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

echo "$clientid" > ${TMPDIR}/pgclone.public
echo "$secretid" > ${TMPDIR}/pgclone.secret

pgclonepublic=$(cat ${TMPDIR}/pgclone.public)
pgclonesecret=$(cat ${TMPDIR}/pgclone.secret)

echo -e "${BLUE}-------------------------------------------------------------------${CEND}"
echo -e "${CGREEN} 🚀 Création du Shared Drive ~ https://github.com/projetssd/ssdv2${CEND}"
echo -e "${BLUE}-------------------------------------------------------------------${CEND}"

echo ""
read -p $'\e[36m↘️ Quel nom souhaitez vous donner à votre Share Drive | Appuyer sur [Enter]? \e[0m' nom < /dev/tty
echo "$nom" > ${TMPDIR}/pgclone.nom
nom=$(cat ${TMPDIR}/pgclone.nom)

echo ""

echo -e "${BWHITE}
https://accounts.google.com/o/oauth2/auth?client_id=$pgclonepublic&redirect_uri=urn:ietf:wg:oauth:2.0:oob&scope=https://www.googleapis.com/auth/drive&response_type=code

NOTE: Copier/Coller l'URL dans votre navigateur | Utiliser le bon compte Google!${CEND}"
echo ""

read -p $'\e[36m↘️ Coller le Token | Appuyer sur [Enter]: \e[0m' token < /dev/tty

curl --request POST --data "code=$token&client_id=$pgclonepublic&client_secret=$pgclonesecret&redirect_uri=urn:ietf:wg:oauth:2.0:oob&grant_type=authorization_code" https://accounts.google.com/o/oauth2/token > ${TMPDIR}/pgclone.info

accesstoken=$(cat ${TMPDIR}/pgclone.info | grep access_token | awk '{print $2}')
ramdom=$(head /dev/urandom | tr -dc A-Za-z | head -c 8 > ${TMPDIR}/pgclone.chaine)
chaine=$(cat ${TMPDIR}/pgclone.chaine)

  curl --request POST \
    "https://www.googleapis.com/drive/v3/teamdrives?requestId='$chaine" \
    --header "Authorization: Bearer ${accesstoken}" \
    --header 'Accept: application/json' \
    --header 'Content-Type: application/json' \
    --data '{"name":"'$nom'"}' \
    --compressed > ${TMPDIR}/teamdrive.output

#####################
secret=$(cat ${TMPDIR}/pgclone.secret)
public=$(cat ${TMPDIR}/pgclone.public)
cat ${TMPDIR}/teamdrive.output | grep "id" | awk '{ print $2 }' | cut -c2- | rev | cut -c3- | rev > ${TMPDIR}/teamdrive.id
cat ${TMPDIR}/teamdrive.output | grep "name" | awk '{ print $2 }' | cut -c2- | rev | cut -c2- | rev > ${TMPDIR}/teamdrive.name
name=$(sed -n ${typed}p ${TMPDIR}/teamdrive.name)
id=$(sed -n ${typed}p ${TMPDIR}/teamdrive.id)
echo "$name" > ${TMPDIR}/pgclone.teamdrive
echo "$id" > ${TMPDIR}/pgclone.teamid
#####################

echo ""

echo -e "${BLUE}-----------------------------------------------------------${CEND}"
echo -e "${CGREEN} 🌎 Primary Password ~ https://github.com/projetssd/ssdv2${CEND}"
echo -e "${BLUE}-----------------------------------------------------------${CEND}"

echo ""
read -p $'\e[36m↘️ Taper votre Password au choix | Appuyer [ENTER]: \e[0m' typed < /dev/tty

primarypassword=$typed

echo ""

echo -e "${BLUE}---------------------------------------------------------------${CEND}"
echo -e "${CGREEN} 🌎 SALT (SALT Password) ~ https://github.com/projetssd/ssdv2${CEND}"
echo -e "${BLUE}---------------------------------------------------------------${CEND}"

echo -e "${BWHITE}
NOTE: Ne pas utiliser le même mot de passe!

Définissez un mot de passe SALT pour le cryptage des données! 
N'OUBLIEZ PAS le mot de passe! Sinon vous ne pourrez pas récupérer vos données!
C'est le principal risque du cryptage!${CEND}"

echo ""

read -p $'\e[36m↘️ Taper SALT Password | Appuyer [ENTER]: \e[0m' typed < /dev/tty

secondarypassword=$typed

echo ""

echo -e "${BLUE}----------------------------------------------------${CEND}"
echo -e "${CGREEN} 🌎 Passwords ~ https://github.com/projetssd/ssdv2${CEND}"
echo -e "${BLUE}----------------------------------------------------${CEND}"

echo -e "${BWHITE}
Primary: $primarypassword
SALT   : $secondarypassword
${CEND}"

echo $primarypassword > ${TMPDIR}/pgclone.password
echo $secondarypassword > ${TMPDIR}/pgclone.salt

echo -e "${BLUE}-------------------------------------------------------------${CEND}"
echo -e "${CGREEN} 🌎 Procédure Complète ~ https://github.com/projetssd/ssdv2${CEND}"
echo -e "${BLUE}-------------------------------------------------------------${CEND}"

echo ""
echo -e "${BWHITE}
💬  Password & SALT sont maintenant actifs, ne les oubliez pas!!${CEND}"

pgclonepublic=$(cat ${TMPDIR}/pgclone.public)
pgclonesecret=$(cat ${TMPDIR}/pgclone.secret)

echo ""

echo -e "${BLUE}------------------------------------------------------${CEND}"
echo -e "${CGREEN} 🚀 Google Auth ~ https://github.com/projetssd/ssdv2${CEND}"
echo -e "${BLUE}------------------------------------------------------${CEND}"

echo -e "${BWHITE}
https://accounts.google.com/o/oauth2/auth?client_id=$pgclonepublic&redirect_uri=urn:ietf:wg:oauth:2.0:oob&scope=https://www.googleapis.com/auth/drive&response_type=code

Copiez et collez à nouveau l'URL dans le navigateur! Assurez-vous d'utiliser et de vous connecter avec
le bon compte Google!${CEND}"

echo ""

read -p $'\e[36m↘️ Coller le Token | Appuyer sur [Enter]: \e[0m' token < /dev/tty

  curl --request POST --data "code=$token&client_id=$pgclonepublic&client_secret=$pgclonesecret&redirect_uri=urn:ietf:wg:oauth:2.0:oob&grant_type=authorization_code" https://accounts.google.com/o/oauth2/token > ${TMPDIR}/pgclone.info

  accesstoken=$(cat ${TMPDIR}/pgclone.info | grep access_token | awk '{print $2}')
  refreshtoken=$(cat ${TMPDIR}/pgclone.info | grep refresh_token | awk '{print $2}')
  rcdate=$(date +'%Y-%m-%d')
  rctime=$(date +"%H:%M:%S" --date="$givenDate 60 minutes")
  rczone=$(date +"%:z")
  final=$(echo "${rcdate}T${rctime}${rczone}")
  nom=$(cat ${TMPDIR}/pgclone.nom)

########################

echo "" >> ${RCLONE_CONFIG_FILE}
echo "[$nom]" >> ${RCLONE_CONFIG_FILE}
echo "client_id = $pgclonepublic" >> ${RCLONE_CONFIG_FILE}
echo "client_secret = $pgclonesecret" >> ${RCLONE_CONFIG_FILE}
echo "type = drive" >> ${RCLONE_CONFIG_FILE}
echo "scope = drive" >> ${RCLONE_CONFIG_FILE}
echo -n "token = {\"access_token\":${accesstoken}\"token_type\":\"Bearer\",\"refresh_token\":${refreshtoken}\"expiry\":\"${final}\"}" >> ${RCLONE_CONFIG_FILE}
echo "" >> ${RCLONE_CONFIG_FILE}
teamid=$(cat ${TMPDIR}/pgclone.teamid)
echo "team_drive = $teamid" >> ${RCLONE_CONFIG_FILE}
echo ""

## Ajout du crypt

PASSWORD=`cat ${TMPDIR}/pgclone.password`
SALT=`cat ${TMPDIR}/pgclone.salt`
ENC_PASSWORD=`rclone obscure "$PASSWORD"`
ENC_SALT=`rclone obscure "$SALT"`
crypt="_crypt"

echo "" >> ${RCLONE_CONFIG_FILE}
echo "[$name$crypt]" >> ${RCLONE_CONFIG_FILE}
echo "type = crypt" >> ${RCLONE_CONFIG_FILE}
echo "remote = $nom:/Medias" >> ${RCLONE_CONFIG_FILE}
echo "filename_encryption = standard" >> ${RCLONE_CONFIG_FILE}
echo "directory_name_encryption = true" >> ${RCLONE_CONFIG_FILE}
echo "password = $ENC_PASSWORD" >> ${RCLONE_CONFIG_FILE}
echo "password2 = $ENC_SALT" >> ${RCLONE_CONFIG_FILE};

echo ""

echo -e "${BLUE}-------------------------------------------------------------${CEND}"
echo -e "${CGREEN} 🌎 Procédure Terminée ~ https://github.com/projetssd/ssdv2${CEND}"
echo -e "${BLUE}-------------------------------------------------------------${CEND}"

echo -e "${BWHITE}
💬  [sharedrive] est maintenant créé et opérationnel! le rclone.conf également!${CEND}"

rm -rf ${TMPDIR}
