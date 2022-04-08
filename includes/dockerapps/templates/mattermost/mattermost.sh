#!/bin/bash

source ${SETTINGS_SOURCE}/includes/functions.sh
source ${SETTINGS_SOURCE}/includes/variables.sh

##install docker-compose
curl -L "https://github.com/docker/compose/releases/download/1.25.5/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

## clone github mattermost
cd /tmp
git clone https://github.com/mattermost/mattermost-docker.git > /dev/null 2>&1
cd mattermost-docker
docker-compose build
docker network create bridge_mattermost > /dev/null 2>&1
clear
echo ""
echo -e "${BLUE}### INSTALLATION DE MATTERMOST ###${NC}"
echo ""

echo -e "${CCYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
					tee <<-EOF
🚀 Mattermost                           📓 Reference: https://github.com/laster13/patxav
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💬 Exemples de configuration SMTP

Amazon SES

    Set SMTP Username to [YOUR_SMTP_USERNAME]
    Set SMTP Password to [YOUR_SMTP_PASSWORD]
    Set SMTP Server to email-smtp.us-east-1.amazonaws.com
    Set SMTP Port to 465
    Set Connection Security to TLS

Postfix

    Make sure Postfix is installed on the machine where Mattermost is installed
    Set SMTP Username to (empty)
    Set SMTP Password to (empty)
    Set SMTP Server to localhost
    Set SMTP Port to 25
    Set Connection Security to (empty)

Gmail

    Set SMTP Username to your_email@gmail.com
    Set SMTP Password to your_password
    Set SMTP Server to smtp.gmail.com
    Set SMTP Port to 587
    Set Connection Security to STARTTLS

    Gmail necessite une config particuliere --> https://support.google.com/a/answer/2956491?hl=fr

Hotmail

    Set SMTP Username to your_email@hotmail.com
    Set SMTP Password to your_password
    Set SMTP Server to smtp-mail.outlook.com
    Set SMTP Port to 587
    Set Connection Security to STARTTLS

Office365 / Outlook

    Set SMTP Username to your_email@hotmail.com
    Set SMTP Password to your_password
    Set SMTP Server Name to smtp.office365.com
    Set SMTP Port to 587
    Set Connection Security to STARTTLS

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀 Mattermost                           📓 Reference: https://github.com/laster13/patxav
					EOF
echo -e "${CCYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${CCYAN}Au cours de l'installation le script va vous demander le type d'information ci dessus${NC}"
echo -e "\n${CCYAN}Prendre le temps de lire et appuyer ensuite sur la touche entrée${CEND} pour continuer..."
read -r

ansible-playbook ${SETTINGS_SOURCE}/includes/dockerapps/mattermost.yml
