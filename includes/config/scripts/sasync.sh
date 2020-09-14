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
clear
echo ""
echo -e "${YELLOW}/!\ IMPORTANT /!\ ${CEND}

${YELLOW}1. ${CEND}""${GREEN}Créer un groupe. Go to groups.google.com et créer un groupe sur ce modèle group_name@googlegroups.com
   ou group_name@domaine.com si vous êtes admin du Gsuite (https://admin.google.com/ac/groups)

${YELLOW}2. ${CEND}""${GREEN}Vérifier la présence des fichiers jsons dans le dossier /opt/sa, sinon créer au préalables les SA avec gen_sa!!
   Servez vous du fichier members.csv pour ajouter les adresses mail au groupe précédemment créé

   Admin: Vous pouvez ajouter en masse les adresses mails.
   Utilisateurs: Vous Pouvez les ajouter par tranche de 100 à la fois.

${YELLOW}3. ${CEND}""${GREEN}Ajouter le groupe à votre source et destination Team Drives et/ou My Drive, click droit sur le teamdrive/my drive --> Partage.
${CEND}"
pause
echo ""
git clone -b develop https://github.com/88lex/sasync.git /opt/sasync
echo ""
ansible-vault decrypt /opt/seedbox/variables/account.yml > /dev/null 2>&1
i=1
sed -i '/#Debut team source/,/#Fin team source/d' /root/.config/rclone/rclone.conf > /dev/null 2>&1
sed -i '/share\_source/d' /opt/seedbox/variables/account.yml > /dev/null 2>&1
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
  echo -e "#Debut team source\n[$teamdrive_sce$source] \ntype = drive\nscope = drive\nserver_side_across_configs = true\nservice_account_file_path = /opt/sa/\nservice_account_file = /opt/sa/1.json\n$id\n#Fin team source" >> /root/.config/rclone/rclone.conf
  sed -i "/plexdrive/a \ \ \ share_source: $teamdrive_sce$source" /opt/seedbox/variables/account.yml
  echo ""
sleep 5s
echo ""

ansible-playbook /opt/seedbox-compose/includes/config/roles/sasync/tasks/main.yml
echo ""
echo ""
echo -e "${YELLOW}/!\ VERIFICATION /!\:${CEND}

${CCYAN}Les 3 commandes ci dessous vont vous permettre de vérifier si les comptes de service sont fonctionnels

${GREEN}rclone lsd remote: --drive-service-account-file=/opt/sa/NUMBER.json
${GREEN}rclone touch remote:test123.txt --drive-service-account-file=/opt/sa/NUMBER.json
${GREEN}rclone deletefile remote:test123.txt --drive-service-account-file=/opt/sa/NUMBER.json

${CCYAN}si tout est ok vous pouvez lancer la copy
${CCYAN}/opt/sasync/sasync -g set.file
${CEND}"

    	echo -e "${CRED}---------------------------------------------------------------${CEND}"
    	echo -e "${CRED}     /!\ COMPTES DE SERVICE INSTALLES AVEC SUCCES /!\          ${CEND}"
    	echo -e "${CRED}---------------------------------------------------------------${CEND}"

echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
read -r
ansible-vault encrypt /opt/seedbox/variables/account.yml > /dev/null 2>&1
