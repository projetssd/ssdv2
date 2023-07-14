#!/bin/bash
##########

function logo() {

  color1='\033[1;31m' # Bold RED
  color2='\033[1;35m' # Bold PURPLE
  color3='\033[0;33m' # Regular YELLOW
  nocolor='\033[0m'   # no color
  colorp='\033[1;34m' # Bold BLUE
  colora='\033[1;32m' # Bold GREEN
  projetname='SSD - V2.2'
  authors='Authors: laster13 - Merrick'

  printf " \n"
  printf " ${color1}███████╗ ${color2}███████╗ ${color3}██████╗  ${colorp}${projetname}${nocolor}\n"
  printf " ${color1}██╔════╝ ${color2}██╔════╝ ${color3}██╔══██╗ ${colora}${authors}${nocolor}\n"
  printf " ${color1}███████╗ ${color2}███████╗ ${color3}██║  ██║ ${nocolor}\n"
  printf " ${color1}╚════██║ ${color2}╚════██║ ${color3}██║  ██║ $(uname -srmo)${nocolor}\n"
  printf " ${color1}███████║ ${color2}███████║ ${color3}██████╔╝ $(lsb_release -sd)${nocolor}\n"
  printf " ${color1}╚══════╝ ${color2}╚══════╝ ${color3}╚═════╝  ${nocolor}Uptime: $(/usr/bin/uptime -p)${nocolor}\n"
  printf " \n"

}

function update_system() {
  #Mise à jour systeme
  echo -e "${BLUE}### MISE A JOUR DU SYSTEME ###${NC}"
  ansible-playbook ${SETTINGS_SOURCE}/includes/config/roles/system/tasks/main.yml
  checking_errors $?
}

function status() {

  # Créé les fichiers de service, comme quoi rien n'est encore installé
  create_dir ${SETTINGS_STORAGE}/status
  sudo chown -R ${USER}: ${SETTINGS_STORAGE}/status
  for app in $(cat ${SETTINGS_SOURCE}/includes/config/services-available); do
    service=$(echo $app | tr '[:upper:]' '[:lower:]' | cut -d\- -f1)
    echo "0" >${SETTINGS_STORAGE}/status/$service
  done
  for app in $(cat ${SETTINGS_SOURCE}/includes/config/other-services-available); do
    service=$(echo $app | tr '[:upper:]' '[:lower:]' | cut -d\- -f1)
    echo "0" >${SETTINGS_STORAGE}/status/$service
  done
}

function update_status() {

  for i in $(docker ps --format "{{.Names}}" --filter "network=traefik_proxy"); do
    echo "2" >${SETTINGS_STORAGE}/status/${i}

  done

}

function cloudflare() {
  #####################################
  # Récupère les infos de cloudflare
  # Pour utilisation ultérieure
  ######################################
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

  if [[ "$OUI" == "o" ]] || [[ "$OUI" == "O" ]]; then

    if [ -z "$cloud_email" ] || [ -z "$cloud_api" ]; then
      cloud_email=$1
      cloud_api=$2
    fi

    while [ -z "$cloud_email" ]; do
      echo >&2 -n -e "${BWHITE}Votre Email Cloudflare: ${CEND}"
      read cloud_email
      manage_account_yml cloudflare.login "$cloud_email"
      update_seedbox_param "cf_login" $cloud_email
    done

    while [ -z "$cloud_api" ]; do
      echo >&2 -n -e "${BWHITE}Votre API Cloudflare: ${CEND}"
      read cloud_api
      manage_account_yml cloudflare.api "$cloud_api"
    done
  fi
  echo ""
}

function oauth() {
  #######################################
  # Récupère les infos oauth
  #######################################

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

  if [[ "$OUI" == "o" ]] || [[ "$OUI" == "O" ]]; then
    if [ -z "$oauth_client" ] || [ -z "$oauth_secret" ] || [ -z "$email" ]; then
      oauth_client=$1
      oauth_secret=$2
      email=$3
    fi

    while [ -z "$oauth_client" ]; do
      echo >&2 -n -e "${BWHITE}Oauth_client: ${CEND}"
      read oauth_client
      manage_account_yml oauth.client "$oauth_client"
    done

    while [ -z "$oauth_secret" ]; do
      echo >&2 -n -e "${BWHITE}Oauth_secret: ${CEND}"
      read oauth_secret
      manage_account_yml oauth.secret "$oauth_secret"
    done

    while [ -z "$email" ]; do
      echo >&2 -n -e "${BWHITE}Compte Gmail utilisé(s), séparés d'une virgule si plusieurs: ${CEND}"
      read email
      manage_account_yml oauth.account "$email"
    done

    openssl=$(openssl rand -hex 16)
    manage_account_yml oauth.openssl "$openssl"

    echo ""
    echo -e "${CRED}---------------------------------------------------------------${CEND}"
    echo -e "${CCYAN}    IMPORTANT:	Avant la 1ere connexion			       ${CEND}"
    echo -e "${CCYAN}    		- Nettoyer l'historique de votre navigateur    ${CEND}"
    echo -e "${CCYAN}    		- déconnection de tout compte google	       ${CEND}"
    echo -e "${CRED}---------------------------------------------------------------${CEND}"
    echo ""
    echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
    read -r
  fi

  echo ""
}

function install-rtorrent-cleaner() {
  #configuration de rtorrent-cleaner avec ansible
  echo -e "${BLUE}### RTORRENT-CLEANER ###${NC}"
  echo ""
  echo -e " ${BWHITE}* Installation RTORRENT-CLEANER${NC}"

  ## choix de l'utilisateur
  #SEEDUSER=$(ls ${SETTINGS_STORAGE}/media* | cut -d '-' -f2)
  sudo cp -r ${SETTINGS_SOURCE}/includes/config/rtorrent-cleaner/rtorrent-cleaner /usr/local/bin
  sudo sed -i "s|%SEEDUSER%|${USER}|g" /usr/local/bin/rtorrent-cleaner
  sudo sed -i "s|%SETTINGS_STORAGE%|${SETTINGS_STORAGE}|g" /usr/local/bin/rtorrent-cleaner
}

function motd() {
  #configuration d'un motd avec ansible
  echo -e "${BLUE}### MOTD ###${NC}"
  echo -e " ${BWHITE}* Installation MOTD${NC}"
  ansible-playbook ${SETTINGS_SOURCE}/includes/config/roles/motd/tasks/start.yml
  checking_errors $?
  echo ""
}

function sauve() {
  create_dir "/var/backup/local"
  #configuration Sauvegarde
  echo -e "${BLUE}### BACKUP ###${NC}"
  echo -e " ${BWHITE}* Mise en place Sauvegarde${NC}"
  ansible-playbook ${SETTINGS_SOURCE}/includes/config/roles/backup/tasks/main.yml
  checking_errors $?
  echo ""
}

function debug() {
  echo "### DEBUG ${1}"
  pause
}

function plex_dupefinder() {
  #configuration plex_dupefinder avec ansible
  echo -e "${BLUE}### PLEX_DUPEFINDER ###${NC}"
  echo -e " ${BWHITE}* Installation plex_dupefinder${NC}"
  ansible-playbook ${SETTINGS_SOURCE}/includes/config/roles/plex_dupefinder/tasks/main.yml
  checking_errors $?
}

function install_traktarr() {
  ##configuration traktarr avec ansible
  echo -e "${BLUE}### TRAKTARR ###${NC}"
  echo -e " ${BWHITE}* Installation traktarr${NC}"
  ansible-playbook ${SETTINGS_SOURCE}/includes/config/roles/traktarr/tasks/main.yml
  checking_errors $?
}

function update_logrotate() {
  ansible-playbook ${SETTINGS_SOURCE}/includes/config/playbooks/logrotate.yml
}

function webtools() {
  ##configuration Webtools avec ansible
  echo -e "${BLUE}### WEBTOOLS ###${NC}"
  echo -e " ${BWHITE}* Installation Webtools${NC}"
  ansible-playbook ${SETTINGS_SOURCE}/includes/config/roles/webtools/tasks/main.yml
  docker restart plex
  checking_errors $?
}

function plex_autoscan() {
  #configuration plex_autoscan avec ansible
  echo -e "${BLUE}### PLEX_AUTOSCAN ###${NC}"
  echo -e " ${BWHITE}* Installation plex_autoscan${NC}"
  ansible-playbook ${SETTINGS_SOURCE}/includes/config/roles/plex_autoscan/tasks/main.yml
  sudo chown -R ${USER} ${HOME}/scripts/plex_autoscan
  checking_errors $?
}

function autoscan() {
  #configuration plex_autoscan avec ansible
  echo -e "${BLUE}### AUTOSCAN ###${NC}"
  echo -e " ${BWHITE}* Installation autoscan${NC}"
  ansible-playbook ${SETTINGS_SOURCE}/includes/config/roles/autoscan/tasks/main.yml
  checking_errors $?
}

function crop() {
  #configuration crop avec ansible
  echo -e "${BLUE}### CROP ###${NC}"
  ${SETTINGS_SOURCE}/includes/config/scripts/crop.sh
  echo -e " ${BWHITE}* Installation crop${NC}"
  ansible-playbook ${SETTINGS_SOURCE}/includes/config/roles/crop/tasks/main.yml
  checking_errors $?
}

function install_cloudplow() {
  #configuration plex_autoscan avec ansible
  echo -e "${BLUE}### CLOUDPLOW ###${NC}"
  echo -e " ${BWHITE}* Installation cloudplow${NC}"
  ansible-playbook ${SETTINGS_SOURCE}/includes/config/roles/cloudplow/tasks/main.yml
  sudo chown -R ${USER} ${HOME}/scripts/cloudplow
  checking_errors $?
}

function check_dir() {
  if [[ $1 != "${SETTINGS_SOURCE}" ]]; then
    # shellcheck disable=SC2164
    cd "${SETTINGS_SOURCE}"
  fi
}

function insert_mod() {
  sed -i 's/\/etc\/update-motd.d/\/opt\/motd\/motd/g' /opt/motd/motd/04-load-average
  sed -i 's/\/etc\/update-motd.d/\/opt\/motd\/motd/g' /opt/motd/motd/10-plex-stats
  sed -i 's/\/etc\/update-motd.d/\/opt\/motd\/motd/g' /opt/motd/motd/12-rtorrent-stats
  /opt/motd/motd/01-banner
  /opt/motd/motd/04-load-average
  /opt/motd/motd/10-plex-stats
  /opt/motd/motd/12-rtorrent-stats
}

function create_dir() {
  ansible-playbook "${SETTINGS_SOURCE}/includes/config/playbooks/create_directory.yml" \
    --extra-vars '{"DIRECTORY":"'${1}'"}'
}

function conf_dir() {
  create_dir "${SETTINGS_STORAGE}"
}

function create_file() {
  TMPMYUID=$(whoami)
  MYGID=$(id -g)
  ansible-playbook "${SETTINGS_SOURCE}/includes/config/playbooks/create_file.yml" \
    --extra-vars '{"FILE":"'${1}'","UID":"'${TMPMYUID}'","GID":"'${MYGID}'"}'
}

function change_file_owner() {
  ansible-playbook "${SETTINGS_SOURCE}/includes/config/playbooks/chown_file.yml" \
    --extra-vars '{"FILE":"'${1}'"}'

}

function make_dir_writable() {
  ansible-playbook "${SETTINGS_SOURCE}/includes/config/playbooks/change_rights.yml" \
    --extra-vars '{"DIRECTORY":"'${1}'"}'

}

function install_base_packages() {
  echo ""
  echo -e "${BLUE}### INSTALLATION DES PACKAGES ###${NC}"
  echo ""
  echo -e " ${BWHITE}* Installation apache2-utils, unzip, git, curl ...${NC}"
  ansible-playbook "${SETTINGS_SOURCE}/includes/config/roles/install/tasks/main.yml"
  checking_errors $?
  echo ""
}

function checking_errors() {
  if [[ "$1" == "0" ]]; then
    echo -e "	${GREEN}--> Operation success !${NC}"
    CURRENT_ERROR=0
  else
    echo -e "	${RED}--> Operation failed !${NC}"
    CURRENT_ERROR=1
  fi
}

function install_fail2ban() {
  echo -e "${BLUE}### FAIL2BAN ###${NC}"
  ansible-playbook "${SETTINGS_SOURCE}/includes/config/roles/fail2ban/tasks/main.yml"
  checking_errors $?
  echo ""
}

function install_ufw() {
  clear
  echo -e "${RED}---------------------------------------------------------------${CEND}"
  echo -e "${RED} UFW sera installé avec les valeurs par défaut uniquement ${CEND}"
  echo -e "${RED} et permettra les accès suivants : ${CEND}"
  echo -e "${RED} ssh, http, https, plex ${CEND}"
  echo -e "${RED} Vous pourrez le modifier en éditant le fichier ${SETTINGS_STORAGE}/conf/ufw.yml ${CEND}"
  echo -e "${RED} pour ajouter des ports/ip supplémentaires ${CEND}"
  echo -e "${RED} avant de relancer ce script ${CEND}"
  echo -e "${RED}---------------------------------------------------------------${CEND}"
  echo -e "${RED} Appuyez sur [Entrée] pour continer ${CEND}"
  read -r
  echo -e "${BLUE}### UFW ###${NC}"
  ansible-playbook "${SETTINGS_SOURCE}/includes/config/roles/ufw/tasks/main.yml"
  ansible-playbook "${SETTINGS_STORAGE}/conf/ufw.yml"
  checking_errors $?
  echo ""
}

function install_traefik() {
  create_dir "${SETTINGS_STORAGE}/docker/traefik/acme/"
  echo -e "${BLUE}### TRAEFIK ###${NC}"

  ansible-playbook "${SETTINGS_SOURCE}/includes/dockerapps/templates/ansible/ansible.yml"
  DOMAIN=$(cat "${TMPDOMAIN}")

  # choix sous domaine traefik
  echo ""
  echo -e "${BWHITE}Adresse par défault: https://traefik.${DOMAIN} ${CEND}"
  echo ""
  read -rp $'\e[33mSouhaitez vous personnaliser le sous domaine? (o/n)\e[0m: ' OUI
  if [[ "$OUI" == "o" ]] || [[ "$OUI" == "O" ]]; then

    while [ -z "$SUBDOMAIN" ]; do
      echo >&2 -n -e "${BWHITE}Sous Domaine: ${CEND}"
      read SUBDOMAIN
    done

    if [ ! -z "$SUBDOMAIN" ]; then
      manage_account_yml sub.traefik.traefik $SUBDOMAIN
    fi
  else
    manage_account_yml sub.traefik.traefik traefik
  fi

  # choix authentification traefik
  echo ""
  read -rp $'\e\033[1;37mChoix de Authentification pour traefik [ Enter ] 1 => basique | 2 => oauth | 3 => authelia: ' AUTH
  case $AUTH in
  1)
    TYPE_AUTH=basique
    ;;

  2)
    TYPE_AUTH=oauth
    ;;

  3)
    TYPE_AUTH=authelia
    ;;

  *)
    TYPE_AUTH=basique
    echo "Pas de choix sélectionné, on passe sur une auth basique"
    ;;
  esac
  manage_account_yml sub.traefik.auth ${TYPE_AUTH}

  echo ""
  echo -e " ${BWHITE}* Installation Traefik${NC}"
  ansible-playbook ${SETTINGS_SOURCE}/includes/dockerapps/traefik.yml
  checking_errors $?
  if [[ ${CURRENT_ERROR} -eq 1 ]]; then
    echo "${RED}Cette étape peut ne pas aboutir lors d'une première installation${CEND}"
    echo "${RED}Suite à l'installation de docker, il faut se déloguer/reloguer pour que cela fonctionne${CEND}"
    echo "${RED}Cette erreur est bloquante, impossible de continuer${CEND}"
    exit 1
  fi

  echo ""
}

function install_watchtower() {
  echo -e "${BLUE}### WATCHTOWER ###${NC}"
  echo -e " ${BWHITE}* Installation Watchtower${NC}"
  ansible-playbook ${SETTINGS_SOURCE}/includes/dockerapps/watchtower.yml
  checking_errors $?
  echo ""
}

function install_plexdrive() {
  echo -e "${BLUE}### PLEXDRIVE ###${NC}"
  echo ""
  sudo mkdir -p /mnt/plexdrive >/dev/null 2>&1
  sudo chown ${USER}: /mnt/plexdrive
  ansible-playbook ${SETTINGS_SOURCE}/includes/config/roles/plexdrive/tasks/main.yml
  systemctl stop plexdrive >/dev/null 2>&1
  echo ""
  clear
  echo -e " ${BWHITE}* Dès que le message ${NC}${CCYAN}"First cache build process started" apparait à l'écran, taper ${NC}${CCYAN}CTRL + C${NC}${BWHITE} pour poursuivre le script !${NC}"
  teamdrive=$(get_from_account_yml rclone.id_teamdrive)
  if [ "${teamdrive}" != notfound ]; then
    /usr/bin/plexdrive mount -v 3 --drive-id="${teamdrive}" --refresh-interval=1m --chunk-check-threads=8 --chunk-load-threads=8 --chunk-load-ahead=4 --max-chunks=100 --fuse-options=allow_other,read_only /mnt/plexdrive
    systemctl start plexdrive >/dev/null 2>&1
  else
    /usr/bin/plexdrive mount -v 3 --refresh-interval=1m --chunk-check-threads=8 --chunk-load-threads=8 --chunk-load-ahead=4 --max-chunks=100 --fuse-options=allow_other,read_only /mnt/plexdrive
    systemctl start plexdrive >/dev/null 2>&1
  fi

}

function plexdrive() {
  echo -e "${BLUE}### PLEXDRIVE ###${NC}"
  echo ""
  sudo mkdir -p /mnt/plexdrive >/dev/null 2>&1
  sudo chown ${USER}: /mnt/plexdrive
  ansible-playbook ${SETTINGS_SOURCE}/includes/config/roles/plexdrive/tasks/plexdrive.yml
  systemctl stop plexdrive >/dev/null 2>&1
  echo ""
  clear
  echo -e " ${BWHITE}* Dès que le message ${NC}${CCYAN}"First cache build process started" apparait à l'écran, taper ${NC}${CCYAN}CTRL + C${NC}${BWHITE} pour poursuivre le script !${NC}"
  teamdrive=$(get_from_account_yml rclone.id_teamdrive)
  if [ "${teamdrive}" != notfound ]; then
    /usr/bin/plexdrive mount -v 3 --drive-id="${teamdrive}" --refresh-interval=1m --chunk-check-threads=8 --chunk-load-threads=8 --chunk-load-ahead=4 --max-chunks=100 --fuse-options=allow_other,read_only /mnt/plexdrive
    systemctl start plexdrive >/dev/null 2>&1
  else
    /usr/bin/plexdrive mount -v 3 --refresh-interval=1m --chunk-check-threads=8 --chunk-load-threads=8 --chunk-load-ahead=4 --max-chunks=100 --fuse-options=allow_other,read_only /mnt/plexdrive
    systemctl start plexdrive >/dev/null 2>&1
  fi

}

function install_rclone() {
  echo -e "${BLUE}### RCLONE ###${NC}"
  fusermount -uz /mnt/rclone >>/dev/null 2>&1
  create_dir /mnt/rclone
  create_dir /mnt/rclone/${USER}
  ${SETTINGS_SOURCE}/includes/config/scripts/rclone.sh
  ansible-playbook ${SETTINGS_SOURCE}/includes/config/roles/rclone/tasks/main.yml
  checking_errors $?
  echo ""
}

function install_common() {
  source "${SETTINGS_SOURCE}/venv/bin/activate"
  # on contre le bug de debian et du venv qui ne trouve pas les paquets installés par galaxy
  temppath=$(ls ${SETTINGS_SOURCE}/venv/lib)
  pythonpath=${SETTINGS_SOURCE}/venv/lib/${temppath}/site-packages
  export PYTHONPATH=${pythonpath}
  # toutes les installs communes
  # installation des dépendances, permet de créer les docker network via ansible
  ansible-galaxy collection install community.general
  #ansible-galaxy collection install community.docker
  # dépendence permettant de gérer les fichiers yml
  ansible-galaxy install kwoodson.yedit

  manage_account_yml settings.storage "${SETTINGS_STORAGE}"
  manage_account_yml settings.source "${SETTINGS_SOURCE}"

  # On vérifie que le user ait bien les droits d'écriture
  make_dir_writable "${SETTINGS_SOURCE}"
  # on vérifie que le user ait bien les droits d'écriture dans la db
  change_file_owner "${SETTINGS_SOURCE}/ssddb"
  # On crée le conf dir (par défaut /opt/seedbox) s'il n'existe pas
  conf_dir

  stocke_public_ip
  # On part à la pêche aux infos....
  ${SETTINGS_SOURCE}/includes/config/scripts/get_infos.sh
  pause
  echo ""
  # On crée les fichier de status à 0
  status
  # Mise à jour du système
  update_system
  # Installation des packages de base
  install_base_packages
  # Installation de docker
  install_docker
  # install de traefik
  if docker ps | grep -q traefik; then
    # on ne fait rien, traefik est déjà isntallé
    :
  else
    install_traefik
  fi
  #unionfs_fuse

}

function unionfs_fuse() {
  echo -e "${BLUE}### Unionfs-Fuse ###${NC}"
  echo -e " ${BWHITE}* Installation Mergerfs${NC}"
  ansible-playbook ${SETTINGS_SOURCE}/includes/config/roles/unionfs/tasks/main.yml
  checking_errors $?
  echo ""
}

function install_docker() {
  echo -e "${BLUE}### DOCKER ###${NC}"
  echo -e " ${BWHITE}* Installation Docker${NC}"
  file="/usr/bin/docker"
  if [ ! -e "$file" ]; then
    ansible-playbook ${SETTINGS_SOURCE}/includes/config/roles/docker/tasks/main.yml
  else
    echo -e " ${YELLOW}* docker est déjà installé !${NC}"
  fi
  echo ""
}

function subdomain() {

  echo ""
  read -rp $'\e\033[1;37m --> Personnaliser les sous domaines: (o/N) ? ' OUI
  echo ""
  if [[ "$OUI" == "o" ]] || [[ "$OUI" == "O" ]]; then
    echo -e " ${CRED}--> NE PAS SAISIR LE NOM DE DOMAINE - LES POINTS NE SONT PAS ACCEPTES${NC}"
    echo ""
    for line in $(cat $SERVICESPERUSER); do

      while [ -z "$SUBDOMAIN" ]; do
        read -rp $'\e[32m* Sous domaine pour\e[0m '${line}': ' SUBDOMAIN
      done
      manage_account_yml sub.${line}.${line} $SUBDOMAIN
    done
  else
    for line in $(cat $SERVICESPERUSER); do
      SUBDOMAIN=${line}
      manage_account_yml sub.${line}.${line} $SUBDOMAIN
    done
  fi
}

function subdomain_unitaire() {
  line=$1
  echo ""
  read -rp $'\e\033[1;37m --> Personnaliser le sous domaines pour '${line}' : (o/N) ? ' OUI
  echo ""
  if [[ "$OUI" == "o" ]] || [[ "$OUI" == "O" ]]; then
    echo -e " ${CRED}--> NE PAS SAISIR LE NOM DE DOMAINE - LES POINTS NE SONT PAS ACCEPTES${NC}"
    echo ""

    read -rp $'\e[32m* Sous domaine pour\e[0m '${line}': ' SUBDOMAIN

  else
    SUBDOMAIN=${line}
  fi
  manage_account_yml sub.${line}.${line} $SUBDOMAIN
}

function auth() {

  echo ""
  for line in $(cat $SERVICESPERUSER); do

    read -rp $'\e\033[1;37m --> Authentification '${line}' [ Enter ] 1 => basique (défaut) | 2 => oauth | 3 => authelia | 4 => aucune: ' AUTH

    case $AUTH in
    1)
      TYPE_AUTH=basique
      ;;

    2)
      TYPE_AUTH=oauth
      ;;

    3)
      TYPE_AUTH=authelia

      ;;

    4)
      TYPE_AUTH=aucune
      ;;

    *)
      TYPE_AUTH=basique
      echo "Pas de choix sélectionné, on passe sur une auth basique"

      ;;
    esac

    manage_account_yml sub.${line}.auth ${TYPE_AUTH}
  done
}

function auth_unitaire() {
  line=$1
  echo ""

  read -rp $'\e\033[1;37m --> Authentification '${line}' [ Enter ] 1 => basique (défaut) | 2 => oauth | 3 => authelia | 4 => aucune: ' AUTH

  case $AUTH in
  1)
    TYPE_AUTH=basique
    ;;

  2)
    TYPE_AUTH=oauth
    ;;

  3)
    TYPE_AUTH=authelia

    ;;

  4)
    TYPE_AUTH=aucune
    ;;

  *)
    TYPE_AUTH=basique
    echo "Pas de choix sélectionné, on passe sur une auth basique"

    ;;
  esac

  manage_account_yml sub.${line}.auth ${TYPE_AUTH}

}

function define_parameters() {
  echo -e "${BLUE}### INFORMATIONS UTILISATEURS ###${NC}"

  create_user
  CONTACTEMAIL=$(
    whiptail --title "Adresse Email" --inputbox \
      "Merci de taper votre adresse Email :" 7 50 3>&1 1>&2 2>&3
  )
  manage_account_yml user.mail $CONTACTEMAIL

  DOMAIN=$(
    whiptail --title "Votre nom de Domaine" --inputbox \
      "Merci de taper votre nom de Domaine (exemple: nomdedomaine.fr) :" 7 50 3>&1 1>&2 2>&3
  )
  manage_account_yml user.domain $DOMAIN
  echo ""
}

function create_user_non_systeme() {
  # nouvelle version de define_parameters()
  echo -e "${BLUE}### INFORMATIONS UTILISATEURS ###${NC}"

  #  SEEDUSER=$(whiptail --title "Administrateur" --inputbox \
  #    "Nom d'Administrateur de la Seedbox :" 7 50 3>&1 1>&2 2>&3)
  #  [[ "$?" == 1 ]] && script_plexdrive
  PASSWORD=$(
    whiptail --title "Password" --passwordbox \
      "Mot de passe :" 7 50 3>&1 1>&2 2>&3
  )

  manage_account_yml user.htpwd $(htpasswd -nb ${USER} $PASSWORD)
  manage_account_yml user.name ${USER}
  manage_account_yml user.pass $PASSWORD
  manage_account_yml user.userid $(id -u)
  manage_account_yml user.groupid $(id -g)

  update_seedbox_param "name" "${user}"
  update_seedbox_param "userid" "$(id -u)"
  update_seedbox_param "groupid" "$(id -g)"
  update_seedbox_param "htpwd" "${htpwd}"

  CONTACTEMAIL=$(
    whiptail --title "Adresse Email" --inputbox \
      "Merci de taper votre adresse Email :" 7 50 3>&1 1>&2 2>&3
  )
  manage_account_yml user.mail "${CONTACTEMAIL}"
  update_seedbox_param "mail" "${CONTACTEMAIL}"

  DOMAIN=$(
    whiptail --title "Votre nom de Domaine" --inputbox \
      "Merci de taper votre nom de Domaine (exemple: nomdedomaine.fr) :" 7 50 3>&1 1>&2 2>&3
  )
  manage_account_yml user.domain "${DOMAIN}"
  update_seedbox_param "domain" "${DOMAIN}"
  echo ""
  return
}

function projects() {
  ansible-playbook "${SETTINGS_SOURCE}/includes/dockerapps/templates/ansible/ansible.yml"
  #SEEDUSER="${USER}"
  DOMAIN=$(cat "${TMPDOMAIN}")
  SEEDGROUP=$(cat "${TMPGROUP}")
  rm -f "${TMPNAME}" "${TMPDOMAIN}" "${TMPGROUP}"

  echo -e "${BLUE}### SERVICES ###${NC}"
  echo -e " ${BWHITE}--> Services en cours d'installation : ${NC}"
  PROJECTPERUSER="$PROJECTUSER${USER}"
  rm -Rf "${PROJECTPERUSER}" >/dev/null 2>&1
  projects="/tmp/projects.txt"

  if [[ -e "$projects" ]]; then
    rm ${projects}
  fi
  for app in $(cat ${PROJECTSAVAILABLE}); do
    service=$(echo "${app}" | cut -d\- -f1)
    desc=$(echo "${app}" | cut -d\- -f2)
    echo "$service $desc off" >>/tmp/projects.txt
  done

  SERVICESTOINSTALL=$(
    whiptail --title "Gestion des Applications" --checklist \
      "\nChoisir vos Applications" 18 47 10 \
      $(cat /tmp/projects.txt) 3>&1 1>&2 2>&3
  )
  [[ "$?" == 1 ]] && rm /tmp/projects.txt
  PROJECTPERUSER="${PROJECTUSER}${USER}"
  touch "${PROJECTPERUSER}"

  for PROJECTS in ${SERVICESTOINSTALL}; do
    echo -e "	${GREEN}* $(echo "${PROJECTS}" | tr -d '"')${NC}"
    echo $(echo ${PROJECTS,,} | tr -d '"') >>"${PROJECTPERUSER}"
  done

  for line in $(cat ${PROJECTPERUSER}); do
    ${line}
  done
}

function choose_services() {
  python3 "${SETTINGS_SOURCE}/includes/config/scripts/generique_python.py" choix_appli_lance
}

function choose_services_deprecated() {
  echo -e "${BLUE}### SERVICES ###${NC}"
  echo "DEBUG ${SERVICESAVAILABLE}"
  echo -e " ${BWHITE}--> Services en cours d'installation : ${NC}"
  rm -Rf "${SERVICESPERUSER}" >/dev/null 2>&1
  menuservices="/tmp/menuservices.txt"
  if [[ -e "${menuservices}" ]]; then
    rm "${menuservices}"
  fi

  for app in $(cat ${SERVICESAVAILABLE}); do
    service=$(echo ${app} | cut -d\- -f1)
    desc=$(echo ${app} | cut -d\- -f2)
    echo "${service} ${desc} off" >>/tmp/menuservices.txt
  done
  SERVICESTOINSTALL=$(
    whiptail --title "Gestion des Applications" --checklist \
      "Appuyer sur la barre espace pour la sélection" 28 64 21 \
      $(cat /tmp/menuservices.txt) 3>&1 1>&2 2>&3
  )
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    rm /tmp/menuservices.txt
    touch $SERVICESPERUSER
    for APPDOCKER in $SERVICESTOINSTALL; do
      echo -e "	${GREEN}* $(echo $APPDOCKER | tr -d '"')${NC}"
      echo $(echo ${APPDOCKER,,} | tr -d '"') >>"${SERVICESPERUSER}"
    done
  else
    return
  fi
}

function choose_other_services() {
  echo -e "${BLUE}### SERVICES ###${NC}"
  echo -e " ${BWHITE}--> Services en cours d'installation : ${NC}"
  rm -Rf "${SERVICESPERUSER}" >/dev/null 2>&1
  menuservices="/tmp/menuservices.txt"
  if [[ -e "${menuservices}" ]]; then
    rm /tmp/menuservices.txt
  fi

  for app in $(cat "${SETTINGS_SOURCE}/includes/config/other-services-available"); do
    service=$(echo "${app}" | cut -d\- -f1)
    desc=$(echo "${app}" | cut -d\- -f2)
    echo "${service} ${desc} off" >>/tmp/menuservices.txt
  done
  SERVICESTOINSTALL=$(
    whiptail --title "Gestion des Applications" --checklist \
      "Appuyer sur la barre espace pour la sélection" 28 64 21 \
      $(cat /tmp/menuservices.txt) 3>&1 1>&2 2>&3
  )
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    rm /tmp/menuservices.txt
    touch "${SERVICESPERUSER}"
    for APPDOCKER in $SERVICESTOINSTALL; do
      echo -e "	${GREEN}* $(echo "${APPDOCKER}" | tr -d '"')${NC}"
      echo $(echo "${APPDOCKER,,}" | tr -d '"') >>"${SERVICESPERUSER}"
    done
  else
    return
  fi
}

function choose_media_folder_classique() {
  echo -e "${BLUE}### DOSSIERS MEDIAS ###${NC}"
  echo -e " ${BWHITE}--> Création des dossiers Medias : ${NC}"
  mkdir -p "${HOME}/filebot"
  mkdir -p "${HOME}/local/{Films,Series,Musiques,Animes}"
  checking_errors $?
  echo ""
}

function choose_media_folder_plexdrive() {
  echo -e "${BLUE}### DOSSIERS MEDIAS ###${NC}"
  USERSEED=$(get_from_account_yml user.name)
  FOLDER="/mnt/rclone/${USERSEED}"

  # si le dossier /mnt/rclone/user n'est pas vide
  mkdir -p "${HOME}/Medias"
  if [ "$(ls -A /mnt/rclone/${USERSEED})" ]; then
    cd "/mnt/rclone/${USERSEED}"
    ls -Ad */ | sed 's,/$,,g' >"${MEDIASPERUSER}"

    echo -e " ${BWHITE}--> Récupération des dossiers Utilisateur à partir de Gdrive... : ${NC}"
    for line in $(cat $MEDIASPERUSER); do
      mkdir -p ${HOME}/local/${line}
      echo -e "	${GREEN}--> Le dossier ${NC}${YELLOW}${line}${NC}${GREEN} a été ajouté avec succès !${NC}"
    done

  else
    echo -e " ${BWHITE}--> Création des dossiers Medias ${NC}"
    echo ""
    echo -e " ${YELLOW}--> ### Veuillez patienter, création en cours des dossiers sur Gdrive ### ${NC}"
    for media in $(cat $MEDIAVAILABLE); do
      service=$(echo $media | cut -d\- -f1)
      desc=$(echo $media | cut -d\- -f2)
      echo "$service $desc off" >>/tmp/menumedia.txt
    done
    MEDIASTOINSTALL=$(
      whiptail --title "Gestion des dossiers Medias" --checklist \
        "Medias à ajouter pour ${USER} (Barre espace pour la sélection)" 28 60 17 \
        $(cat /tmp/menumedia.txt) 3>&1 1>&2 2>&3
    )
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      touch "$MEDIASPERUSER"
      for MEDDOCKER in $MEDIASTOINSTALL; do
        echo -e "	${GREEN}* $(echo $MEDDOCKER | tr -d '"')${NC}"
        echo $(echo ${MEDDOCKER} | tr -d '"') >>$MEDIASPERUSER
      done
      for line in $(cat $MEDIASPERUSER); do
        line=$(echo ${line} | sed 's/\(.\)/\U\1/')
        create_dir "${HOME}/local/${line}"
        create_dir "/mnt/rclone/${USER}/${line}"
      done
      rm /tmp/menumedia.txt
    fi
  fi
  mkdir -p "${HOME}/filebot"
  echo ""
}

function install_services() {
  if [ -f "$SERVICESPERUSER" ]; then

    if [[ ! -d "${SETTINGS_STORAGE}/conf" ]]; then
      mkdir -p "${SETTINGS_STORAGE}/conf" >/dev/null 2>&1
    fi

    if [[ ! -d "${SETTINGS_STORAGE}/vars" ]]; then
      mkdir -p "${SETTINGS_STORAGE}/vars" >/dev/null 2>&1
    fi

    create_file "${SETTINGS_STORAGE}/temp.txt"

    ## préparation installation
    #for line in $(grep -l 2 ${SETTINGS_STORAGE}/status/*); do
    #  basename=$(basename "${line}")
    #  launch_service "${basename}"
    #done

    for line in $(cat $SERVICESPERUSER); do
      launch_service "${line}"
    done
  fi
}

function launch_service() {

  line=$1

  log_write "Installation de ${line}"
  error=0
  tempsubdomain=$(get_from_account_yml sub.${line}.${line})
  if [ "${tempsubdomain}" = notfound ]; then
    subdomain_unitaire ${line}
  fi
  tempauth=$(get_from_account_yml sub.${line}.auth)
  if [ "${tempauth}" = notfound ]; then
    auth_unitaire ${line}
  fi

  if [[ "${line}" == "plex" ]]; then
    echo ""
    echo -e "${BLUE}### CONFIG POST COMPOSE PLEX ###${NC}"
    echo -e " ${BWHITE}* Processing plex config file...${NC}"
    echo ""
    echo -e " ${GREEN}ATTENTION IMPORTANT - NE PAS FAIRE D'ERREUR - SINON DESINSTALLER ET REINSTALLER${NC}"
    "${SETTINGS_SOURCE}/includes/config/roles/plex_autoscan/plex_token.sh"

    choose_media_folder_plexdrive
    if [[ -f "${SETTINGS_STORAGE}/conf/plex.yml" ]]; then
      :
    else
      cp "${SETTINGS_SOURCE}/includes/dockerapps/plex.yml" "${SETTINGS_STORAGE}/conf/plex.yml" >/dev/null 2>&1
    fi
    ansible-playbook "${SETTINGS_STORAGE}/conf/plex.yml"
    echo "2" >"${SETTINGS_STORAGE}/status/plex"
  else
    # On est dans le cas générique
    # on regarde s'i y a un playbook existant

    if [[ -f "${SETTINGS_STORAGE}/conf/${line}.yml" ]]; then
      # il y a déjà un playbook "perso", on le lance
      ansible-playbook "${SETTINGS_STORAGE}/conf/${line}.yml"
    elif [[ -f "${SETTINGS_STORAGE}/vars/${line}.yml" ]]; then
      # il y a des variables persos, on les lance
      ansible-playbook "${SETTINGS_SOURCE}/includes/dockerapps/generique.yml" --extra-vars "@${SETTINGS_STORAGE}/vars/${line}.yml"

    elif [[ -f "${SETTINGS_SOURCE}/includes/dockerapps/${line}.yml" ]]; then
      # pas de playbook perso ni de vars perso
      # puis on le lance
      ansible-playbook "${SETTINGS_SOURCE}/includes/dockerapps/${line}.yml"
    elif [[ -f "${SETTINGS_SOURCE}/includes/dockerapps/vars/${line}.yml" ]]; then
      # puis on lance le générique avec ce qu'on vient de copier
      ansible-playbook "${SETTINGS_SOURCE}/includes/dockerapps/generique.yml" --extra-vars "@${SETTINGS_SOURCE}/includes/dockerapps/vars/${line}.yml"
    else
      log_write "Aucun fichier de configuration trouvé dans les sources, abandon"
      error=1
    fi
  fi
  if [ ${error} = 0 ]; then
    temp_subdomain=$(get_from_account_yml "sub.${line}.${line}")
    DOMAIN=$(get_from_account_yml user.domain)
    echo "2" >"${SETTINGS_STORAGE}/status/${line}"

    FQDNTMP="${temp_subdomain}.$DOMAIN"

  fi
  FQDNTMP=""
}

function copie_yml() {
  echo "#########################################################"
  echo "# ATTENTION                                             #"
  echo "# Cette fonction va copier les fichiers yml choisis     #"
  echo "# Afin de pouvoir les personnaliser                     #"
  echo "# Mais ne lancera pas les services associés             #"
  echo "#########################################################"
  choose_services
  for line in $(cat $SERVICESPERUSER); do
    copie_yml_unit "${line}"
  done
  choose_other_services
  for line in $(cat $SERVICESPERUSER); do
    copie_yml_unit "${line}"
  done
}

function copie_yml_unit() {

  if [[ -f "${SETTINGS_SOURCE}/includes/dockerapps/${line}.yml" ]]; then
    # Il y a un playbook spécifique pour cette appli, on le copie
    cp "${SETTINGS_SOURCE}/includes/dockerapps/${line}.yml" "${SETTINGS_STORAGE}/conf/${line}.yml"
  elif [[ -f "${SETTINGS_SOURCE}/includes/dockerapps/vars/${line}.yml" ]]; then
    # on copie les variables pour le user
    cp "${SETTINGS_SOURCE}/includes/dockerapps/vars/${line}.yml" "${SETTINGS_STORAGE}/vars/${line}.yml"
  else
    log_write "Aucun fichier de configuration trouvé dans les sources, abandon"
  fi
}

decompte() {
  i=$1
  while [[ $i -ge 0 ]]; do
    echo -e "\033[1;37m\r * "$var ""$i""s" \c\033[0m"
    sleep 1
    i=$(expr $i - 1)
  done
  echo -e ""
}

function manage_apps() {
  echo -e "${BLUE}##########################################${NC}"
  echo -e "${BLUE}###          GESTION DES APPLIS        ###${NC}"
  echo -e "${BLUE}##########################################${NC}"

  ansible-playbook ${SETTINGS_SOURCE}/includes/dockerapps/templates/ansible/ansible.yml

}

function suppression_appli() {

  sousdomaine=$(get_from_account_yml sub.${APPSELECTED}.${APPSELECTED})
  domaine=$(get_from_account_yml user.domain)

  APPSELECTED=$1
  DELETE=0
  if [[ $# -eq 2 ]]; then
    if [ "$2" = "1" ]; then
      DELETE=1
    fi
  fi
  manage_account_yml sub.${APPSELECTED} " "

  docker rm -f "$APPSELECTED" >/dev/null 2>&1
  if [ $DELETE -eq 1 ]; then
    log_write "Suppresion de ${APPSELECTED}, données supprimées"
    sudo rm -rf ${SETTINGS_STORAGE}/docker/${USER}/$APPSELECTED
  else
    log_write "Suppresion de ${APPSELECTED}, données conservées"
  fi

  rm ${SETTINGS_STORAGE}/conf/$APPSELECTED.yml >/dev/null 2>&1
  rm ${SETTINGS_STORAGE}/vars/$APPSELECTED.yml >/dev/null 2>&1
  echo "0" >${SETTINGS_STORAGE}/status/$APPSELECTED

  case $APPSELECTED in
  seafile)
    docker rm -f memcached >/dev/null 2>&1
    ;;
  varken)
    docker rm -f influxdb telegraf grafana >/dev/null 2>&1
    if [ $DELETE -eq 1 ]; then
      sudo rm -rf ${SETTINGS_STORAGE}/docker/${USER}/telegraf
      sudo rm -rf ${SETTINGS_STORAGE}/docker/${USER}/grafana
      sudo rm -rf ${SETTINGS_STORAGE}/docker/${USER}/influxdb
    fi
    ;;
  jitsi)
    docker rm -f prosody jicofo jvb
    rm -rf ${SETTINGS_STORAGE}/docker/${USER}/.jitsi-meet-cfg
    ;;
  nextcloud)
    docker rm -f collabora coturn office
    rm -rf ${SETTINGS_STORAGE}/docker/${USER}/coturn
    ;;
  rtorrentvpn)
    rm ${SETTINGS_STORAGE}/conf/rutorrent-vpn.yml
    ;;
  jackett)
    docker rm -f flaresolverr >/dev/null 2>&1
    ;;
  petio)
    docker rm -f mongo >/dev/null 2>&1
    ;;
  vinkunja)
    docker rm -f vikunja-api >/dev/null 2>&1
    ;;
  esac

  if docker ps | grep -q db-$APPSELECTED; then
    docker rm -f db-$APPSELECTED >/dev/null 2>&1
  fi

  if docker ps | grep -q redis-$APPSELECTED; then
    docker rm -f redis-$APPSELECTED >/dev/null 2>&1
  fi

  if docker ps | grep -q memcached-$APPSELECTED; then
    docker rm -f memcached-$APPSELECTED >/dev/null 2>&1
  fi

  checking_errors $?

  ansible-playbook -e pgrole=${APPSELECTED} ${SETTINGS_SOURCE}/includes/config/playbooks/remove_cf_record.yml

  echo""
  echo -e "${BLUE}### $APPSELECTED a été supprimé ###${NC}"
  echo ""

  req1="delete from applications where name='"
  req2="'"
  req=${req1}${APPSELECTED}${req2}
  sqlite3 ${SETTINGS_SOURCE}/ssddb <<EOF
$req

EOF

}

function pause() {
  echo ""
  echo -e "${YELLOW}###  -->APPUYER SUR ENTREE POUR CONTINUER<--  ###${NC}"
  read
  echo ""
}

select_seedbox_param() {
  if [ ! -f ${SETTINGS_SOURCE}/ssddb ]; then
    # le fichier de base de données n'est pas là
    # on sort avant de faire une requête, sinon il va se créer
    # et les tests ne seront pas bons
    return 0
  fi
  request="select value from seedbox_params where param ='"${1}"'"
  RETURN=$(sqlite3 ${SETTINGS_SOURCE}/ssddb "${request}")
  if [ $? != 0 ]; then
    echo 0
  else
    echo $RETURN
  fi

}

function update_seedbox_param() {
  # shellcheck disable=SC2027
  request="replace into seedbox_params (param,value) values ('"${1}"','"${2}"')"
  sqlite3 "${SETTINGS_SOURCE}/ssddb" "${request}"
}

function manage_account_yml() {
  # usage
  # manage_account_yml key value
  # key séparées par des points (par exemple user.name ou sub.application.subdomain)
  # pour supprimer une clé, il faut que le value soit égale à un espace
  # ex : manage_account_yml sub.toto.toto toto => va créer la clé sub.toto.toto et lui mettre à la valeur toto
  # ex : manage_account_yml sub.toto.toto " " => va supprimer la clé sub.toto.toto et toutes les sous clés
  if [ -f ${SETTINGS_STORAGE}/.account.lock ]; then
    echo "Fichier account locké, impossible de continuer"
    echo "----------------------------------------------"
    echo "Présence du fichier ${SETTINGS_STORAGE}/.account.lock"
    exit 1
  else
    touch ${SETTINGS_STORAGE}/.account.lock
    ansible-vault decrypt "${ANSIBLE_VARS}" >/dev/null 2>&1
    if [ "${2}" = " " ]; then
      ansible-playbook "${SETTINGS_SOURCE}/includes/config/playbooks/manage_account_yml.yml" -e "account_key=${1} account_value=${2}  state=absent"
    else
      ansible-playbook "${SETTINGS_SOURCE}/includes/config/playbooks/manage_account_yml.yml" -e "account_key=${1} account_value=${2} state=present"
    fi
    ansible-vault encrypt "${ANSIBLE_VARS}" >/dev/null 2>&1
    rm -f ${SETTINGS_STORAGE}/.account.lock
  fi
}

function get_from_account_yml() {
  tempresult=$(ansible-playbook ${SETTINGS_SOURCE}/includes/config/playbooks/get_var.yml -e myvar=$1 -e tempfile=${tempfile} | grep "##RESULT##" | awk -F'##RESULT##' '{print $2}'|xargs)
  if [ -z "$tempresult" ]; then
    tempresult=notfound
  fi
  echo $tempresult
}

function get_from_account_yml_old() {
  # usage
  # get_from_account_yml user.name
  # retourne la valeur trouvée
  # si la valeur est vide ou n'existe pas, retourn la chaine "notfound"
  if [ -f ${SETTINGS_STORAGE}/.account.lock ]; then
    echo "Fichier account locké, impossible de continuer"
    echo "----------------------------------------------"
    echo "Présence du fichier ${SETTINGS_STORAGE}/.account.lock"
    exit 1
  else
    touch ${SETTINGS_STORAGE}/.account.lock
    ansible-vault decrypt "${HOME}/.ansible/inventories/group_vars/all.yml" >/dev/null 2>&1
    temp_return=$(shyaml -q get-value $1 <"${HOME}/.ansible/inventories/group_vars/all.yml")
    if [ $? != 0 ]; then
      temp_return=notfound
    fi
    if [ -z "$temp_return" ]; then
      temp_return=notfound
    fi
    if [ "$temp_return" == "None" ]; then
      temp_return=notfound
    fi
    ansible-vault encrypt "${HOME}/.ansible/inventories/group_vars/all.yml" >/dev/null 2>&1
    if [ "$1" == "network.ipv6" ]; then
      if [[ "${temp_return}" == 'a['* ]]; then
        temp_return=${temp_return:2:-1}
      fi
    fi
    echo $temp_return
    rm -f ${SETTINGS_STORAGE}/.account.lock
  fi
}

function install_gui() {
  domain=$(get_from_account_yml user.domain)
  tempsubdomain=$(get_from_account_yml sub.gui.gui)
  if [ "${tempsubdomain}" = notfound ]; then
    subdomain_unitaire gui
  fi
  tempauth=$(get_from_account_yml sub.gui.auth)
  if [ "${tempauth}" = notfound ]; then
    auth_unitaire gui
  fi
  subomain=$(get_from_account_yml sub.gui.gui})

  set +a
  export gui_subdomain=$subdomain
  # On install nginx
  ansible-playbook ${SETTINGS_SOURCE}/includes/config/roles/nginx/tasks/main.yml

  echo -e "${CRED}---------------------------------------------------------------${CEND}"
  echo -e "${CRED}          /!\ INSTALLATION EFFECTUEE AVEC SUCCES /!\           ${CEND}"
  echo -e "${CRED}---------------------------------------------------------------${CEND}"
  echo ""
  echo -e "${CRED}---------------------------------------------------------------${CEND}"
  echo -e "${CCYAN}              Adresse de l'interface WebUI                    ${CEND}"
  echo -e "${CCYAN}              https://${subdomain}.${domain}              ${CEND}"
  echo -e "${CRED}---------------------------------------------------------------${CEND}"
  echo ""

  echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour sortir du script..."
  read -r
  exit 0
}

function premier_lancement() {

  sudo chown -R ${USER}: ${SETTINGS_SOURCE}/

  echo "Certains composants doivent encore être installés/réglés"
  echo "Cette opération va prendre plusieurs minutes selon votre système "
  echo "=================================================================="
  read -p "Appuyez sur entrée pour continuer, ou ctrl+c pour sortir"

  # installation des paquets nécessaires
  # on passe le user en parametre pour pouvoir créer le /etc/sudoers.d/${USER}
  sudo "${SETTINGS_SOURCE}/includes/config/scripts/prerequis_root.sh" "${USER}"

  # création d'un vault_pass vide

  if [ ! -f "${HOME}/.vault_pass" ]; then
    mypass=$(
      tr -dc A-Za-z0-9 </dev/urandom | head -c 25
      echo ''
    )
    echo "$mypass" >"${HOME}/.vault_pass"

  fi

  # création d'un virtualenv
  python3 -m venv ${SETTINGS_SOURCE}/venv

  # activation du venv
  source ${SETTINGS_SOURCE}/venv/bin/activate

  temppath=$(ls ${SETTINGS_SOURCE}/venv/lib)
  pythonpath=${SETTINGS_SOURCE}/venv/lib/${temppath}/site-packages
  export PYTHONPATH=${pythonpath}

  ## Constants
  python3 -m pip install --disable-pip-version-check --upgrade --force-reinstall \
    pip
  pip install wheel
  pip install ansible \
    docker \
    shyaml \
    netaddr \
    dnspython \
    configparser \
    inquirer \
    pyyaml \
    ansible-runner \
    simple-term-menu

  ##########################################
  # Pas de configuration existante
  # On installe les prérequis
  ##########################################

  echo "Installation en cours ...."

  mkdir -p ~/.ansible/inventories

  ###################################
  # Configuration ansible
  # Pour le user courant uniquement
  ###################################
  mkdir -p /etc/ansible/inventories/ 1>/dev/null 2>&1
  cat <<EOF >~/.ansible/inventories/local
  [local]
  127.0.0.1 ansible_connection=local
EOF

  cat <<EOF >~/.ansible.cfg
  [defaults]
  command_warnings = False
  callback_whitelist = profile_tasks
  deprecation_warnings=False
  inventory = ~/.ansible/inventories/local
  interpreter_python=/usr/bin/python3
  vault_password_file = ~/.vault_pass
  log_path=${SETTINGS_SOURCE}/logs/ansible.log
EOF

  echo "Création de la configuration en cours"
  # On créé la database
  sqlite3 "${SETTINGS_SOURCE}/ssddb" <<EOF
    create table seedbox_params(param varchar(50) PRIMARY KEY, value varchar(50));
    replace into seedbox_params (param,value) values ('installed',0);
    create table applications(name varchar(50) PRIMARY KEY,
      status integer,
      subdomain varchar(50),
      port integer);
    create table applications_params (appname varchar(50),
      param varachar(50),
      value varchar(50),
      FOREIGN KEY(appname) REFERENCES applications(name));
EOF

  ##################################################
  # Account.yml
  sudo mkdir "${SETTINGS_SOURCE}/logs"
  sudo chown -R ${user}: "${SETTINGS_SOURCE}/logs"
  sudo chmod 755 "${SETTINGS_SOURCE}/logs"

  create_dir "${SETTINGS_STORAGE}"
  create_dir "${SETTINGS_STORAGE}/variables"
  create_dir "${SETTINGS_STORAGE}/conf"
  create_dir "${SETTINGS_STORAGE}/vars"
  if [ ! -f "${ANSIBLE_VARS}" ]; then
    mkdir -p "${HOME}/.ansible/inventories/group_vars"
    cp ${SETTINGS_SOURCE}/includes/config/account.yml "${ANSIBLE_VARS}"
  fi

  if [[ -d "${HOME}/.cache" ]]; then
    sudo chown -R "${USER}": "${HOME}/.cache"
  fi
  if [[ -d "${HOME}/.local" ]]; then
    sudo chown -R "${USER}": "${HOME}/.local"
  fi
  if [[ -d "${HOME}/.ansible" ]]; then
    sudo chown -R "${USER}": "${HOME}/.ansible"
  fi

  touch "${SETTINGS_SOURCE}/.prerequis.lock"

  install_common
  # shellcheck disable=SC2162
  echo "Les composants sont maintenants tous installés/réglés, poursuite de l'installation"

  read -p "Appuyez sur entrée pour continuer, ou ctrl+c pour sortir"

  # fin du venv
}

function usage() {
  echo ""
  echo "########################################"
  echo "# SSD: Script Seedbox Docker           #"
  echo "# USAGE                                #"
  echo "########################################"
  echo "./seedbox.sh [OPTIONS]"
  echo ""
  echo "Si aucune options passée, le script se lance en interactif"
  echo "----------------------------------------"
  echo "./seedbox.sh [OPTIONS]"
  echo ""
  echo "Si aucune options passée, le script se lance en interactif"
  echo "----------------------------------------"
  echo "Options possibles : "
  echo "--help"
  echo "  Affiche cette aide"
  echo "--migrate"
  echo "  gère la migration de la V1 vers la V2"
  echo ""
  exit 0
}

function log_write() {
  DATE=$(date +'%F %T')
  FILE=${SETTINGS_SOURCE}/logs/seedbox.log
  echo "${DATE} - ${1}" >>${FILE}
  echo "${1}"
}

function log_migrate() {
  LOG_MIGRATE=${SETTINGS_SOURCE}/logs/migrate.log
  echo $1 >>${LOG_MIGRATE}
  echo $1
}

function migrate() {
  LOG_MIGRATE=${SETTINGS_SOURCE}/logs/migrate.log
  echo "Vous allez migrer de SSD V1 vers SSD V2"
  if [ "$USER" == "root" ]; then
    echo "Vous ne POUVEZ pas faire cette opération en root"
    echo "Merci de vous connecter sur le bon user avant de relancer"
    exit 1
  fi

  # on bouge le vault pass
  if sudo test -f /root/.vault_pass; then
    sudo cp /root/.vault_pass ${HOME}/.vault_pass
    sudo chown ${USER}: ${HOME}/.vault_pass
  else
    # pas de vault_pass trouvé en root ?
    if [ -f "${HOME}/.vault_pass" ]; then
      :
    else
      # pas de vault_pass dans le user, on en créé un
      mypass=$(
        tr -dc A-Za-z0-9 </dev/urandom | head -c 25
        echo ''
      )
      echo "$mypass" >"${HOME}/.vault_pass"
    fi
  fi
  echo "Application des droits pour le nouveau user"
  echo "Cette opération peut prendre du temps en fonction du nombre de fichiers à traiter"
  echo "Merci de votre patience ..."
  echo "=================================================================================="
  sudo chown -R "${USER}": ${SETTINGS_STORAGE}/status
  sudo chown -R ${USER}: ${SETTINGS_STORAGE}/status/*
  sudo chown ${USER} ${ANSIBLE_VARS}
  premier_lancement

  # on revient dans le venv
  sudo chown -R "${USER}": ${SETTINGS_SOURCE}/venv
  source ${SETTINGS_SOURCE}/venv/bin/activate
  olduser=$(get_from_account_yml user.name)
  if [ "${olduser}" != "$USER" ]; then
    echo "Vous devez être connexté avec le même user que celui qui gérait la seedbox (${olduser}) pour effectuer cette action"
    exit 1
  fi

  sudo chown -R "${USER}": ${SETTINGS_STORAGE}/status
  sudo chown -R ${USER}: ${SETTINGS_STORAGE}/status/*
  sudo chown ${USER} ${ANSIBLE_VARS}

  echo "Assurez vous d'être connecté sur le bon utilisateur (celui qui va piloter la seedbox)"
  echo "en connection directe (pas de connection sur un autre user ou root, puis sudo)"
  echo "Cela va provoquer des coupures de service"
  echo "--------------------------------------------"
  echo "Les données vont être conservées, mais les éventuelles personnalisations peuvent être perdues"
  echo "(personnalisations = modifications manuelles des fichiers de service ou des playbooks)"
  read -p "Appuyez sur entrée pour lancer la procédure"
  # copie éventuelle du rclone existant
  if [ -f "${HOME}/.config/rclone/rclone.conf" ]; then
    mv "${HOME}/.config/rclone/rclone.conf" "${HOME}/.config/rclone/rclone.conf.backup_migration"
    log_migrate "Le fichier rclone existant a été copié sur ${HOME}/.config/rclone/rclone.conf.backup_migration"
  fi
  # copie du rclone de root
  mkdir -p "${HOME}/.config/rclone"
  mkdir -p "${SETTINGS_STORAGE}/vars"
  sudo cp /root/.config/rclone/rclone.conf "${HOME}/.config/rclone/rclone.conf"
  sudo chown "${USER}" "${HOME}/.config/rclone/rclone.conf"
  sudo chown -R "${USER}" ${SETTINGS_STORAGE}/conf
  sudo chown "${USER}": "${ANSIBLE_VARS}"

  # remplacement du backup
  log_migrate "Mise à jour du script de sauvegarde"
  sauve
  # on relance l'install de rclone pour avoir le bon fichier service
  # on supprime le fichier de service existant
  if [ -f "/etc/systemd/system/rclone.service" ]; then
    ansible-playbook ${SETTINGS_SOURCE}/includes/config/roles/rclone/tasks/main.yml
  fi
  # on met les bons droits sur le conf dir
  conf_dir
  # cloudplow
  if [ -f "/etc/systemd/system/cloudplow.service" ]; then
    # on sauvegarde l'ancienne config
    cp /home/${USER}/scripts/cloudplow/config.json /tmp/cloudplow
    install_cloudplow
    # on remet l'ancienne config
    cp /home/${USER}/scripts/cloudplow/config.json /home/${USER}/scripts/cloudplow/config.json.ssdv2
    cp /tmp/cloudplow /home/${USER}/scripts/cloudplow/config.json
    sudo chown -R ${USER}: /home/${USER}/scripts/cloudplow

  fi
  # crop
  if [ -f "/etc/systemd/system/crop_upload.service" ]; then
    crop
  fi
  # plexdrive
  if [ -f "/etc/systemd/system/plexdrive.service" ]; then
    plexdrive
  fi
  # Resintall des applis
  log_migrate "Prérequis de migration terminés, passage à la réinstallation des applications"
  pause
  reinstall_appli_migrate

  # on marque la seedbox comme installée
  update_seedbox_param "installed" 1
  log_migrate "Migration terminée, il est conseillé de redémarrer la seedbox"
}

function reinstall_appli_migrate() {
  for appli in $(ls ${SETTINGS_STORAGE}/status/); do
    temp=$(cat ${SETTINGS_STORAGE}/status/${appli})
    if [ ${appli} != "traefik" ] && [ ${appli:0:3} != "db-" ] && [ ${appli} != "watchtower" ] && [ ${appli} != "flaresolverr" ] && [ ${appli} != "cloudplow" ] && [ ${appli} != "autoscan" ] && [ ${appli} != "collabora" ] && [ ${appli} != "office" ] && [ ${appli} != "plex" ]; then
      if [ "${temp:0:1}" = 2 ]; then
        echo "###########################################"
        echo "# Migration de l'application ${appli}"
        # appli à réinstaller
        # echo "L'appli ${appli} est à réinstaller"
        # on supprime les fichiers de conf existant
        rm -f "${SETTINGS_STORAGE}/conf/${appli}.yml"
        launch_service ${appli}
      fi
    fi
  done
}

function check_docker_group() {
  error=0
  if getent group docker >/dev/null 2>&1; then
    if getent group docker | grep ${USER} >/dev/null 2>&1; then
      :
    else
      error=1
      sudo usermod -aG docker ${USER}
    fi
  else
    error=1
    sudo groupadd docker
    sudo usermod -aG docker ${USER}
  fi
  if [ "${error}" = 1 ]; then
    echo "IMPORTANT !"
    echo "==================================================="
    echo "Votre utilisateur n'était pas dans le groupe docker"
    echo "Il a été ajouté, mais vous devez vous déconnecter/reconnecter pour que la suite du process puisse fonctionner"
    echo "===================================================="
    exit 1
  fi
}

function stocke_public_ip() {
  echo "Stockage des adresses ip publiques"
  IPV4=$(curl -4 https://ip.mn83.fr)
  echo "IPV4 = ${IPV4}"
  manage_account_yml network.ipv4 ${IPV4}
  #IPV6=$(dig @resolver1.ipv6-sandbox.opendns.com AAAA myip.opendns.com +short -6)
  IPV6=$(curl -6 https://ip.mn83.fr)
  if [ $? -eq 0 ]; then
    echo "IPV6 = ${IPV6}"
    manage_account_yml network.ipv6 "a[${IPV6}]"
  else
    echo "Aucune adresse ipv6 trouvée"
  fi
}

function install_environnement() {
  clear
  echo ""
  source "${SETTINGS_SOURCE}/profile.sh"
  ansible-playbook "${SETTINGS_SOURCE}/includes/config/roles/user_environment/tasks/main.yml"
  echo "Pour bénéficer des changements, vous devez vous déconnecter/reconnecter"
  pause
}

function debug_menu() {
  if [ -z "$OLDIFS" ]; then
    OLDIFS=${IFS}
  fi
  IFS=$'\n'
  start_menu="is null"
  precedent=""
  if [[ $# -ne 0 ]]; then
    if [ -z "$1" ]; then
      :
    else
      start_menu="=${1}"
      precedent="${1}"
    fi
  fi

  ## chargement des menus
  request="select * from menu where parent_id ${start_menu}"
  sqlite3 "${SETTINGS_SOURCE}/menu" "${request}" | while read -a db_select; do
    texte_sep=""
    IFS='|'
    read -ra db_select2 <<<"$db_select"
    separateur=$(calcul_niveau_menu "${db_select2[0]}")
    IFS=$'\n'
    for i in $(seq 1 ${separateur}); do
      texte_sep="${texte_sep} ==> "
    done

    echo -e "${texte_sep}${db_select2[0]}-${db_select2[3]}) ${db_select2[1]} | ${db_select2[4]}"

    # on regarde s'il y a des menus enfants
    request_cpt="select count(*) from menu where parent_id = ${db_select2[0]}"
    cpt=$(sqlite3 ${SETTINGS_SOURCE}/menu "$request_cpt")
    if [ "${cpt}" -eq 0 ]; then
      # pas de sous menu, on va rester sur le même
      :
    else
      debug_menu "${db_select2[0]}"

    fi
    IFS=$'\n'
  done

  IFS=${OLDFIFS}
}

function calcul_niveau_menu() {
  if [[ $# -ne 0 ]]; then
    niveau=${2}
    if [ -z $niveau ]; then
      niveau=1
    fi
    depart="${1}"
    request_cpt="select parent_id from menu where id = ${depart}"
    parent=$(sqlite3 "${SETTINGS_SOURCE}/menu" "$request_cpt")
    if [ -z "$parent" ]; then

      echo $niveau
    else
      request_cpt="select count(*) from menu where parent_id = ${parent}"
      cpt=$(sqlite3 ${SETTINGS_SOURCE}/menu "$request_cpt")
      if [ "${cpt}" -eq 0 ]; then
        echo $niveau
      else
        niveau=$((niveau + 1))
        request_cpt="select parent_id from menu where id = ${depart}"
        parent2=$(sqlite3 ${SETTINGS_SOURCE}/menu "$request_cpt")
        if [ -z "$parent2" ]; then
          echo $niveau
        fi
        niveau=$(calcul_niveau_menu ${parent} ${niveau})
      fi
      echo $niveau
    fi
  else
    echo 0
  fi
}

function affiche_menu_db() {
  if [ -z "$OLDIFS" ]; then
    OLDIFS=${IFS}
  fi
  IFS=$'\n'
  echo -e "${CGREEN}${CEND}"
  start_menu="is null"
  texte_sortie="Sortie du script"
  precedent=""
  if [[ $# -eq 1 ]]; then
    if [ -z "$1" ]; then
      :
    else
      start_menu="=${1}"
      texte_sortie="Menu précédent"
      precedent="${1}"
    fi
  fi
  clear
  logo
  ## chargement des menus
  request="select * from menu where parent_id ${start_menu}"
  sqlite3 "${SETTINGS_SOURCE}/menu" "${request}" | while read -a db_select; do
    IFS='|'
    read -ra db_select2 <<<"$db_select"
    echo -e "${CGREEN}   ${db_select2[3]}) ${db_select2[1]}${CEND}"
    IFS=$'\n'
  done
  echo -e "${CGREEN}---------------------------------------${CEND}"
  if [ "${precedent}" = "" ]; then
    :
  else
    echo -e "${CGREEN}   H) Retour au menu principal${CEND}"
    echo -e "${CGREEN}   B) Retour au menu précédent${CEND}"
  fi
  echo -e "${CGREEN}   Q) Quitter${CEND}"
  echo -e "${CGREEN}---------------------------------------${CEND}"
  read -p "Votre choix : " PORT_CHOICE

  if [ "${PORT_CHOICE,,}" == "b" ]; then

    request2="select parent_id from menu where id ${start_menu}"
    newchoice=$(sqlite3 ${SETTINGS_SOURCE}/menu $request2)
    affiche_menu_db ${newchoice}
  elif [ "${PORT_CHOICE,,}" == "q" ]; then
    exit 0
  elif [ "${PORT_CHOICE,,}" == "h" ]; then
    # retour au début
    affiche_menu_db
  else
    # on va voir s'il y a une action à faire
    request_action="select action from menu where parent_id ${start_menu} and ordre = ${PORT_CHOICE}"
    action=$(sqlite3 ${SETTINGS_SOURCE}/menu "$request_action")
    if [ -z "$action" ]; then
      : # pas d'action à effectuer
    else
      # on va lancer la fonction qui a été chargée
      IFS=${OLDIFS}
      ${action}
    fi

    req_new_choice="select id from menu where parent_id ${start_menu} and ordre = ${PORT_CHOICE}"
    newchoice=$(sqlite3 ${SETTINGS_SOURCE}/menu "${req_new_choice}")
    request_cpt="select count(*) from menu where parent_id = ${newchoice}"
    cpt=$(sqlite3 ${SETTINGS_SOURCE}/menu "$request_cpt")
    if [ "${cpt}" -eq 0 ]; then
      # pas de sous menu, on va rester sur le même
      newchoice=${precedent}
    fi
    affiche_menu_db ${newchoice}

  fi
  IFS=${OLDFIFS}
}

function log_statusbar() {
  tput sc                           #save the current cursor position
  tput cup $(($(tput lines) - 2)) 3 # go to last line
  tput ed
  tput cup $(($(tput lines) - 1)) 3 # go to last line
  echo $1
  tput rc # bring the cursor back to the last saved position
}

function choix_appli_sauvegarde() {
  touch $SERVICESPERUSER
  TABSERVICES=()
  for SERVICEACTIVATED in $(docker ps --format "{{.Names}}"); do
    SERVICE=$(echo $SERVICEACTIVATED | cut -d\. -f1)
    TABSERVICES+=(${SERVICE//\"/} " ")
  done

  line=$(
    whiptail --title "App Manager" --menu \
      "Sélectionner le container à sauvegarder" 19 45 11 \
      "${TABSERVICES[@]}" 3>&1 1>&2 2>&3
  )
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    sauve_one_appli ${line}
  fi
}

function sauve_one_appli() {
  #############################
  # Parametres :
  # $1 = nom de l'appli
  # $2 ((optionnel) : nombre de backups à garder
  # si $2 = 0 => pas de suppression des vieux backups
  # si $2 non renseigné, on reste à 3 backups à garder
  ##############################

  # Définition des variables de couleurs
  CSI="\033["
  CEND="${CSI}0m"
  CRED="${CSI}1;31m"
  CGREEN="${CSI}1;32m"
  CYELLOW="${CSI}1;33m"
  CCYAN="${CSI}0;36m"

  # Variables
  remote=$(get_from_account_yml rclone.remote)
  APPLI=$1

  NB_MAX_BACKUP=3
  ALL_RETENTION=0
  if [ $# == 2 ]; then
    if [ "$2" == 0 ]; then
      ALL_RETENTION=1
    else
      NB_MAX_BACKUP=$2
    fi
  fi
  SOURCE_DIR="${SETTINGS_STORAGE}/docker/${USER}"
  remote_backups=BACKUPS

  echo "Sauvegarde de l'application $1"
  if [ $ALL_RETENTION -eq 0 ]; then
    echo "Nombre de backups à garder : $NB_MAX_BACKUP"
  else
    echo "Pas de suppression des vieux backups"
  fi

  CDAY=$(date +%Y%m%d-%H%M)
  BACKUP_PARTITION=/var/backup/local
  #BACKUP_FOLDER=$BACKUP_PARTITION/$APPLI-$CDAY
  ARCHIVE=$APPLI-$CDAY.tar.gz

  echo ""
  echo -e "${CRED}-------------------------------------------------------${CEND}"
  echo -e "${CRED} /!\ ATTENTION : SAUVEGARDE DE ${APPLI} IMMINENTE /!\ ${CEND}"
  echo -e "${CRED}-------------------------------------------------------${CEND}"

  # Stop Plex
  echo -e "${CCYAN}> Arrêt de ${APPLI}${CEND}"
  #docker stop `docker ps -q`
  docker stop ${APPLI}
  sleep 5

  echo ""
  echo -e "${CCYAN}#########################################################${CEND}"
  echo ""
  echo -e "${CCYAN}          DEMARRAGE DU SCRIPT DE SAUVEGARDE              ${CEND}"
  echo ""
  echo -e "${CCYAN}#########################################################${CEND}"
  echo ""

  echo -e "${CCYAN}> Création de l'archive${CEND}"
  sudo tar -I pigz -cf $BACKUP_PARTITION/$ARCHIVE -P $SOURCE_DIR/$APPLI
  sleep 2s

  # Si une erreur survient lors de la compression
  if [[ -s "$ERROR_FILE" ]]; then
    echo -e "\n${CRED}/!\ ERREUR: Echec de la compression des fichiers système.${CEND}" | tee -a $LOG_FILE
    echo -e "" | tee -a $LOG_FILE
    exit 1
  fi

  # Restart Plex
  echo -e "${CCYAN}> Lancement de ${APPLI}${CEND}"
  docker start $APPLI
  sleep 5

  echo -e "${CCYAN}> Envoie Archive vers Google Drive${CEND}"
  # Envoie Archive vers Google Drive
  rclone --config "/home/${USER}/.config/rclone/rclone.conf" copy "$BACKUP_PARTITION/$ARCHIVE" "${remote}:/${USER}/${remote_backups}/" -v --progress

  # Nombre de sauvegardes effectuées
  nbBackup=$(find $BACKUP_PARTITION -type f -name $APPLI-* | wc -l)
  if [ $ALL_RETENTION -eq 0 ]; then
    if [[ "$nbBackup" -gt "$NB_MAX_BACKUP" ]]; then

      # Archive la plus ancienne
      oldestBackupPath=$(find $BACKUP_PARTITION -type f -name $APPLI-* -printf '%T+ %p\n' | sort | head -n 1 | awk '{print $2}')
      oldestBackupFile=$(find $BACKUP_PARTITION -type f -name $APPLI-* -printf '%T+ %p\n' | sort | head -n 1 | awk '{split($0,a,/\//); print a[5]}')

      # Suppression du répertoire du backup
      rm -rf "$oldestBackupPath"

      # Suppression Archive Google Drive
      echo -e "${CCYAN}> Suppression de l'archive la plus ancienne${CEND}"
      rclone --config "/home/${USER}/.config/rclone/rclone.conf" purge "$remote:/$remote_backups/$oldestBackupFile" -v --log-file=/var/log/backup.log
    fi
  fi
  echo ""
  echo -e "${CRED}-------------------------------------------------------${CEND}"
  echo -e "${CRED}        SAUVEGARDE ${APPLI}  TERMINEE                 ${CEND}"
  echo -e "${CRED}-------------------------------------------------------${CEND}"

}

function change_password() {
  echo "#############################################"
  echo "Cette procédure va redéarrer traefik "
  echo "Pendant cette opération, les interfaces web seront inaccessibles"
  read -rp $'\e[33mSaisissez le nouveau password\e[0m : ' NEWPASS
  manage_account_yml user.pass "${NEWPASS}"
  manage_account_yml user.htpwd $(htpasswd -nb ${USER} ${NEWPASS})
  docker rm -f traefik
  launch_service traefik
}

function relance_container() {
  touch $SERVICESPERUSER
  TABSERVICES=()
  for SERVICEACTIVATED in $(docker ps --format "{{.Names}}"); do
    SERVICE=$(echo $SERVICEACTIVATED | cut -d\. -f1)
    TABSERVICES+=(${SERVICE//\"/} " ")
  done
  line=$(
    whiptail --title "App Manager" --menu \
      "Sélectionner le container à réinitialiser" 19 45 11 \
      "${TABSERVICES[@]}" 3>&1 1>&2 2>&3
  )
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    log_write "Relance du container ${line}"
    echo "###############################################"
    echo "# Relance du container ${line} "
    echo "###############################################"
    docker rm -f ${line}
    launch_service ${line}
  fi
}

function install_plextraktsync() {
  ansible-playbook ${SETTINGS_SOURCE}/includes/config/roles/plextraktsync/tasks/main.yml
  echo "Préparation pour le premier lancement de configuration"
  echo "Assurez vous d'avoir les api Trakt avant de continuer (https://trakt.tv/oauth/applications/new)"
  pause
  /usr/local/bin/plextraktsync
  echo "L'outil est installé et se lancera automatiquement toutes les heures"
  pause
}

function install_block_public_tracker() {
  echo "Block_public_tracker va bloquer les trackers publics (piratebay, etc...) sur votre machine au niveau réseau"
  echo "Ces trackers ne seront plus accessibles"
  echo "Appuyez sur entrée pour continer, ou ctrl+C pour sortir"
  pause
  ansible-playbook ${SETTINGS_SOURCE}/includes/config/playbooks/block_public_tracker.yml
  echo "Block_public_tracker a été installé avec succès"
  pause
}

function relance_tous_services() {
  sqlite3 ${SETTINGS_SOURCE}/ssddb <<EOF >$SERVICESPERUSER
select name from applications;
EOF

  install_services
  launch_service traefik
}

function correct_init() {
  echo "###################################"
  echo "# ATTENTION !!! Cette opération va redémarrer le démon docker"
  echo "# Cette opération peut prendre quelques minutes et certaines appliactions"
  echo "# risquent de ne pas redémarrer"
  echo "####################################"
  echo "# Ne continuez que si vous avez le bug 'init'"
  echo "# Si vous n'êtes pas sur, faites ctrl+c pour sortir"
  pause
  sudo rm -f /etc/docker/daemon.json
  sudo systemctl restart docker

}

function apply_patches() {
  touch "${HOME}/.config/kubeseed/patches"
  for patch in $(ls ${SETTINGS_SOURCE}/patches); do
    if grep -q "${patch}" "${HOME}/.config/kubeseed/patches"; then
      # parch déjà appliqué, on ne fait rien
      :
    else
      # on applique le patch
      bash "${SETTINGS_SOURCE}/patches/${patch}"
      echo "${patch}" >>"${HOME}/.config/kubeseed/patches"
    fi
  done
}