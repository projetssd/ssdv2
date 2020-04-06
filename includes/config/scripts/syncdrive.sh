#!/bin/bash

source includes/functions.sh
source includes/variables.sh

    	echo -e "${CRED}---------------------------------------------------------${CEND}"
    	echo -e "${CCYAN}    /!\ Mise en place synchronisation deux Drives /!\	 ${CEND}"
    	echo -e "${CRED}---------------------------------------------------------${CEND}"
	echo ""


## dechiffrage du fichier account.yml (variables)
ansible-vault decrypt /opt/seedbox/variables/account.yml > /dev/null 2>&1

## récupération du remote (2eme drive)
sed -n -i '1h; 1!H; ${x; s/\n*$//; p}' /root/.config/rclone/rclone.conf > /dev/null 2>&1
remote=$(tac /root/.config/rclone/rclone.conf | grep -A 3 'Medias' | head -3 | tail -1 | sed "s/\[//g" | sed "s/\]//g")

## Mise à jour du fichier account.yml avec rajout de la variable 'drivetwo'
grep -R "drivetwo" "/opt/seedbox/variables/account.yml" > /dev/null 2>&1
if [[ "$?" != "0" ]]; then sed -i -e '/crypt/a\' -e '   drivetwo:' /opt/seedbox/variables/account.yml; fi 
sed -i "/drivetwo:/c\   drivetwo: $remote" /opt/seedbox/variables/account.yml > /dev/null 2>&1

## remplacement du fichier config.json dans cloudplow
ansible-playbook /opt/seedbox-compose/includes/config/roles/cloudplow/tasks/drivetwo.yml

## chiffrement des variables
ansible-vault encrypt /opt/seedbox/variables/account.yml > /dev/null 2>&1

echo ""
    	echo -e "${CRED}------------------------------------------------------------------${CEND}"
    	echo -e "${CCYAN}    /!\ Mise en place synchronisation deux Drives terminée/!\	  ${CEND}"
    	echo -e "${CRED}------------------------------------------------------------------${CEND}"
	echo ""

echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
read -r
