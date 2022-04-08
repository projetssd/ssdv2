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
  if [ ! -f "${SCRIPTPATH}/ssddb" ]; then
    # la seedbox est installée, on va prendre les valeurs par défaut de la v1/2.0
    export SETTINGS_SOURCE=/opt/seedbox-compose/
    export SETTINGS_STORAGE=/opt/seedbox
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
    echo "Dans quel répertoire voulez vous stocker les réglages des containers ? (défaut : ${HOME}/seedbox/docker")
    read destdir
    export SETTINGS_STORAGE=${destdir}
    echo "SETTINGS_STORAGE=${destdir}/" >>"${HOME}/.config/ssd/env"
  fi

else
  source "${HOME}/.config/ssd/env"
fi

export BASEDIR=${SETTINGS_SOURCE}
export CONFDIR=${SETTINGS_STORAGE}
export SERVICESAVAILABLE="$BASEDIR/includes/config/services-available"
export WEBSERVERAVAILABLE="$BASEDIR/includes/config/webserver-available"
export PROJECTSAVAILABLE="$BASEDIR/includes/config/projects-available"
export MEDIAVAILABLE="$BASEDIR/includes/config/media-available"
export SERVICES="$BASEDIR/includes/config/services"
export SERVICESUSER="$CONFDIR/services-"
export SERVICESPERUSER="${SERVICESUSER}${USER}"
export PROJECTUSER="$CONFDIR/projects-"
export MEDIASUSER="${CONFDIR}/media-"
export MEDIASPERUSER=${MEDIASUSER}${USER}
export PACKAGESFILE="$BASEDIR/includes/config/packages"
export TMPDOMAIN=${BASEDIR}/tmp/domain
export TMPNAME=${BASEDIR}/tmp/name
export TMPGROUP=${BASEDIR}/tmp/group

# On risque d'avoir besoin de ces variables d'environnement par la suite
export MYUID=$(id -u)
export MYGID=$(id -g)
export MYGIDNAME=$(id -gn)
