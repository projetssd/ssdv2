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
  # pas de fichier d'environnement
  if [ -f "/opt/seedbox-compose/ssddb" ]; then
    # la seedbox est installée, on va prendre les valeurs par défaut de la v1/2.0
    if [ -z ${SETTINGS_SOURCE+x} ]; then
      export SETTINGS_SOURCE=/opt/seedbox-compose/
    fi
    if [ -z ${SETTINGS_STORAGE+x} ]; then
      export SETTINGS_STORAGE=/opt/seedbox
    fi
    mkdir -p "${HOME}/.config/ssd/"
    echo "SETTINGS_SOURCE=/opt/seedbox-compose/" >>"${HOME}/.config/ssd/env"
    echo "SETTINGS_STORAGE=/opt/seedbox/" >>"${HOME}/.config/ssd/env"
  else
    # Si on est là, c'est que rien n'est installé, on va poser les questions
    mkdir -p "${HOME}/.config/ssd/"
    # on prend le répertoire courant pour la source
    sourcedir=$(dirname "$(readlink -f "$0")")
    export SETTINGS_SOURCE=${sourcedir}
    echo "SETTINGS_SOURCE=${sourcedir}" >>"${HOME}/.config/ssd/env"
    read -p "Dans quel répertoire voulez vous stocker les réglages des containers ? (défaut : ${HOME}/seedbox)" destdir
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
