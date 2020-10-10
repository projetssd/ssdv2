#!/bin/bash

source includes/functions.sh
source includes/variables.sh

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

${YELLOW}3. ${CEND}""${GREEN}Ajouter le groupe à votre source et destination Team Drives et/ou My Drive, click droit sur le teamdrive/my drive --> Partage.

${YELLOW}4. ${CEND}""${CRED}Je vous conseille de vous mettre à jour avec les pré-requis avant de poursuivre.

${YELLOW}5. ${CEND}""${CRED}rclone.conf doit contenir le nouveau remote sharedrive.

${CEND}"

ansible-vault decrypt /opt/seedbox/variables/account.yml > /dev/null 2>&1

sed -i '/#Debut team source/,/#Fin team source/d' /root/.config/rclone/rclone.conf > /dev/null 2>&1
sed -i '/share_source/d' /opt/seedbox/variables/account.yml > /dev/null 2>&1
sed -i '/My_drive/d' /opt/seedbox/variables/account.yml > /dev/null 2>&1

read -rp $'\e[36m   Souhaitez vous poursuivre l installation: (o/n) ? \e[0m' OUI

if [[ "$OUI" = "o" ]] || [[ "$OUI" = "O" ]]; then
  echo ""

  if [[ ! -d "/opt/sa" ]]; then
    /opt/seedbox-compose/includes/config/scripts/sa-gen.sh
  fi

  if [[ ! -d "/opt/sasync" ]]; then
    git clone https://github.com/88lex/sasync.git /opt/sasync
  fi

  i=1
  sed -i '/My_drive/d' /opt/seedbox/variables/account.yml > /dev/null 2>&1
  echo -e " ${BWHITE}* Liste des remotes disponibles${NC}"

  grep "token" /root/.config/rclone/rclone.conf | uniq > /tmp/temp.txt
  if [ $? -eq 0 ]; then
      while read line; do
        grep "token" /root/.config/rclone/rclone.conf > /dev/null 2>&1
        if [ $? -eq 0 ]; then
         drive=$(grep -iC 5 "$line" /root/.config/rclone/rclone.conf | head -n 1 | sed "s/\[//g" | sed "s/\]//g")
         echo "$drive" >> /tmp/drive.txt
        fi
        echo -e "${CGREEN}   $i. $drive${CEND}"
        let "i+=1"
      done < /tmp/temp.txt
   echo ""
  else
    echo -e " ${BWHITE}* Aucun Drive perso détecté${NC}"
    echo ""
    exit
  fi

## drive perso
  nombre=$(wc -l /tmp/drive.txt | cut -d ' ' -f1)

  while :
  do
  read -rp $'\e[36m   Choisir le Gdrive source: \e[0m' RTYPE
    if [ "$RTYPE" -le "$nombre" -a "$RTYPE" -ge "1"  ]; then
   break
  else
  echo -e " ${CRED}* /!\ erreur de saisie /!\{NC}"
  echo ""
  fi
  done

  ## Variables
  My_drive=$(sed -n "$RTYPE"p /tmp/drive.txt)
  i=1
  ## drive perso
  echo ""
  sed -i "/remote/a \ \ \ My_drive: $My_drive" /opt/seedbox/variables/account.yml > /dev/null 2>&1
  sed -i '/#Debut team source/,/#Fin team source/d' /root/.config/rclone/rclone.conf > /dev/null 2>&1
  sed -i '/share_source/d' /opt/seedbox/variables/account.yml > /dev/null 2>&1
  grep "team_drive" /root/.config/rclone/rclone.conf | uniq > /tmp/crop.txt
  grep "team_drive" /root/.config/rclone/rclone.conf > /dev/null 2>&1

  if [ $? -eq 0 ]; then
    echo -e " ${BWHITE}* Teamdrives disponibles${NC}"
    echo ""
      while read line; do
        team=$(grep -iC 6 "$line" /root/.config/rclone/rclone.conf | head -n 1 | sed "s/\[//g" | sed "s/\]//g")
        echo "$team" >> /tmp/team.txt
        echo -e "${CGREEN}   $i. $team${CEND}"
        let "i+=1"
      done < /tmp/crop.txt
    echo ""
  else
    echo -e " ${BWHITE}* Aucun teamdrive/share drive détecté${NC}"
    echo ""
    exit
  fi
 
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
  echo -e "${CCYAN}   Destination : ${CGREEN}$teamdrive_sce --> $teamdrive_a${CEND}"
  id=$(sed -n "$i"p /tmp/crop.txt)
  echo -e "#Debut team source\n[$teamdrive_sce$source] \ntype = drive\nscope = drive\nserver_side_across_configs = true\nservice_account_file_path = /opt/sa/\nservice_account_file = /opt/sa/1.json\n$id\n#Fin team source\n" >> /root/.config/rclone/rclone.conf
  sed -i "/remote/a \ \ \ share_source: $teamdrive_sce$source" /opt/seedbox/variables/account.yml
  echo ""

  ansible-playbook /opt/seedbox-compose/includes/config/roles/sasync/tasks/main.yml
  echo ""

    	echo -e "${CRED}---------------------------------------------------------------${CEND}"
    	echo -e "${CRED}     /!\ COMPTES DE SERVICE INSTALLES AVEC SUCCES /!\          ${CEND}"
    	echo -e "${CRED}---------------------------------------------------------------${CEND}"
  
  rm /tmp/temp.txt /tmp/drive.txt
  rm /tmp/crop.txt /tmp/team.txt
  echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour revenir au menu principal..."
  read -r
  ansible-vault encrypt /opt/seedbox/variables/account.yml > /dev/null 2>&1
  ## Lancement de la synchro
  cd /opt/sasync
  ./sasync -l set.file
fi
