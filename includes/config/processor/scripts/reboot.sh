 #!/bin/bash
clear
if (whiptail --title "Reboot Question" --yesno "Les nouveaux réglages ne prendront effet qu'après le rebbot. Voulez vous relancer le serveur maintenant?" 0 0) then
  whiptail --title "Reboot Selected" --msgbox "Reboot du serveur" 0 0
  sudo reboot
  exit
else
  whiptail --title "Reboot non sélectionner" --msgbox "Aucun problème, juste penser à relancer le serveur plus tard" 0 0
  cd /opt/seedbox-compose
  ./seedbox.sh
fi
