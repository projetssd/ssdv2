#!/bin/bash

source includes/functions.sh
source includes/variables.sh

rm /tmp/temp.txt /tmp/drive.txt > /dev/null 2>&1
rm /tmp/crop.txt /tmp/team.txt > /dev/null 2>&1



    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"
    	echo -e "${CCYAN}          /!\ Migration Gdrive vers ShareDrive /!\                           ${CEND}"
    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"
	echo ""
    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"
    	echo -e "${CCYAN}https://github.com/laster13/patxav/wiki/Installations-Comptes-de-Service     ${CEND}"
    	echo -e "${CCYAN}           https://github.com/88lex/sasync                                   ${CEND}"
    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"

echo -e "${YELLOW}/!\ PRE REQUIS IMPORTANT/!\ ${CEND}"

echo -e "${CGREEN}
Pour des contraintes liées aux quotas Google il est préconisé de créer un Share Drive sur le même compte que Gdrive 
Il est primordial de monter le rclone.conf du Share Drive avec le même projet et identifiants que ceux qui ont servi 
pour Gdrive${CEND}"

ansible-vault decrypt /opt/seedbox/variables/account.yml > /dev/null 2>&1

echo ""

read -rp $'\e[36m   Souhaitez vous poursuivre l installation: (o/n) ? \e[0m' OUI

if [[ "$OUI" = "o" ]] || [[ "$OUI" = "O" ]]; then
  echo ""
  i=1
  grep "root_folder_id = ." /root/.config/rclone/rclone.conf | uniq > /tmp/temp.txt
  grep "root_folder_id = ." /root/.config/rclone/rclone.conf > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo -e " ${BWHITE}* Gdrive disponibles${NC}"
      while read line; do
        grep "root_folder_id = ." /root/.config/rclone/rclone.conf > /dev/null 2>&1
        if [ $? -eq 0 ]; then
         drive=$(grep -iC 6 "$line" /root/.config/rclone/rclone.conf | head -n 1 | sed "s/\[//g" | sed "s/\]//g")
         echo "$drive" >> /tmp/drive.txt
        fi
        echo -e "${CGREEN}   $i. $drive${CEND}"
        let "i+=1"
      done < /tmp/temp.txt
  else
    echo -e " ${BWHITE}* Aucun Gdrive détecté${NC}"
    exit 1
  fi

## Gdrive
  nombre=$(wc -l /tmp/drive.txt | cut -d ' ' -f1)
  echo ""
  while :
  do
  read -rp $'\e[36m   Choisir le Gdrive parmis la liste des remotes: \e[0m' RTYPE
    if [ "$RTYPE" -le "$nombre" -a "$RTYPE" -ge "1"  ]; then
   break
  else
  echo -e " ${CRED}* /!\ erreur de saisie /!\{NC}"
  echo ""
  fi
  done

  ## Variables
  gdrive=$(sed -n "$RTYPE"p /tmp/drive.txt)
  i=1

  grep "team_drive" /root/.config/rclone/rclone.conf | uniq > /tmp/crop.txt
  grep "team_drive" /root/.config/rclone/rclone.conf > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo ""
    echo -e " ${BWHITE}* Share Drive disponibles${NC}"
      while read line; do
        team=$(grep -iC 6 "$line" /root/.config/rclone/rclone.conf | head -n 1 | sed "s/\[//g" | sed "s/\]//g")
        echo "$team" >> /tmp/team.txt
        echo -e "${CGREEN}   $i. $team${CEND}"
        let "i+=1"
      done < /tmp/crop.txt
    echo ""
  else
    echo -e " ${BWHITE}* Aucun Share Drive détecté${NC}"
    exit 1
  fi

## sharedrive
  nombre=$(wc -l /tmp/team.txt | cut -d ' ' -f1)
  while :
  do
  read -rp $'\e[36m   Choisir le Share Drive de destination: \e[0m' RTYPE
    if [ "$RTYPE" -le "$nombre" -a "$RTYPE" -ge "1"  ]; then
   break
    else
      echo -e " ${CRED}* /!\ erreur de saisie /!\{NC}"
      echo ""
   fi
  done
  sharedrive=$(sed -n "$RTYPE"p /tmp/team.txt)
echo ""
echo -e "${CGREEN}Déplacement des données de Gdrive: $drive vers Share Drive: $sharedrive${CEND}"
echo ""
rclone move $drive: $sharedrive: -v \
--delete-empty-src-dirs --fast-list --drive-stop-on-upload-limit \
--drive-server-side-across-configs \
--config /root/.config/rclone/rclone.conf
fi
