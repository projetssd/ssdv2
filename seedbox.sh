#!/bin/bash

# Absolute path to this script.
CURRENT_SCRIPT=$(readlink -f "$0")
# Absolute path this script is in.
export SCRIPTPATH=$(dirname "$CURRENT_SCRIPT")


# shellcheck source=${BASEDIR}/includes/functions.sh
source "${SCRIPTPATH}/includes/functions.sh"
# shellcheck source=${BASEDIR}/includes/variables.sh
source "${SCRIPTPATH}/includes/variables.sh"

# on créé un vault pass vide pour commencer
if [ ! -f "${HOME}/.vault_pass" ]; then
  echo "0" >  ${HOME}/.vault_pass
fi

#####################################
# TEST ROOT USER
if [ "$USER" == "root" ]; then
  echo -e "${CCYAN}-----------------------${CEND}"
  echo -e "${CCYAN}[  Lancement en root  ]${CEND}"
  echo -e "${CCYAN}-----------------------${CEND}"
  echo -e "${CCYAN}Pour des raisons de sécurité, il n'est pas conseillé de lancer ce script en root${CEND}"
  read -p "Appuyez sur entrée pour continuer, ou ctrl+c pour sortir"
fi


clear
if [ -f"${SCRIPTPATH}/ssddb" ]; then
  # le fichier de conf existe
  IS_INSTALLED=$(select_seedbox_param "installed")
else
  # Aucun fichier de conf
  echo -e "${CCYAN}
   ___  ____  ____  ____  ____  _____  _  _
  / __)( ___)(  _ \(  _ \(  _ \(  _  )( \/ )
  \__ \ )__)  )(_) ))(_) )) _ < )(_)(  )  (
  (___/(____)(____/(____/(____/(_____)(_/\_)

  ${CEND}"

  echo ""
  echo -e "${CCYAN}---------------------------------${CEND}"
  echo -e "${CCYAN}[  INSTALLATION DES PRÉ-REQUIS  ]${CEND}"
  echo -e "${CCYAN}---------------------------------${CEND}"
  echo ""
  echo -e "${CCYAN}Les prérequis ne sont pas installés. Merci de le faire en tapant${CEND}"
  echo -e "${CYAN}sudo ./prerequis.sh${CEND}"
  echo -e "${CYAN}avant de continuer${CEND}"
  exit 1
fi


if [[ ${IS_INSTALLED} -eq 0 ]]; then
  # Si on est là, c'est que le prérequis sont installés, mais c'est tout
  # On propose donc l'install de la seedbox
  clear
  logo
  echo -e "${CCYAN}INSTALLATION SEEDBOX DOCKER${CEND}"
  echo -e "${CGREEN}${CEND}"
  echo -e "${CGREEN}   1) Installation Seedbox rclone && gdrive${CEND}"
  echo -e "${CGREEN}   2) Installation Seedbox Classique ${CEND}"
  echo -e "${CGREEN}   3) Restauration Seedbox${CEND}"
  echo -e "${CGREEN}   9) Sortir du script${CEND}"

  echo -e ""
  read -p "Votre choix : " CHOICE
  echo ""
  case $CHOICE in


  1) ## Installation de la seedbox Rclone et Gdrive

    check_dir "$PWD"
    if [[ ! -d "$CONFDIR" ]]; then
      clear
      ansible-galaxy collection install community.general
      make_dir_writable ${BASEDIR}
      change_file_owner ${BASEDIR}/ssddb
      conf_dir
      update_system
      install_base_packages
      install_docker
      create_user_non_systeme
      cloudflare
      oauth
      install_traefik
      install_rclone
      install_watchtower

      install_fail2ban
      choose_media_folder_plexdrive
      unionfs_fuse
      pause
      choose_services
      subdomain
      install_services
      for i in $(docker ps --format "{{.Names}}")
      do
      if [[ "$i" == "plex" ]]; then
        plex_sections
      fi
      done
      projects
      filebot
      sauve
      resume_seedbox
      pause
      ansible-vault encrypt ${CONFDIR}/variables/account.yml >/dev/null 2>&1
      script_plexdrive
    else
      script_plexdrive
    fi
    ;;

  2) ## Installation de la seedbox classique

    check_dir "$PWD"
    if [[ ! -d "$CONFDIR" ]]; then
      clear
      conf_dir
      update_system
      install_base_packages
      install_docker
      define_parameters
      cloudflare
      oauth
      install_traefik
      install_watchtower
      install_fail2ban
      choose_media_folder_classique
      choose_services
      subdomain
      install_services
      filebot
      resume_seedbox
      pause
      ansible-vault encrypt ${CONFDIR}/variables/account.yml >/dev/null 2>&1
      touch "${CONFDIR}/media-$SEEDUSER"
      script_classique
    else
      script_classique
    fi
    ;;

  3) ## restauration de la seedbox

    check_dir "$PWD"
    if [[ ! -d "$CONFDIR" ]]; then
      clear
      echo ""
      echo -e "${CRED}---------------------------------------------------------------${CEND}"
      echo -e "${CRED} /!\ ATTENTION : PREPARATION DE LA RESTAURATION DU SERVEUR /!\ ${CEND}"
      echo -e "${CRED}---------------------------------------------------------------${CEND}"
      echo ""
      conf_dir
      update_system
      install_base_packages
      install_docker
      define_parameters
      install_rclone
      install_fail2ban
      sauve
      restore
      choose_media_folder_plexdrive
      rm /etc/systemd/system/mergerfs.service >/dev/null 2>&1
      unionfs_fuse
      cloudflare
      install_traefik
      install_watchtower
      SERVICESPERUSER="$SERVICESUSER$SEEDUSER"
      while read line; do echo $line | cut -d'.' -f1; done <"/home/$SEEDUSER/resume" >"$SERVICESUSER$SEEDUSER"
      rm "/home/$SEEDUSER/resume"
      install_services

      ## restauration plex_dupefinder
      PLEXDUPE=/home/$SEEDUSER/scripts/plex_dupefinder/plex_dupefinder.py
      if [[ -e "$PLEXDUPE" ]]; then
        cd "/home/$SEEDUSER/scripts/plex_dupefinder"
        python3 -m pip install -r requirements.txt
      fi

      ## restauration cloudplow
      CLOUDPLOWSERVICE=/etc/systemd/system/cloudplow.service
      if [[ -e "$CLOUDPLOWSERVICE" ]]; then
        cd "/home/$SEEDUSER/scripts/cloudplow"
        python3 -m pip install -r requirements.txt
        ln -s /home/$SEEDUSER/scripts/cloudplow/cloudplow.py /usr/local/bin/cloudplow
        systemctl start cloudplow.service
      fi

      ## restauration plex_autoscan
      PLEXSCANSERVICE=/etc/systemd/system/plex_autoscan.service
      if [[ -e "$PLEXSCANSERVICE" ]]; then
        cd "/home/$SEEDUSER/scripts/plex_autoscan"
        python -m pip install -r requirements.txt
        systemctl start plex_autoscan.service
      fi

      ## restauration des crons
      (
        crontab -l | grep .
        echo "*/1 * * * * ${CONFDIR}/docker/$SEEDUSER/.filebot/filebot-process.sh"
      ) | crontab -
      ln -s "/home/$SEEDUSER/scripts/plex_dupefinder/plex_dupefinder.py" /usr/local/bin/plexdupes
      rm $SERVICESUSER$SEEDUSER
      checking_errors $?
      echo ""
      echo -e "${CRED}---------------------------------------------------------------${CEND}"
      echo -e "${CRED}     /!\ RESTAURATION DU SERVEUR EFFECTUEE AVEC SUCCES /!\     ${CEND}"
      echo -e "${CRED}---------------------------------------------------------------${CEND}"
      echo ""
      pause
      ansible-vault encrypt ${CONFDIR}/variables/account.yml >/dev/null 2>&1
      script_plexdrive
    else
      script_plexdrive
    fi
    ;;
  9)
    exit 0
    ;;

  999) ## Installation seedbox webui
      ansible-galaxy collection install community.general
      make_dir_writable ${BASEDIR}
      change_file_owner ${BASEDIR}/ssddb
      conf_dir
      ${BASEDIR}/includes/config/scripts/get_infos.sh
      echo ""
      status
      update_system
      install_base_packages
      install_docker
      ansible-playbook ${BASEDIR}/includes/config/roles/users/tasks/main.yml
      ansible-playbook ${BASEDIR}/includes/config/roles/users/tasks/chggroup.yml
      ansible-playbook ${BASEDIR}/includes/config/roles/nginx/tasks/main.yml
      create_dir ${CONFDIR}/docker/traefik/acme/
      install_traefik

      DOMAIN=$(select_seedbox_param "domain")

      echo -e "${CRED}---------------------------------------------------------------${CEND}"
      echo -e "${CRED}          /!\ INSTALLATION EFFECTUEE AVEC SUCCES /!\           ${CEND}"
      echo -e "${CRED}---------------------------------------------------------------${CEND}"
      echo ""
      echo -e "${CRED}---------------------------------------------------------------${CEND}"
      echo -e "${CCYAN}              Adresse de l'interface WebUI                    ${CEND}"
      echo -e "${CCYAN}              https://${SUBDOMAIN}.${DOMAIN}                  ${CEND}"
      echo -e "${CRED}---------------------------------------------------------------${CEND}"
      echo ""

      ansible-vault encrypt ${CONFDIR}/variables/account.yml > /dev/null 2>&1
      echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour sortir du script..."
      read -r
      exit 1
   ;;

  esac


fi

status

if [ ! -d "${CONFDIR}/status" ]
then
  mkdir -p ${CONFDIR}/status
fi
for i in $(docker ps --format "{{.Names}}" --filter "network=traefik_proxy")
do
  echo "2" > ${CONFDIR}/status/${i}

done

PLEXDRIVE="/usr/bin/rclone"
if [[ -e "$PLEXDRIVE" ]]; then
  script_plexdrive
else
  script_classique
fi
