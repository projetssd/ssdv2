#!/bin/bash

# on change tout de suite le path pour la suite
export PATH="$HOME/.local/bin:$PATH"
export IFSORIGIN="${IFS}"

# Absolute path to this script.
CURRENT_SCRIPT=$(readlink -f "$0")
# Absolute path this script is in.
SETTINGS_SOURCE=$(dirname "$CURRENT_SCRIPT")
export SETTINGS_SOURCE
cd ${SETTINGS_SOURCE}
export TEXTDOMAINDIR="${SETTINGS_SOURCE}/i18n"
export TEXTDOMAIN=ks
source "${SETTINGS_SOURCE}/includes/functions.sh"
source "${SETTINGS_SOURCE}/includes/variables.sh"
source "${SETTINGS_SOURCE}/includes/menus.sh"

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
    echo -e "${CCYAN}"$(gettext "Pour des raisons de sécurité, il n'est pas conseillé de lancer ce script en root")"${CEND}"
    echo -e "${CCYAN}-----------------------${CEND}"
    echo -e "${CCYAN}"$(gettext "Vous pouvez continuer en root en passant l'option --force-root en parametre")"${CEND}"
    exit 1
  fi
fi

IS_INSTALLED=$(select_seedbox_param "installed")

if [ $mode_install = "manuel" ]; then

  if [[ ${IS_INSTALLED} -eq 0 ]]; then
      for patch in $(ls ${SETTINGS_SOURCE}/patches); do
        echo "${patch}" >>"${HOME}/.config/ssd/patches"
      done
      if [[ ${IS_INSTALLED} -eq 0 ]]; then
        # Choix des dossiers et création de l'arborescence
        create_folders
        sauve
        # on marque la seedbox comme installée
        update_seedbox_param "installed" 1
        # installation environnement
        install_environnement
        echo $(gettext "L'installation est maintenant terminée.")
        echo $(gettext "Pour le configurer ou modifier les applis, vous pouvez le relancer")
        echo "cd ${SETTINGS_SOURCE}"
        echo "./seedbox.sh"
        exit 0
      else
        affiche_menu_db
      fi
  fi

  log_statusbar "$(echo $(gettext "Check de la dernière version sur git"))"
  git_branch=$(git rev-parse --abbrev-ref HEAD)
  if [ ${git_branch} == 'master' ]; then
    cd ${SETTINGS_SOURCE}
    git fetch >>/dev/null 2>&1
    current_hash=$(git rev-parse HEAD)
    distant_hash=$(git rev-parse master@{upstream})
    if [ ${current_hash} != ${distant_hash} ]; then
      clear
      echo "==============================================="
      echo $(gettext "= Il existe une mise à jour")
      echo $(gettext "= Pour le faire, sortez du script, puis tapez")
      echo "= git pull"
      echo "==============================================="
      pause
    fi
  else
    clear
    echo "==============================================="
    echo $(gettext "= Attention, vous n'êtes pas sur la branche master !")
    echo $(gettext "= Pour repasser sur master, sortez du script, puis tapez ")
    echo "= git checkout master"
    echo "==============================================="
    pause
  fi
  #####################################################
  # On finit de setter les variables
  source ${SETTINGS_SOURCE}/venv/bin/activate
  emplacement_stockage=$(get_from_account_yml settings.storage)
  if [ "${emplacement_stockage}" == notfound ]; then
    manage_account_yml settings.storage "${SETTINGS_STORAGE}"
  fi

  emplacement_source=$(get_from_account_yml settings.source)
  if [ "${emplacement_source}" == notfound ]; then
    manage_account_yml settings.source "${SETTINGS_SOURCE}"
  fi
  # Verif compatibilité v2/0 => V2.1
  # On regarde que settings.storage existe
  log_statusbar "$(echo $(gettext "Verification de l'emplacement du stockage"))"
  emplacement_stockage=$(get_from_account_yml settings.storage)
  if [ "${emplacement_stockage}" == notfound ]; then
    manage_account_yml settings.storage "/opt/seedbox"
  fi
  # On ressource l'environnement
  source "${SETTINGS_SOURCE}/profile.sh"
  export TEXTDOMAIN=ks
  export TEXTDOMAINDIR="${SETTINGS_SOURCE}/i18n"
  apply_patches

  affiche_menu_db
fi
