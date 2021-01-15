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
export CONFDIR="/opt/seedbox"
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
export NEWT_COLORS='
  window=,white
  border=green,blue
  textbox=black,white
'
# On risque d'avoir besoin de ces variables d'environnement par la suite
export MYUID=$(id -u)
export MYGID=$(id -g)
export MYGIDNAME=$(id -gn)