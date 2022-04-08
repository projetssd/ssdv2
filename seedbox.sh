#!/bin/bash

# on change tout de suite le path pour la suite
export PATH="$HOME/.local/bin:$PATH"
export IFSORIGIN="${IFS}"

# Absolute path to this script.
CURRENT_SCRIPT=$(readlink -f "$0")
# Absolute path this script is in.
SETTINGS_SOURCE=$(dirname "$CURRENT_SCRIPT")
export SCRIPTPATH
cd ${SETTINGS_SOURCE}

source "${SETTINGS_SOURCE}/includes/variables.sh"
source "${SETTINGS_SOURCE}/includes/functions.sh"
source "${SETTINGS_SOURCE}/includes/menus.sh"

################################################
# récupération des parametres
# valeurs par défaut
FORCE_ROOT=0
INI_FILE=${SETTINGS_SOURCE}/autoinstall.ini
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
if [ ! -f "${SETTINGS_SOURCE}/ssddb" ]; then

  premier_lancement
  # on ajoute le PATH qui va bien, au cas où il ne soit pas pris en compte par le ~/.profile
fi

# on contre le bug de debian et du venv qui ne trouve pas les paquets installés par galaxy
source "${SETTINGS_SOURCE}/venv/bin/activate"
temppath=$(ls ${SETTINGS_SOURCE}/venv/lib)
pythonpath=${SETTINGS_SOURCE}/venv/lib/${temppath}/site-packages
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
#sudo chown -R ${USER}: ${SETTINGS_SOURCE}

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


        # mise en place de la sauvegarde
        sauve
        # Affichage du résumé
        #pause
        # on marque la seedbox comme installée
        update_seedbox_param "installed" 1
        echo "L'installation est maintenant terminée."
        echo "Pour le configurer ou modifier les applis, vous pouvez le relancer"
        echo "cd ${SETTINGS_SOURCE}"
        echo "./seedbox.sh"
        exit 0
      else
        affiche_menu_db
      fi
      ;;

    2) ## Installation de la seedbox classique

      check_dir "$PWD"
      if [[ ${IS_INSTALLED} -eq 0 ]]; then
        # Install de watchtower
        install_watchtower
        # Install fail2ban
        install_fail2ban
        # Choix des dossiers et création de l'arborescence
        choose_media_folder_plexdrive
        update_seedbox_param "installed" 1
        pause
        touch "${CONFDIR}/media-$SEEDUSER"
        echo "L'installation est maintenant terminée."
        echo "Pour le configurer ou modifier les applis, vous pouvez le relancer"
        echo "cd ${SETTINGS_SOURCE}"
        echo "./seedbox.sh"
        exit 0
      else
        affiche_menu_db
      fi
      ;;

    3) ## restauration de la seedbox

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



        # mise en place de la sauvegarde
        sauve

        ## On va garder ce qui a été saisi pour l'écraser plus tard
        cp /opt/seedbox/variables/account.yml /opt/seebox/variables/account.temp

        sudo restore
        # on remet le account.yml précédent qui a été écrasé par la restauration
        cp /opt/seedbox/variables/account.yml /opt/seedbox/variables/account.restore
        mv /opt/seebox/variables/account.temp /opt/seebox/variables/account.yml
        stocke_public_ip
        ## on remet les bonnes infos
        userid=$(id -u)
        grpid=$(id -g)

        manage_account_yml user.userid "$userid"
        manage_account_yml user.id "$userid"
        manage_account_yml user.groupid "$grpid"
        ## reinitialisation de toutes les applis
        relance_tous_services
        # on marque la seedbox comme installée
        update_seedbox_param "installed" 1
        affiche_menu_db
      else
        affiche_menu_db
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

  chmod 755 ${SETTINGS_SOURCE}/logs
  #update_logrotate
  log_statusbar "Check de la dernière version sur git"
  git_branch=$(git rev-parse --abbrev-ref HEAD)
  if [ ${git_branch} == 'master' ]; then
    cd ${SETTINGS_SOURCE}
    git fetch >>/dev/null 2>&1
    current_hash=$(git rev-parse HEAD)
    distant_hash=$(git rev-parse master@{upstream})
    if [ ${current_hash} != ${distant_hash} ]; then
      clear
      echo "==============================================="
      echo "= Il existe une mise à jour"
      echo "= Pour le faire, sortez du script, puis tapez"
      echo "= git pull"
      echo "==============================================="
      pause
    fi
  else
    clear
    echo "==============================================="
    echo "= Attention, vous n'êtes pas sur la branche master !"
    echo "= Pour repasser sur master, sortez du script, puis tapez "
    echo "= git checkout master"
    echo "==============================================="
    pause
  fi
  log_statusbar "Verification de l'emplacement du stockage"
  emplacement_stockage=$(get_from_account_yml settings.storage)
  if [ "${emplacement_stockage}" == notfound ]; then
    manage_account_yml settings.storage "/opt/seedbox"
  fi

  affiche_menu_db
fi

