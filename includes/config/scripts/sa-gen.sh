#!/bin/bash

source includes/functions.sh
source includes/variables.sh

    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"
    	echo -e "${CCYAN}          /!\ Installation des services account /!\                          ${CEND}"
    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"
	echo ""
    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"
    	echo -e "${CCYAN}https://github.com/laster13/patxav/wiki/Installations-Comptes-de-Service     ${CEND}"
    	echo -e "${CCYAN}                https://github.com/88lex/sa-gen                              ${CEND}"
    	echo -e "${CRED}------------------------------------------------------------------------------${CEND}"
clear
echo ""
echo -e "${YELLOW}/!\ PRE REQUIS IMPORTANT /!\ ${CEND}

${YELLOW}1. ${CEND}""${GREEN}Créer un groupe. Go to groups.google.com et créer un groupe sur ce modèle group_name@googlegroups.com
   ou group_name@domaine.com si vous êtes admin du Gsuite (https://admin.google.com/ac/groups)

${YELLOW}2. ${CEND}""${GREEN}Une fois le script terminé vérifier la présence des fichiers jsons dans le dossier /opt/sa
   Servez vous du fichier members.csv pour ajouter les adresses mail au groupe précédemment créé

   Admin: Vous pouvez ajouter en masse les adresses mails.
   Utilisateurs: Vous Pouvez les ajouter par tranche de 100 à la fois.

${YELLOW}3. ${CEND}""${GREEN}Ajouter le groupe à votre source et destination Team Drives et/ou My Drive, click droit sur le teamdrive/my drive --> Partage.

${YELLOW}4. ${CEND}""${CRED}Je vous conseille de vous mettre à jour avec les pré-requis avant de poursuivre.
${CEND}"

read -rp $'\e[36m   Souhaitez vous poursuivre l installation: (o/n) ? \e[0m' OUI

if [[ "$OUI" = "o" ]] || [[ "$OUI" = "O" ]]; then

# Add the Cloud SDK distribution URI as a package source
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

# Import the Google Cloud Platform public key
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -

# Update the package list and install the Cloud SDK
apt update && apt install google-cloud-sdk
echo ""
gcloud init
echo ""
git clone https://github.com/88lex/sa-gen.git /opt/gen-sa
echo ""
ansible-playbook /opt/seedbox-compose/includes/config/roles/gen-sa/tasks/main.yml
echo ""
/opt/gen-sa/sa-gen
echo ""
echo -e "${YELLOW}/!\ VERIFICATION /!\:${CEND}

${CCYAN}Les 3 commandes ci dessous vont vous permettre de vérifier si les comptes de service sont fonctionnels

${GREEN}rclone lsd remote: --drive-service-account-file=/opt/sa/NUMBER.json
${GREEN}rclone touch remote:test123.txt --drive-service-account-file=/opt/sa/NUMBER.json
${GREEN}rclone deletefile remote:test123.txt --drive-service-account-file=/opt/sa/NUMBER.json

${CEND}"

    	echo -e "${CRED}---------------------------------------------------------------${CEND}"
    	echo -e "${CRED}     /!\ COMPTES DE SERVICE INSTALLES AVEC SUCCES /!\          ${CEND}"
    	echo -e "${CRED}---------------------------------------------------------------${CEND}"

sleep 5s
fi