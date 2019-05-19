#!/bin/bash
#
# Title:      PGBlitz (Reference Title File)
# Author(s):  Admin9705 - Deiteq
# URL:        https://pgblitz.com - http://github.pgblitz.com
# GNU:        General Public License v3.0
################################################################################
clear
question1 () {
tee <<-EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🌎  Processer Policy Interface      ⚡ Reference: processor.pgblitz.com
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💬  Fonctionne uniquement sur les Dedicated Servers! (No VPS, ESXI, VMs, and etc)

1. Mode Performance
2. A la demande
3. Mode conservateur
4. Voir le réglage actuel
Z. Retour menu principal

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

read -p 'Type a Number | Press [ENTER]: ' typed < /dev/tty

case $typed in
    1 )
        ansible-playbook /opt/seedbox-compose/includes/config/processor/processor.yml  --tags performance
        rebootpro ;;
    2 )
        ansible-playbook /opt/seedbox-compose/includes/config/processor/processor.yml  --tags ondemand
        rebootpro ;;
    3 )
        ansible-playbook /opt/seedbox-compose/includes/config/processor/processor.yml  --tags conservative
        rebootpro ;;
    4 )
        echo ""
        cpufreq-info
        echo ""
        read -p '🌍  Done? | Appuyer sur la touche [ENTER] ' typed < /dev/tty
	/opt/seedbox-compose/seedbox.sh
        ;;
    z )
        /opt/seedbox-compose/seedbox.sh ;;
    Z )
        /opt/seedbox-compose/seedbox.sh ;;
    * )
        question1 ;;
esac
}

rebootpro() {
  bash /opt/seedbox-compose/includes/config/processor/scripts/reboot.sh
}

question1
