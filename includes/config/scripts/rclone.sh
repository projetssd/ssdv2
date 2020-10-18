#!/bin/bash	

source includes/functions.sh
source includes/variables.sh

sed -i '/remote/d' /opt/seedbox/variables/account.yml > /dev/null 2>&1
sed -i '/crypt/d' /opt/seedbox/variables/account.yml > /dev/null 2>&1
sed -i '/id_teamdrive/d' /opt/seedbox/variables/account.yml > /dev/null 2>&1
rm drive.txt team.txt > /dev/null 2>&1

function paste() {
echo -e "${YELLOW}\nColler le contenu de rclone.conf avec le clic droit, et taper ${CCYAN}STOP${CEND}${YELLOW} pour poursuivre le script.\n${NC}"   				
while :
do		
  read -p "" EXCLUDEPATH
  if [[ "$EXCLUDEPATH" = "STOP" ]] || [[ "$EXCLUDEPATH" = "stop" ]]; then
    break
  fi
  echo "$EXCLUDEPATH" >> /root/.config/rclone/rclone.conf
done
sed -n -i '1h; 1!H; ${x; s/\n*$//; p}' /root/.config/rclone/rclone.conf > /dev/null 2>&1
echo ""
}

function detection() {
## detection drive ##
i=1
grep "team_drive" /root/.config/rclone/rclone.conf | uniq > /tmp/drive.txt
grep "team_drive" /root/.config/rclone/rclone.conf > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo -e " ${BWHITE}* Teamdrives disponibles${NC}"
  echo ""
    while read line; do
      team=$(grep -iC 6 "$line" /root/.config/rclone/rclone.conf | head -n 1 | sed "s/\[//g" | sed "s/\]//g")
      echo "$team" >> /tmp/team.txt
      echo -e "${CGREEN}   $i. $team${CEND}"
      let "i+=1"
    done < /tmp/drive.txt
  nombre=$(wc -l /tmp/team.txt | cut -d ' ' -f1)
fi

[ -s /tmp/drive.txt ]
if [ $? -eq 1 ]; then
  grep "root_folder_id = ." /root/.config/rclone/rclone.conf | uniq > /tmp/drive.txt
  grep "root_folder_id = ." /root/.config/rclone/rclone.conf > /dev/null 2>&1
  if [ $? -eq 0 ]; then
      echo -e " ${BWHITE}* Gdrives disponibles${NC}"
      echo ""
      while read line; do
        team=$(grep -iC 6 "$line" /root/.config/rclone/rclone.conf | head -n 1 | sed "s/\[//g" | sed "s/\]//g")
        echo "$team" >> /tmp/team.txt
        echo -e "${CGREEN}   $i. $team${CEND}"
        let "i+=1"
      done < /tmp/drive.txt
      nombre=$(wc -l /tmp/team.txt | cut -d ' ' -f1)
  else
    grep "token" /root/.config/rclone/rclone.conf > /tmp/drive.txt
    grep "token" /root/.config/rclone/rclone.conf > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo -e " ${BWHITE}* Gdrives disponibles${NC}"
      echo ""
      while read line; do
        team=$(grep -iC 5 "$line" /root/.config/rclone/rclone.conf | head -n 1 | sed "s/\[//g" | sed "s/\]//g")
        echo "$team" >> /tmp/team.txt
        echo -e "${CGREEN}   $i. $team${CEND}"
        let "i+=1"
      done < /tmp/drive.txt
      nombre=$(wc -l /tmp/team.txt | cut -d ' ' -f1)
    fi
  fi
fi

while :
do
echo ""
read -rp $'\e[36m   Choisir le stockage principal associé à la Seedbox: \e[0m' RTYPE
echo ""
  if [ "$RTYPE" -le "$nombre" -a "$RTYPE" -ge "1"  ]; then
    i="$RTYPE"
    remote=$(sed -n "$i"p /tmp/team.txt)
    grep "team_drive" /root/.config/rclone/rclone.conf > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      id_teamdrive=$(sed -n "$i"p /tmp/drive.txt | cut -d '=' -f2 | sed 's/ //g')
      echo -e "${CCYAN}   Source séléctionnée: ${CGREEN}$remote - id: $id_teamdrive${CEND}"
      echo ""
    else
      echo -e "${CCYAN}   Source séléctionnée: ${CGREEN}$remote${CEND}"
      echo ""
    fi
    break
  else
    echo -e " ${CRED}* /!\ erreur de saisie /!\{NC}"
    echo ""
  fi
done
}

function clone() {
## si rclone n'existe pas
rclone="/usr/bin/rclone"
conf="/root/.config/rclone/rclone.conf"
## pas de rclone.conf
if [ ! -e "$rclone" ] ; then
 curl https://rclone.org/install.sh | bash
fi
}

function verif() {
## si rclone.conf contient des remotes crypt --> exit
grep "crypt" /root/.config/rclone/rclone.conf > /dev/null 2>&1
if [ $? -eq 0 ]; then
crypt=$(grep -iC 2 "remote = /mnt/plexdrive/Medias" /root/.config/rclone/rclone.conf | head -n 1 | sed "s/\[//g" | sed "s/\]//g")
detection
sed -i "/rclone/a \ \ \ remote: $remote" /opt/seedbox/variables/account.yml
sed -i "/remote/a \ \ \ crypt: $crypt" /opt/seedbox/variables/account.yml
sed -i "/rclone/a \ \ \ id_teamdrive: $id_teamdrive" /opt/seedbox/variables/account.yml
exit
fi
}

function password () {
    if [ $? -eq 1 ]; then
      echo -e "#Debut remote crypt\n[$remote$crypt] \ntype = crypt\nremote = $remote:Medias\nfilename_encryption = standard" >> /root/.config/rclone/rclone.conf
    
      rclone config password $remote$crypt password yohann > /dev/null 2>&1
      rclone config password $remote$crypt password2 yohann > /dev/null 2>&1
      password=$(grep "password" /root/.config/rclone/rclone.conf) > /dev/null 2>&1
      password2=$(grep "password2" /root/.config/rclone/rclone.conf | head -1) > /dev/null 2>&1
      sed -i "/password2/a #Fin remote crypt" /root/.config/rclone/rclone.conf

    else
      echo -e "#Debut remote crypt\n[$remote$crypt] \ntype = crypt\nremote = $remote:Medias\nfilename_encryption = standard" >> /root/.config/rclone/rclone.conf
      password=$(grep "password" /root/.config/rclone/rclone.conf | sort -u -r) > /dev/null 2>&1
      echo -e "$password\n#Fin remote crypt\n" >> /root/.config/rclone/rclone.conf
    fi
}

## sinon creation des remotes crypt
function create() {
grep -E "root_folder_id = .|team_drive" /root/.config/rclone/rclone.conf | uniq > /tmp/drive.txt
grep -E "root_folder_id = .|team_drive" /root/.config/rclone/rclone.conf > /dev/null 2>&1
if [ $? -eq 0 ]; then
  while read line; do
    crypt="_crypt"
    plexdrive="_plexdrive"
    remote=$(grep -iC 6 "$line" /root/.config/rclone/rclone.conf | head -n 1 | sed "s/\[//g" | sed "s/\]//g")
    grep "password" /root/.config/rclone/rclone.conf > /dev/null 2>&1
    password
  done < /tmp/drive.txt
else
  grep -E "token" /root/.config/rclone/rclone.conf | uniq > /tmp/drive.txt
  grep -E "token" /root/.config/rclone/rclone.conf > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    while read line; do
      crypt="_crypt"
      plexdrive="_plexdrive"
      remote=$(grep -iC 5 "$line" /root/.config/rclone/rclone.conf | head -n 1 | sed "s/\[//g" | sed "s/\]//g")
      grep "password" /root/.config/rclone/rclone.conf > /dev/null 2>&1
      password
    done < /tmp/drive.txt
  fi
fi

## creation du remote plexdrive
echo -e "#Debut remote plexdrive\n[plexdrive] \ntype = crypt\nremote = /mnt/plexdrive/Medias\nfilename_encryption = standard" >> /root/.config/rclone/rclone.conf
password=$(grep "password" /root/.config/rclone/rclone.conf | sort -u -r) > /dev/null 2>&1
echo -e "$password\n#Fin remote plexdrive\n" >> /root/.config/rclone/rclone.conf


remote=$(sed -n "$i"p /tmp/team.txt)
sed -i "/rclone/a \ \ \ remote: $remote$crypt" /opt/seedbox/variables/account.yml
sed -i "/remote/a \ \ \ crypt: plexdrive" /opt/seedbox/variables/account.yml
sed -i "/rclone/a \ \ \ id_teamdrive: $id_teamdrive" /opt/seedbox/variables/account.yml
}

function menu() {
        clear
        logo
        echo ""
	echo -e "${CCYAN}Gestion du rclone.conf${CEND}"
	echo -e "${CGREEN}${CEND}"
	echo -e "${CGREEN}   1) Copier/coller un rclone.conf déjà existant ${CEND}"
	echo -e "${CGREEN}   2) Création rclone.conf${CEND}"
	echo -e "${CGREEN}   3) rclone.conf déjà existant sur le serveur --> /root/.config./rclone/rclone.conf${CEND}"

	echo -e ""
	read -p "Votre choix [1-3]: " CHOICE

	case $CHOICE in
		1) ## Copier/coller un rclone.conf déjà existant
                   rclone="/usr/bin/rclone"
                   if [ ! -e "$rclone" ] ; then
                   curl https://rclone.org/install.sh | bash
                   fi
                   rclone > /dev/null 2>&1
                   paste
                   verif
                   detection
                   create
                   ;;
                2) ## Création rclone.conf
                   clone
                   clear
                   /opt/seedbox-compose/includes/config/scripts/createrclone.sh
                   verif
                   clear
                   detection
                   create
                   ;;
                3) ## Création rclone.conf
                   clone
                   verif
                   clear
                   detection
                   create
                   ;;
                   esac
}
menu
cd /tmp
rm drive.txt team.txt > /dev/null 2>&1

