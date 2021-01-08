#!/bin/bash

source /opt/seedbox-compose/includes/functions.sh
source /opt/seedbox-compose/includes/variables.sh

RCLONE_CONFIG_FILE=${HOME}/.config/rclone/rclone.conf

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

echo ""
sed -i '/#Debut team source/,/#Fin team source/d' ${RCLONE_CONFIG_FILE} > /dev/null 2>&1
sed -i '/#Debut team backup/,/#Fin team backup/d' ${RCLONE_CONFIG_FILE} > /dev/null 2>&1

read -rp $'\e[36m   Souhaitez vous créer un Share Drive?: (o/n) ? \e[0m' OUI

if [[ "$OUI" = "o" ]] || [[ "$OUI" = "O" ]]; then
/opt/seedbox-compose/includes/config/scripts/createrclone.sh
fi
echo ""

read -rp $'\e[36m   Souhaitez vous poursuivre l installation: (o/n) ? \e[0m' OUI

if [[ "$OUI" = "o" ]] || [[ "$OUI" = "O" ]]; then
  echo ""
i=1
  grep "token" ${RCLONE_CONFIG_FILE} | uniq > /tmp/temp.txt
  grep "token" ${RCLONE_CONFIG_FILE} > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo -e " ${BWHITE}* Remotes disponibles${NC}"
    echo ""
      while read line; do
        grep "token" ${RCLONE_CONFIG_FILE} > /dev/null 2>&1
        if [ $? -eq 0 ]; then
         drive=$(grep -iC 5  "$line" ${RCLONE_CONFIG_FILE} | head -n 1 | sed "s/\[//g" | sed "s/\]//g")
         echo "$drive" >> /tmp/drive.txt
        fi
        echo -e "${CGREEN}   $i. $drive${CEND}"
        let "i+=1"
      done < /tmp/temp.txt
  fi

## Gdrive
  nombre=$(wc -l /tmp/drive.txt | cut -d ' ' -f1)
  echo ""
  while :
  do
  read -rp $'\e[36m   Choisir le Gdrive parmis la liste des remotes: \e[0m' RTYPE
    if [ "$RTYPE" -le "$nombre" -a "$RTYPE" -ge "1"  ]; then
    echo ""
    drive=$(sed -n "$RTYPE"p /tmp/drive.txt)
    echo -e "${CCYAN}   Source : ${CGREEN}$drive${CEND}"
   break
  else
  echo -e " ${CRED}* /!\ erreur de saisie /!\{NC}"
  echo ""
  fi
  done

  ## Variables
  gdrive=$(sed -n "$RTYPE"p /tmp/drive.txt)
  i=1

  grep "team_drive" ${RCLONE_CONFIG_FILE} | uniq > /tmp/crop.txt
  grep "team_drive" ${RCLONE_CONFIG_FILE} > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo ""
    echo -e " ${BWHITE}* Share Drive disponibles${NC}"
    echo ""
      while read line; do
        team=$(grep -iC 6 "$line" ${RCLONE_CONFIG_FILE} | head -n 1 | sed "s/\[//g" | sed "s/\]//g")
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
    echo ""
    echo -e "${CCYAN}   Destination : ${CGREEN}$team${CEND}"
   break
    else
      echo -e " ${CRED}* /!\ erreur de saisie /!\{NC}"
      echo ""
   fi
  done
  sharedrive=$(sed -n "$RTYPE"p /tmp/team.txt)
echo ""
echo -e "${BWHITE}Déplacement des données de Gdrive:${CEND}${CCYAN} $drive${CEND}${BWHITE} vers Share Drive:${CEND}${CCYAN} $sharedrive${CEND}${BWHITE} en cours ...${CEND}"
echo ""
docker stop plex > /dev/null 2>&1
rclone move $drive: $sharedrive: -v \
--delete-empty-src-dirs --fast-list --drive-stop-on-upload-limit \
--drive-server-side-across-configs \
--config ${RCLONE_CONFIG_FILE}
docker start plex > /dev/null 2>&1
fi
