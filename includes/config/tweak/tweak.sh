#!/bin/bash
###############################################################################
# Title: PlexGuide | PGBlitz (  PG System Tweaker )
#
# Author(s): 	Admin9705 
# Coder : 	MrDoob - freelance Coder 
# URL: 		https://pgblitz.com
# Base :	http://github.pgblitz.com
# GNU: General Public License v3.0E
#
################################################################################
source includes/functions.sh
source includes/variables.sh

tee <<-EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⌛  Verifiying  PG System Tweaker
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

echo "Upgdating packages" 
	apt-get update -yqq 2>&1 >> /dev/null
		export DEBIAN_FRONTEND=noninteractive
echo "Upgrading packages"
	apt-get upgrade -yqq 2>&1 >> /dev/null
		export DEBIAN_FRONTEND=noninteractive
echo "Dist-Upgrading packages"   
	apt-get dist-upgrade -yqq 2>&1 >> /dev/null
		export DEBIAN_FRONTEND=noninteractive
echo "Autoremove old Updates"    
	apt-get autoremove -yqq 2>&1 >> /dev/null
		export DEBIAN_FRONTEND=noninteractive
echo "install complete"

tee <<-EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀 PG System Tweaker
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💬 PG System Tweaker

[1] Network Tweaker ( Debian 9 & Ubuntu 18 only )
[2] Docker Swapness

[Z] Exit

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

# Standby
read -p 'Type a Number | Press [ENTER]: ' typed < /dev/tty

if [ "$typed" == "1" ]; then
	echo "networktools install | please wait"
 		 apt-get install ethtool -yqq 2>&1 >> /dev/null
  			export DEBIAN_FRONTEND=noninteractive
	echo "networktools installed"
		sleep 2
	network=$(ifconfig | grep -E 'eno1|enp0s|em1' | awk '{print $1}' | sed -e 's/://g' )
		sleep 2
      echo $network "network detected"
      ethtool -K $network tso off tx off
      sed -i '$a\' /etc/crontab
      sed -i '$a\#################################' /etc/crontab
      sed -i '$a\##	PG Network tweak	##' /etc/crontab
      sed -i '$a\#################################' /etc/crontab 
      sed -i '$a\@reboot ethtool -K '$network' tso off tx off\' /etc/crontab
      sleep 2
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo " ✅ PASSED ! Network Tweak done"
        echo " ✅ PASSED ! crontab line added"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" && sleep 10
	pause    
	script_plexdrive

elif [ "$typed" == "2" ]; then
      sudo sysctl vm.swappiness=0
      sudo sysctl vm.overcommit_memory=1
      sed -i '$a\' /etc/sysctl.conf
      sed -i '$a\' /etc/sysctl.conf
      sed -i '$a\#########################################' /etc/sysctl.conf
      sed -i '$a\##	Docker PG Swapness changes	##' /etc/sysctl.conf
      sed -i '$a\#########################################' /etc/sysctl.conf
      sed -i '$a\vm.swappiness=0\' /etc/sysctl.conf
      sed -i '$a\vm.overcommit_memory=1\' /etc/sysctl.conf
      sleep 2
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo " ✅ PASSED ! Docker swappiness offline"
        echo " ✅ PASSED ! systctl edit"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" && sleep 10
	pause    
	script_plexdrive      

elif [ "$typed" == "Z" ] || [ "$typed" == "z" ]; then
  exit
  script_plexdrive
fi
