#!/bin/bash

source ${SETTINGS_SOURCE}/profile.sh

clear

logo

## Variable

oauth_client=$1
oauth_secret=$2
email=$3

echo -e "${BLUE}###" $(gettext "OAuth2 Proxy avec Traefik – Secure SSO pour les services Docker") "###${NC}"
echo ""
echo -e "${CCYAN}------------------------------------------------------------------${CEND}"
echo -e "${CCYAN}"$(gettext "Protocole d'identification via Google OAuth2 (OAuth2 Proxy)") "${CEND}"
echo -e "${CCYAN}"$(gettext "Securisation SSO pour les services Docker") "${CEND}"
echo -e "${CCYAN}------------------------------------------------------------------${CEND}"
echo ""
echo -e "${CRED}------------------------------------------------------------------${CEND}"
echo -e "${CRED}IMPORTANT: $(gettext "Au préalable créer un projet et vos identifiants")${CEND}"
echo -e "${CRED}https://github.com/laster13/patxav/wiki${CEND}"
echo -e "${CRED}------------------------------------------------------------------${CEND}"
echo ""

while [ -z "$oauth_client" ]; do
  >&2 echo -n -e "${BWHITE}Oauth_client: ${CEND}"
  read oauth_client
  manage_account_yml oauth2proxy.client $oauth_client
done

while [ -z "$oauth_secret" ]; do
  >&2 echo -n -e "${BWHITE}Oauth_secret: ${CEND}"
  read oauth_secret
  manage_account_yml oauth2proxy.secret $oauth_secret
done

while [ -z "$email" ]; do
  echo >&2 -n -e "${BWHITE}$(gettext "Compte Gmail utilisé(s), séparés d'une virgule si plusieurs:") ${CEND}"
  read email
  manage_account_yml oauth2proxy.account $email
done

openssl=$(openssl rand -hex 16)
manage_account_yml oauth2proxy.openssl $openssl

# ⭐ Créer le répertoire et le fichier emails.txt

echo -e "${CCYAN}$(gettext "Création du fichier whitelist emails pour OAuth2 Proxy...")${CEND}"

sudo mkdir -p /etc/oauth2_proxy

echo "$email" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sudo tee /etc/oauth2_proxy/emails.txt > /dev/null

sudo chmod 644 /etc/oauth2_proxy/emails.txt

echo -e "${CGREEN}✓ $(gettext "Fichier emails.txt créé avec succès")${CEND}"

# Écrire le type OAuth2 Proxy

manage_account_yml oauth_type "oauth2-proxy"
manage_account_yml oauth_enabled "true"

## reinstallation traefik

echo ""
suppression_appli traefik
install_traefik

echo -e "${CRED}---------------------------------------------------------------${CEND}"
echo -e "${CRED}$(gettext "OAuth2 Proxy installé et configuré")${CEND}"
echo -e "${CCYAN}$(gettext "Vérifier le service : docker ps | grep oauth2-proxy")${CEND}"
echo -e "${CRED}---------------------------------------------------------------${CEND}"
echo ""

echo -e "${CRED}---------------------------------------------------------------${CEND}"
echo -e "${CCYAN}IMPORTANT: $(gettext "Avant la 1ere connexion")${CEND}"
echo -e "${CCYAN}- $(gettext "Nettoyer l'historique de votre navigateur")${CEND}"
echo -e "${CCYAN}- $(gettext "Déconnexion de tout compte google")${CEND}"
echo -e "${CRED}---------------------------------------------------------------${CEND}"
echo ""

echo -e "${CCYAN}$(gettext "Appuyer sur") [ENTREE]${CEND} $(gettext "pour continuer")${CEND}"
read -r
