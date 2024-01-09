## PARAMETERS

CSI="\033["
CEND="${CSI}0m"
CRED="${CSI}1;31m"
CGREEN="${CSI}1;32m"
CPURPLE="${CSI}1;35m"
CCYAN="${CSI}1;36m"
RED='\e[0;31m'
GREEN='\033[0;32m'
BLUEDARK='\033[0;34m'
BLUE='\e[0;36m'
YELLOW='\e[0;33m'
BWHITE='\e[1;37m'
NC='\033[0m'
DATE=$(date +%d/%m/%Y-%H:%M:%S)
IPADDRESS=$(hostname -I | cut -d\  -f1)
CURRENTDIR="$PWD"
export NEWT_COLORS='
  window=,white
  border=green,blue
  textbox=black,white
'

# A partir de là, on va chercher les variables nécessaires

if [ ! -f "${HOME}/.config/ssd/env" ]; then

  # Demander à l'utilisateur de choisir la langue
  clear
  logo
  echo -e "${CCYAN}"Veuillez choisir la langue/Please choose a language :"${CEND}"
  echo ""
  echo -e "${CGREEN}"1. Anglais/English"${CEND}"
  echo -e "${CGREEN}"2. Français/French"${CEND}"
  echo ""
  read -p "Choix/Choice : " choix_langue

  # Changer les locales en fonction du choix de l'utilisateur
  case $choix_langue in
      1)
          nouvelle_locale="en_US.UTF-8"
          ;;
      2)
          nouvelle_locale="fr_FR.UTF-8"
          ;;
      *)
          echo "Choix invalide. Utilisez 1 pour l'anglais ou 2 pour le français."
          exit 1
          ;;
  esac
  sudo localectl set-locale LANG=$nouvelle_locale
  source /etc/default/locale

  # pas de fichier d'environnement
  if [ -f "/opt/seedbox-compose/ssddb" ]; then
    # la seedbox est installée, on va prendre les valeurs par défaut de la v1/2.0
    export SETTINGS_SOURCE=/opt/seedbox-compose
    export SETTINGS_STORAGE=/opt/seedbox
    mkdir -p "${HOME}/.config/ssd/"
    echo "SETTINGS_SOURCE=/opt/seedbox-compose" >>"${HOME}/.config/ssd/env"
    echo "SETTINGS_STORAGE=/opt/seedbox" >>"${HOME}/.config/ssd/env"
  else
    clear
    logo
    # Si on est là, c'est que rien n'est installé, on va poser les questions*
    echo ""
    echo -e "${CRED}========================================================${CEND}"
    echo -e "${CGREEN}                     ATTENTION !!                     ${CEND}"
    echo -e "${CRED}========================================================${CEND}"
    echo ""
    echo $(gettext "Actuellement, la restauration ne fonctionne")
    echo $(gettext "que si le script a été installé depuis le même")
    echo $(gettext "répertoire que celui qui a servi à faire la")
    echo $(gettext "sauvegarde, et a été installé sur la même destination")
    echo ""
    echo "========================================================"
    echo -e "\n"$(gettext "Appuyer sur")"${CCYAN}["$(gettext "ENTREE")"]${CEND}" $(gettext "pour continuer")
    read -r
    mkdir -p "${HOME}/.config/ssd/"
    # on prend le répertoire courant pour la source
    sourcedir=$(dirname "$(readlink -f "$0")")
    export SETTINGS_SOURCE=${sourcedir}
    echo "SETTINGS_SOURCE=${sourcedir}" >>"${HOME}/.config/ssd/env"
    echo >&2 -n -e "${BWHITE}"$(gettext "Dans quel répertoire voulez vous stocker les réglages des containers ?")" (défaut : ${HOME}/seedbox)${CEND} "
    read destdir
    destdir=${destdir:-${HOME}/seedbox}
    export SETTINGS_STORAGE=${destdir}
    echo "SETTINGS_STORAGE=${destdir}/" >>"${HOME}/.config/ssd/env"
    mkdir -p ${SETTINGS_STORAGE}
  fi
else
  source "${HOME}/.config/ssd/env"
fi

export SETTINGS_SOURCE=${SETTINGS_SOURCE}
export SETTINGS_STORAGE=${SETTINGS_STORAGE}
export SERVICESAVAILABLE="${SETTINGS_SOURCE}/includes/config/services-available"
export WEBSERVERAVAILABLE="${SETTINGS_SOURCE}/includes/config/webserver-available"
export PROJECTSAVAILABLE="${SETTINGS_SOURCE}/includes/config/projects-available"
export MEDIAVAILABLE="${SETTINGS_SOURCE}/includes/config/media-available"
export SERVICES="${SETTINGS_SOURCE}/includes/config/services"
export SERVICESUSER="${SETTINGS_STORAGE}/services-"
export SERVICESPERUSER="${SERVICESUSER}${USER}"
export PROJECTUSER="${SETTINGS_STORAGE}/projects-"
export MEDIASUSER="${SETTINGS_STORAGE}/media-"
export MEDIASPERUSER=${MEDIASUSER}${USER}
export PACKAGESFILE="${SETTINGS_SOURCE}/includes/config/packages"
export TMPDOMAIN=${SETTINGS_SOURCE}/tmp/domain
export TMPNAME=${SETTINGS_SOURCE}/tmp/name
export TMPGROUP=${SETTINGS_SOURCE}/tmp/group
export ANSIBLE_VARS="${HOME}/.ansible/inventories/group_vars/all.yml"
# On risque d'avoir besoin de ces variables d'environnement par la suite
export MYUID=$(id -u)
export MYGID=$(id -g)
export MYGIDNAME=$(id -gn)
