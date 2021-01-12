#!/bin/bash	

# shellcheck source=${BASEDIR}/includes/functions.sh
source "${SCRIPTPATH}/includes/functions.sh"
# shellcheck source=${BASEDIR}/includes/variables.sh
source "${SCRIPTPATH}/includes/variables.sh"

mkdir -p ${HOME}/.config/rclone
RCLONE_CONFIG_FILE=${HOME}/.config/rclone/rclone.conf

sed -i '/plexdrive/d' ${CONFDIR}/variables/account.yml > /dev/null 2>&1
sed -i '/remote/d' ${CONFDIR}/variables/account.yml > /dev/null 2>&1
sed -i '/id_teamdrive/d' ${CONFDIR}/variables/account.yml > /dev/null 2>&1
cd /tmp
rm drive.txt team.txt > /dev/null 2>&1

function paste() {
echo -e "${YELLOW}\nColler le contenu de rclone.conf avec le clic droit, et taper ${CCYAN}STOP${CEND}${YELLOW} pour poursuivre le script.\n${NC}"   				
while :
do		
  read -p "" EXCLUDEPATH
  if [[ "$EXCLUDEPATH" = "STOP" ]] || [[ "$EXCLUDEPATH" = "stop" ]]; then
    break
  fi
  echo "$EXCLUDEPATH" >> ${RCLONE_CONFIG_FILE}
done
sed -n -i '1h; 1!H; ${x; s/\n*$//; p}' ${RCLONE_CONFIG_FILE} > /dev/null 2>&1
echo ""
}

function detection() {
  #clear
  echo ""
  echo -e "${CCYAN}Choisir le remote principal :${CEND}"
  echo -e "${CGREEN}${CEND}"
  echo -e "${CGREEN}   1) Share Drive ${CEND}"
  echo -e "${CGREEN}   2) Gdrive${CEND}"
  echo ""
  
  read -rp "Votre choix: " RTYPE
  
  case "$RTYPE" in
	  "1")
	  i=1
	  # on met les team drive dans un fichier temporaire
	  grep "team_drive" ${RCLONE_CONFIG_FILE} | uniq > /tmp/drive.txt
	  grep "team_drive" ${RCLONE_CONFIG_FILE} > /dev/null 2>&1
	  if [ $? -eq 0 ]; then
		  echo ""
		  #clear
		  echo -e " ${BWHITE}* Share Drive disponibles${NC}"
		  echo ""
		  while read line; do
		    # on lit le nom de la team
			  team=$(grep -iC 6 "$line" ${RCLONE_CONFIG_FILE} | head -n 1 | sed "s/\[//g" | sed "s/\]//g")
			  echo "$team" >> /tmp/team.txt
			  echo -e "${CGREEN}   $i. $team${CEND}"
			  let "i+=1"
		  done < /tmp/drive.txt
		  nombre=$(wc -l /tmp/team.txt | cut -d ' ' -f1)
	  fi
	  
	  while :
	  do
		  echo ""
		  read -rp $'\e[36m   Choisir le stockage principal associé à la Seedbox: \e[0m' RTYPE
		  echo ""
		  if [ "$RTYPE" -le "$nombre" -a "$RTYPE" -ge "1"  ]; then
		    
			  i="$RTYPE"
			  remote=$(sed -n "$i"p /tmp/team.txt)
			  grep "team_drive" ${RCLONE_CONFIG_FILE} > /dev/null 2>&1
			  if [ $? -eq 0 ]; then
				  id_teamdrive=$(sed -n "$i"p /tmp/drive.txt | cut -d '=' -f2 | sed 's/ //g')

				  remotecrypt=$(grep -C2 "$id_teamdrive" ${RCLONE_CONFIG_FILE} | tail -1 | sed "s/\[//g" | sed "s/\]//g")

				  if [ -z "$remotecrypt" ]; then

					  remotecrypt=$(grep -C3 "$id_teamdrive" ${RCLONE_CONFIG_FILE} | tail -1 | sed "s/\[//g" | sed "s/\]//g")

				  fi
				  echo -e "${CCYAN}   Source séléctionnée: ${CGREEN}$remote - id: $id_teamdrive${CEND}"
				  echo ""
				else
				  echo -e "${CCYAN}   Source séléctionnée: ${CGREEN}$remote${CEND}"

			  fi
			  break
			  else
			  echo -e " ${CRED}* /!\ erreur de saisie /!\{NC}"
			  echo ""
		  fi
	  done
	  ;;
	  
	  "2")
	  i=1
	  grep "root_folder_id = ." ${RCLONE_CONFIG_FILE} | uniq > /tmp/drive.txt
	  grep "root_folder_id = ." ${RCLONE_CONFIG_FILE} > /dev/null 2>&1
	  if [ $? -eq 0 ]; then
		  echo -e " ${BWHITE}* Gdrives disponibles${NC}"
		  echo ""
		  while read line; do
			  team=$(grep -iC 6 "$line" ${RCLONE_CONFIG_FILE} | head -n 1 | sed "s/\[//g" | sed "s/\]//g")
			  echo "$team" >> /tmp/team.txt
			  echo -e "${CGREEN}   $i. $team${CEND}"
			  let "i+=1"
		  done < /tmp/drive.txt
		  nombre=$(wc -l /tmp/team.txt | cut -d ' ' -f1)
	  else
		  grep "token" ${RCLONE_CONFIG_FILE} > /tmp/drive.txt
		  grep "token" ${RCLONE_CONFIG_FILE} > /dev/null 2>&1
		  if [ $? -eq 0 ]; then
			  echo -e " ${BWHITE}* Remotes disponibles${NC}"
			  echo ""
			  while read line; do
				  team=$(grep -iC 5 "$line" ${RCLONE_CONFIG_FILE} | head -n 1 | sed "s/\[//g" | sed "s/\]//g")
				  echo "$team" >> /tmp/team.txt
				  echo -e "${CGREEN}   $i. $team${CEND}"
				  let "i+=1"
			  done < /tmp/drive.txt
			  nombre=$(wc -l /tmp/team.txt | cut -d ' ' -f1)
		  fi
	  fi
	  
	  while :
	  do
		  echo ""
		  read -rp $'\e[36m   Choisir le stockage principal associé à la Seedbox: \e[0m' RTYPE
		  echo ""
		  echo ""
		  read -rp $'\e[36m   Choisir le stockage principal associé à la Seedbox: \e[0m' RTYPE
		  echo ""
		  if [ "$RTYPE" -le "$nombre" -a "$RTYPE" -ge "1"  ]; then
			  i="$RTYPE"
			  remote=$(sed -n "$i"p /tmp/team.txt)
			  root_folder_id=$(sed -n "$i"p /tmp/drive.txt | cut -d '=' -f2 | sed 's/ //g')
			  remotecrypt=$(grep -C2 "$root_folder_id" ${RCLONE_CONFIG_FILE} | tail -1 | sed "s/\[//g" | sed "s/\]//g")
			  echo -e "${CCYAN}   Source séléctionnée: ${CGREEN}$remote${CEND}"
			  echo ""
			  break
		  else
			  echo -e " ${CRED}* /!\ erreur de saisie /!\{NC}"
			  echo ""
		  fi
	  done
	  while :
	  do
		  echo ""
		  read -rp $'\e[36m   Choisir le stockage principal associé à la Seedbox: \e[0m' RTYPE
		  echo ""
		  if [ "$RTYPE" -le "$nombre" -a "$RTYPE" -ge "1"  ]; then
			  i="$RTYPE"
			  remote=$(sed -n "$i"p /tmp/team.txt)
			  root_folder_id=$(sed -n "$i"p /tmp/drive.txt | cut -d '=' -f2 | sed 's/ //g')
			  remotecrypt=$(grep -C2 "$root_folder_id" ${RCLONE_CONFIG_FILE} | tail -1 | sed "s/\[//g" | sed "s/\]//g")
			  echo -e "${CCYAN}   Source séléctionnée: ${CGREEN}$remote${CEND}"
			  echo ""
			  break
		  else
			  echo -e " ${CRED}* /!\ erreur de saisie /!\{NC}"
			  echo ""
		  fi
	  done
	  ;;
	  
	  *)
	  echo -e "${CRED}Action inconnue${CEND}"
	  ;;
  esac
  
}

function clone() {
## si rclone n'existe pas
rclone="/usr/bin/rclone"
conf="${RCLONE_CONFIG_FILE}"
## pas de rclone.conf
if [ ! -e "${RCLONE_CONFIG_FILE}" ] ; then
 curl https://rclone.org/install.sh | bash
fi
}

function verif() {
  detection
  
  sed -i "/rclone/a \ \ \ remote: $remotecrypt" ${CONFDIR}/variables/account.yml > /dev/null 2>&1
  sed -i "/rclone/a \ \ \ id_teamdrive: $id_teamdrive" ${CONFDIR}/variables/account.yml > /dev/null 2>&1
  exit
}

function menu() {
        clear
        logo
  	if [ ! -e "$rclone" ] ; then
    curl https://rclone.org/install.sh | sudo bash
  fi
        echo ""

	echo -e "${CCYAN}Gestion du rclone.conf${CEND}"
	echo -e "${CGREEN}${CEND}"
	echo -e "${CGREEN}   1) Copier/coller un rclone.conf déjà existant ${CEND}"
	echo -e "${CGREEN}   2) Création rclone.conf${CEND}"
	echo -e "${CGREEN}   3) rclone.conf déjà existant sur le serveur --> ${RCLONE_CONFIG_FILE}${CEND}"

	echo -e ""

	read -p "Votre choix [1-3]: " CHOICE

	case $CHOICE in
		1) ## Copier/coller un rclone.conf déjà existant
                   rclone="/usr/bin/rclone"

                   rclone > /dev/null 2>&1
                   paste
                   verif
                   ;;
                2) ## Création rclone.conf
                   clone
                   clear
                   ${BASEDIR}/includes/config/scripts/createrclone.sh
                   verif
                   ;;
                3) ## Création rclone.conf
                   clone
                   verif
                   ;;
                   esac
}
menu
cd /tmp
rm drive.txt team.txt > /dev/null 2>&1
