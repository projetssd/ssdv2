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
FIRSTPORT="51413"
FIRSTPORT1="5000"
FIRSTPORT2="6881"
LASTPORT="8080"
CURRENTDIR="$PWD"
BASEDIR="/opt/seedbox-compose"
CONFDIR="/opt/seedbox"
SERVICESAVAILABLE="$BASEDIR/includes/config/services-available"
WEBSERVERAVAILABLE="$BASEDIR/includes/config/webserver-available"
MEDIAVAILABLE="$BASEDIR/includes/config/media-available"
SERVICES="$BASEDIR/includes/config/services"
SERVICESUSER="/opt/seedbox/services-"
MEDIASUSER="/opt/seedbox/media-"
FILEPORTPATH="/opt/seedbox/ports.pt"
FILEPORTPATH1="/opt/seedbox/ports1.pt"
FILEPORTPATH2="/opt/seedbox/ports2.pt"
SCANPORTPATH="/opt/seedbox/scan.pt"
PLEXPORTPATH="/opt/seedbox/plex.pt"
PACKAGESFILE="$BASEDIR/includes/config/packages"
USERSFILE="$CONFDIR/variables/users"
GROUPFILE="$CONFDIR/variables/group"
MAILFILE="$CONFDIR/variables/mail"
DOMAINFILE="$CONFDIR/variables/domain"

export NEWT_COLORS='
  window=,white
  border=green,blue
  textbox=black,white
'
