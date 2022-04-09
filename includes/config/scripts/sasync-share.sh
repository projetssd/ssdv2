#!/bin/bash

source /opt/seedbox-compose/includes/functions.sh
source /opt/seedbox-compose/includes/variables.sh

RCLONE_CONFIG_FILE=${HOME}/.config/rclone/rclone.conf

    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"
    	echo -e "${CCYAN}          /!\ Création des SA-Installation de Sasync /!\                     ${CEND}"
    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"
	echo ""
    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"
    	echo -e "${CCYAN}https://github.com/laster13/patxav/wiki/Installations-Comptes-de-Service     ${CEND}"
    	echo -e "${CCYAN}           https://github.com/88lex/sasync                                   ${CEND}"
    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"

echo -e "${YELLOW}/!\ PRE REQUIS IMPORTANT: RAPPEL /!\ ${CEND}

${YELLOW}1. ${CEND}""${GREEN}Créer un groupe. Go to groups.google.com et créer un groupe sur ce modèle group_name@googlegroups.com
   ou group_name@domaine.com si vous êtes admin du Gsuite (https://admin.google.com/ac/groups)

${YELLOW}2. ${CEND}""${GREEN}Une fois le script terminé vérifier la présence des fichiers jsons dans le dossier /opt/sa
   Servez vous du fichier members.csv pour ajouter les adresses mail au groupe précédemment créé

   Admin: Vous pouvez ajouter en masse les adresses mails.
   Utilisateurs: Vous Pouvez les ajouter par tranche de 100 à la fois.

${YELLOW}3. ${CEND}""${GREEN}Ajouter le groupe à votre source et destination Share Drive et/ou GDrive, click droit sur le Share Drive/GDrive --> Partage.

${YELLOW}4. ${CEND}""${CRED}Je vous conseille de vous mettre à jour avec les pré-requis avant de poursuivre.

${YELLOW}5. ${CEND}""${CRED}rclone.conf doit contenir le nouveau remote sharedrive.

${CEND}"

rm /tmp/team.txt /tmp/crop.txt > /dev/null 2>&1


read -rp $'\e[36m   Souhaitez vous poursuivre l installation: (o/n) ? \e[0m' OUI

if [[ "$OUI" = "o" ]] || [[ "$OUI" = "O" ]]; then
  if [[ ! -d "/opt/sasync" ]]; then
    git clone https://github.com/88lex/sasync.git /opt/sasync > /dev/null 2>&1
  fi

echo ""

read -rp $'\e[36m   Souhaitez vous créer un Share Drive?: (o/n) ? \e[0m' OUI

if [[ "$OUI" = "o" ]] || [[ "$OUI" = "O" ]]; then
/opt/seedbox-compose/includes/config/scripts/createrclone.sh
fi
echo ""

if [[ ! -d "/opt/sa" ]]; then
  read -rp $'\e[36m   Souhaitez vous créer des comptes de services: (o/n) ? \e[0m' OUI
  if [[ "$OUI" = "o" ]] || [[ "$OUI" = "O" ]]; then
    /opt/seedbox-compose/includes/config/scripts/sa-gen.sh
  fi
echo ""
fi

i=1
grep "team_drive" ${RCLONE_CONFIG_FILE} | uniq > /tmp/crop.txt
grep "team_drive" ${RCLONE_CONFIG_FILE} > /dev/null 2>&1

if [ $? -eq 0 ]; then
  echo -e " ${BWHITE}* Share Drives disponibles${NC}"
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
  echo ""
exit
fi

nombre=$(wc -l /tmp/team.txt | cut -d ' ' -f1)
while :
do
  read -rp $'\e[36m   Choisir le Share Drive Source: \e[0m' RTYPE
  if [ "$RTYPE" -le "$nombre" -a "$RTYPE" -ge "1"  ]; then
    break
  else
    echo -e " ${CRED}* /!\ erreur de saisie /!\{NC}"
    echo ""
  fi
done

## Variables
i="$RTYPE"
teamdrive_sce=$(sed -n "$i"p /tmp/team.txt)
teamdrive_dest=$(sed -n "$i"p /tmp/team.txt)
teamdrive_a=$(sed -n "$i"p /tmp/crop.txt)
teamdrive_b=$(sed -n "$i"p /tmp/crop.txt)
source=_source
dest=_backup
  
## Stockage principal
echo ""
echo -e "${CCYAN}   Source : ${CGREEN}$teamdrive_sce --> $teamdrive_a${CEND}"
id=$(sed -n "$i"p /tmp/crop.txt)
echo -e "#Debut team source\n[$teamdrive_sce$source] \ntype = drive\nscope = drive\nserver_side_across_configs = true\nservice_account_file_path = /opt/sa/\nservice_account_file = /opt/sa/1.json\n$id\n#Fin team source\n" >> ${RCLONE_CONFIG_FILE}
echo ""

if [ "$nombre" -lt 2 ]; then
  exit
else
  while :
  do
  read -rp $'\e[36m   Choisir le Share Drive Destination: \e[0m' RTYPE
    if [ "$RTYPE" -le "$nombre" -a "$RTYPE" -ge "1"  ]; then
      break
    else
      echo -e " ${CRED}* /!\ erreur de saisie /!\{NC}"
      echo ""
    fi
  done
fi

## Variables
j="$RTYPE"
teamdrive_sce=$(sed -n "$j"p /tmp/team.txt)
teamdrive_dest=$(sed -n "$j"p /tmp/team.txt)
teamdrive_a=$(sed -n "$j"p /tmp/crop.txt)
teamdrive_b=$(sed -n "$j"p /tmp/crop.txt)
source=_source
dest=_backup

## Backup
echo ""
echo -e "${CCYAN}   Backup : ${CGREEN}$teamdrive_dest --> $teamdrive_b${CEND}"
id=$(sed -n "$j"p /tmp/crop.txt)
echo -e "#Debut team backup\n[$teamdrive_dest$dest] \ntype = drive\nscope = drive\nserver_side_across_configs = true\nservice_account_file_path = /opt/sa/\nservice_account_file = /opt/sa/1.json\n$id\n#Fin team backup\n" >> ${RCLONE_CONFIG_FILE}
ansible-playbook /opt/seedbox-compose/includes/config/roles/sasync/tasks/main.yml
rm /tmp/team.txt /tmp/crop.txt > /dev/null 2>&1
echo ""

read -rp $'\e[36m   Souhaitez vous lancer la synchro maintenant?: (o/n) ? \e[0m' OUI
  if [[ "$OUI" = "o" ]] || [[ "$OUI" = "O" ]]; then
    docker stop plex
    echo ""
    cd /opt/sasync
    ./sasync -t set.file
    docker start plex
  fi
fi
