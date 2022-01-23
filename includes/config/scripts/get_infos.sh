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

USERNAME=$(get_from_account_yml user.name)
if [ ${USERNAME} == notfound ]; then
  manage_account_yml user.name "${USER}"
  update_seedbox_param "name" ${USER}
else
  echo -e "${BLUE}Username déjà renseigné${CEND}"
  user=${USERNAME}
fi

PASSWORD=$(get_from_account_yml user.pass)
if [ ${PASSWORD} == notfound ]; then
  read -p $'\e[32m↘️ Mot de passe | Appuyer sur [Enter]: \e[0m' pass </dev/tty
  manage_account_yml user.pass "$pass"
else
  echo -e "${BLUE}Password déjà renseigné${CEND}"
  pass=${PASSWORD}
fi

MAIL=$(get_from_account_yml user.mail)
if [ ${MAIL} == notfound ]; then
  read -p $'\e[32m↘️ Mail | Appuyer sur [Enter]: \e[0m' mail </dev/tty
  update_seedbox_param "mail" $mail
  manage_account_yml user.mail $mail
else
  echo -e "${BLUE}Email déjà renseigné${CEND}"
fi

DOMAINE=$(get_from_account_yml user.domain)
if [ ${DOMAINE} == notfound ]; then
  read -p $'\e[32m↘️ Domaine | Appuyer sur [Enter]: \e[0m' domain </dev/tty
  manage_account_yml user.domain "$domain"
  update_seedbox_param "domain" $domain
else
  echo -e "${BLUE}Domaine déjà renseigné${CEND}"
fi
#gestion d'un domaine princ pour la gestion des sous domaines
DOMAIN_PRINC=$(get_from_account_yml user.domainPrinc)
if [ ${DOMAIN_PRINC} == notfound ]; then
  read -p $'\e[32m↘️ Domaine principal | Appuyer sur [Enter]: \e[0m' domainPrinc </dev/tty
  manage_account_yml user.domainPrinc "$domainPrinc"
  update_seedbox_param "domainPrinc" $domainPrinc
else
  echo -e "${BLUE}Domaine principal déjà renseigné${CEND}"
fi
#gestion du sous domaine s'il exsite
SOUS_DOMAINE=$(get_from_account_yml user.sousDomain)
if [ ${SOUS_DOMAINE} == notfound ] && [ ${DOMAINE} -nq ${DOMAIN_PRINC} ]; then
  sousDomain="${DOMAINE//"$DOMAIN_PRINC"}"
  manage_account_yml user.sousDomain "$sousDomain"
  update_seedbox_param "sousDomain" $sousDomain
else if [ ${SOUS_DOMAINE} == notfound ]; then
  sousDomain=""
  manage_account_yml user.sousDomain "$sousDomain"
  update_seedbox_param "sousDomain" $sousDomain
else
  echo -e "${BLUE}Sous domaine déjà renseigné${CEND}"
fi

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

  CLOUD_EMAIL=$(get_from_account_yml cloudflare.login)
  if [ "$CLOUD_EMAIL" == notfound ]; then
    while [ -z "$cloud_email" ]; do
      echo >&2 -n -e "${BWHITE}Votre Email Cloudflare: ${CEND}"
      read cloud_email

    done
    manage_account_yml cloudflare.login "$cloud_email"
  else
    echo -e "${BLUE}Cloudflare login déjà renseigné${CEND}"
  fi
  CLOUD_API=$(get_from_account_yml cloudflare.api)
  if [ "$CLOUD_API" == notfound ]; then
    while [ -z "$cloud_api" ]; do
      echo >&2 -n -e "${BWHITE}Votre API Cloudflare: ${CEND}"
      read cloud_api

    done
    manage_account_yml cloudflare.api "$cloud_api"
  else
    echo -e "${BLUE}Cloudflare api déjà renseigné${CEND}"
  fi
fi

#echo ""
#echo -e "${BLUE}### Google OAuth2 avec Traefik – Secure SSO pour les services Docker ###${NC}"
#echo ""
#echo -e "${CCYAN}------------------------------------------------------------------${CEND}"
#echo -e "${CCYAN}    Protocole d identification via Google OAuth2		   ${CEND}"
#echo -e "${CCYAN}    Securisation SSO pour les services Docker			   ${CEND}"
#echo -e "${CCYAN}------------------------------------------------------------------${CEND}"
#echo ""
#echo -e "${CRED}-------------------------------------------------------------------${CEND}"
#echo -e "${CRED}    /!\ IMPORTANT: Au préalable créer un projet et vos identifiants${CEND}"
#echo -e "${CRED}    https://github.com/laster13/patxav/wiki /!\ 		   ${CEND}"
#echo -e "${CRED}-------------------------------------------------------------------${CEND}"
#echo ""
#
#read -rp $'\e[33mSouhaitez vous sécuriser vos Applis avec Google OAuth2 ? (o/n - default n)\e[0m :' OUI
#if [[ "$OUI" == "o" ]] || [[ "$OUI" == "O" ]]; then
#  if [ -z "$oauth_client" ] || [ -z "$oauth_secret" ] || [ -z "$email" ]; then
#    oauth_client=$1
#    oauth_secret=$2
#    email=$3
#  fi
#
#  OAUTH_CLIENT=$(get_from_account_yml oauth.client)
#  if [ "OAUTH_CLIENT" == notfound ]; then
#    while [ -z "$oauth_client" ]; do
#      echo >&2 -n -e "${BWHITE}Oauth_client: ${CEND}"
#      read oauth_client
#
#    done
#    manage_account_yml oauth.client "$oauth_client"
#  else
#    echo -e "${BLUE}Oauth client renseigné${CEND}"
#  fi
#
#  OAUTH_SECRET=$(get_from_account_yml oauth.secret)
#  if [ "OAUTH_SECRET" == notfound ]; then
#    while [ -z "$oauth_secret" ]; do
#      echo >&2 -n -e "${BWHITE}Oauth_secret: ${CEND}"
#      read oauth_secret
#    done
#    manage_account_yml oauth.secret "$oauth_secret"
#  else
#    echo -e "${BLUE}Oauth secret déjà renseigné${CEND}"
#  fi
#
#  OAUTH_ACCOUNT=$(get_from_account_yml oauth.account)
#  if [ "OAUTH_ACCOUNT" == notfound ]; then
#    while [ -z "$email" ]; do
#      echo >&2 -n -e "${BWHITE}Compte Gmail utilisé.s, séparés d une virgule si plusieurs: ${CEND}"
#      read email
#    done
#    manage_account_yml oauth.account "$email"
#  else
#    echo -e "${BLUE}Oauth account déjà renseigné${CEND}"
#  fi
#  OAUTH_SSL=$(get_from_account_yml oauth.openssl)
#  if [ "OAUTH_SSL" == notfound ]; then
#    openssl=$(openssl rand -hex 16)
#    manage_account_yml oauth.openssl "openssl"
#  fi
#  manage_account_yml sub.gui.auth oauth
#  echo ""
#else
#  manage_account_yml sub.gui.auth basique
#fi

# creation utilisateur
userid=$(id -u)
grpid=$(id -g)

# on reprend les valeurs du account.yml, juste au cas où
user=$(get_from_account_yml user.name)
pass=$(get_from_account_yml user.pass)


manage_account_yml user.htpwd $(htpasswd -nb $user $pass)

manage_account_yml user.userid "$userid"
manage_account_yml user.groupid "$grpid"

