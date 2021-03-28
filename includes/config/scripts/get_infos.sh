#!/bin/bash
########################################
# Gestion des services SSD
########################################
#
# Permet de récupérer des infos
# qui seront traitées par la suite
# TODO : a voir si on passe des parametres
# pour dire quelle info on veut ?
########################################

source ${BASEDIR}/includes/functions.sh
source ${BASEDIR}/includes/variables.sh

echo -e "${BLUE}### INFORMATIONS UTILISATEURS ###${NC}"

ACCOUNT=${CONFDIR}/variables/account.yml

if [ ! -f ${ACCOUNT} ]; then
  cp ${BASEDIR}/includes/config/account.yml ${ACCOUNT}
fi



echo ""
echo -e "${BLUE}L'utilisateur et mot de passe demandés${NC}"
echo -e "${BLUE}serviront à vous authentifier sur les différents services en mode web${NC}"

read -p $'\e[32m↘️ Nom d utilisateur | Appuyer sur [Enter]: \e[0m' user </dev/tty

read -p $'\e[32m↘️ Mot de passe | Appuyer sur [Enter]: \e[0m' pass </dev/tty

read -p $'\e[32m↘️ Mail | Appuyer sur [Enter]: \e[0m' mail </dev/tty
read -p $'\e[32m↘️ Domaine | Appuyer sur [Enter]: \e[0m' domain </dev/tty

echo ""

echo -e "${BLUE}### Gestion des DNS ###${NC}"
echo ""
echo -e "${CCYAN}------------------------------------------------------------------${CEND}"
echo -e "${CCYAN}   CloudFlare protège et accélère les sites internet.             ${CEND}"
echo -e "${CCYAN}   CloudFlare optimise automatiquement la déliverabilité          ${CEND}"
echo -e "${CCYAN}   de vos pages web afin de diminuer le temps de chargement       ${CEND}"
echo -e "${CCYAN}   et d’améliorer les performances. CloudFlare bloque aussi       ${CEND}"
echo -e "${CCYAN}   les menaces et empêche certains robots illégitimes de          ${CEND}"
echo -e "${CCYAN}   consommer votre bande passante et les ressources serveur.      ${CEND}"
echo -e "${CCYAN}------------------------------------------------------------------${CEND}"
echo ""

read -rp $'\e[33mSouhaitez vous utiliser les DNS Cloudflare ? (o/n - default n)\e[0m :' OUI

if [[ "$OUI" == "o" ]] || [[ "$OUI" == "O" ]]; then

  while [ -z "$cloud_email" ]; do
    echo >&2 -n -e "${BWHITE}Votre Email Cloudflare: ${CEND}"
    read cloud_email
  done

  while [ -z "$cloud_api" ]; do
    echo >&2 -n -e "${BWHITE}Votre API Cloudflare: ${CEND}"
    read cloud_api
  done
fi

echo ""
echo -e "${BLUE}### Google OAuth2 avec Traefik – Secure SSO pour les services Docker ###${NC}"
echo ""
echo -e "${CCYAN}------------------------------------------------------------------${CEND}"
echo -e "${CCYAN}    Protocole d'identification via Google OAuth2		   ${CEND}"
echo -e "${CCYAN}    Securisation SSO pour les services Docker			   ${CEND}"
echo -e "${CCYAN}------------------------------------------------------------------${CEND}"
echo ""
echo -e "${CRED}-------------------------------------------------------------------${CEND}"
echo -e "${CRED}    /!\ IMPORTANT: Au préalable créer un projet et vos identifiants${CEND}"
echo -e "${CRED}    https://github.com/laster13/patxav/wiki /!\ 		   ${CEND}"
echo -e "${CRED}-------------------------------------------------------------------${CEND}"
echo ""

read -rp $'\e[33mSouhaitez vous sécuriser vos Applis avec Google OAuth2 ? (o/n - default n)\e[0m :' OUI
if [[ "$OUI" == "o" ]] || [[ "$OUI" == "O" ]]; then
  if [ -z "$oauth_client" ] || [ -z "$oauth_secret" ] || [ -z "$email" ]; then
    oauth_client=$1
    oauth_secret=$2
    email=$3
  fi

  while [ -z "$oauth_client" ]; do
    echo >&2 -n -e "${BWHITE}Oauth_client: ${CEND}"
    read oauth_client
  done

  while [ -z "$oauth_secret" ]; do
    echo >&2 -n -e "${BWHITE}Oauth_secret: ${CEND}"
    read oauth_secret
  done

  while [ -z "$email" ]; do
    echo >&2 -n -e "${BWHITE}Compte Gmail utilisé.s, séparés d une virgule si plusieurs: ${CEND}"
    read email
  done

  echo ""
fi

openssl=$(openssl rand -hex 16)

set -a
echo ""
echo -e "${BWHITE}Adresse par défault: https://gui.$domain ${CEND}"
echo ""
read -rp $'\e[33mSouhaitez vous personnaliser le sous domaine? (o/n - default n)\e[0m :' OUI

if [[ "$OUI" == "o" ]] || [[ "$OUI" == "O" ]]; then
  if [ -z "$subdomain" ]; then
    subdomain=$1
  fi
  while [ -z "$subdomain" ]; do
    echo >&2 -n -e "${BWHITE}Sous Domaine: ${CEND}"
    read subdomain
  done

  echo ""
fi
if [  -z "$subdomain" ]; then
  subdomain=gui
fi
manage_account_yml sub.gui.gui "$subdomain"
set +a
export gui_subdomain=$subdomain

# creation utilisateur
userid=$(id -u)
grpid=$(id -g)
htpasswd -c -b /tmp/.htpasswd $user $pass >/dev/null 2>&1
htpwd=$(cat /tmp/.htpasswd)
echo $pass >~/.vault_pass

# pour l'instant, on laisse tout dans le fichier vault
# a terme, on n'y mettra que les infos sensibles

manage_account_yml user.name "$user"
manage_account_yml user.pass "$pass"
manage_account_yml user.userid "$userid"
manage_account_yml user.groupid "$grpid"
manage_account_yml user.domain "$domain"
manage_account_yml cloudflare.login "$cloud_email"
manage_account_yml cloudflare.api "$cloud_api"
manage_account_yml oauth.client "$oauth_client"
manage_account_yml oauth.secret "$oauth_secret"
manage_account_yml oauth.account "$email"
manage_account_yml user.htpwd "$htpwd"

update_seedbox_param "name" $user
update_seedbox_param "userid" $userid
update_seedbox_param "groupid" $grpid
update_seedbox_param "group" $user
update_seedbox_param "mail" $mail
update_seedbox_param "domain" $domain
update_seedbox_param "cf_login" $cloud_email
update_seedbox_param "oauth2_email" $email
update_seedbox_param "gui_subdomain" $subdomain
