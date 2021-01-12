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
DATE=`date +%d/%m/%Y-%H:%M:%S`
IPADDRESS=$(hostname -I | cut -d\  -f1)
CURRENTDIR="$PWD"
export BASEDIR="/opt/seedbox-compose"
export CONFDIR=$(select_seedbox_param "seedbox_path")
SERVICESAVAILABLE="$BASEDIR/includes/config/services-available"
WEBSERVERAVAILABLE="$BASEDIR/includes/config/webserver-available"
PROJECTSAVAILABLE="$BASEDIR/includes/config/projects-available"
MEDIAVAILABLE="$BASEDIR/includes/config/media-available"
SERVICES="$BASEDIR/includes/config/services"
SERVICESUSER="$CONFDIR/services-"
SERVICESPERUSER="${SERVICESUSER}${USER}"
PROJECTUSER="$CONFDIR/projects-"
MEDIASUSER="$CONFDIR/media-"
PACKAGESFILE="$BASEDIR/includes/config/packages"
export TMPDOMAIN=${BASEDIR}/tmp/domain
export TMPNAME=${BASEDIR}/tmp/name
export TMPGROUP=${BASEDIR}/tmp/group
export NEWT_COLORS='
  window=,white
  border=green,blue
  textbox=black,white
'
# On risque d'avoir besoin de ces variables d'environnement par la suite
export MYUID=$(id -u)
export MYGID=$(id -g)
export MYGIDNAME=$(id -gn)