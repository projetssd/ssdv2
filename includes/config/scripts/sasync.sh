#!/bin/bash

source includes/functions.sh
source includes/variables.sh

    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"
    	echo -e "${CCYAN}          /!\ Installation de Sasync /!\                                     ${CEND}"
    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"
	echo ""
    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"
    	echo -e "${CCYAN}https://github.com/laster13/patxav/wiki/Installations-Comptes-de-Service     ${CEND}"
    	echo -e "${CCYAN}           https://github.com/88lex/sasync                                   ${CEND}"
    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"

echo ""
ansible-vault decrypt /opt/seedbox/variables/account.yml > /dev/null 2>&1

if [[ ! -d "/opt/sasync" ]]; then
git clone -b develop https://github.com/88lex/sasync.git /opt/sasync
fi
echo ""
i=1
sed -i '/My_drive/d' /opt/seedbox/variables/account.yml > /dev/null 2>&1
grep "root_folder_id" /root/.config/rclone/rclone.conf | uniq > /tmp/temp.txt
grep "root_folder_id" /root/.config/rclone/rclone.conf > /dev/null 2>&1

if [ $? -eq 0 ]; then
  echo -e " ${BWHITE}* remotes disponibles${NC}"
  echo ""
    while read line; do
      drive=$(grep -iC 6 "$line" /root/.config/rclone/rclone.conf | head -n 1 | sed "s/\[//g" | sed "s/\]//g")
      echo "$drive" >> /tmp/drive.txt
      echo -e "${CGREEN}   $i. $drive${CEND}"
      let "i+=1"
    done < /tmp/temp.txt
    echo ""
echo ""
else
echo -e " ${BWHITE}* Aucun Drive perso détecté${NC}"
echo ""
exit
fi


## drive perso
read -rp $'\e[36m   Choisir le remote Drive perso: \e[0m' RTYPE
## Variables
i="$RTYPE"
My_drive=$(sed -n "$i"p /tmp/drive.txt)

## drive perso
echo ""
sed -i "/remote/a \ \ \ My_drive: $My_drive" /opt/seedbox/variables/account.yml > /dev/null 2>&1

i=1
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

  read -rp $'\e[36m   Choisir le stockage principal: \e[0m' RTYPE

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
  echo -e "#Debut team source\n[$teamdrive_sce$source] \ntype = drive\nscope = drive\nserver_side_across_configs = true\nservice_account_file_path = /opt/sa/\nservice_account_file = /opt/sa/1.json\n$id\n#Fin team source\n" >> /root/.config/rclone/rclone.conf
  sed -i "/plexdrive/a \ \ \ share_source: $teamdrive_sce$source" /opt/seedbox/variables/account.yml
  echo ""

ansible-playbook /opt/seedbox-compose/includes/config/roles/sasync/tasks/main.yml
echo ""

    	echo -e "${CRED}---------------------------------------------------------------${CEND}"
    	echo -e "${CRED}     /!\ COMPTES DE SERVICE INSTALLES AVEC SUCCES /!\          ${CEND}"
    	echo -e "${CRED}---------------------------------------------------------------${CEND}"

echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
read -r
ansible-vault encrypt /opt/seedbox/variables/account.yml > /dev/null 2>&1
rm /tmp/temp.txt /tmp/drive.txt
rm /tmp/crop.txt /tmp/team.txt
## Lancement de la synchro
cd /opt/sasync
./sasync -g set.file
