#!/bin/bash

source includes/functions.sh
source includes/variables.sh

## Variable
SEEDUSER=$(cat /etc/passwd | tail -1 | cut -d: -f1)
DOMAIN=$(cat /home/$SEEDUSER/resume | tail -1 | cut -d. -f2-3)
INSTALLEDFILE="/home/$SEEDUSER/resume"

    	echo -e "${CRED}---------------------------------------------------------------${CEND}"
    	echo -e "${CRED}     		/!\ CREATION APPLI DOCKER /!\		       ${CEND}"
    	echo -e "${CRED}---------------------------------------------------------------${CEND}"
	echo ""

## Définir le nom de l'appli, le port et l'image docker

if [ -z "$appli" ] || [ -z "$port" ] || [ -z "$image" ]; then
    appli=$1
    port=$2
    image=$3
    bd=$3
fi

while [ -z "$appli" ]; do
    >&2 echo -n -e "${BWHITE}Votre nouvelle Application (en minuscule): ${CEND}"
    read appli
    echo $appli > /opt/seedbox/variables/appli
done

while [ -z "$port" ]; do
    >&2 echo -n -e "${BWHITE}Le port utilisé par l'appli: ${CEND}"
    read port
    echo $port > /opt/seedbox/variables/port
done

while [ -z "$image" ]; do
    >&2 echo -n -e "${BWHITE}L'image Docker: ${CEND}"
    read image
    echo $image > /opt/seedbox/variables/image
done

>&2 echo -n -e "${BWHITE}Est ce qu'une base de donnée est nécessaire ? (o/n) : ${CEND}"
read reponse
if [[ "$reponse" = "o" ]] || [[ "$reponse" = "O" ]]; then
    ## Déplacement de l'appli dans le dossier conf
    cp "/opt/seedbox-compose/includes/dockerapps/modelebd.yml" "/opt/seedbox/conf/$appli.yml"
else
    cp "/opt/seedbox-compose/includes/dockerapps/modele.yml" "/opt/seedbox/conf/$appli.yml"
fi


## Installation de l'appli
ansible-playbook /opt/seedbox/conf/$appli.yml
FQDNTMP="$appli.$DOMAIN"
echo "$FQDNTMP" >> $INSTALLEDFILE
rm /opt/seedbox/variables/image
rm /opt/seedbox/variables/port
rm /opt/seedbox/variables/appli
    echo ""
    echo -e "${CRED}------------------------------------------------------------------${CEND}"
    echo -e "${CRED}        INSTALLATION DE L'APPLI $appli TERMINEE		      ${CEND}"
    echo -e "${CRED}------------------------------------------------------------------${CEND}"
echo ""
resume_seedbox

    echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
    read -r

