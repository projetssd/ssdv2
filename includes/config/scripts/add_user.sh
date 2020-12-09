#!/bin/bash
########################################
# Gestion des services SSD
########################################

# TEST ROOT USER
if [ "$USER" != "root" ]; then
  echo "Ce script doit être lancé par root"
  exit 1
fi

source /opt/seedbox-compose/includes/functions.sh
source /opt/seedbox-compose/includes/variables.sh

  echo -e "${BLUE}### INFORMATIONS UTILISATEURS ###${NC}"
  mkdir -p $CONFDIR/variables
  cp /opt/seedbox-compose/includes/config/account.yml /opt/seedbox/variables/account.yml
  ACCOUNT=/opt/seedbox/variables/account.yml

  echo ""
  read -p $'\e[32m↘️ Nom d utilisateur | Appuyer sur [Enter]: \e[0m' user < /dev/tty
  read -p $'\e[32m↘️ Mot de passe | Appuyer sur [Enter]: \e[0m' pass < /dev/tty
  read -p $'\e[32m↘️ Mail | Appuyer sur [Enter]: \e[0m' mail < /dev/tty
  read -p $'\e[32m↘️ Domaine | Appuyer sur [Enter]: \e[0m' domain < /dev/tty
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

  read -rp $'\e[33mSouhaitez vous utiliser les DNS Cloudflare ? (o/n)\e[0m :' OUI

    if [[ "$OUI" = "o" ]] || [[ "$OUI" = "O" ]]; then
      if [ -z "$cloud_email" ] || [ -z "$cloud_api" ]; then
        cloud_email=$1
        cloud_api=$2
      fi

      while [ -z "$cloud_email" ]; do
        >&2 echo -n -e "${BWHITE}Votre Email Cloudflare: ${CEND}"
        read cloud_email
      done

      while [ -z "$cloud_api" ]; do
        >&2 echo -n -e "${BWHITE}Votre API Cloudflare: ${CEND}"
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
  read -rp $'\e[33mSouhaitez vous sécuriser vos Applis avec Google OAuth2 ? (o/n)\e[0m :' OUI

  if [[ "$OUI" = "o" ]] || [[ "$OUI" = "O" ]]; then
    if [ -z "$oauth_client" ] || [ -z "$oauth_secret" ] || [ -z "$email" ]; then
      oauth_client=$1
      oauth_secret=$2
      email=$3
    fi

    while [ -z "$oauth_client" ]; do
      >&2 echo -n -e "${BWHITE}Oauth_client: ${CEND}"
      read oauth_client
    done

    while [ -z "$oauth_secret" ]; do
      >&2 echo -n -e "${BWHITE}Oauth_secret: ${CEND}"
      read oauth_secret
    done

    while [ -z "$email" ]; do
      >&2 echo -n -e "${BWHITE}Compte Gmail utilisé(s), séparés d'une virgule si plusieurs: ${CEND}"
      read email
    done

    openssl=$(openssl rand -hex 16)
    echo ""
  fi

  # creation utilisateur
  password=$(perl -e 'print crypt($ARGV[0], "password")' $pass)
  useradd -m $user -p $password -s /bin/bash
  usermod -aG docker $user
  chsh -s /bin/bash $user
  chown -R $user:$user /home/$user
  chmod 755 /home/$user
  userid=$(id -u $user)
  grpid=$(id -g $user)
  htpasswd -c -b /tmp/.htpasswd $user $pass > /dev/null 2>&1
  htpwd=$(cat /tmp/.htpasswd)
  echo $pass > ~/.vault_pass
  echo "vault_password_file = ~/.vault_pass" >> /etc/ansible/ansible.cfg


  sed -i "s/name:/name: $user/
          s/pass:/pass: $pass/
          s/userid:/userid: $userid/
          s/groupid:/groupid: $grpid/
          s/group:/group: $user/
          s/mail:/mail: $mail/
          s/domain:/domain: $domain/
          s/login:/login: $cloud_email/
          s/api:/api: $cloud_api/
          s/client:/client: $oauth_client/
          s/secret:/secret: $oauth_secret/
          s/account:/account: $email/
          s/openssl:/openssl: $openssl/
          /htpwd:/c\   htpwd: $htpwd" $ACCOUNT



