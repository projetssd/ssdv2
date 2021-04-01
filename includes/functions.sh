#!/bin/bash
##########

function logo() {

  color1='\033[1;31m' # light red
  color2='\033[1;35m' # light purple
  color3='\033[0;33m' # light yellow
  nocolor='\033[0m'   # no color
  companyname='\033[1;34mMondedie.fr\033[0m'
  divisionname='\033[1;32mlaster13\033[0m'
  descriptif='\033[1;31mHeimdall - Syncthing - sonerezh - Portainer - Nextcloud - Lidarr\033[0m'
  appli='\033[0;36mPlex - Sonarr - Medusa - Rutorrent - Radarr - Jackett - Pyload - Traefik\033[0m'

  printf "               ${color1}.-.${nocolor}\n"
  printf "         ${color2}.-'\`\`${color1}(   )    ${companyname}${nocolor}\n"
  printf "      ${color3},\`\\ ${color2}\\    ${color1}\`-\`${color2}.    ${divisionname}${nocolor}\n"
  printf "     ${color3}/   \\ ${color2}'\`\`-.   \`   ${color3}$(lsb_release -sd)${nocolor}\n"
  printf "   ${color2}.-.  ${color3},       ${color2}\`___:  ${nocolor}$(uname -srmo)${nocolor}\n"
  printf "  ${color2}(   ) ${color3}:       ${color1} ___   ${nocolor}$(date +"%A, %e %B %Y, %r")${nocolor}\n"
  printf "   ${color2}\`-\`  ${color3}\`      ${color1} ,   :${nocolor}  Seedbox docker\n"
  printf "     ${color3}\\   / ${color1},..-\`   ,${nocolor}   ${descriptif} ${nocolor}\n"
  printf "      ${color3}\`./${color1} /    ${color3}.-.${color1}\`${nocolor}    ${appli}\n"
  printf "         ${color1}\`-..-${color3}(   )${nocolor}    Uptime: $(/usr/bin/uptime -p)\n"
  printf "               ${color3}\`-\`${nocolor}\n"
  echo ""

}

function update_system() {
  #Mise à jour systeme
  echo -e "${BLUE}### MISE A JOUR DU SYTEME ###${NC}"
  ansible-playbook ${BASEDIR}/includes/config/roles/system/tasks/main.yml
  checking_errors $?
}

function status() {
  # Créé les fichiers de service, comme quoi rien n'est encore installé
  create_dir ${CONFDIR}/status
  for app in $(cat ${BASEDIR}/includes/config/services-available); do
    service=$(echo $app | tr '[:upper:]' '[:lower:]' | cut -d\- -f1)
    echo "0" >>${CONFDIR}/status/$service
  done
  for app in $(cat ${BASEDIR}/includes/config/other-services-available); do
    service=$(echo $app | tr '[:upper:]' '[:lower:]' | cut -d\- -f1)
    echo "0" >>${CONFDIR}/status/$service
  done
}

function update_status() {
  for i in $(docker ps --format "{{.Names}}" --filter "network=traefik_proxy"); do
    echo "2" >${CONFDIR}/status/${i}

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
      ###sed -i "/login:/c\   login: $cloud_email" ${CONFDIR}/variables/account.yml
      update_seedbox_param "cf_login" $cloud_email
    done

    while [ -z "$cloud_api" ]; do
      echo >&2 -n -e "${BWHITE}Votre API Cloudflare: ${CEND}"
      read cloud_api
      manage_account_yml cloudflare.api "$cloud_api"
      ###sed -i "/api:/c\   api: $cloud_api" ${CONFDIR}/variables/account.yml
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
      ###sed -i "s/client:/client: $oauth_client/" ${CONFDIR}/variables/account.yml
    done

    while [ -z "$oauth_secret" ]; do
      echo >&2 -n -e "${BWHITE}Oauth_secret: ${CEND}"
      read oauth_secret
      manage_account_yml oauth.secret "$oauth_secret"
      ###sed -i "s/secret:/secret: $oauth_secret/" ${CONFDIR}/variables/account.yml
    done

    while [ -z "$email" ]; do
      echo >&2 -n -e "${BWHITE}Compte Gmail utilisé(s), séparés d'une virgule si plusieurs: ${CEND}"
      read email
      manage_account_yml oauth.account "$email"
      ###sed -i "s/account:/account: $email/" ${CONFDIR}/variables/account.yml
    done

    openssl=$(openssl rand -hex 16)
    manage_account_yml oauth.openssl "$openssl"
    ###sed -i "s/openssl:/openssl: $openssl/" ${CONFDIR}/variables/account.yml

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

function rtorrent-cleaner() {
  #configuration de rtorrent-cleaner avec ansible
  echo -e "${BLUE}### RTORRENT-CLEANER ###${NC}"
  echo ""
  echo -e " ${BWHITE}* Installation RTORRENT-CLEANER${NC}"

  ## choix de l'utilisateur
  SEEDUSER=$(ls ${CONFDIR}/media* | cut -d '-' -f2)
  cp -r ${BASEDIR}/includes/config/rtorrent-cleaner/rtorrent-cleaner /usr/local/bin
  sed -i "s|%SEEDUSER%|$SEEDUSER|g" /usr/local/bin/rtorrent-cleaner
}

function motd() {
  #configuration d'un motd avec ansible
  echo -e "${BLUE}### MOTD ###${NC}"
  echo -e " ${BWHITE}* Installation MOTD${NC}"
  ansible-playbook ${BASEDIR}/includes/config/roles/motd/tasks/start.yml
  checking_errors $?
  echo ""
}

function sauve() {
  create_dir "/var/backup/local"
  #configuration Sauvegarde
  echo -e "${BLUE}### BACKUP ###${NC}"
  echo -e " ${BWHITE}* Mise en place Sauvegarde${NC}"
  ansible-playbook ${BASEDIR}/includes/config/roles/backup/tasks/main.yml
  checking_errors $?
  echo ""
}

function plex_dupefinder() {
  #configuration plex_dupefinder avec ansible
  echo -e "${BLUE}### PLEX_DUPEFINDER ###${NC}"
  echo -e " ${BWHITE}* Installation plex_dupefinder${NC}"
  ansible-playbook ${BASEDIR}/includes/config/roles/plex_dupefinder/tasks/main.yml
  checking_errors $?
}

function traktarr() {
  ##configuration traktarr avec ansible
  echo -e "${BLUE}### TRAKTARR ###${NC}"
  echo -e " ${BWHITE}* Installation traktarr${NC}"
  ansible-playbook ${BASEDIR}/includes/config/roles/traktarr/tasks/main.yml
  checking_errors $?
}

function webtools() {
  ##configuration Webtools avec ansible
  echo -e "${BLUE}### WEBTOOLS ###${NC}"
  echo -e " ${BWHITE}* Installation Webtools${NC}"
  ansible-playbook ${BASEDIR}/includes/config/roles/webtools/tasks/main.yml
  docker restart plex
  checking_errors $?
}

function plex_autoscan() {
  #configuration plex_autoscan avec ansible
  echo -e "${BLUE}### PLEX_AUTOSCAN ###${NC}"
  echo -e " ${BWHITE}* Installation plex_autoscan${NC}"
  ansible-playbook ${BASEDIR}/includes/config/roles/plex_autoscan/tasks/main.yml
  checking_errors $?
}

function autoscan() {
  #configuration plex_autoscan avec ansible
  echo -e "${BLUE}### AUTOSCAN ###${NC}"
  echo -e " ${BWHITE}* Installation autoscan${NC}"
  ansible-playbook ${BASEDIR}/includes/config/roles/autoscan/tasks/main.yml
  checking_errors $?
}

function crop() {
  #configuration crop avec ansible
  echo -e "${BLUE}### CROP ###${NC}"
  ${BASEDIR}/includes/config/scripts/crop.sh
  echo -e " ${BWHITE}* Installation crop${NC}"
  ansible-playbook ${BASEDIR}/includes/config/roles/crop/tasks/main.yml
  checking_errors $?
}

function cloudplow() {
  #configuration plex_autoscan avec ansible
  echo -e "${BLUE}### CLOUDPLOW ###${NC}"
  echo -e " ${BWHITE}* Installation cloudplow${NC}"
  ansible-playbook ${BASEDIR}/includes/config/roles/cloudplow/tasks/main.yml
  checking_errors $?
}

function filebot() {
  #configuration filebot avec ansible
  echo ""
  echo -e "${BLUE}### FILEBOT ###${NC}"
  echo -e " ${BWHITE}* Installation filebot${NC}"
  ansible-playbook ${BASEDIR}/includes/config/roles/filebot/tasks/main.yml
  checking_errors $?
  echo ""
}

function check_dir() {
  if [[ $1 != ${BASEDIR} ]]; then
    cd ${BASEDIR}
  fi
}

function script_classique() {
  if [[ -d "${CONFDIR}" ]]; then
    clear

    # Vérification installation modt
    confmodt="/opt/motd"
    if [ -d "$confmodt" ]; then
      insert_mod
    else
      logo
    fi

    echo ""
    echo -e "${CCYAN}SEEDBOX CLASSIQUE${CEND}"
    echo -e "${CGREEN}${CEND}"
    echo -e "${CGREEN}   1) Désinstaller la seedbox ${CEND}"
    echo -e "${CGREEN}   2) Ajout/Supression d'Applis${CEND}"
    echo -e "${CGREEN}   3) Outils${CEND}"
    echo -e "${CGREEN}   4) Quitter${CEND}"

    echo -e ""
    read -p "Votre choix [1-4]: " PORT_CHOICE

    case $PORT_CHOICE in
    1) ## Installation de la seedbox
      clear
      echo ""
      echo -e "${YELLOW}### Seedbox-Compose déjà installée !###${NC}"
      if (whiptail --title "Seedbox-Compose déjà installée" --yesno "Désinstaller complètement la Seedbox ?" 7 50); then
        if (whiptail --title "ATTENTION" --yesno "Etes vous sur de vouloir désintaller la seedbox ?" 7 55); then
          uninstall_seedbox
        else
          script_classique
        fi
      else
        script_classique
      fi
      ;;
    2)
      clear
      ## Ajout d'Applications
      echo""
      clear
      manage_apps
      ;;
    3)
      clear
      logo
      echo ""
      echo -e "${CCYAN}OUTILS${CEND}"
      echo -e "${CGREEN}${CEND}"
      echo -e "${CGREEN}   1) Sécuriser la Seedbox${CEND}"
      echo -e "${CGREEN}   2) Mise à jour Seedbox avec Cloudflare${CEND}"
      echo -e "${CGREEN}   3) Changement du nom de Domaine${CEND}"
      if docker ps | grep -q mailserver; then
        echo -e "${YELLOW}   4) Desinstaller Mailserver ${CCYAN}@Hardware-Mondedie.fr${CEND}${NC}"
      else
        echo -e "${CGREEN}   4) Installer Mailserver ${CCYAN}@Hardware-Mondedie.fr${CEND}${NC}"
      fi
      echo -e "${CGREEN}   5) Modèle Création Appli Personnalisée Docker${CEND}"
      echo -e "${CGREEN}   6) Installation du motd${CEND}"
      echo -e "${CGREEN}   7) Traktarr${CEND}"
      echo -e "${CGREEN}   8) Webtools${CEND}"
      echo -e "${CGREEN}   9) rtorrent-cleaner de ${CCYAN}@Magicalex-Mondedie.fr${CEND}${NC}"
      echo -e "${CGREEN}   10) Plex_Patrol${CEND}"
      echo -e "${CGREEN}   11) Bloquer les ports non vitaux avec UFW${CEND}"
      echo -e "${CGREEN}   12) Retour menu principal${CEND}"
      echo -e ""
      read -p "Votre choix [1-12]: " OUTILS

      case $OUTILS in

      1) ## Mise en place Google OAuth avec Traefik
        clear
        logo
        echo ""
        echo -e "${CCYAN}SECURISER APPLIS DOCKER${CEND}"
        echo -e "${CGREEN}${CEND}"
        echo -e "${CGREEN}   1) Sécuriser Traefik avec Google OAuth2${CEND}"
        echo -e "${CGREEN}   2) Sécuriser avec Authentification Classique${CEND}"
        echo -e "${CGREEN}   3) Ajout / Supression adresses mail autorisées pour Google OAuth2${CEND}"
        echo -e "${CGREEN}   4) Modification port SSH, mise à jour fail2ban, installation Iptables${CEND}"
        echo -e "${CGREEN}   5) Retour menu principal${CEND}"

        echo -e ""
        read -p "Votre choix [1-5]: " OAUTH
        case $OAUTH in

        1)
          clear
          echo ""
          "${BASEDIR}/includes/config/scripts/oauth.sh"
          script_classique
          ;;

        2) ## auth classique, on supprime les valeurs de oauth
          clear
          echo ""
          manage_account_yml oauth.client " "
          manage_account_yml oauth.secret " "
          manage_account_yml oauth.account " "
          manage_account_yml oauth.openssl " "
          #          sed -i "/client:/c\   client: " ${CONFDIR}/variables/account.yml
          #          sed -i "/secret:/c\   secret: " ${CONFDIR}/variables/account.yml
          #          sed -i "/account:/c\   account: " ${CONFDIR}/variables/account.yml
          #          sed -i "/openssl:/c\   openssl: " ${CONFDIR}/variables/account.yml
          "${BASEDIR}/includes/config/scripts/basique.sh"
          script_classique
          ;;

        3)
          clear
          logo
          echo ""
          echo >&2 -n -e "${BWHITE}Compte(s) Gmail utilisé(s), séparés d'une virgule si plusieurs: ${CEND}"
          read email
          manage_account_yml oauth.account $email
          ###sed -i "/account:/c\   account: $email" ${CONFDIR}/variables/account.yml
          ansible-playbook ${BASEDIR}/includes/dockerapps/traefik.yml

          echo -e "${CRED}---------------------------------------------------------------${CEND}"
          echo -e "${CRED}     /!\ MISE A JOUR EFFECTUEE AVEC SUCCES /!\      ${CEND}"
          echo -e "${CRED}---------------------------------------------------------------${CEND}"

          echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
          read -r

          script_classique
          ;;

        4)
          clear
          echo ""
          ${BASEDIR}/includes/config/scripts/iptables.sh
          script_classique
          ;;

        5)
          script_classique
          ;;

        esac
        ;;

      2) ## Mise à jour Cloudflare
        ${BASEDIR}/includes/config/scripts/cloudflare.sh
        script_classique
        ;;

      3) ## Changement du nom de domaine
        echo ""
        echo -e "${CCYAN}SEEDBOX RCLONE/PLEXDRIVE${CEND}"
        echo -e "${CGREEN}${CEND}"
        echo -e "${CGREEN}   1) Changement du nom de domaine ${CEND}"
        echo -e "${CGREEN}   2) Modifier les sous domaines${CEND}"
        echo -e "${CGREEN}   3) Retour Menu principal${CEND}"

        echo -e ""
        read -p "Votre choix [1-3]: " DOMAIN
        case $DOMAIN in

        1) ## Changement nom de domaine
          clear
          echo ""
          ${BASEDIR}/includes/config/scripts/domain.sh
          ;;
        2) ## Modifier les sous domaines
          subdomain
          ;;
        3)
          Retour menu principal
          script_classique
          ;;
        esac
        ;;

      4) ## Installation du mailserver @Hardware
        if docker ps | grep -q mailserver; then
          echo -e "${BLUE}### DESINSTALLATION DU MAILSERVER ###${NC}"
          echo ""
          echo -e " ${BWHITE}* désinstallation mailserver @Hardware${NC}"
          docker rm -f mailserver postfixadmin mariadb redis rainloop >/dev/null 2>&1
          rm -rf /mnt/docker >/dev/null 2>&1
          checking_errors $?
          echo""
          echo -e "${BLUE}### Mailserver a été supprimé ###${NC}"
          echo ""
        else
          echo -e "${BLUE}### INSTALLATION DU MAILSERVER ###${NC}"
          echo ""
          echo -e " ${BWHITE}* Installation mailserver @Hardware${NC}"
          ansible-playbook ${BASEDIR}/includes/config/roles/mailserver/tasks/main.yml
          echo ""
          echo -e " ${CCYAN}* https://github.com/laster13/patxav/wiki/Configuration-Mailserver-@Hardware${NC}"
        fi
        pause
        script_classique
        ;;

      5) ## Modèle création appli docker
        clear
        echo ""
        ${BASEDIR}/includes/config/scripts/docker_create.sh
        script_classique
        ;;

      6) ## Installation du motd
        clear
        echo ""
        motd
        pause
        script_classique
        ;;

      7) ## Installation de traktarr
        clear
        echo ""
        traktarr
        pause
        script_classique
        ;;

      8) ## Installation de Webtools
        clear
        echo ""
        webtools
        pause
        script_classique
        ;;

      9) ## Installation de rtorrent-cleaner
        clear
        echo ""
        rtorrent-cleaner
        docker run -it --rm -v /home/$SEEDUSER/local/rutorrent:/home/$SEEDUSER/local/rutorrent -v /run/php:/run/php magicalex/rtorrent-cleaner
        pause
        script_classique
        ;;

      10) ## Installation Plex_Patrol
        ansible-playbook ${BASEDIR}/includes/config/roles/plex_patrol/tasks/main.yml
        SEEDUSER=$(ls ${CONFDIR}/media* | cut -d '-' -f2)
        DOMAIN=$(cat /home/$SEEDUSER/resume | tail -1 | cut -d. -f2-3)
        FQDNTMP="plex_patrol.$DOMAIN"
        echo "$FQDNTMP" >>/home/$SEEDUSER/resume
        cp "${BASEDIR}/includes/config/roles/plex_patrol/tasks/main.yml" "${CONFDIR}/conf/plex_patrol.yml" >/dev/null 2>&1
        echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour revenir au menu principal..."
        read -r
        script_classique
        ;;

      11)
        clear
        install_ufw
        ;;

      12)
        script_classique
        ;;
      esac
      ;;
    4)
      exit
      ;;
    esac
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

# shellcheck disable=SC2120
function script_plexdrive() {
  if [[ -d "${CONFDIR}" ]]; then
    clear

    # Vérification installation modt
    confmodt="/opt/motd"
    if [ -d "$confmodt" ]; then
      insert_mod
    else
      logo
    fi

    echo ""
    echo -e "${CCYAN}SEEDBOX RCLONE/PLEXDRIVE${CEND}"
    echo -e "${CGREEN}${CEND}"
    echo -e "${CGREEN}   1) Ajout/Supression d'Applis${CEND}"
    echo -e "${CGREEN}   2) Gestion${CEND}"
    echo -e "${CGREEN}   3) Quitter${CEND}"
    echo -e "${CGREEN}   4) Installer/Réinstaller la GUI${CEND}"
    echo -e "${CRED}   10) Désinstaller la seedbox ${CEND}"

    echo -e ""
    read -p "Votre choix: " PORT_CHOICE

    case $PORT_CHOICE in

    \
      1)
      clear
      ## Ajout d'Applications
      echo""
      clear
      manage_apps
      ;;

    2)
      clear
      logo
      echo ""
      echo -e "${CCYAN}GESTION${CEND}"
      echo -e "${CGREEN}${CEND}"
      echo -e "${CGREEN}   1) Sécurisation Systeme${CEND}"
      echo -e "${CGREEN}   2) Utilitaires${CEND}"
      echo -e "${CGREEN}   3) Création Share Drive && rclone${CEND}"
      echo -e "${CGREEN}   4) Outils (autoscan, crop, cloudplow, plex-autoscan, plex_dupefinder)${CEND}"
      echo -e "${CGREEN}   5) Comptes de Service${CEND}"
      echo -e "${CGREEN}   6) Migration Gdrive/Share Drive ==> Share Drive${CEND}"
      echo -e "${CGREEN}   7) Installation Rclone vfs && Plexdrive${CEND}"
      echo -e "${CGREEN}   8) Retour menu principal${CEND}"
      echo -e ""
      read -p "Votre choix [1-8]: " GESTION

      case $GESTION in

      1) ## sécurisation systeme
        clear
        logo
        echo ""
        echo -e "${CCYAN}SECURISER APPLIS DOCKER${CEND}"
        echo -e "${CGREEN}${CEND}"
        echo -e "${CGREEN}   1) Sécuriser Traefik avec Google OAuth2${CEND}"
        echo -e "${CGREEN}   2) Sécuriser avec Authentification Classique${CEND}"
        echo -e "${CGREEN}   3) Ajout / Supression adresses mail autorisées pour Google OAuth2${CEND}"
        echo -e "${CGREEN}   4) Modification port SSH, mise à jour fail2ban, installation Iptables${CEND}"
        echo -e "${CGREEN}   5) Mise à jour Seedbox avec Cloudflare${CEND}"
        echo -e "${CGREEN}   6) Changement de Domaine && Modification des sous domaines${CEND}"
        echo -e "${CGREEN}   7) Retour menu principal${CEND}"

        echo -e ""
        read -p "Votre choix [1-8]: " OAUTH
        case $OAUTH in

        1)
          clear
          echo ""
          ${BASEDIR}/includes/config/scripts/oauth.sh
          script_plexdrive
          ;;

        2) ## auth classique, on supprime les valeurs oauth
          clear
          echo ""
          manage_account_yml oauth.client " "
          manage_account_yml oauth.secret " "
          manage_account_yml oauth.openssl " "
          manage_account_yml oauth.account " "
          #          sed -i "/client:/c\   client: " ${CONFDIR}/variables/account.yml
          #          sed -i "/secret:/c\   secret: " ${CONFDIR}/variables/account.yml
          #          sed -i "/openssl:/c\   openssl: " ${CONFDIR}/variables/account.yml
          #          sed -i "/account:/c\   account: " ${CONFDIR}/variables/account.yml

          ${BASEDIR}/includes/config/scripts/basique.sh
          script_plexdrive
          ;;

        3)
          clear
          logo
          echo ""
          echo >&2 -n -e "${BWHITE}Compte(s) Gmail utilisé(s), séparés d'une virgule si plusieurs: ${CEND}"
          read email
          ###sed -i "/account:/c\   account: $email" ${CONFDIR}/variables/account.yml
          manage_account_yml oauth.email $email
          ansible-playbook ${BASEDIR}/includes/dockerapps/traefik.yml

          echo -e "${CRED}---------------------------------------------------------------${CEND}"
          echo -e "${CRED}     /!\ MISE A JOUR EFFECTUEE AVEC SUCCES /!\      ${CEND}"
          echo -e "${CRED}---------------------------------------------------------------${CEND}"

          echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
          read -r

          script_plexdrive
          ;;

        4)
          clear
          echo ""
          ${BASEDIR}/includes/config/scripts/iptables.sh
          script_plexdrive
          ;;

        5) ## Mise à jour Cloudflare
          ${BASEDIR}/includes/config/scripts/cloudflare.sh
          script_plexdrive
          ;;

        6) ## Changement du nom de domaine
          clear
          logo
          echo ""
          echo -e "${CCYAN}CHANGEMENT DOMAINE && SOUS DOMAINES${CEND}"
          echo -e "${CGREEN}${CEND}"
          echo -e "${CGREEN}   1) Changement du nom de domaine ${CEND}"
          echo -e "${CGREEN}   2) Modifier les sous domaines${CEND}"
          echo -e "${CGREEN}   3) Retour Menu principal${CEND}"

          echo -e ""
          read -p "Votre choix [1-3]: " DOMAIN
          case $DOMAIN in

          1) ## Changement nom de domaine
            clear
            echo ""
            ${BASEDIR}/includes/config/scripts/domain.sh
            ;;

          2) ## Modifier les sous domaines
            ansible-playbook ${BASEDIR}/includes/dockerapps/templates/ansible/ansible.yml
            SERVICESPERUSER="$SERVICESUSER$SEEDUSER"
            SEEDUSER=$(cat ${TMPNAME})
            rm ${TMPNAME}
            rm ${CONFDIR}/conf/* >/dev/null 2>&1

            while read line; do
              echo ${line} | cut -d'.' -f1
            done </home/$SEEDUSER/resume >$SERVICESUSER$SEEDUSER
            mv /home/$SEEDUSER/resume ${CONFDIR}/resume >/dev/null 2>&1
            subdomain

            grep "plex" $SERVICESPERUSER >/dev/null 2>&1
            if [ $? -eq 0 ]; then
              ansible-playbook ${BASEDIR}/includes/config/roles/plex/tasks/main.yml
              sed -i "/plex/d" $SERVICESPERUSER >/dev/null 2>&1
            fi

            install_services
            mv ${CONFDIR}/resume /home/$SEEDUSER/resume >/dev/null 2>&1
            resume_seedbox
            script_plexdrive
            ;;

          3)
            Retour menu principal
            script_plexdrive
            ;;
          esac
          ;;

        7)
          script_plexdrive
          ;;
        esac
        ;;
      2) ## utilitaires
        clear
        logo
        echo ""
        echo -e "${CCYAN}UTILITAIRES${CEND}"
        echo -e "${CGREEN}${CEND}"
        echo -e "${CGREEN}   1) Installation du motd${CEND}"
        echo -e "${CGREEN}   2) Traktarr${CEND}"
        echo -e "${CGREEN}   3) Webtools${CEND}"
        echo -e "${CGREEN}   4) rtorrent-cleaner de ${CCYAN}@Magicalex-Mondedie.fr${CEND}${NC}"
        echo -e "${CGREEN}   5) Plex_Patrol${CEND}"
        echo -e "${CGREEN}   6) Bloquer les ports non vitaux avec UFW${CEND}"
        echo -e "${CGREEN}   7) Configuration du Backup${CEND}"
        echo -e "${CGREEN}   10) Retour menu principal${CEND}"
        echo -e ""

        read -p "Votre choix [1-8]: " UTIL
        case $UTIL in

        \
          1) ## Installation du motd
          clear
          echo ""
          motd
          pause
          script_plexdrive
          ;;

        2) ## Installation de traktarr
          clear
          echo ""
          traktarr
          pause
          script_plexdrive
          ;;

        3) ## Installation de Webtools
          clear
          echo ""
          webtools
          pause
          script_plexdrive
          ;;

        4) ## Installation de rtorrent-cleaner
          clear
          echo ""
          rtorrent-cleaner
          docker run -it --rm -v /home/$SEEDUSER/local/rutorrent:/home/$SEEDUSER/local/rutorrent -v /run/php:/run/php magicalex/rtorrent-cleaner
          pause
          script_plexdrive
          ;;

        5) ## Installation Plex_Patrol
          ansible-playbook ${BASEDIR}/includes/config/roles/plex_patrol/tasks/main.yml
          SEEDUSER=$(ls ${CONFDIR}/media* | cut -d '-' -f2)
          DOMAIN=$(cat /home/$SEEDUSER/resume | tail -1 | cut -d. -f2-3)
          FQDNTMP="plex_patrol.$DOMAIN"
          echo "$FQDNTMP" >>/home/$SEEDUSER/resume
          cp "${BASEDIR}/includes/config/roles/plex_patrol/tasks/main.yml" "${CONFDIR}/conf/plex_patrol.yml" >/dev/null 2>&1
          echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour revenir au menu principal..."
          read -r
          script_plexdrive
          ;;

        6)
          clear
          install_ufw
          ;;

        7)
          clear
          echo -e " ${BLUE}* Configuration du Backup${NC}"
          echo ""
          ansible-playbook ${BASEDIR}/includes/config/roles/backup/tasks/main.yml
          echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
          read -r

          script_plexdrive
          ;;

        10)
          script_plexdrive
          ;;
        esac
        ;;

      3) ### creation share drive + rclone.conf
        clear
        echo ""
        ${BASEDIR}/includes/config/scripts/createrclone.sh
        ;;

      4) ## Outils
        clear
        logo
        echo ""
        echo -e "${CCYAN}OUTILS${CEND}"
        echo -e "${CGREEN}${CEND}"
        echo -e "${CGREEN}   1) Plex_autoscan${CEND}"
        echo -e "${CGREEN}   2) Autoscan (Nouvelle version de Plex_autoscan)${CEND}"
        echo -e "${CGREEN}   3) Cloudplow${CEND}"
        echo -e "${CGREEN}   4) Crop (Nouvelle version de Cloudplow) => Experimental${CEND}"
        echo -e "${CGREEN}   5) Plex_dupefinder${CEND}"
        echo -e "${CGREEN}   6) Retour menu principal${CEND}"

        echo -e ""
        read -p "Votre choix [1-6]: " OUTILS
        case $OUTILS in

        1) ## Installation Plex_autoscan
          clear
          echo ""
          plex_autoscan
          pause
          script_plexdrive
          ;;

        2) ## Installation Autoscan
          clear
          echo ""
          ansible-playbook ${BASEDIR}/includes/config/roles/autoscan/tasks/main.yml
          pause
          script_plexdrive
          ;;

        3) ## Installation Cloudplow
          clear
          logo
          echo ""
          cloudplow
          pause
          script_plexdrive
          ;;

        4) ## Installation Crop
          clear
          crop
          echo ""
          pause
          script_plexdrive
          ;;

        5) ## Installation plex_dupefinder
          clear
          plex_dupefinder
          echo ""
          pause
          script_plexdrive
          ;;

        6)
          script_plexdrive
          ;;
        esac
        ;;

      5) ## Comptes de Services
        clear
        logo
        echo ""
        echo -e "${CCYAN}COMPTES DE SERVICES${CEND}"
        echo -e "${CGREEN}${CEND}"
        echo -e "${CGREEN}   1) Création des SA avec sa_gen${CEND}"
        echo -e "${CGREEN}   2) Création des SA avec safire${CEND}"
        echo -e "${CGREEN}   3) Retour menu principal${CEND}"
        echo -e ""
        read -p "Votre choix [1-3]: " SERVICES
        case $SERVICES in

        1) ## Création des SA avec gen-sa
          ${BASEDIR}/includes/config/scripts/sa-gen.sh
          script_plexdrive
          ;;

        2) ## Creation des SA avec safire
          ${BASEDIR}/includes/config/scripts/safire.sh
          script_plexdrive
          ;;

        3)
          script_plexdrive
          ;;
        esac
        ;;

      6) ## Migration Gdrive - Share Drive --> share drive
        clear
        logo
        echo ""
        echo -e "${CCYAN}MIGRATION${CEND}"
        echo -e "${CGREEN}${CEND}"
        echo -e "${CGREEN}   1) GDrive => Share Drive${CEND}"
        echo -e "${CGREEN}   2) Share Drive => Share Drive${CEND}"
        echo -e "${CGREEN}   3) Retour menu principal${CEND}"
        echo -e ""
        read -p "Votre choix [1-3]: " MIGRE
        case $MIGRE in

        1) ## migration gdrive -> share drive
          clear
          logo
          echo ""
          echo -e "${CCYAN}MIGRATION GDRIVE ==> SHARE DRIVE${CEND}"
          echo -e "${CGREEN}${CEND}"
          echo -e "${CGREEN}   1) GDrive et Share Drive font partis du même compte Google ${CEND}"
          echo -e "${CGREEN}   2) GDrive et Share Drive sont sur deux comptes Google Différents ${CEND}"
          echo -e "${CGREEN}   3) Retour menu principal${CEND}"
          echo ""
          read -p "Votre choix [1-3]: " MVEA
          case $MVEA in
          1)
            clear
            logo
            echo ""
            echo -e "${CCYAN}MIGRATION GDRIVE ==> SHARE DRIVE$ => MEME COMPTE GOOGLE{CEND}"
            echo -e "${CGREEN}${CEND}"
            echo -e "${CGREEN}   1) Déplacer les données => Pas de limite ${CEND}"
            echo -e "${CGREEN}   2) Copier les données => 10 Tera par jour ${CEND}"
            echo -e "${CGREEN}   3) Retour menu principal${CEND}"
            echo ""
            read -p "Votre choix [1-3]: " MVEB
            case $MVEB in

            1) # Déplacer les données (Pas de limite)
              clear
              ${BASEDIR}/includes/config/scripts/migration.sh
              pause
              script_plexdrive
              ;;

            2) # Copier les données (10 Tera par jour)
              clear
              ${BASEDIR}/includes/config/scripts/sasync.sh
              pause
              script_plexdrive
              ;;

            3)
              script_plexdrive
              ;;
            esac
            ;;
          2)
            clear
            logo
            echo ""
            echo -e "${CCYAN}MIGRATION GDRIVE ==> SHARE DRIVE => COMPTES GOOGLE DIFFERENTS${CEND}"
            echo -e "${CGREEN}${CEND}"
            echo -e "${CGREEN}   1) Déplacer les données => Pas de limite ${CEND}"
            echo -e "${CGREEN}   2) Copier les données => 1,8 Tera par jour ${CEND}"
            echo -e "${CGREEN}   3) Retour menu principal${CEND}"
            echo ""
            read -p "Votre choix [1-3]: " MVEBC
            case $MVEBC in

            1) # Déplacer les données (Pas de limite)
              clear
              ${BASEDIR}/includes/config/scripts/migration.sh
              pause
              script_plexdrive
              ;;

            2) # Copier les données (1,8 Tera par jour)
              clear
              ${BASEDIR}/includes/config/scripts/sasync-bwlimit.sh
              pause
              script_plexdrive
              ;;

            3)
              script_plexdrive
              ;;
            esac
            ;;
          3)
            script_plexdrive
            ;;
          esac
          ;;

        2) ## migration share drive -> share drive
          clear
          logo
          echo ""
          echo -e "${CCYAN}Share Drive => Share Drive${CEND}"
          echo -e "${CGREEN}${CEND}"
          echo -e "${CGREEN}   1) Share Drive et Share Drive font partis du même compte Google${CEND}"
          echo -e "${CGREEN}   2) Share Drive et Share Drive sont sur deux comptes Google Différents${CEND}"
          echo -e "${CGREEN}   3) Retour menu principal${CEND}"
          echo ""
          read -p "Votre choix [1-3]: " SHARE
          case $SHARE in

          1) ## migration share drive -> share drive
            clear
            logo
            echo ""
            echo -e "${CCYAN}Share Drive => Share Drive ==> Même compte Google${CEND}"
            echo -e "${CGREEN}${CEND}"
            echo -e "${CGREEN}   1) Déplacer les données => Vous pouvez directement le faire à partir de l'interface UI${CEND}"
            echo -e "${CGREEN}   2) Copier les données =>10 Tera par jour ${CEND}"
            echo -e "${CGREEN}   3) Retour menu principal${CEND}"
            echo ""
            read -p "Votre choix [1-3]: " MVEC
            case $MVEC in

            \
              1) # Déplacer les données (Pas de limite)
              clear
              logo
              echo ""
              echo -e "${CGREEN} /!\ Vous pouvez directement le faire à partir de l'interface UI /!\ ${CEND}"
              echo ""
              read -rp $'\e[36m   Poursuivre malgré tout avec rclone: (o/n) ? \e[0m' OUI

              if [[ "$OUI" == "o" ]] || [[ "$OUI" == "O" ]]; then
                echo ""
                ${BASEDIR}/includes/config/scripts/sasync-share.sh
              fi
              pause
              script_plexdrive
              ;;

            2) # Copier les données (10 Tera par jour)
              ${BASEDIR}/includes/config/scripts/sasync-share.sh
              pause
              script_plexdrive
              ;;

            3)
              script_plexdrive
              ;;
            esac
            ;;

          2) ## migration gdrive -> share drive
            clear
            logo
            echo ""
            echo -e "${CCYAN}Share Drive => Share Drive => Compte Google Différents${CEND}"
            echo -e "${CGREEN}${CEND}"
            echo -e "${CGREEN}   1) Déplacer les données => Vous pouvez directement le faire à partir de l'interface UI${CEND}"
            echo -e "${CGREEN}   2) Copier les données => 10 Tera par jour${CEND}"
            echo -e "${CGREEN}   3) Retour menu principal${CEND}"
            echo ""
            read -p "Votre choix [1-3]: " MVED
            case $MVED in

            1) # Déplacer les données (Pas de limite)
              clear
              logo
              echo ""
              echo -e "${CGREEN} /!\ Vous pouvez directement le faire à partir de l'interface UI /!\ ${CEND}"
              echo ""
              read -rp $'\e[36m   Poursuivre malgré tout avec rclone: (o/n) ? \e[0m' OUI
              if [[ "$OUI" == "o" ]] || [[ "$OUI" == "O" ]]; then
                echo ""
                ${BASEDIR}/includes/config/scripts/sasync-share.sh
              fi
              pause
              script_plexdrive
              ;;

            2) # Copier les données (10 Tera par jour)
              ${BASEDIR}/includes/config/scripts/sasync-share.sh
              pause
              script_plexdrive
              ;;

            3)
              script_plexdrive
              ;;
            esac
            ;;
          3)
            script_plexdrive
            ;;
          esac
          ;;
        3)
          script_plexdrive
          ;;
        esac

        ;;

      7)
        clear
        logo
        echo ""
        echo -e "${CCYAN}RCLONE && PLEXDRIVE${CEND}"
        echo ""
        echo -e "${CGREEN}   1) Installation rclone vfs${CEND}"
        echo -e "${CGREEN}   2) Installation plexdrive${CEND}"
        echo -e "${CGREEN}   3) Installation plexdrive + rclone vfs${CEND}"
        echo -e ""

        read -p "Votre choix: " RCLONE
        case $RCLONE in

        1)
          ${BASEDIR}/includes/config/scripts/fusermount.sh
          install_rclone
          unionfs_fuse
          rm -rf /mnt/plexdrive
          echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
          read -r
          script_plexdrive
          ;;

        2)
          clear
          ${BASEDIR}/includes/config/scripts/fusermount.sh
          ${BASEDIR}/includes/config/scripts/rclone.sh
          ${BASEDIR}/includes/config/scripts/plexdrive.sh
          install_plexdrive
          echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
          read -r
          script_plexdrive
          ;;

        3)
          clear
          ${BASEDIR}/includes/config/scripts/fusermount.sh
          install_rclone
          unionfs_fuse
          ${BASEDIR}/includes/config/scripts/plexdrive.sh

          plexdrive
          echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
          read -r
          script_plexdrive
          ;;
        esac
        ;;

      8) ## retour menu principal
        script_plexdrive
        ;;
      esac
      ;;

    4) ## install gui
      install_gui
      ;;

    10) ## Désinstallation seedbox
      clear
      echo ""
      echo -e "${YELLOW}### Seedbox-Compose déjà installée !###${NC}"
      if (whiptail --title "Seedbox-Compose déjà installée" --yesno "Désinstaller complètement la Seedbox ?" 7 50); then
        if (whiptail --title "ATTENTION" --yesno "Etes vous sur de vouloir désintaller la seedbox ?" 7 55); then
          uninstall_seedbox
        else
          script_plexdrive
        fi
      else
        script_plexdrive
      fi
      ;;

    999)
      clear
      # Accès SSD WebUI
      echo -e "${CCYAN}INSTALLATION SSD WebUI${CEND}"
      echo ""

      # definition variables
      ansible-playbook ${BASEDIR}/includes/dockerapps/templates/ansible/ansible.yml
      DOMAIN=$(cat ${TMPDOMAIN})

      # Nettoyage account.yml
      manage_account_yml sub.traefik " "
      manage_account_yml sub.gui " "
      #      sed -i "/traefik/,+2d" ${CONFDIR}/variables/account.yml >/dev/null 2>&1
      #      sed -i "/gui/,+2d" ${CONFDIR}/variables/account.yml >/dev/null 2>&1

      # supression container traefik pour nouvelles rules
      docker rm -f traefik >/dev/null 2>&1
      rm ${CONFDIR}/docker/traefik/rules/nginx.toml >/dev/null 2>&1

      # reinstallation traefik
      install_traefik

      # Suppression des precedentes variables SUBDOMAIN et AUTH deja utilisé pour traefik
      unset SUBDOMAIN
      unset AUTH

      # choix sous domaine gui
      echo ""
      echo -e "${BWHITE}Adresse par défault: https://gui.${DOMAIN} ${CEND}"
      echo ""
      read -rp $'\e[33mSouhaitez vous personnaliser le sous domaine? (o/n)\e[0m: ' OUI
      if [[ "$OUI" == "o" ]] || [[ "$OUI" == "O" ]]; then
        if [ -z "$SUBDOMAIN" ]; then
          SUBDOMAIN=$1
        fi
        while [ -z "$SUBDOMAIN" ]; do
          echo >&2 -n -e "${BWHITE}Sous Domaine: ${CEND}"
          read SUBDOMAIN
        done

        if [ ! -z "$SUBDOMAIN" ]; then
          manage_account_yml sub.gui.gui $SUBDOMAIN
          #          grep "gui:" ${CONFDIR}/variables/account.yml >/dev/null 2>&1
          #          if [ $? -eq 0 ]; then
          #            sed -i "/gui/,+2d" ${CONFDIR}/variables/account.yml >/dev/null 2>&1
          #          fi
          #          sed -i "/sub/a \ \ \ gui:" /opt/seedbox/variables/account.yml
          #          sed -i "/gui:/a \ \ \ \ \ gui: $SUBDOMAIN" ${CONFDIR}/variables/account.yml
        else
          manage_account_yml sub.gui.gui gui
        fi
      fi
      SUBDOMAIN=get_from_account_yml sub.gui.gui

      # choix authentification gui
      echo ""
      read -rp $'\e\033[1;37mChoix de Authentification pour la gui [ Enter ] 1 => basique | 2 => oauth | 3 => authelia: ' AUTH
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
        echo "Action $action inconnue"
        exit 1
        ;;
      esac
      manage_account_yml sub.gui.auth ${TYPE_AUTH}
      ###sed -i "/gui: ./a \ \ \ \ \ auth: ${TYPE_AUTH}" ${CONFDIR}/variables/account.yml

      # installation ssd webui
      ansible-playbook ${BASEDIR}/includes/config/roles/nginx/tasks/main.yml

      # pour eviter les doublons dans ${CONFDIR}/resume
      if grep "traefik" ${CONFDIR}/resume >/dev/null 2>&1; then
        sed -i "/traefik/d" ${CONFDIR}/resume >/dev/null 2>&1
      fi

      grep "oauth" ${CONFDIR}/resume >/dev/null 2>&1
      if [ $? -eq 0 ]; then
        sed -i "/oauth/d" ${CONFDIR}/resume >/dev/null 2>&1
      fi

      # Mise à jour du fichier /opt/seedbox/resume
      for i in $(docker ps --format "{{.Names}}" --filter "network=traefik_proxy"); do
        temp=$(get_from_account_yml gui.${i}.${i})
        if [ "${temp}" != notfound ]; then
          echo "${i} = ${temp}.${DOMAIN}" >>${CONFDIR}/resume
        else
          echo "${i} = ${i}.${DOMAIN}" >>${CONFDIR}/resume
        fi
      done
      echo ""
      echo -e "${CRED}---------------------------------------------------------------${CEND}"
      echo -e "${CRED}          /!\ INSTALLATION EFFECTUEE AVEC SUCCES /!\           ${CEND}"
      echo -e "${CRED}---------------------------------------------------------------${CEND}"
      echo ""
      echo -e "${CRED}---------------------------------------------------------------${CEND}"
      echo -e "${CCYAN}              Adresse de l'interface WebUI                    ${CEND}"
      echo -e "${CCYAN}              https://${SUBDOMAIN}.${DOMAIN}                  ${CEND}"
      echo -e "${CRED}---------------------------------------------------------------${CEND}"
      echo ""

      rm -f "${TMPDOMAIN}"
      echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour sortir du script..."
      read -r
      ;;

    4)
      exit
      ;;
    esac
  fi
}

function create_dir() {
  ansible-playbook ${BASEDIR}/includes/config/playbooks/create_directory.yml \
    --extra-vars '{"DIRECTORY":"'${1}'"}'
}

function conf_dir() {
  create_dir ${CONFDIR}
}

function create_file() {
  TMPMYUID=$(whoami)
  MYGID=$(id -g)
  ansible-playbook ${BASEDIR}/includes/config/playbooks/create_file.yml \
    --extra-vars '{"FILE":"'${1}'","UID":"'${TMPMYUID}'","GID":"'${MYGID}'"}'
}

function change_file_owner() {
  ansible-playbook ${BASEDIR}/includes/config/playbooks/chown_file.yml \
    --extra-vars '{"FILE":"'${1}'"}'

}

function make_dir_writable() {
  ansible-playbook ${BASEDIR}/includes/config/playbooks/change_rights.yml \
    --extra-vars '{"DIRECTORY":"'${1}'"}'

}

function install_base_packages() {
  echo ""
  echo -e "${BLUE}### INSTALLATION DES PACKAGES ###${NC}"
  echo ""
  echo -e " ${BWHITE}* Installation apache2-utils, unzip, git, curl ...${NC}"
  ansible-playbook ${BASEDIR}/includes/config/roles/install/tasks/main.yml
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
  ansible-playbook ${BASEDIR}/includes/config/roles/fail2ban/tasks/main.yml
  checking_errors $?
  echo ""
}

function install_ufw() {
  clear
  echo -e "${RED}---------------------------------------------------------------${CEND}"
  echo -e "${RED} UFW sera installé avec les valeurs par défaut uniquement ${CEND}"
  echo -e "${RED} et permettra les accès suivants : ${CEND}"
  echo -e "${RED} ssh, http, https, plex ${CEND}"
  echo -e "${RED} Vous pourrez le modifier en éditant le fichier ${CONFDIR}/conf/ufw.yml ${CEND}"
  echo -e "${RED} pour ajouter des ports/ip supplémentaires ${CEND}"
  echo -e "${RED} avant de relancer ce script ${CEND}"
  echo -e "${RED}---------------------------------------------------------------${CEND}"
  echo -e "${RED} Appuyez sur [Entrée] pour continer ${CEND}"
  read -r
  echo -e "${BLUE}### UFW ###${NC}"
  ansible-playbook ${BASEDIR}/includes/config/roles/ufw/tasks/main.yml
  ansible-playbook ${CONFDIR}/conf/ufw.yml
  checking_errors $?
  echo ""
}

function install_traefik() {
  create_dir ${CONFDIR}/docker/traefik/acme/
  echo -e "${BLUE}### TRAEFIK ###${NC}"

  ansible-playbook ${BASEDIR}/includes/dockerapps/templates/ansible/ansible.yml
  DOMAIN=$(cat ${TMPDOMAIN})

  #  if grep "traefik:" ${CONFDIR}/variables/account.yml >/dev/null 2>&1; then
  #    sed -i "/traefik/,+2d" ${CONFDIR}/variables/account.yml >/dev/null 2>&1
  #  fi

  # choix sous domaine traefik
  echo ""
  echo -e "${BWHITE}Adresse par défault: https://traefik.${DOMAIN} ${CEND}"
  echo ""
  read -rp $'\e[33mSouhaitez vous personnaliser le sous domaine? (o/n)\e[0m: ' OUI
  if [[ "$OUI" == "o" ]] || [[ "$OUI" == "O" ]]; then
    if [ -z "$SUBDOMAIN" ]; then
      SUBDOMAIN=$1
    fi
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
    echo "Action $action inconnue"
    exit 1
    ;;
  esac
  manage_account_yml sub.traefik.auth ${TYPE_AUTH}
  ###sed -i "/traefik: ./a \ \ \ \ \ auth: ${TYPE_AUTH}" ${CONFDIR}/variables/account.yml

  echo ""
  echo -e " ${BWHITE}* Installation Traefik${NC}"
  ansible-playbook ${BASEDIR}/includes/dockerapps/traefik.yml
  checking_errors $?
  if [[ ${CURRENT_ERROR} -eq 1 ]]; then
    echo "${RED}Cette étape peut ne pas aboutir lors d'une première installation${CEND}"
    echo "${RED}Suite à l'installation de docker, il faut se déloguer/reloguer pour que cela fonctionne${CEND}"
    echo "${RED}Cette erreur est bloquante, impossible de continuer${CEND}"
    exit 1
  fi

  # eviter les doublons dans  ${CONFDIR}/resume
  grep "traefik" ${CONFDIR}/resume >/dev/null 2>&1
  if [ $? -eq 1 ]; then
    echo "traefik = ${SUBDOMAIN}.${DOMAIN}" >>${CONFDIR}/resume
  fi

  grep "oauth" ${CONFDIR}/resume >/dev/null 2>&1
  if [ $? -eq 1 ]; then
    echo "oauth = ${SUBDOMAIN}.${DOMAIN}" >>${CONFDIR}/resume
  fi

  echo ""
}

function install_watchtower() {
  echo -e "${BLUE}### WATCHTOWER ###${NC}"
  echo -e " ${BWHITE}* Installation Watchtower${NC}"
  ansible-playbook ${BASEDIR}/includes/dockerapps/watchtower.yml
  checking_errors $?
  echo ""
}

function install_plexdrive() {
  echo -e "${BLUE}### PLEXDRIVE ###${NC}"
  echo ""
  mkdir -p /mnt/plexdrive >/dev/null 2>&1
  ansible-playbook ${BASEDIR}/includes/config/roles/plexdrive/tasks/main.yml
  systemctl stop plexdrive >/dev/null 2>&1
  ansible-vault decrypt ${CONFDIR}/variables/account.yml >/dev/null 2>&1
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
  mkdir -p /mnt/plexdrive >/dev/null 2>&1
  ansible-playbook ${BASEDIR}/includes/config/roles/plexdrive/tasks/plexdrive.yml
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
  create_dir /mnt/rclone
  create_dir /mnt/rclone/${USER}
  ${BASEDIR}/includes/config/scripts/rclone.sh
  ansible-playbook ${BASEDIR}/includes/config/roles/rclone/tasks/main.yml
  checking_errors $?
  echo ""
}

function unionfs_fuse() {
  echo -e "${BLUE}### Unionfs-Fuse ###${NC}"
  echo -e " ${BWHITE}* Installation Mergerfs${NC}"
  ansible-playbook ${BASEDIR}/includes/config/roles/unionfs/tasks/main.yml
  checking_errors $?
  echo ""
}

function install_docker() {
  echo -e "${BLUE}### DOCKER ###${NC}"
  echo -e " ${BWHITE}* Installation Docker${NC}"
  file="/usr/bin/docker"
  if [ ! -e "$file" ]; then
    # cp -r /usr/local/lib/python2.7/dist-packages/backports/ssl_match_hostname/ /usr/lib/python2.7/dist-packages/backports
    ansible-playbook ${BASEDIR}/includes/config/roles/docker/tasks/main.yml
  else
    echo -e " ${YELLOW}* docker est déjà installé !${NC}"
  fi
  echo ""
}

function subdomain() {

  echo ""
  read -rp $'\e\033[1;37m --> Personnaliser les sous domaines: (o/n) ? ' OUI
  echo ""
  if [[ "$OUI" == "o" ]] || [[ "$OUI" == "O" ]]; then
    echo -e " ${CRED}--> NE PAS SAISIR LE NOM DE DOMAINE - LES POINTS NE SONT PAS ACCEPTES${NC}"
    echo ""
    for line in $(cat $SERVICESPERUSER); do

      if [ -z "$SUBDOMAIN" ]; then
        SUBDOMAIN=$1
      fi

      while [ -z "$SUBDOMAIN" ]; do
        read -rp $'\e[32m* Sous domaine pour\e[0m '${line}': ' SUBDOMAIN
      done

      #      grep "${line}: ." ${CONFDIR}/variables/account.yml >/dev/null 2>&1
      #      if [ $? -eq 0 ]; then
      #        sed -i "/${line}/,+2d" ${CONFDIR}/variables/account.yml >/dev/null 2>&1
      #      fi
      manage_account_yml sub.${line}.${line} $SUBDOMAIN
      ###sed -i "/sub/a \ \ \ ${line}:" /opt/seedbox/variables/account.yml
      ###sed -i "/${line}:/a \ \ \ \ \ ${line}: $SUBDOMAIN" ${CONFDIR}/variables/account.yml
    done
  else
    for line in $(cat $SERVICESPERUSER); do
      SUBDOMAIN=${line}
      manage_account_yml sub.${line}.${line} $SUBDOMAIN
    done
  fi
}

function auth() {
  #  grep "sub" ${CONFDIR}/variables/account.yml >/dev/null 2>&1
  #  if [ $? -eq 1 ]; then
  #    sed -i '/transcodes/a sub:' ${CONFDIR}/variables/account.yml
  #  fi
  echo ""
  for line in $(cat $SERVICESPERUSER); do

    if [ -z "$AUTH" ]; then
      AUTH=$1
    fi

    while [ -z "$AUTH" ]; do
      read -rp $'\e\033[1;37m --> Authentification '${line}' [ Enter ] 1 => basique | 2 => oauth | 3 => authelia | 4 => aucune: ' AUTH
    done

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
      echo "Action $action inconnue"
      exit 1
      ;;
    esac
    #    grep "${line}:" ${CONFDIR}/variables/account.yml >/dev/null 2>&1
    #    if [ $? -eq 1 ]; then
    #      sed -i "/sub/a \ \ \ ${line}:" ${CONFDIR}/variables/account.yml
    #      sed -i "/${line}:/a \ \ \ \ \ auth: ${TYPE_AUTH}" ${CONFDIR}/variables/account.yml
    #    else
    #      sed -i "/${line}: ./a \ \ \ \ \ auth: ${TYPE_AUTH}" ${CONFDIR}/variables/account.yml
    #    fi
    manage_account_yml sub.${line}.auth ${TYPE_AUTH}
  done
}

function define_parameters() {
  echo -e "${BLUE}### INFORMATIONS UTILISATEURS ###${NC}"

  create_user
  CONTACTEMAIL=$(whiptail --title "Adresse Email" --inputbox \
    "Merci de taper votre adresse Email :" 7 50 3>&1 1>&2 2>&3)
  manage_account_yml user.mail $CONTACTEMAIL
  ###sed -i "s/mail:/mail: $CONTACTEMAIL/" ${CONFDIR}/variables/account.yml

  DOMAIN=$(whiptail --title "Votre nom de Domaine" --inputbox \
    "Merci de taper votre nom de Domaine (exemple: nomdedomaine.fr) :" 7 50 3>&1 1>&2 2>&3)
  manage_account_yml user.domain $DOMAIN
  ###sed -i "s/domain:/domain: $DOMAIN/" ${CONFDIR}/variables/account.yml
  echo ""
}

function create_user_non_systeme() {
  # nouvelle version de define_parameters()
  echo -e "${BLUE}### INFORMATIONS UTILISATEURS ###${NC}"

  SEEDUSER=$(whiptail --title "Administrateur" --inputbox \
    "Nom d'Administrateur de la Seedbox :" 7 50 3>&1 1>&2 2>&3)
  [[ "$?" == 1 ]] && script_plexdrive
  PASSWORD=$(whiptail --title "Password" --passwordbox \
    "Mot de passe :" 7 50 3>&1 1>&2 2>&3)

  htpasswd -c -b /tmp/.htpasswd $SEEDUSER $PASSWORD >/dev/null 2>&1
  htpwd=$(cat /tmp/.htpasswd)
  manage_account_yml user.htpwd $htpwd
  manage_account_yml user.name $SEEDUSER
  manage_account_yml user.pass $PASSWORD
  manage_account_yml user.userid $(id -u)
  manage_account_yml user.groupid $(id -g)
  #  sed -i "/htpwd:/c\   htpwd: $htpwd" ${CONFDIR}/variables/account.yml
  #  sed -i "s/name:/name: $SEEDUSER/" ${CONFDIR}/variables/account.yml
  #  sed -i "s/pass:/pass: $PASSWORD/" ${CONFDIR}/variables/account.yml
  #  sed -i "s/userid:/userid: $(id -u)/" ${CONFDIR}/variables/account.yml
  #  sed -i "s/groupid:/groupid: $(id -g)/" ${CONFDIR}/variables/account.yml

  update_seedbox_param "name" $user
  update_seedbox_param "userid" $(id -u)
  update_seedbox_param "groupid" $(id -g)
  update_seedbox_param "htpwd" $htpwd

  CONTACTEMAIL=$(whiptail --title "Adresse Email" --inputbox \
    "Merci de taper votre adresse Email :" 7 50 3>&1 1>&2 2>&3)
  manage_account_yml user.mail $CONTACTEMAIL
  ###sed -i "s/mail:/mail: $CONTACTEMAIL/" ${CONFDIR}/variables/account.yml
  update_seedbox_param "mail" $CONTACTEMAIL

  DOMAIN=$(whiptail --title "Votre nom de Domaine" --inputbox \
    "Merci de taper votre nom de Domaine (exemple: nomdedomaine.fr) :" 7 50 3>&1 1>&2 2>&3)
  ###sed -i "s/domain:/domain: $DOMAIN/" ${CONFDIR}/variables/account.yml
  manage_account_yml user.domain $DOMAIN
  update_seedbox_param "domain" $DOMAIN
  echo ""
  return
}

function create_user() {
  SEEDGROUP=$(whiptail --title "Group" --inputbox \
    "Création d'un groupe pour la Seedbox" 7 50 3>&1 1>&2 2>&3)
  egrep "^$SEEDGROUP" /etc/group >/dev/null
  if [[ "$?" != "0" ]]; then
    echo -e " ${BWHITE}* Création du groupe $SEEDGROUP"
    groupadd $SEEDGROUP
    checking_errors $?
  else
    echo -e " ${YELLOW}* Le groupe $SEEDGROUP existe déjà.${NC}"
  fi
  manage_account_yml user.group $SEEDGROUP
  ###sed -i "s/group:/group: $SEEDGROUP/" ${CONFDIR}/variables/account.yml

  SEEDUSER=$(whiptail --title "Administrateur" --inputbox \
    "Nom d'Administrateur de la Seedbox :" 7 50 3>&1 1>&2 2>&3)
  [[ "$?" == 1 ]] && script_plexdrive
  PASSWORD=$(whiptail --title "Password" --passwordbox \
    "Mot de passe :" 7 50 3>&1 1>&2 2>&3)
  manage_account_yml user.pass $PASSWORD
  ###sed -i "s/pass:/pass: $PASSWORD/" ${CONFDIR}/variables/account.yml
  if egrep "^$SEEDUSER" /etc/passwd >/dev/null; then
    echo -e " ${YELLOW}* L'utilisateur existe déjà !${NC}"
    USERID=$(id -u $SEEDUSER)
    GRPID=$(id -g $SEEDUSER)
    manage_account_yml user.userid $USERID
    manage_account_yml user.group $GRPID
    #    sed -i "s/userid:/userid: $USERID/" ${CONFDIR}/variables/account.yml
    #    sed -i "s/groupid:/groupid: $GRPID/" ${CONFDIR}/variables/account.yml
    usermod -a -G docker $SEEDUSER >/dev/null 2>&1
    echo -e " ${BWHITE}* Ajout de $SEEDUSER à $SEEDGROUP"
    usermod -a -G $SEEDGROUP $SEEDUSER
    checking_errors $?
  else
    PASS=$(perl -e 'print crypt($ARGV[0], "password")' $PASSWORD)
    echo -e " ${BWHITE}* Ajout de $SEEDUSER au système"
    useradd -M -g $SEEDGROUP -p $PASS -s /bin/bash $SEEDUSER >/dev/null 2>&1
    usermod -a -G docker $SEEDUSER >/dev/null 2>&1
    mkdir -p /home/$SEEDUSER
    chown -R $SEEDUSER:$SEEDGROUP /home/$SEEDUSER
    chmod 755 /home/$SEEDUSER
    checking_errors $?
    USERID=$(id -u $SEEDUSER)
    GRPID=$(id -g $SEEDUSER)
    manage_account_yml user.userid $USERID
    manage_account_yml user.groupid $GRPID
    #    sed -i "s/userid:/userid: $USERID/" ${CONFDIR}/variables/account.yml
    #    sed -i "s/groupid:/groupid: $GRPID/" ${CONFDIR}/variables/account.yml
  fi
  htpasswd -c -b /tmp/.htpasswd $SEEDUSER $PASSWORD >/dev/null 2>&1
  htpwd=$(cat /tmp/.htpasswd)
  manage_account_yml user.htpwd $htpwd
  manage_account_yml user.name $SEEDUSER
  #  sed -i "/htpwd:/c\   htpwd: $htpwd" ${CONFDIR}/variables/account.yml
  #  sed -i "s/name:/name: $SEEDUSER/" ${CONFDIR}/variables/account.yml

  echo "vault_password_file = ~/.vault_pass" >>/etc/ansible/ansible.cfg
  return
}

function projects() {
  ansible-playbook ${BASEDIR}/includes/dockerapps/templates/ansible/ansible.yml
  SEEDUSER=${USER}
  DOMAIN=$(cat ${TMPDOMAIN})
  SEEDGROUP=$(cat ${TMPGROUP})
  rm ${TMPNAME} ${TMPDOMAIN} ${TMPGROUP}

  echo -e "${BLUE}### SERVICES ###${NC}"
  echo -e " ${BWHITE}--> Services en cours d'installation : ${NC}"
  PROJECTPERUSER="$PROJECTUSER$SEEDUSER"
  rm -Rf $PROJECTPERUSER >/dev/null 2>&1
  projects="/tmp/projects.txt"

  if [[ -e "$projects" ]]; then
    rm ${projects}
  fi
  for app in $(cat $PROJECTSAVAILABLE); do
    service=$(echo $app | cut -d\- -f1)
    desc=$(echo $app | cut -d\- -f2)
    echo "$service $desc off" >>/tmp/projects.txt
  done

  SERVICESTOINSTALL=$(whiptail --title "Gestion des Applications" --checklist \
    "\nChoisir vos Applications" 18 47 10 \
    $(cat /tmp/projects.txt) 3>&1 1>&2 2>&3)
  [[ "$?" == 1 ]] && script_plexdrive && rm /tmp/projects.txt
  PROJECTPERUSER="$PROJECTUSER$SEEDUSER"
  touch $PROJECTPERUSER

  for PROJECTS in $SERVICESTOINSTALL; do
    echo -e "	${GREEN}* $(echo $PROJECTS | tr -d '"')${NC}"
    echo $(echo ${PROJECTS,,} | tr -d '"') >>$PROJECTPERUSER
  done

  for line in $(cat $PROJECTPERUSER); do
    ${line}
  done
}

function choose_services() {
  echo -e "${BLUE}### SERVICES ###${NC}"
  echo -e " ${BWHITE}--> Services en cours d'installation : ${NC}"
  rm -Rf $SERVICESPERUSER >/dev/null 2>&1
  menuservices="/tmp/menuservices.txt"
  if [[ -e "$menuservices" ]]; then
    rm $menuservices
  fi

  for app in $(cat $SERVICESAVAILABLE); do
    service=$(echo $app | cut -d\- -f1)
    desc=$(echo $app | cut -d\- -f2)
    echo "$service $desc off" >>/tmp/menuservices.txt
  done
  SERVICESTOINSTALL=$(whiptail --title "Gestion des Applications" --checklist \
    "Appuyer sur la barre espace pour la sélection" 28 64 21 \
    $(cat /tmp/menuservices.txt) 3>&1 1>&2 2>&3)
  [[ "$?" == 1 ]] && script_plexdrive && rm /tmp/menuservices.txt
  touch $SERVICESPERUSER
  for APPDOCKER in $SERVICESTOINSTALL; do
    echo -e "	${GREEN}* $(echo $APPDOCKER | tr -d '"')${NC}"
    echo $(echo ${APPDOCKER,,} | tr -d '"') >>$SERVICESPERUSER
  done
}

function choose_other_services() {
  echo -e "${BLUE}### SERVICES ###${NC}"
  echo -e " ${BWHITE}--> Services en cours d'installation : ${NC}"
  rm -Rf $SERVICESPERUSER >/dev/null 2>&1
  menuservices="/tmp/menuservices.txt"
  if [[ -e "$menuservices" ]]; then
    rm /tmp/menuservices.txt
  fi

  for app in $(cat ${BASEDIR}/includes/config/other-services-available); do
    service=$(echo $app | cut -d\- -f1)
    desc=$(echo $app | cut -d\- -f2)
    echo "$service $desc off" >>/tmp/menuservices.txt
  done
  SERVICESTOINSTALL=$(whiptail --title "Gestion des Applications" --checklist \
    "Appuyer sur la barre espace pour la sélection" 28 64 21 \
    $(cat /tmp/menuservices.txt) 3>&1 1>&2 2>&3)
  [[ "$?" == 1 ]] && script_plexdrive && rm /tmp/menuservices.txt
  touch $SERVICESPERUSER
  for APPDOCKER in $SERVICESTOINSTALL; do
    echo -e "	${GREEN}* $(echo $APPDOCKER | tr -d '"')${NC}"
    echo $(echo ${APPDOCKER,,} | tr -d '"') >>$SERVICESPERUSER
  done
}

function choose_media_folder_classique() {
  echo -e "${BLUE}### DOSSIERS MEDIAS ###${NC}"
  echo -e " ${BWHITE}--> Création des dossiers Medias : ${NC}"
  mkdir -p ${HOME}/filebot
  mkdir -p ${HOME}/local/{Films,Series,Musiques,Animes}
  checking_errors $?
  echo ""
}

function choose_media_folder_plexdrive() {
  # Attention, là on ne va pas créer de /home/$SEEDUSER, on reste sur le user qui a lancé l'install
  echo -e "${BLUE}### DOSSIERS MEDIAS ###${NC}"
  FOLDER="/mnt/rclone/${USER}"

  # si le dossier /mnt/rclone/user n'est pas vide
  mkdir -p ${HOME}/Medias
  if [ "$(ls -A /mnt/rclone/${USER})" ]; then
    cd /mnt/rclone/${USER}
    ls -Ad */ | sed 's,/$,,g' >$MEDIASPERUSER

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
    MEDIASTOINSTALL=$(whiptail --title "Gestion des dossiers Medias" --checklist \
      "Medias à ajouter pour $SEEDUSER (Barre espace pour la sélection)" 28 60 17 \
      $(cat /tmp/menumedia.txt) 3>&1 1>&2 2>&3)
    touch $MEDIASPERUSER
    for MEDDOCKER in $MEDIASTOINSTALL; do
      echo -e "	${GREEN}* $(echo $MEDDOCKER | tr -d '"')${NC}"
      echo $(echo ${MEDDOCKER} | tr -d '"') >>$MEDIASPERUSER
    done
    for line in $(cat $MEDIASPERUSER); do
      line=$(echo ${line} | sed 's/\(.\)/\U\1/')
      create_dir ${HOME}/local/${line}
      create_dir /mnt/rclone/${USER}/${line}
    done
    rm /tmp/menumedia.txt
  fi
  mkdir -p ${HOME}/filebot
  echo ""
}

function install_services() {
  INSTALLEDFILE="${HOME}/resume"
  touch ${INSTALLEDFILE} >/dev/null 2>&1

  if [[ ! -d "${CONFDIR}/conf" ]]; then
    mkdir -p ${CONFDIR}/conf >/dev/null 2>&1
  fi

  if [[ ! -d "${CONFDIR}/vars" ]]; then
    mkdir -p ${CONFDIR}/vars >/dev/null 2>&1
  fi

  create_file ${CONFDIR}/temp.txt

  ## préparation installation
  for line in $(cat $SERVICESPERUSER); do

    if [[ "${line}" == "plex" ]]; then
      echo ""
      echo -e "${BLUE}### CONFIG POST COMPOSE PLEX ###${NC}"
      echo -e " ${BWHITE}* Processing plex config file...${NC}"
      echo ""
      echo -e " ${GREEN}ATTENTION IMPORTANT - NE PAS FAIRE D'ERREUR - SINON DESINSTALLER ET REINSTALLER${NC}"
      token=$(. ${BASEDIR}/includes/config/roles/plex_autoscan/plex_token.sh)
      manage_account_yml plex.token $token
      ###sed -i "/token:/c\   token: $token" ${CONFDIR}/variables/account.yml
      ansible-playbook ${BASEDIR}/includes/dockerapps/plex.yml
      cp "${BASEDIR}/includes/dockerapps/plex.yml" "${CONFDIR}/conf/plex.yml" >/dev/null 2>&1
    else
      # On est dans le cas générique
      # on regarde s'i y a un playbook existant
      if [[ -f "${CONFDIR}/conf/${line}.yml" ]]; then
        # il y a déjà un playbook "perso", on le lance
        ansible-playbook "${CONFDIR}/conf/${line}.yml"
      elif [[ -f "${CONFDIR}/vars/${line}.yml" ]]; then
        # il y a des variables persos, on les lance
        ansible-playbook "${BASEDIR}/includes/dockerapps/generique.yml" --extra-vars "@${CONFDIR}/vars/${line}.yml"
      elif [[ -f "${BASEDIR}/includes/dockerapps/${line}.yml" ]]; then
        # pas de playbook perso ni de vars perso
        # Il y a un playbook spécifique pour cette appli, on le copie
        cp "${BASEDIR}/includes/dockerapps/${line}.yml" "${CONFDIR}/conf/${line}.yml"
        # puis on le lance
        ansible-playbook "${CONFDIR}/conf/${line}.yml"
      else
        # on copie les variables pour le user
        cp "${BASEDIR}/includes/dockerapps/vars/${line}.yml" "${CONFDIR}/vars/${line}.yml"
        # puis on lance le générique avec ce qu'on vient de copier
        ansible-playbook ${BASEDIR}/includes/dockerapps/generique.yml --extra-vars "@${CONFDIR}/vars/${line}.yml"
      fi
    fi

    temp_subdomain=$(get_from_account_yml "sub.${line}.${line}")
    if [ "${temp_subdomain}" != notfound ]; then
      FQDNTMP="${temp_subdomain}.$DOMAIN"
      echo "${line} = $FQDNTMP" | tee -a "${CONFDIR}/resume" >/dev/null
      echo "${line}.$DOMAIN" >>"$INSTALLEDFILE"
    else
      FQDNTMP="${line}.$DOMAIN"
      echo "$FQDNTMP" >>$INSTALLEDFILE
      echo "${line} = $FQDNTMP" | tee -a "${CONFDIR}/resume" >/dev/null

    fi

    FQDNTMP=""

  done
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

  ansible-playbook ${BASEDIR}/includes/dockerapps/templates/ansible/ansible.yml

  SEEDUSER=$(cat ${TMPNAME})
  DOMAIN=$(cat ${TMPDOMAIN})
  SEEDGROUP=$(cat ${TMPGROUP})
  rm ${TMPNAME} ${TMPDOMAIN} ${TMPGROUP}
  USERRESUMEFILE="/home/$SEEDUSER/resume"
  status
  echo ""
  echo -e "${GREEN}### Gestion des Applis pour: $SEEDUSER ###${NC}"
  ## CHOOSE AN ACTION FOR APPS
  ACTIONONAPP=$(whiptail --title "App Manager" --menu \
    "Selectionner une action :" 12 50 4 \
    "1" "Ajout Applications" \
    "2" "Suppression Applications" \
    "3" "Réinitialisation Container" 3>&1 1>&2 2>&3)
  [[ "$?" == 1 ]] && if [[ -e "$PLEXDRIVE" ]]; then script_plexdrive; else script_classique; fi

  case $ACTIONONAPP in
  "1") ## Ajout APP

    APPLISEEDBOX=$(whiptail --title "App Manager" --menu \
      "Selectionner une action :" 12 50 4 \
      "1" "Applications Seedbox" \
      "2" "Autres Applications" 3>&1 1>&2 2>&3)
    [[ "$?" == 1 ]] && if [[ -e "$PLEXDRIVE" ]]; then script_plexdrive; else script_classique; fi
    case $APPLISEEDBOX in
    "1") ## Ajout Applications Seedbox
      echo -e " ${BWHITE}* Resume file: $USERRESUMEFILE${NC}"
      echo ""
      choose_services
      for line in $(cat $SERVICESPERUSER); do
        if [ ${line} != "authelia" ]; then
          subdomain
          auth
        fi
      done
      install_services
      pause
      resume_seedbox
      if [[ -e "$PLEXDRIVE" ]]; then
        script_plexdrive
      else
        script_classique
      fi
      ;;

    "2") ## Autres Applications
      echo -e " ${BWHITE}* Resume file: $USERRESUMEFILE${NC}"
      echo ""
      choose_other_services
      subdomain
      auth
      install_services
      pause
      resume_seedbox
      pause
      if [[ -e "$PLEXDRIVE" ]]; then
        script_plexdrive
      else
        script_classique
      fi
      ;;
    esac
    ;;

  "2") ## Suppression APP
    echo -e " ${BWHITE}* Resume file: $USERRESUMEFILE${NC}"
    echo ""

    [ -s /home/$SEEDUSER/resume ]
    if [[ "$?" == "1" ]]; then
      echo -e " ${BWHITE}* Pas d'Applis à Désinstaller ${NC}"
      pause
      if [[ -e "$PLEXDRIVE" ]]; then
        script_plexdrive
      else
        script_classique
      fi
    fi

    echo -e " ${BWHITE}* Application en cours de suppression${NC}"
    TABSERVICES=()
    for SERVICEACTIVATED in $(docker ps --format "{{.Names}}" | cut -d'-' -f2 | sort -u); do
      SERVICE=$(echo $SERVICEACTIVATED | cut -d\. -f1)
      TABSERVICES+=(${SERVICE//\"/} " ")
    done
    APPSELECTED=$(whiptail --title "App Manager" --menu \
      "Sélectionner l'Appli à supprimer" 19 45 11 \
      "${TABSERVICES[@]}" 3>&1 1>&2 2>&3)
    [[ "$?" == 1 ]] && if [[ -e "$PLEXDRIVE" ]]; then script_plexdrive; else script_classique; fi
    echo -e " ${GREEN}   * $APPSELECTED${NC}"

    #    grep "$APPSELECTED:" ${CONFDIR}/variables/account.yml >/dev/null 2>&1
    #    if [ $? -eq 0 ]; then
    #      sed -i "/$APPSELECTED/,+2d" ${CONFDIR}/variables/account.yml >/dev/null 2>&1
    #    fi
    manage_account_yml sub.${APPSELECTED} " "

    sed -i "/$APPSELECTED/d" ${CONFDIR}/resume >/dev/null 2>&1
    sed -i "/$APPSELECTED/d" /home/$SEEDUSER/resume >/dev/null 2>&1
    docker rm -f "$APPSELECTED" >/dev/null 2>&1
    rm -rf ${CONFDIR}/docker/$SEEDUSER/$APPSELECTED
    rm ${CONFDIR}/conf/$APPSELECTED.yml >/dev/null 2>&1
    rm ${CONFDIR}/vars/$APPSELECTED.yml >/dev/null 2>&1
    echo "0" >${CONFDIR}/status/$APPSELECTED

    case $APPSELECTED in
    seafile)
      docker rm -f memcached >/dev/null 2>&1
      ;;
    varken)
      docker rm -f influxdb telegraf grafana >/dev/null 2>&1
      rm -rf ${CONFDIR}/docker/$SEEDUSER/telegraf
      rm -rf ${CONFDIR}/docker/$SEEDUSER/grafana
      rm -rf ${CONFDIR}/docker/$SEEDUSER/influxdb
      ;;
    jitsi)
      docker rm -f prosody jicofo jvb
      rm -rf ${CONFDIR}/docker/$SEEDUSER/.jitsi-meet-cfg
      ;;
    nextcloud)
      docker rm -f collabora coturn office
      rm -rf ${CONFDIR}/docker/$SEEDUSER/coturn
      ;;
    rtorrentvpn)
      rm ${CONFDIR}/conf/rutorrent-vpn.yml
      ;;
    jackett)
      docker rm -f flaresolverr >/dev/null 2>&1
      ;;
    petio)
      docker rm -f mongo >/dev/null 2>&1
      ;;
    esac

    if docker ps | grep -q db-$APPSELECTED; then
      docker rm -f db-$APPSELECTED >/dev/null 2>&1
    fi

    docker system prune -af >/dev/null 2>&1
    checking_errors $?
    echo""
    echo -e "${BLUE}### $APPSELECTED a été supprimé ###${NC}"
    echo ""
    pause
    if [[ -e "$PLEXDRIVE" ]]; then
      script_plexdrive
    else
      script_classique
    fi
    ;;

  "3") ## Réinitialisation container
    touch $SERVICESPERUSER
    echo -e " ${BWHITE}* Les fichiers de configuration ne seront pas effacés${NC}"
    TABSERVICES=()
    for SERVICEACTIVATED in $(docker ps --format "{{.Names}}"); do
      SERVICE=$(echo $SERVICEACTIVATED | cut -d\. -f1)
      TABSERVICES+=(${SERVICE//\"/} " ")
    done
    line=$(whiptail --title "App Manager" --menu \
      "Sélectionner le container à réinitialiser" 19 45 11 \
      "${TABSERVICES[@]}" 3>&1 1>&2 2>&3)
    [[ "$?" == 1 ]] && if [[ -e "$PLEXDRIVE" ]]; then script_plexdrive; else script_classique; fi
    echo -e " ${GREEN}   * ${line}${NC}"
    subdomain=$(get_from_account_yml "sub.${line}.${line}")
    ###subdomain=$(grep "${line}" ${CONFDIR}/variables/account.yml | cut -d ':' -f2 | sed 's/ //g')

    sed -i "/${line}/d" ${CONFDIR}/resume >/dev/null 2>&1
    sed -i "/${line}/d" /home/$SEEDUSER/resume >/dev/null 2>&1
    docker rm -f "${line}" >/dev/null 2>&1
    docker system prune -af >/dev/null 2>&1
    docker volume rm $(docker volume ls -qf "dangling=true") >/dev/null 2>&1
    echo ""
    echo ${line} >>$SERVICESPERUSER

    install_services
    pause
    checking_errors $?
    echo""
    echo -e "${BLUE}### Le Container ${line} a été Réinitialisé ###${NC}"
    echo ""
    resume_seedbox
    pause
    if [[ -e "$PLEXDRIVE" ]]; then
      script_plexdrive
    else
      script_classique
    fi
    ;;
  esac
}

function resume_seedbox() {
  clear
  echo -e "${BLUE}##########################################${NC}"
  echo -e "${BLUE}###     INFORMATION SEEDBOX INSTALL    ###${NC}"
  echo -e "${BLUE}##########################################${NC}"
  echo ""
  echo -e " ${BWHITE}* Accès Applis à partir de URL :${NC}"
  PASSE=$(get_from_account_yml user.pass)

  if [[ -s ${CONFDIR}/temp.txt ]]; then
    while read line; do
      for word in ${line}; do
        ACCESSDOMAIN=$(echo ${line} | cut -d "-" -f 2-4)
        DOCKERAPP=$(echo $word | cut -d "-" -f1)
        echo -e "	--> ${BWHITE}$DOCKERAPP${NC} --> ${YELLOW}$ACCESSDOMAIN${NC}"
      done
    done <"${CONFDIR}/temp.txt"
  else
    while read line; do
      for word in ${line}; do
        ACCESSDOMAIN=$(echo ${line})
        DOCKERAPP=$(echo $word | cut -d "." -f1)
        echo -e "	--> ${BWHITE}$DOCKERAPP${NC} --> ${YELLOW}$ACCESSDOMAIN${NC}"
      done
    done <"/home/$SEEDUSER/resume"
  fi

  echo ""
  echo -e " ${BWHITE}* Vos IDs :${NC}"
  echo -e "	--> ${BWHITE}Utilisateur:${NC} ${YELLOW}$SEEDUSER${NC}"
  echo -e "	--> ${BWHITE}Password:${NC} ${YELLOW}$PASSE${NC}"
  echo ""

  rm -Rf $SERVICESPERUSER >/dev/null 2>&1
  rm ${CONFDIR}/temp.txt >/dev/null 2>&1
}

function uninstall_seedbox() {
  clear
  echo -e "${BLUE}##########################################${NC}"
  echo -e "${BLUE}###       DESINSTALLATION SEEDBOX      ###${NC}"
  echo -e "${BLUE}##########################################${NC}"

  ## variables
  ansible-playbook ${BASEDIR}/includes/dockerapps/templates/ansible/ansible.yml
  SEEDUSER=$(cat ${TMPNAME})
  DOMAIN=$(cat ${TMPDOMAIN})
  SEEDGROUP=$(cat ${TMPGROUP})
  rm ${TMPNAME} ${TMPDOMAIN} ${TMPGROUP}

  USERHOMEDIR="/home/$SEEDUSER"
  PLEXDRIVE="/usr/bin/rclone"
  PLEXSCAN="$USERHOMEDIR/scripts/plex_autoscan/scan.py"
  CLOUDPLOW="$USERHOMEDIR/scripts/cloudplow/cloudplow.py"
  CROP="$USERHOMEDIR/scripts/crop/crop"

  if [[ -e "$PLEXDRIVE" ]]; then
    systemctl stop plexdrive.service >/dev/null 2>&1
    systemctl disable plexdrive.service >/dev/null 2>&1
    rm /etc/systemd/system/plexdrive.service >/dev/null 2>&1
    rm -rf /mnt/plexdrive >/dev/null 2>&1
    rm -rf ${HOME}/.plexdrive >/dev/null 2>&1
    rm /usr/bin/plexdrive >/dev/null 2>&1

    if [[ -e "$PLEXSCAN" ]]; then
      echo -e " ${BWHITE}* Suppression plex_autoscan${NC}"
      systemctl stop plex_autoscan.service >/dev/null 2>&1
      systemctl disable plex_autoscan.service >/dev/null 2>&1
      rm /etc/systemd/system/plex_autoscan.service >/dev/null 2>&1
      checking_errors $?
    fi

    echo -e " ${BWHITE}* Suppression rclone${NC}"
    systemctl stop rclone.service >/dev/null 2>&1
    systemctl disable rclone.service >/dev/null 2>&1
    rm /etc/systemd/system/rclone.service >/dev/null 2>&1
    rm /usr/bin/rclone >/dev/null 2>&1
    rm -rf /mnt/rclone >/dev/null 2>&1
    rm -rf ${HOME}/.config/rclone >/dev/null 2>&1
    checking_errors $?

    if [[ -e "$CLOUDPLOW" ]]; then
      echo -e " ${BWHITE}* Suppression cloudplow${NC}"
      systemctl stop cloudplow.service >/dev/null 2>&1
      systemctl disable cloudplow.service >/dev/null 2>&1
      rm /etc/systemd/system/cloudplow.service >/dev/null 2>&1
      checking_errors $?
    fi

    if [[ -e "$CROP" ]]; then
      echo -e " ${BWHITE}* Suppression crop${NC}"
      systemctl stop crop_upload.service >/dev/null 2>&1
      systemctl stop crop_sync.service >/dev/null 2>&1
      systemctl stop crop_upload.timer >/dev/null 2>&1
      systemctl stop crop_sync.timer >/dev/null 2>&1

      systemctl disable crop_upload.service >/dev/null 2>&1
      systemctl disable crop_sync.service >/dev/null 2>&1
      systemctl disable crop_upload.timer >/dev/null 2>&1
      systemctl disable crop_sync.service >/dev/null 2>&1

      rm /etc/systemd/system/crop_upload.service >/dev/null 2>&1
      rm /etc/systemd/system/crop_sync.service >/dev/null 2>&1
      rm /etc/systemd/system/crop_upload.timer >/dev/null 2>&1
      rm /etc/systemd/system/crop_sync.timer >/dev/null 2>&1

      checking_errors $?
    fi

    echo -e " ${BWHITE}* Suppression unionfs/mergerfs${NC}"
    service unionfs stop >/dev/null 2>&1
    systemctl disable unionfs.service >/dev/null 2>&1
    rm /etc/systemd/system/unionfs.service >/dev/null 2>&1

    service mergerfs stop >/dev/null 2>&1
    systemctl disable mergerfs.service >/dev/null 2>&1
    rm /etc/systemd/system/mergerfs.service >/dev/null 2>&1
    checking_errors $?
  fi

  echo -e " ${BWHITE}* Suppression user: $SEEDUSER...${NC}"
  userdel -rf $SEEDUSER >/dev/null 2>&1
  checking_errors $?

  echo -e " ${BWHITE}* Suppression home $SEEDUSER...${NC}"
  rm -Rf $USERHOMEDIR >/dev/null 2>&1
  checking_errors $?
  echo ""

  echo -e " ${BWHITE}* Suppression Containers...${NC}"
  docker rm -f $(docker ps -aq) >/dev/null 2>&1
  docker volume rm $(docker volume ls -qf "dangling=true") >/dev/null 2>&1
  checking_errors $?

  echo -e " ${BWHITE}* Suppression group...${NC}"
  groupdel $SEEDGROUP >/dev/null 2>&1
  checking_errors $?

  echo -e " ${BWHITE}* Supression du dossier ${CONFDIR}...${NC}"
  rm -Rf ${CONFDIR}
  checking_errors $?
  pause
}

function pause() {
  echo ""
  echo -e "${YELLOW}###  -->APPUYER SUR ENTREE POUR CONTINUER<--  ###${NC}"
  read
  echo ""
}

function select_seedbox_param() {
  if [ ! -f ${SCRIPTPATH}/ssddb ]; then
    # le fichier de base de données n'est pas là
    # on sort avant de faire une requête, sinon il va se créer
    # et les tests ne seront pas bons
    return 0
  fi
  request="select value from seedbox_params where param ='"${1}"'"
  RETURN=$(sqlite3 ${SCRIPTPATH}/ssddb "${request}")
  if [ $? != 0 ]; then
    echo 0
  else
    echo $RETURN
  fi

}

function update_seedbox_param() {
  request="replace into seedbox_params (param,value) values ('"${1}"','"${2}"')"
  sqlite3 ${SCRIPTPATH}/ssddb "${request}"
}

function manage_account_yml() {
  # usage
  # manage_account_yml key value
  # key séparées par des points (par exemple user.name ou sub.application.subdomain)
  ansible-vault decrypt "${CONFDIR}/variables/account.yml" >/dev/null 2>&1
  ansible-playbook "${BASEDIR}/includes/config/playbooks/manage_account_yml.yml" -e "account_key=${1} account_value=${2}"
  ansible-vault encrypt "${CONFDIR}/variables/account.yml" >/dev/null 2>&1
}

function get_from_account_yml() {
  # usage
  # get_from_account_yml user.name
  # retourne la valeur trouvée
  # si la valeur est vide ou n'existe pas, retourn la chaine "notfound"
  ansible-vault decrypt "${CONFDIR}/variables/account.yml" >/dev/null 2>&1
  temp_return=$(shyaml -q get-value $1 <"${CONFDIR}/variables/account.yml")
  if [ $? != 0 ]; then
    temp_return=notfound
  fi
  if [ -z "$temp_return" ]; then
    temp_return=notfound
  fi
  if [ "$temp_return" == "None" ]; then
    temp_return=notfound
  fi
  ansible-vault encrypt "${CONFDIR}/variables/account.yml" >/dev/null 2>&1
  echo $temp_return
}

function install_gui() {

  # installation des dépendances, permet de créer les docker network via ansible
  ansible-galaxy collection install community.general
  # dépendence permettant de gérer les fichiers yml
  ansible-galaxy install kwoodson.yedit
  # On vérifie que le user ait bien les droits d'écriture
  make_dir_writable ${BASEDIR}
  # on vérifie que le user ait bien les droits d'écriture dans la db
  change_file_owner ${BASEDIR}/ssddb
  # On crée le conf dir (par défaut /opt/seedbox) s'il n'existe pas
  conf_dir
  # On part à la pêche aux infos....
  ${BASEDIR}/includes/config/scripts/get_infos.sh
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
  # On install nginx
  ansible-playbook ${BASEDIR}/includes/config/roles/nginx/tasks/main.yml

  DOMAIN=$(select_seedbox_param "domain")
  GUISUBDOMAIN=$(get_from_account_yml sub.gui.gui)

  echo -e "${CRED}---------------------------------------------------------------${CEND}"
  echo -e "${CRED}          /!\ INSTALLATION EFFECTUEE AVEC SUCCES /!\           ${CEND}"
  echo -e "${CRED}---------------------------------------------------------------${CEND}"
  echo ""
  echo -e "${CRED}---------------------------------------------------------------${CEND}"
  echo -e "${CCYAN}              Adresse de l'interface WebUI                    ${CEND}"
  echo -e "${CCYAN}              https://${GUISUBDOMAIN}.${DOMAIN}              ${CEND}"
  echo -e "${CRED}---------------------------------------------------------------${CEND}"
  echo ""

  echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour sortir du script..."
  read -r
  exit 0
}

function premier_lancement() {

  echo "Certains composants doivent encore être installés/réglés"
  read -p "Appuyez sur entrée pour continuer, ou ctrl+c pour sortir"

  # installation des paquets nécessaires
  sudo ${SCRIPTPATH}/includes/config/scripts/prerequis_root.sh

  # création d'un vault_pass vide

  if [ ! -f "${HOME}/.vault_pass" ]; then
    mypass=$(
      tr -dc A-Za-z0-9 </dev/urandom | head -c 25
      echo ''
    )
    echo "$mypass" >"${HOME}/.vault_pass"

  fi

  # création d'un virtualenv
  python3 -m venv ${SCRIPTPATH}/venv

  # activation du venv
  source ${SCRIPTPATH}/venv/bin/activate

  ## Constants
  python3 -m pip install --disable-pip-version-check --upgrade --force-reinstall \
    pip
  pip install wheel
  pip install ansible \
    docker \
    shyaml
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
  log_path=${SCRIPTPATH}/logs/ansible.log
EOF
  ansible-playbook ${SCRIPTPATH}/includes/config/roles/users/tasks/main.yml

  echo "Création de la configuration en cours"
  # On créé la database
  sqlite3 ${SCRIPTPATH}/ssddb <<EOF
    create table seedbox_params(param varchar(50) PRIMARY KEY, value varchar(50));
    replace into seedbox_params (param,value) values ('installed',0);
    replace into seedbox_params (param,value) values ('seedbox_path','/opt/seedbox');
    create table applications(name varchar(50) PRIMARY KEY,
      status integer,
      subdomain varchar(50),
      port integer);
    create table applications_params (appname varchar(50),
      param varachar(50),
      value varchar(50),
      FOREIGN KEY(appname) REFERENCES applications(name));
EOF
  ansible-galaxy collection install community.general
  # dépendence permettant de gérer les fichiers yml
  ansible-galaxy install kwoodson.yedit
  echo "Les composants sont maintenants tous installés/réglés, poursuite de l'installation"

  read -p "Appuyez sur entrée pour continuer, ou ctrl+c pour sortir"

  export CONFDIR=/opt/seedbox

  ##################################################
  # Account.yml
  create_dir ${CONFDIR}
  create_dir ${CONFDIR}/variables
  if [ ! -f ${CONFDIR}/variables/account.yml ]; then
    cp /opt/seedbox-compose/includes/config/account.yml ${CONFDIR}/variables/account.yml
  fi

  if [[ -d "${HOME}/.cache" ]]; then
    sudo chown -R ${USER}: "${HOME}/.cache"
  fi
  if [[ -d "${HOME}/.local" ]]; then
    sudo chown -R ${USER}: "${HOME}/.local"
  fi
  if [[ -d "${HOME}/.ansible" ]]; then
    sudo chown -R ${USER}: "${HOME}/.ansible"
  fi
  sudo chown -R ${USER} ${SCRIPTPATH}/logs/
  sudo chmod 777 ${SCRIPTPATH}/logs
  touch ${SCRIPTPATH}/.prerequis.lock
  # fin du venv
  deactivate

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
  echo "--action <action>"
  echo "  définit une action à lancer"
  echo "  Cette option nécessite un fichier autoinstall.ini"
  echo "  Les actions possibles sont :"
  echo "     install_gui : Installe la gui"
  echo "--force-root"
  echo "  permet d'installer la seedbox en root"
  echo "--migrate"
  echo "  gère la migration de la V1 vers la V2"
  echo "--ini-file <fichier>"
  echo "  Change le chemin par défaut du ini-file"
  echo ""
  exit 0
}

function migrate() {
  # on sort du venv car on va le retrouver juste après
  deactivate
  premier_lancement
  # on revient dans le venv
  source ${SCRIPTPATH}/venv/bin/activate

  echo "Vous allez migrer de SSD V1 vers SSD V2"
  if [ "$USER" == "root" ]; then
    echo "Vous ne POUVEZ pas faire cette opération en root"
    echo "Merci de vous connecter sur le bon user avant de relancer"
    exit 1
  fi
  echo "Assurez vous d'être connecté sur le bon utilisateur (celui qui va piloter la seedbox)"
  echo "Cela doit être le user qui a été créé lors de la v1, "
  echo "en connection directe (pas de connection sur un autre user ou root, puis sudo)"
  echo "Cela va provoquer des coupures de service"
  read -p "Appuyez sur entrée pour lancer la procédure"
  # copie éventuelle du rclone existant
  if [ -f "${HOME}/.config/rclone/rclone.conf" ]; then
    mv "${HOME}/.config/rclone/rclone.conf" "${HOME}/.config/rclone/rclone.conf.backup_migration"
    echo "Le fichier rclone existant a été copié sur ${HOME}/.config/rclone/rclone.conf.backup_migration"
  fi
  # copie du rclone de root
  mkdir -p "${HOME}/.config/rclone"
  sudo cp /root/.config/rclone/rclone.conf "${HOME}/.config/rclone/rclone.conf"
  sudo chown "${USER}" "${HOME}/.config/rclone/rclone.conf"
  sudo chown -R "${USER}" /opt/seedbox/conf
  sudo cp /root/.vault_pass "${HOME}/.vault_pass"
  sudo chown "${USER}": "${HOME}/.vault_pass"
  sudo chown "${USER}": "${CONFDIR}/variables/account.yml"
  sudo chown -R "${USER}": /opt/seedbox/status
  sudo chown -R "${USER}": /opt/seedbox/docker
  # remplacement du backup
  sauve
  # on relance l'install de rclone pour avoir le bon fichier service
  # on supprime le fichier de service existant
  if [ -f "/etc/systemd/system/rclone.service" ]; then
    sudo systemctl stop rclone
    sudo rm -f /etc/systemd/system/rclone.service
    echo "La configuration rclone va commencer"
    echo "Choisissez le choix 3 (fichier déjà présent) et laissez vous guider"
    read -p "Appuyez sur entrée pour continuer"
    install_rclone
  fi
  # on met les bons droits sur le conf dir
  conf_dir
  # cloudplow
  if [ -f "/etc/systemd/system/cloudplow.service" ]; then
    cloudplow
  fi
  # crop
  if [ -f "/etc/systemd/system/crop_upload.service" ]; then
    crop
  fi
  # plexdrive
  if [ -f "/etc/systemd/system/plexdrive.service" ]; then
    plexdrive
  fi
  # mise  à jour du account.yml
  echo "Mise à jour du account.yml, merci de patienter"
  if docker ps | grep oauth; then
    type_auth=oauth
  else
    type_auth=basique
  fi
  sort -u /opt/seedbox/resume >/tmp/resume
  rm /opt/seedbox/resume
  mv /tmp/resume /opt/seedbox/resume
  while read line; do
    appli=$(echo $line | awk '{print $3}' | awk -F'.' '{print $1}')
    if [ -z ${appli} ]; then
      :
    else
      manage_account_yml sub.${line} " "
      manage_account_yml sub.${line}.${line} ${appli}
      manage_account_yml sub.${line}.auth ${type_auth}
    fi
  done </opt/seedbox/resume
  update_seedbox_param "installed" 1
  echo "Migration terminée, il est conseillé de redémarrer la seedbox"
}
