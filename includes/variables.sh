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
BACKUPDATE=`date +%d-%m-%Y-%H-%M-%S`
IPADDRESS=$(hostname -I | cut -d\  -f1)
FIRSTPORT="45002"
LASTPORT="8080"
CURRENTDIR="$PWD"
BASEDIR="/opt/seedbox-compose"
CONFDIR="/opt/seedbox"
DOCKERLIST="/etc/apt/sources.list.d/docker.list"
SERVICESAVAILABLE="$BASEDIR/includes/config/services-available"
MEDIAVAILABLE="$BASEDIR/includes/config/media-available"
SERVICES="$BASEDIR/includes/config/services"
SERVICESUSER="/opt/seedbox/services-"
MEDIASUSER="/opt/seedbox/media-"
FILEPORTPATH="/opt/seedbox/ports.pt"
PACKAGESFILE="$BASEDIR/includes/config/packages"
USERSFILE="/opt/seedbox/users"
GROUPFILE="/opt/seedbox/group"
INFOLOGS="/var/log/seedboxcompose.info.log"
ERRORLOGS="/var/log/seedboxcompose.error.log"

export NEWT_COLORS='
  window=,white
  border=green,blue
  textbox=black,white
'
