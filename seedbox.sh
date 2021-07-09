#!/bin/bash

# on change tout de suis le path pour la suite
export PATH="$HOME/.local/bin:$PATH"

# Absolute path to this script.
CURRENT_SCRIPT=$(readlink -f "$0")
# Absolute path this script is in.
SCRIPTPATH=$(dirname "$CURRENT_SCRIPT")
export SCRIPTPATH
cd ${SCRIPTPATH}

# shellcheck source=${BASEDIR}/includes/functions.sh
source "${SCRIPTPATH}/includes/functions.sh"
# shellcheck source=${BASEDIR}/includes/variables.sh
source "${SCRIPTPATH}/includes/variables.sh"
# shellcheck source=${BASEDIR}/includes/functions.sh
source "${SCRIPTPATH}/includes/functions.sh"

################################################
# récupération des parametre
# valeurs par défaut
FORCE_ROOT=0
INI_FILE=${SCRIPTPATH}/autoinstall.ini
action=manuel
export mode_install=manuel
# lecture des parametres
OPTS=$(getopt -o vhns: --long \
  help,action:,ini-file:,force-root,migrate \
  -n 'parse-options' -- "$@")

if [ $? != 0 ]; then
  echo "Failed parsing options." >&2
  exit 1
fi

eval set -- "${OPTS}"

while true; do
  case "$1" in
  --action)
    export action=$2
    export mode_install=auto
    shift 2
    ;;

  --force-root)
    FORCE_ROOT=1
    shift
    ;;

  --ini-file)
    INI_FILE=$2
    shift 2
    ;;

  --migrate)
    migrate
    shift 1
    exit 0
    ;;

  --help)

    usage
    shift
    ;;

  --)
    shift
    break
    ;;
  *)
    echo "Internal error! $2"
    exit 1
    ;;
  esac
done

#
# Maintenant, on a toutes les infos
#
check_docker_group
if [ ! -f "${SCRIPTPATH}/ssddb" ]; then

  premier_lancement
  # on ajoute le PATH qui va bien, au cas où il ne soit pas pris en compte par le ~/.profile
fi

# on contre le bug de debian et du venv qui ne trouve pas les paquets installés par galaxy
source "${SCRIPTPATH}/venv/bin/activate"
temppath=$(ls /opt/seedbox-compose/venv/lib)
pythonpath=/opt/seedbox-compose/venv/lib/${temppath}/site-packages
export PYTHONPATH=${pythonpath}

case "$action" in
install_gui)
  if [ ! -f ${INI_FILE} ]; then
    echo "ERREUR, fichier d'autoinstall non trouvé !"
    exit 1
  fi
  source <(grep = ${INI_FILE})
  install_gui

  exit 0
  ;;
manuel)
  # pas d'action passée, on sort du case
  ;;
*)
  echo "Action $action inconnue"
  exit 1
  ;;
esac

# Si on est ici, c'est a priori qu'on n'a pas passé d'option
# ou en tout cas qu'on n'a pas redirigé vers une fonction
# spécifique

################################################
# TEST ROOT USER
if [ "$USER" == "root" ]; then
  if [ "$FORCE_ROOT" == 0 ]; then
    echo -e "${CCYAN}-----------------------${CEND}"
    echo -e "${CCYAN}[  Lancement en root  ]${CEND}"
    echo -e "${CCYAN}-----------------------${CEND}"
    echo -e "${CCYAN}Pour des raisons de sécurité, il n'est pas conseillé de lancer ce script en root${CEND}"
    echo -e "${CCYAN}-----------------------${CEND}"
    echo -e "${CCYAN}Vous pouvez continuer en root en passant l'option --force-root en parametre${CEND}"
    exit 1
  fi
fi

# on met les droits comme il faut, au cas où il y ait eu un mauvais lancement
sudo chown -R ${USER}: ${SCRIPTPATH}

IS_INSTALLED=$(select_seedbox_param "installed")

#clear

if [ $mode_install = "manuel" ]; then

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
    #echo -e "${CGREEN}   999) Installer la GUI${CEND}"
    echo -e "${CGREEN}   9) Sortir du script${CEND}"

    echo -e ""
    read -p "Votre choix : " CHOICE
    echo ""
    case $CHOICE in

    \
      1) ## Installation de la seedbox Rclone et Gdrive

      #check_dir "$PWD"
      if [[ ${IS_INSTALLED} -eq 0 ]]; then

        clear
        # Installation et configuration de rclone
        install_rclone
        # Install de watchtower
        install_watchtower
        # Install fail2ban
        install_fail2ban
        # Choix des dossiers et création de l'arborescence
        choose_media_folder_plexdrive
        # Installation de mergerfs
        # Cette install a une incidence sur docker (dépendances dans systemd)
        unionfs_fuse
        pause


        # Installation de filebot
        # TODO : à laisser ? Ou à mettre dans les applis ?
        #filebot

        # mise en place de la sauvegarde
        sauve
        # Affichage du résumé
        #resume_seedbox
        #pause
        # on marque la seedbox comme installée
        update_seedbox_param "installed" 1
        echo "L'installation est maintenant terminée."
        echo "Pour le configurer ou modifier les applis, vous pouvez le relancer"
        echo "cd /opt/seedbox-compose"
        echo "./seedbox.sh"
        exit 0
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
        touch "${CONFDIR}/media-$SEEDUSER"
        echo "L'installation est maintenant terminée."
        echo "Pour le configurer ou modifier les applis, vous pouvez le relancer"
        echo "cd /opt/seedbox-comose"
        echo "./seedbox.sh"
        exit 0
      else
        script_classique
      fi
      ;;

    3) ## restauration de la seedbox

      #check_dir "$PWD"
      if [[ ${IS_INSTALLED} -eq 0 ]]; then
        clear
        # on met la timezone
        #ansible-playbook ${BASEDIR}/includes/config/playbooks/timezone.yml
        # Dépendances pour ansible (permet de créer le docker network)
        ansible-galaxy collection install community.general
        # on vérifie les droits sur répertoire et bdd
        make_dir_writable ${BASEDIR}
        change_file_owner ${BASEDIR}/ssddb
        # On crée le conf dir (par défaut /opt/seedbox) s'il n'existe pas
        conf_dir
        # Maj du système
        update_system
        # On crée le dossier status
        status
        # Install des packages de base
        install_base_packages
        # Install de docker
        install_docker
        #  On part à la pêche aux infos
        create_user_non_systeme
        # récup infos cloudflare
        cloudflare
        # récup infos oauth
        oauth
        # Install de traefik
        install_traefik
        # Installation et configuration de rclone
        install_rclone
        # Install de watchtower
        install_watchtower
        # Install fail2ban
        install_fail2ban
        # Choix des dossiers et création de l'arborescence
        choose_media_folder_plexdrive
        unionfs_fuse
        sauve
        sudo restore
        ## reinitialisation de toutes les applis
        while read line; do echo $line | cut -d'.' -f1; done <"/home/${USER}/resume" >$SERVICESPERUSER
        rm /home/${USER}/resume
        install_services
        # on marque la seedbox comme installée
        update_seedbox_param "installed" 1
        script_plexdrive
      else
        script_plexdrive
      fi
      ;;

    9)
      exit 0
      ;;

    999) ## Installation seedbox webui
      install_gui
      ;;

    esac
  fi

  update_status

  chmod 755 /opt/seedbox-compose/logs
  update_logrotate
  PLEXDRIVE="/usr/bin/rclone"
  if [[ -e "$PLEXDRIVE" ]]; then
    script_plexdrive
  else
    script_classique
  fi
fi
