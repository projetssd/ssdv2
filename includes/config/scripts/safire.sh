#!/bin/bash

source includes/functions.sh
source includes/variables.sh

    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"
    	echo -e "${CCYAN}          /!\ Installation de safire /!\                                     ${CEND}"
    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"
	echo ""
    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"
    	echo -e "${CCYAN}https://github.com/laster13/patxav/wiki/Installations-Comptes-de-Service     ${CEND}"
    	echo -e "${CCYAN}           https://github.com/88lex/safire                                   ${CEND}"
    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"
clear
echo ""
echo -e "${YELLOW}/!\ IMPORTANT /!\ ${CEND}

${YELLOW}1. ${CEND}""${GREEN}Créer un groupe. Go to groups.google.com et créer un groupe sur ce modèle group_name@googlegroups.com
   ou group_name@domaine.com si vous êtes admin du Gsuite (https://admin.google.com/ac/groups)

   Admin: Vous pouvez ajouter en masse les adresses mails.
   Utilisateurs: Vous Pouvez les ajouter par tranche de 100 à la fois.

${YELLOW}2. ${CEND}""${GREEN}Ajouter le groupe à votre source et destination Team Drives et/ou My Drive, click droit sur le teamdrive/my drive --> Partage.

${CEND}"
pause
echo ""
git clone https://github.com/88lex/safire.git /opt/safire
cd /opt/safire
pip install -r requirements.txt
echo ""
ansible-playbook /opt/seedbox-compose/includes/config/roles/safire/tasks/main.yml
echo ""
echo -e "${YELLOW}/!\ VERIFICATION /!\:${CEND}

${CCYAN}Les 3 commandes ci dessous vont vous permettre de vérifier si les comptes de service sont fonctionnels

${GREEN}rclone lsd remote: --drive-service-account-file=/opt/sa/NUMBER.json
${GREEN}rclone touch remote:test123.txt --drive-service-account-file=/opt/sa/NUMBER.json
${GREEN}rclone deletefile remote:test123.txt --drive-service-account-file=/opt/sa/NUMBER.json
${CEND}"

    	echo -e "${CRED}---------------------------------------------------------------${CEND}"
    	echo -e "${CRED}     /!\ SAFIRE INSTALLES AVEC SUCCES /!\          ${CEND}"
    	echo -e "${CRED}---------------------------------------------------------------${CEND}"

echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
read -r
