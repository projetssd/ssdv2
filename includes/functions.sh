#!/bin/bash
##########
function logo() {

color1='\033[1;31m'    # light red
color2='\033[1;35m'    # light purple
color3='\033[0;33m'    # light yellow
nocolor='\033[0m'      # no color
companyname='\033[1;34mMondedie.fr\033[0m'
divisionname='\033[1;32mlaster13\033[0m'
descriptif='\033[1;31mHeimdall - Syncthing - sonerezh - Portainer - Nextcloud - Lidarr\033[0m'
appli='\033[0;36mPlex - Sonarr - Medusa - Rutorrent - Radarr - Jackett - Pyload - Traefik\033[0m'



printf "               ${color1}.-.${nocolor}\n"
printf "         ${color2}.-'\`\`${color1}(   )    ${companyname}${nocolor}\n"
printf "      ${color3},\`\\ ${color2}\\    ${color1}\`-\`${color2}.    ${divisionname}${nocolor}\n"
printf "     ${color3}/   \\ ${color2}'\`\`-.   \`   ${color3}`lsb_release -s -d`${nocolor}\n"
printf "   ${color2}.-.  ${color3},       ${color2}\`___:  ${nocolor}`uname -srmo`${nocolor}\n"
printf "  ${color2}(   ) ${color3}:       ${color1} ___   ${nocolor}`date +"%A, %e %B %Y, %r"`${nocolor}\n"
printf "   ${color2}\`-\`  ${color3}\`      ${color1} ,   :${nocolor}  Seedbox docker\n"
printf "     ${color3}\\   / ${color1},..-\`   ,${nocolor}   ${descriptif} ${nocolor}\n"
printf "      ${color3}\`./${color1} /    ${color3}.-.${color1}\`${nocolor}    ${appli}\n"
printf "         ${color1}\`-..-${color3}(   )${nocolor}    Uptime: `/usr/bin/uptime -p`\n"
printf "               ${color3}\`-\`${nocolor}\n"
}

function check_domain() {
		TESTDOMAIN=$1
		echo -e " ${BWHITE}* Checking domain - ping $TESTDOMAIN...${NC}"
		ping -c 1 $TESTDOMAIN | grep "$IPADDRESS" > /dev/null
		checking_errors $?
}

function rtorrent-cleaner() {
			#configuration de rtorrent-cleaner avec ansible
			echo -e "${BLUE}### RTORRENT-CLEANER ###${NC}"
			echo -e " ${BWHITE}* Installation RTORRENT-CLEANER${NC}"

			## choix de l'utilisateur
			TMPGROUP=$(cat $GROUPFILE)
			TABUSERS=()
			for USERSEED in $(members $TMPGROUP)
			do
	        	IDSEEDUSER=$(id -u $USERSEED)
	        	TABUSERS+=( ${USERSEED//\"} ${IDSEEDUSER//\"} )
			done
			## CHOISIR USER
			SEEDUSER=$(whiptail --title "App Manager" --menu \
	                		"Merci de sélectionner l'Utilisateur" 12 50 3 \
	                		"${TABUSERS[@]}"  3>&1 1>&2 2>&3)

			cp -r $BASEDIR/includes/config/rtorrent-cleaner/rtorrent-cleaner /usr/local/bin
			sed -i "s|%SEEDUSER%|$SEEDUSER|g" /usr/local/bin/rtorrent-cleaner
			checking_errors $?
}

function motd() {
			#configuration d'un motd avec ansible
			echo -e "${BLUE}### MOTD ###${NC}"
			echo -e " ${BWHITE}* Installation MOTD${NC}"
			cd /opt/seedbox-compose/includes/config/roles/motd
			ansible-playbook motd.yml
			checking_errors $?
}

function openvpn() {
			#configuration openvpn
			echo -e "${BLUE}### OPENVPN Angristan ###${NC}"
			echo -e " ${BWHITE}* Mise en place Openvpn${NC}"
			curl -O https://raw.githubusercontent.com/Angristan/openvpn-install/master/openvpn-install.sh
			chmod +x openvpn-install.sh
			env AUTO_INSTALL=y ./openvpn-install.sh
			checking_errors $?
}

function sauve() {
			#configuration Sauvegarde
			echo -e "${BLUE}### BACKUP ###${NC}"
			echo -e " ${BWHITE}* Mise en place Sauvegarde${NC}"

			## remote crypté
			REMOTE=$(grep -iC 4 "token" /root/.config/rclone/rclone.conf | head -n 1 | sed "s/\[//g" | sed "s/\]//g")
			REMOTEPLEX=$(grep -iC 2 "/mnt/plexdrive" /root/.config/rclone/rclone.conf | head -n 1 | sed "s/\[//g" | sed "s/\]//g")
			REMOTECRYPT=$(grep -v -e $REMOTEPLEX -e $REMOTE /root/.config/rclone/rclone.conf | grep "\[" | sed "s/\[//g" | sed "s/\]//g" | head -n 1)
			
			cp -r $BASEDIR/includes/config/backup/* /usr/bin
			sed -i "s|%SEEDUSER%|$SEEDUSER|g" /usr/bin/backup
			sed -i "s|%REMOTECRYPT%|$REMOTECRYPT|g" /usr/bin/backup
			sed -i "s|%SEEDUSER%|$SEEDUSER|g" /usr/bin/restore
			sed -i "s|%REMOTECRYPT%|$REMOTECRYPT|g" /usr/bin/restore

			## cron
			(crontab -l | grep . ; echo "0 3 * * 6 /usr/bin/backup >> /home/$SEEDUSER/scripts/backup.log") | crontab -

			checking_errors $?
			echo ""
}

function plex_dupefinder() {
			#configuration plex_dupefinder avec ansible
			echo -e "${BLUE}### PLEX_DUPEFINDER ###${NC}"
			echo -e " ${BWHITE}* Installation plex_dupefinder${NC}"
			cp -r "$BASEDIR/includes/config/roles/plex_dupefinder" "/opt/seedbox/docker/$SEEDUSER/plex_dupefinder"
			sed -i "s|%SEEDUSER%|$SEEDUSER|g" /opt/seedbox/docker/$SEEDUSER/plex_dupefinder/tasks/main.yml
			sed -i "s|%USERID%|$USERID|g" /opt/seedbox/docker/$SEEDUSER/plex_dupefinder/tasks/main.yml
			sed -i "s|%GRPID%|$GRPID|g" /opt/seedbox/docker/$SEEDUSER/plex_dupefinder/tasks/main.yml
			sed -i "s|%TOKEN%|$X_PLEX_TOKEN|g" /opt/seedbox/docker/$SEEDUSER/plex_dupefinder/templates/config.json.j2
			sed -i "s|%DOMAIN%|$DOMAIN|g" /opt/seedbox/docker/$SEEDUSER/plex_dupefinder/templates/config.json.j2
			sed -i "s|%FILMS%|$FILMS|g" /opt/seedbox/docker/$SEEDUSER/plex_dupefinder/templates/config.json.j2
			sed -i "s|%SERIES%|$SERIES|g" /opt/seedbox/docker/$SEEDUSER/plex_dupefinder/templates/config.json.j2

			cd /opt/seedbox/docker/$SEEDUSER/plex_dupefinder/tasks
			ansible-playbook main.yml
			rm -rf /opt/seedbox/docker/$SEEDUSER/plex_dupefinder
			checking_errors $?
}

function traktarr() {
			##configuration traktarr avec ansible
			echo -e "${BLUE}### TRAKTARR ###${NC}"
			echo -e " ${BWHITE}* Installation traktarr${NC}"
			TMPGROUP=$(cat $GROUPFILE)
			TABUSERS=()
			for USERSEED in $(members $TMPGROUP)
			do
	        	IDSEEDUSER=$(id -u $USERSEED)
	        	TABUSERS+=( ${USERSEED//\"} ${IDSEEDUSER//\"} )
			done
			## CHOISIR USER
			SEEDUSER=$(whiptail --title "App Manager" --menu \
	                		"Merci de sélectionner l'Utilisateur" 12 50 3 \
	                		"${TABUSERS[@]}"  3>&1 1>&2 2>&3)
			USERID=$(id -u $SEEDUSER)
			GRPID=$(id -g $SEEDUSER)

			## récupération nom de domaine
			ACCESSDOMAIN=$(whiptail --title "Votre nom de Domaine" --inputbox \
			"Merci de taper votre nom de Domaine (exemple: nomdedomaine.fr) :" 7 50 3>&1 1>&2 2>&3)

			cp -r "$BASEDIR/includes/config/roles/traktarr" "/opt/seedbox/docker/$SEEDUSER/traktarr"
			sed -i "s|%SEEDUSER%|$SEEDUSER|g" /opt/seedbox/docker/$SEEDUSER/traktarr/tasks/main.yml
			sed -i "s|%USERID%|$USERID|g" /opt/seedbox/docker/$SEEDUSER/traktarr/tasks/main.yml
			sed -i "s|%GRPID%|$GRPID|g" /opt/seedbox/docker/$SEEDUSER/traktarr/tasks/main.yml

			sed -i "s|%SEEDUSER%|$SEEDUSER|g" /opt/seedbox/docker/$SEEDUSER/traktarr/templates/config.json.j2
			sed -i "s|%USERID%|$USERID|g" /opt/seedbox/docker/$SEEDUSER/traktarr/templates/config.json.j2
			sed -i "s|%GRPID%|$GRPID|g" /opt/seedbox/docker/$SEEDUSER/traktarr/templates/config.json.j2
			sed -i "s|%DOMAIN%|$DOMAIN|g" /opt/seedbox/docker/$SEEDUSER/traktarr/templates/config.json.j2
			sed -i "s|%SEEDUSER%|$SEEDUSER|g" /opt/seedbox/docker/$SEEDUSER/traktarr/templates/config.json.j2

			sed -i "s|%SEEDUSER%|$SEEDUSER|g" /opt/seedbox/docker/$SEEDUSER/traktarr/templates/traktarr.service.j2
			sed -i "s|%USERID%|$USERID|g" /opt/seedbox/docker/$SEEDUSER/traktarr/templates/traktarr.service.j2
			sed -i "s|%GRPID%|$GRPID|g" /opt/seedbox/docker/$SEEDUSER/traktarr/templates/traktarr.service.j2

			cd /opt/seedbox/docker/$SEEDUSER/traktarr/tasks
			ansible-playbook main.yml
			rm -rf /opt/seedbox/docker/$SEEDUSER/traktarr
			service traktarr restart
			checking_errors $?
}

function webtools() {
			##configuration Webtools avec ansible
			echo -e "${BLUE}### WEBTOOLS ###${NC}"
			echo -e " ${BWHITE}* Installation Webtoots${NC}"
			TMPGROUP=$(cat $GROUPFILE)
			TABUSERS=()
			for USERSEED in $(members $TMPGROUP)
			do
	        	IDSEEDUSER=$(id -u $USERSEED)
	        	TABUSERS+=( ${USERSEED//\"} ${IDSEEDUSER//\"} )
			done
			## CHOISIR USER
			SEEDUSER=$(whiptail --title "App Manager" --menu \
	                		"Merci de sélectionner l'Utilisateur" 12 50 3 \
	                		"${TABUSERS[@]}"  3>&1 1>&2 2>&3)
			USERID=$(id -u $SEEDUSER)
			GRPID=$(id -g $SEEDUSER)

			cp -r "$BASEDIR/includes/config/roles/webtools" "/opt/seedbox/docker/$SEEDUSER/webtools"
			sed -i "s|%SEEDUSER%|$SEEDUSER|g" /opt/seedbox/docker/$SEEDUSER/webtools/tasks/main.yml
			sed -i "s|%USERID%|$USERID|g" /opt/seedbox/docker/$SEEDUSER/webtools/tasks/main.yml
			sed -i "s|%GRPID%|$GRPID|g" /opt/seedbox/docker/$SEEDUSER/webtools/tasks/main.yml

			cd /opt/seedbox/docker/$SEEDUSER/webtools/tasks
			ansible-playbook main.yml
			docker restart plex-$SEEDUSER
			rm -rf /opt/seedbox/docker/$SEEDUSER/webtools
			checking_errors $?
}

function processor() {
			/opt/seedbox-compose/includes/config/processor/processor.sh
}


function plex_autoscan() {
			#configuration plex_autoscan avec ansible
			echo -e "${BLUE}### PLEX_AUTOSCAN ###${NC}"
			echo -e " ${BWHITE}* Installation plex_autoscan${NC}"
			echo ""
			echo -e " ${GREEN}ATTENTION IMPORTANT - NE PAS FAIRE D'ERREUR - SINON DESINSTALLER ET REINSTALLER${NC}"
			. /opt/seedbox-compose/includes/config/roles/plex_autoscan/plex_token.sh
			cp -r "$BASEDIR/includes/config/roles/plex_autoscan" "/opt/seedbox/docker/$SEEDUSER/plex_autoscan"
			sed -i "s|%SEEDUSER%|$SEEDUSER|g" /opt/seedbox/docker/$SEEDUSER/plex_autoscan/tasks/main.yml
			sed -i "s|%USERID%|$USERID|g" /opt/seedbox/docker/$SEEDUSER/plex_autoscan/tasks/main.yml
			sed -i "s|%GRPID%|$GRPID|g" /opt/seedbox/docker/$SEEDUSER/plex_autoscan/tasks/main.yml

			sed -i "s|%SEEDUSER%|$SEEDUSER|g" /opt/seedbox/docker/$SEEDUSER/plex_autoscan/templates/config.json.j2
			sed -i "s|%DOMAIN%|$DOMAIN|g" /opt/seedbox/docker/$SEEDUSER/plex_autoscan/templates/config.json.j2
			sed -i "s|%TOKEN%|$X_PLEX_TOKEN|g" /opt/seedbox/docker/$SEEDUSER/plex_autoscan/templates/config.json.j2

			sed -i "s|%USERID%|$USERID|g" /opt/seedbox/docker/$SEEDUSER/plex_autoscan/templates/plex_autoscan.service.j2
			sed -i "s|%GRPID%|$GRPID|g" /opt/seedbox/docker/$SEEDUSER/plex_autoscan/templates/plex_autoscan.service.j2
			sed -i "s|%SEEDUSER%|$SEEDUSER|g" /opt/seedbox/docker/$SEEDUSER/plex_autoscan/templates/plex_autoscan.service.j2

			cd /opt/seedbox/docker/$SEEDUSER/plex_autoscan/tasks
			ansible-playbook main.yml
			/home/$SEEDUSER/scripts/plex_autoscan/scan.py sections > /dev/null 2>&1
			/home/$SEEDUSER/scripts/plex_autoscan/scan.py sections > /home/$SEEDUSER/scripts/plex_autoscan/plex.log
			sleep 5
			for i in `seq 1 50`;
			do
   				var=$(grep "$i: " /home/$SEEDUSER/scripts/plex_autoscan/plex.log | cut -d: -f2 | cut -d ' ' -f2-3)
   				if [ -n "$var" ]
   				then
     				echo "$i" "$var"
   				fi 
			done > /home/$SEEDUSER/scripts/plex_autoscan/categories.log
			cd /home/$SEEDUSER/scripts/plex_autoscan
			ID_FILMS=$(grep -E 'Films' categories.log | cut -d: -f1 | cut -d ' ' -f1)
			ID_SERIES=$(grep -E 'Series' categories.log | cut -d: -f1 | cut -d ' ' -f1)
			ID_ANIMES=$(grep -E 'Animes' categories.log | cut -d: -f1 | cut -d ' ' -f1)
			ID_MUSIC=$(grep -E 'Musiques' categories.log | cut -d: -f1 | cut -d ' ' -f1)

			if [[ -f "$SCANPORTPATH" ]]; then
				declare -i PORT=$(cat $SCANPORTPATH | tail -1)
			else
				declare -i PORT=3470
			fi
			
			## le port ne fonctionne pas a verifier
			PLEXCANFILE="/home/$SEEDUSER/scripts/plex_autoscan/config/config.json"
			sed -i "s|%PORT%|$PORT|g" $PLEXCANFILE
			sed -i "s|%FILMS%|$FILMS|g" $PLEXCANFILE
			sed -i "s|%SERIES%|$SERIES|g" $PLEXCANFILE
			sed -i "s|%MUSIC%|$MUSIC|g" $PLEXCANFILE
			sed -i "s|%ANIMES%|$ANIMES|g" $PLEXCANFILE
			sed -i "s|%ID_FILMS%|$ID_FILMS|g" $PLEXCANFILE
			sed -i "s|%ID_SERIES%|$ID_SERIES|g" $PLEXCANFILE
			sed -i "s|%ID_ANIMES%|$ID_ANIMES|g" $PLEXCANFILE
			sed -i "s|%ID_MUSIC%|$ID_MUSIC|g" $PLEXCANFILE
			rm -rf /opt/seedbox/docker/$SEEDUSER/plex_autoscan
			checking_errors $?
}

function cloudplow() {
			#configuration plex_autoscan avec ansible
			echo -e "${BLUE}### CLOUDPLOW ###${NC}"
			echo -e " ${BWHITE}* Installation cloudplow${NC}"

			## Récupération des variables
			SEEDGROUP=$(cat $GROUPFILE)
			REMOTE=$(grep -iC 4 "token" /root/.config/rclone/rclone.conf | head -n 1 | sed "s/\[//g" | sed "s/\]//g")
			REMOTEPLEX=$(grep -iC 2 "/mnt/plexdrive" /root/.config/rclone/rclone.conf | head -n 1 | sed "s/\[//g" | sed "s/\]//g")
			REMOTECRYPT=$(grep -v -e $REMOTEPLEX -e $REMOTE /root/.config/rclone/rclone.conf | grep "\[" | sed "s/\[//g" | sed "s/\]//g" | head -n 1)
			echo ""
			cp -r "$BASEDIR/includes/config/roles/cloudplow" "/opt/seedbox/docker/$SEEDUSER/cloudplow"
			sed -i "s|%SEEDUSER%|$SEEDUSER|g" /opt/seedbox/docker/$SEEDUSER/cloudplow/tasks/main.yml
			sed -i "s|%USERID%|$USERID|g" /opt/seedbox/docker/$SEEDUSER/cloudplow/tasks/main.yml
			sed -i "s|%GRPID%|$GRPID|g" /opt/seedbox/docker/$SEEDUSER/cloudplow/tasks/main.yml

			sed -i "s|%USERID%|$USERID|g" /opt/seedbox/docker/$SEEDUSER/cloudplow/templates/config.json.j2
			sed -i "s|%GRPID%|$GRPID|g" /opt/seedbox/docker/$SEEDUSER/cloudplow/templates/config.json.j2
			sed -i "s|%SEEDUSER%|$SEEDUSER|g" /opt/seedbox/docker/$SEEDUSER/cloudplow/templates/config.json.j2
			sed -i "s|%REMOTECRYPT%|$REMOTECRYPT|g" /opt/seedbox/docker/$SEEDUSER/cloudplow/templates/config.json.j2
			sed -i "s|%DOMAIN%|$DOMAIN|g" /opt/seedbox/docker/$SEEDUSER/cloudplow/templates/config.json.j2
			sed -i "s|%TOKEN%|$X_PLEX_TOKEN|g" /opt/seedbox/docker/$SEEDUSER/cloudplow/templates/config.json.j2

			sed -i "s|%USERID%|$USERID|g" /opt/seedbox/docker/$SEEDUSER/cloudplow/templates/cloudplow.service.j2
			sed -i "s|%GRPID%|$GRPID|g" /opt/seedbox/docker/$SEEDUSER/cloudplow/templates/cloudplow.service.j2
			sed -i "s|%SEEDUSER%|$SEEDUSER|g" /opt/seedbox/docker/$SEEDUSER/cloudplow/templates/cloudplow.service.j2
			
			cd /opt/seedbox/docker/$SEEDUSER/cloudplow/tasks
			ansible-playbook main.yml
			rm -rf /opt/seedbox/docker/$SEEDUSER/cloudplow
}

function filebot() {
			#configuration filebot avec ansible
			echo ""
			echo -e "${BLUE}### FILEBOT ###${NC}"
			echo -e " ${BWHITE}* Installation filebot${NC}"
			cp -r "$BASEDIR/includes/config/filebot" "/tmp"
			sed -i "s|%USER%|$SEEDUSER|g" /tmp/filebot/tasks/filebot.yml
			sed -i "s|%UID%|$USERID|g" /tmp/filebot/tasks/filebot.yml
			sed -i "s|%GID%|$GRPID|g" /tmp/filebot/tasks/filebot.yml
			cd /tmp/filebot/tasks
			ansible-playbook filebot.yml

			chmod a+x /opt/seedbox/docker/$SEEDUSER/.filebot/filebot.sh > /dev/null 2>&1
			chmod a+x /opt/seedbox/docker/$SEEDUSER/.filebot/update-filebot.sh > /dev/null 2>&1

			#configuration filebot
			cp "$BASEDIR/includes/config/filebot/filebot-process.sh" "/opt/seedbox/docker/$SEEDUSER/.filebot/filebot-process.sh" > /dev/null 2>&1
			sed -i "s|%SEEDUSER%|$SEEDUSER|g" /opt/seedbox/docker/$SEEDUSER/.filebot/filebot-process.sh
			chown $USERID:$GRPID /opt/seedbox/docker/$SEEDUSER/.filebot/filebot-process.sh

			## mise en place d'un cron pour le lancement de filebot
			(crontab -l | grep . ; echo "*/1 * * * * /opt/seedbox/docker/$SEEDUSER/.filebot/filebot-process.sh >> /home/$SEEDUSER/scripts/filebot.log") | crontab -
			service cron restart
			checking_errors $?
			rm -rf /tmp/filebot
			echo ""

}

function rclone_aide() {
echo ""
echo -e "${CCYAN}### MODELE RCLONE.CONF ###${NC}"
echo ""
echo -e "${YELLOW}[remote non chiffré]${NC}"
echo -e "${BWHITE}type = drive${NC}"
echo -e "${BWHITE}client_id = XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX${NC}"
echo -e "${BWHITE}client_secret = XXXXXXXXXXXXXXXXXXXXXXXXXXXXX${NC}"
echo -e "${BWHITE}token = {"access_token":"xxxxxxxxxxxxxxxxxx"}${NC}"
echo ""
echo -e "${YELLOW}[remote_chiffré_plexdrive]${NC}"
echo -e "${BWHITE}type = crypt${NC}"
echo -e "${BWHITE}remote = ${NC}${YELLOW}/mnt/plexdrive/Medias${NC}"
echo -e "${BWHITE}filename_encryption = standard${NC}"
echo -e "${BWHITE}password = -xxxxxxxxxxxxxxxxxx${NC}"
echo -e "${BWHITE}password2 = xxxxxxxxxxxxxxxxxx${NC}"
echo ""
echo -e "${YELLOW}[remote_chiffré_rclone]${NC}"
echo -e "${BWHITE}type = crypt${NC}"
echo -e "${BWHITE}remote = ${NC}${YELLOW}<remote non chiffré>:Medias${NC}"
echo -e "${BWHITE}filename_encryption = standard${NC}"
echo -e "${BWHITE}password = xxxxxxxxxxxxxxxxxx${NC}"
echo -e "${BWHITE}password2 = xxxxxxxxxxxxxxxxxx${NC}"
echo ""
}

function check_dir() {
	if [[ $1 != $BASEDIR ]]; then
		cd $BASEDIR
	fi
}

function script_classique() {
	if [[ -d "$CONFDIR" ]]; then
	clear
	logo
	echo ""
	echo -e "${CCYAN}SEEDBOX CLASSIQUE${CEND}"
	echo -e "${CGREEN}${CEND}"
	echo -e "${CGREEN}   1) Desinstaller la seedbox ${CEND}"
	echo -e "${CGREEN}   2) Ajout/Supression d'utilisateurs${CEND}"
	echo -e "${CGREEN}   3) Ajout/Supression d'Applis${CEND}"

	echo -e ""
	read -p "Votre choix [1-3]: " -e -i 1 PORT_CHOICE

	case $PORT_CHOICE in
		1) ## Installation de la seedbox
		clear
		echo ""
		echo -e "${YELLOW}### Seedbox-Compose déjà installée !###${NC}"
		if (whiptail --title "Seedbox-Compose déjà installée" --yesno "Désinstaller complètement la Seedbox ?" 7 50) then
			uninstall_seedbox
		else
			script_classique
		fi
		;;
		2)
		clear
		logo
		## Ajout d'Utilisateurs
		## Defines parameters for dockers : password, domains and replace it in docker-compose file
		clear
			manage_users
 		;;
		3)
		clear
		logo
		## Ajout d'Applications
		echo""
		clear
			manage_apps
		;;
	esac
	fi
}

function script_plexdrive() {
	if [[ -d "$CONFDIR" ]]; then
	clear
	logo
	echo ""
	echo -e "${CCYAN}SEEDBOX RCLONE/PLEXDRIVE${CEND}"
	echo -e "${CGREEN}${CEND}"
	echo -e "${CGREEN}   1) Désinstaller la seedbox ${CEND}"
	echo -e "${CGREEN}   2) Ajout/Supression d'utilisateurs${CEND}"
	echo -e "${CGREEN}   3) Ajout/Supression d'Applis${CEND}"
	echo -e "${CGREEN}   4) Outils${CEND}"

	echo -e ""
	read -p "Votre choix [1-4]: " PORT_CHOICE

	case $PORT_CHOICE in
		1) ## Installation de la seedbox
		clear
		echo ""
		echo -e "${YELLOW}### Seedbox-Compose déjà installée !###${NC}"
		if (whiptail --title "Seedbox-Compose déjà installée" --yesno "Désinstaller complètement la Seedbox ?" 7 50) then
			uninstall_seedbox
		else
			script_plexdrive
		fi
		;;
		2)
		clear
		logo
		## Ajout d'Utilisateurs
		## Defines parameters for dockers : password, domains and replace it in docker-compose file
		clear
			manage_users
 		;;
		3)
		clear
		logo
		## Ajout d'Applications
		echo""
		clear
			manage_apps
		;;
		4)
			clear
			logo
			echo ""
			echo -e "${CCYAN}OUTILS${CEND}"
			echo -e "${CGREEN}${CEND}"
			echo -e "${CGREEN}   1) Installation de la sauvegarde${CEND}"
			echo -e "${CGREEN}   2) Installation du motd${CEND}"
			echo -e "${CGREEN}   3) Traktarr${CEND}"
			echo -e "${CGREEN}   4) Webtools${CEND}"
			echo -e "${CGREEN}   5) rtorrent-cleaner de ${CCYAN}@Magicalex-Mondedie.fr${CEND}${NC}"
			echo -e "${CGREEN}   6) Openvpn${CEND}"
			echo -e "${CGREEN}   7) Réglage du processeur${CEND}"
			echo -e "${CGREEN}   8) Mise à jour - Nouvelle version du script${CEND}"
			echo -e "${CGREEN}   9) Retour menu principal${CEND}"
			echo -e ""
			read -p "Votre choix [1-8]: " OUTILS

			case $OUTILS in

			1) ## Installation de la sauvegarde
			clear
			echo ""
			TMPGROUP=$(cat $GROUPFILE)
			TABUSERS=()
			for USERSEED in $(members $TMPGROUP)
			do
	        	IDSEEDUSER=$(id -u $USERSEED)
	        	TABUSERS+=( ${USERSEED//\"} ${IDSEEDUSER//\"} )
			done
			## CHOISIR USER
			SEEDUSER=$(whiptail --title "App Manager" --menu \
	                		"Merci de sélectionner l'Utilisateur" 12 50 3 \
	                		"${TABUSERS[@]}"  3>&1 1>&2 2>&3)
			sauve
			pause
			script_plexdrive
			;;

			2) ## Installation du motd
			clear
			echo ""
			motd
			pause
			script_plexdrive
			;;

			3) ## Installation de traktarr
			clear
			echo ""
			traktarr
			pause
			script_plexdrive
			;;

			4) ## Installation de Webtools
			clear
			echo ""
			webtools
			pause
			script_plexdrive
			;;

			5) ## Installation de rtorrent-cleaner
			clear
			echo ""
			rtorrent-cleaner
			docker run -it --rm -v /home/$SEEDUSER/local/rutorrent:/home/$SEEDUSER/local/rutorrent -v /run/php:/run/php magicalex/docker-rtorrent-cleaner
			pause
			script_plexdrive
			;;

			6)
			openvpn
			pause
			script_plexdrive
			;;

			7)
			processor
			;;

			8)
			cp -r $BASEDIR/includes/config/update/* /usr/local/bin
			update
			;;

			9)
			script_plexdrive
			;;

			esac
		;;
	esac
	fi
}

function conf_dir() {
	if [[ ! -d "$CONFDIR" ]]; then
		mkdir $CONFDIR > /dev/null 2>&1
	fi
}

function install_base_packages() {
	echo ""
	echo -e "${BLUE}### INSTALLATION DES PACKAGES ###${NC}"
	echo ""
	echo -e " ${BWHITE}* Installation apache2-utils, unzip, git, curl ...${NC}"
	ansible-playbook /opt/seedbox-compose/includes/config/dependency.yml
	checking_errors $?
	echo ""
}

function checking_system() {
	echo -e "${BLUE}### VERIFICATION SYSTEME ###${NC}"
	echo -e " ${BWHITE}* Vérification du système OS${NC}"

	dpkg -s gawk &> /dev/null
	if [ $? -ne 0 ]; then
    		apt install gawk -y > /dev/null 2>&1
	fi
	
	TMPSYSTEM=$(gawk -F= '/^NAME/{print $2}' /etc/os-release)
	TMPCODENAME=$(lsb_release -sc)
	TMPRELEASE=$(cat /etc/debian_version)
	if [[ $(echo $TMPSYSTEM | sed 's/\"//g') == "Debian GNU/Linux" ]]; then
		SYSTEMOS="Debian"
		if [[ $(echo $TMPRELEASE | grep "8") != "" ]]; then
			SYSTEMRELEASE=$TMPRELEASE
			SYSTEMCODENAME="jessie"
		elif [[ $(echo $TMPRELEASE | grep "9") != "" ]]; then
			SYSTEMRELEASE=$TMPRELEASE
			SYSTEMCODENAME="stretch"
		fi
	elif [[ $(echo $TMPSYSTEM | sed 's/\"//g') == "Ubuntu" ]]; then
		SYSTEMOS="Ubuntu"
		if [[ $(echo $TMPCODENAME | grep "xenial") != "" ]]; then
			SYSTEMRELEASE="16.04"
			SYSTEMCODENAME="xenial"
		elif [[ $(echo $TMPCODENAME | grep "yakkety") != "" ]]; then
			SYSTEMRELEASE="16.10"
			SYSTEMCODENAME="yakkety"
		elif [[ $(echo $TMPCODENAME | grep "zesty") != "" ]]; then
			SYSTEMRELEASE="17.14"
			SYSTEMCODENAME="zesty"
		elif [[ $(echo $TMPCODENAME | grep "bionic") != "" ]]; then
			SYSTEMRELEASE="18.04"
			SYSTEMCODENAME="bionic"
		elif [[ $(echo $TMPCODENAME | grep "cosmic") != "" ]]; then
			SYSTEMRELEASE="18.10"
			SYSTEMCODENAME="cosmic"
		fi
	fi
	echo -e "	${YELLOW}--> System OS : $SYSTEMOS${NC}"
	echo -e "	${YELLOW}--> Release : $SYSTEMRELEASE${NC}"
	echo -e "	${YELLOW}--> Codename : $SYSTEMCODENAME${NC}"
	echo ""

	## installation ansible
	echo -e "${BLUE}### ANSIBLE ###${NC}"
	echo -e " ${BWHITE}* Installation de Ansible ${NC}"
	apt-get install software-properties-common -y > /dev/null 2>&1
	apt-add-repository --yes --update ppa:ansible/ansible > /dev/null 2>&1
	apt-get install ansible -y > /dev/null 2>&1

	# Configuration ansible
 	mkdir -p /etc/ansible/inventories/ 1>/dev/null 2>&1
  	echo "[local]" > /etc/ansible/inventories/local
  	echo "127.0.0.1 ansible_connection=local" >> /etc/ansible/inventories/local

  	### Reference: https://docs.ansible.com/ansible/2.4/intro_configuration.html
  	echo "[defaults]" > /etc/ansible/ansible.cfg
  	echo "command_warnings = False" >> /etc/ansible/ansible.cfg
  	echo "callback_whitelist = profile_tasks" >> /etc/ansible/ansible.cfg
	echo "deprecation_warnings=False" >> /etc/ansible/ansible.cfg
  	echo "inventory = /etc/ansible/inventories/local" >> /etc/ansible/ansible.cfg
	checking_errors $?
}

function checking_errors() {
	if [[ "$1" == "0" ]]; then
		echo -e "	${GREEN}--> Operation success !${NC}"
	else
		echo -e "	${RED}--> Operation failed !${NC}"
	fi
}

function install_fail2ban() {
	echo -e "${BLUE}### FAIL2BAN ###${NC}"
	SSH=$(echo ${SSH_CLIENT##* })
	IP_DOM=$(grep 'Accepted' /var/log/auth.log | cut -d ' ' -f11 | head -1)
	cp "$BASEDIR/includes/config/fail2ban/custom.conf" "/etc/fail2ban/jail.d/custom.conf" > /dev/null 2>&1
	cp "$BASEDIR/includes/config/fail2ban/traefik.conf" "/etc/fail2ban/jail.d/traefik.conf" > /dev/null 2>&1
	cp "$BASEDIR/includes/config/fail2ban/traefik-auth.conf" "/etc/fail2ban/filter.d/traefik-auth.conf" > /dev/null 2>&1
	cp "$BASEDIR/includes/config/fail2ban/traefik-botsearch.conf" "/etc/fail2ban/filter.d/traefik-botsearch.conf" > /dev/null 2>&1
	cp "$BASEDIR/includes/config/fail2ban/docker-action.conf" "/etc/fail2ban/action.d/docker-action.conf" > /dev/null 2>&1
	sed -i "s|%SSH%|$SSH|g" /etc/fail2ban/jail.d/custom.conf
	sed -i "s|%IP_DOM%|$IP_DOM|g" /etc/fail2ban/jail.d/custom.conf
	sed -i "s|%IP_DOM%|$IP_DOM|g" /etc/fail2ban/jail.d/traefik.conf
	docker restart traefik > /dev/null 2>&1
	systemctl restart fail2ban.service > /dev/null 2>&1
	checking_errors $?
	echo ""
}	

function install_traefik() {
	echo -e "${BLUE}### TRAEFIK ###${NC}"

	TRAEFIK="$CONFDIR/docker/traefik"
	INSTALLEDFILE="$CONFDIR/resume"

	if [[ ! -f "$INSTALLEDFILE" ]]; then
	touch $INSTALLEDFILE> /dev/null 2>&1
	fi

	if docker ps | grep -q traefik; then
		echo -e " ${YELLOW}* Traefik est déjà installé !${NC}"
	else
		echo -e " ${BWHITE}* Installation Traefik${NC}"
		mkdir -p $TRAEFIK
		cp "$BASEDIR/includes/dockerapps/traefik.toml" "$CONFDIR/docker/traefik/"
		cp "$BASEDIR/includes/dockerapps/traefik.yml" "/tmp/"
		cp "$BASEDIR/includes/dockerapps/acme.json" "/tmp/"
		sed -i "s|%EMAIL%|$CONTACTEMAIL|g" $CONFDIR/docker/traefik/traefik.toml
		sed -i "s|%DOMAIN%|$DOMAIN|g" $CONFDIR/docker/traefik/traefik.toml
		sed -i "s|%DOMAIN%|$DOMAIN|g" /tmp/traefik.yml
		cd /tmp
		docker network create traefik_proxy > /dev/null 2>&1
		ansible-playbook traefik.yml
		rm traefik.yml acme.json
		echo "traefik-port-traefik.$DOMAIN" >> $INSTALLEDFILE
		checking_errors $?		
	fi
	echo ""
}

function install_portainer() {
	echo -e "${BLUE}### PORTAINER ###${NC}"
	INSTALLEDFILE="$CONFDIR/resume"
	if [[ ! -f "$INSTALLEDFILE" ]]; then
	touch $INSTALLEDFILE> /dev/null 2>&1
	fi

	if docker ps | grep -q portainer; then
		echo -e " ${BWHITE}--> portainer est déjà installé !${NC}"
		else
		if (whiptail --title "Docker Portainer" --yesno "Voulez vous installer portainer" 7 50) then
			echo -e " ${BWHITE}* Installation Portainer${NC}"
			mkdir -p $TRAEFIK
			cp "$BASEDIR/includes/dockerapps/portainer.yml" "/tmp/"
			sed -i "s|%DOMAIN%|$DOMAIN|g" /tmp/portainer.yml
			cd /tmp
			ansible-playbook portainer.yml
			rm portainer.yml
			echo "portainer-port-portainer.$DOMAIN" >> $INSTALLEDFILE
			checking_errors $?
		else
			echo -e " ${BWHITE}--> portainer n'est pas installé !${NC}"
		fi
	fi
	echo ""
}

function install_watchtower() {
	echo -e "${BLUE}### WATCHTOWER ###${NC}"
	echo -e " ${BWHITE}* Installation Watchtower${NC}"
	cd /opt/seedbox-compose/includes/dockerapps
	ansible-playbook watchtower.yml
	checking_errors $?
	echo ""
}

function install_plexdrive() {
	echo -e "${BLUE}### PLEXDRIVE ###${NC}"
	mkdir -p /mnt/plexdrive > /dev/null 2>&1
	PLEXDRIVE="/usr/bin/plexdrive"

	if [[ ! -e "$PLEXDRIVE" ]]; then
		echo -e " ${BWHITE}* Installation plexdrive${NC}"
		cd /tmp
		wget $(curl -s https://api.github.com/repos/dweidenfeld/plexdrive/releases/latest | grep 'browser_' | cut -d\" -f4 | grep plexdrive-linux-amd64) -q -O plexdrive > /dev/null 2>&1
		chmod -c +x /tmp/plexdrive > /dev/null 2>&1
		#install plexdrive
		mv -v /tmp/plexdrive /usr/bin/ > /dev/null 2>&1
		chown -c root:root /usr/bin/plexdrive > /dev/null 2>&1
		echo ""
		echo -e " ${YELLOW}* Dès que le message ${NC}${CPURPLE}"First cache build process finished!"${NC}${YELLOW} apparait à l'écran, taper ${NC}${CPURPLE}CTRL + C${NC}${YELLOW} pour poursuivre le script !${NC}"
		echo ""
		/usr/bin/plexdrive mount -v 3 /mnt/plexdrive
		cp "$BASEDIR/includes/config/systemd/plexdrive.service" "/etc/systemd/system/plexdrive.service" > /dev/null 2>&1
		systemctl daemon-reload > /dev/null 2>&1
		systemctl enable plexdrive.service > /dev/null 2>&1
		systemctl start plexdrive.service > /dev/null 2>&1
		echo ""
		echo -e " ${GREEN}* Configuration Plexdrive terminée avec succés !${NC}"
	else
		echo -e " ${YELLOW}* Plexdrive est déjà installé !${NC}"
	fi
	echo ""
}

function install_rclone() {
	echo -e "${BLUE}### RCLONE ###${NC}"
	mkdir /mnt/rclone > /dev/null 2>&1
	RCLONECONF="/root/.config/rclone/rclone.conf"
	USERID=$(id -u $SEEDUSER)
	GRPID=$(id -g $SEEDUSER)

	if [[ ! -f "$RCLONECONF" ]]; then
		echo -e " ${BWHITE}* Installation rclone${NC}"
		clear
		rclone_aide
		pause
		curl https://rclone.org/install.sh | bash > /dev/null 2>&1
		mkdir -p /root/.config/rclone
		echo ""
    		echo -e "${YELLOW}\nColler le contenu de rclone.conf avec le clic droit, appuyer ensuite sur la touche Entrée et Taper ${CPURPLE}STOP${CEND}${YELLOW} pour poursuivre le script.\n${NC}"   				
		while :
    		do		
        	read -p "" EXCLUDEPATH
        		if [[ "$EXCLUDEPATH" = "STOP" ]] || [[ "$EXCLUDEPATH" = "stop" ]]; then
            				break
        		fi
        	echo "$EXCLUDEPATH" >> /root/.config/rclone/rclone.conf
    		done
		echo ""
		REMOTE=$(grep -iC 4 "token" /root/.config/rclone/rclone.conf | head -n 1 | sed "s/\[//g" | sed "s/\]//g")
		REMOTEPLEX=$(grep -iC 2 "/mnt/plexdrive" /root/.config/rclone/rclone.conf | head -n 1 | sed "s/\[//g" | sed "s/\]//g")
		REMOTECRYPT=$(grep -v -e $REMOTEPLEX -e $REMOTE /root/.config/rclone/rclone.conf | grep "\[" | sed "s/\[//g" | sed "s/\]//g" | head -n 1)
		clear
		echo -e " ${BWHITE}* Remote chiffré rclone${NC} --> ${YELLOW}$REMOTECRYPT:${NC}"
		checking_errors $?
		echo ""
		echo -e " ${BWHITE}* Remote chiffré plexdrive${NC} --> ${YELLOW}$REMOTEPLEX:${NC}"
		checking_errors $?
		echo ""

		mkdir -p /mnt/rclone/$SEEDUSER

		cp "$BASEDIR/includes/config/systemd/rclone.service" "/etc/systemd/system/rclone-$SEEDUSER.service" > /dev/null 2>&1
		sed -i "s|%REMOTEPLEX%|$REMOTEPLEX:|g" /etc/systemd/system/rclone-$SEEDUSER.service
		sed -i "s|%SEEDUSER%|$SEEDUSER|g" /etc/systemd/system/rclone-$SEEDUSER.service
		sed -i "s|%USERID%|$USERID|g" /etc/systemd/system/rclone-$SEEDUSER.service
		sed -i "s|%GRPID%|$GRPID|g" /etc/systemd/system/rclone-$SEEDUSER.service

		systemctl daemon-reload > /dev/null 2>&1
		systemctl enable rclone-$SEEDUSER.service > /dev/null 2>&1
		service rclone-$SEEDUSER start
		var="Montage rclone en cours, merci de patienter..."
		decompte 15
		checking_errors $?
	else
		echo -e " ${YELLOW}* rclone est déjà installé !${NC}"
	fi
	echo ""
}

function rclone_service() {
		REMOTE=$(grep -iC 4 "token" /root/.config/rclone/rclone.conf | head -n 1 | sed "s/\[//g" | sed "s/\]//g")
		REMOTEPLEX=$(grep -iC 2 "/mnt/plexdrive" /root/.config/rclone/rclone.conf | head -n 1 | sed "s/\[//g" | sed "s/\]//g")
		REMOTECRYPT=$(grep -v -e $REMOTEPLEX -e $REMOTE /root/.config/rclone/rclone.conf | grep "\[" | sed "s/\[//g" | sed "s/\]//g" | head -n 1)
		clear
		echo -e " ${BWHITE}* Remote chiffré rclone${NC} --> ${YELLOW}$REMOTECRYPT:${NC}"
		checking_errors $?
		echo ""
		echo -e " ${BWHITE}* Remote chiffré plexdrive${NC} --> ${YELLOW}$REMOTEPLEX:${NC}"
		checking_errors $?
		echo ""

		mkdir -p /mnt/rclone/$SEEDUSER

		cp "$BASEDIR/includes/config/systemd/rclone.service" "/etc/systemd/system/rclone-$SEEDUSER.service" > /dev/null 2>&1
		sed -i "s|%REMOTEPLEX%|$REMOTEPLEX:|g" /etc/systemd/system/rclone-$SEEDUSER.service
		sed -i "s|%SEEDUSER%|$SEEDUSER|g" /etc/systemd/system/rclone-$SEEDUSER.service
		sed -i "s|%USERID%|$USERID|g" /etc/systemd/system/rclone-$SEEDUSER.service
		sed -i "s|%GRPID%|$GRPID|g" /etc/systemd/system/rclone-$SEEDUSER.service

		systemctl daemon-reload > /dev/null 2>&1
		systemctl enable rclone-$SEEDUSER.service > /dev/null 2>&1
		service rclone-$SEEDUSER start
		var="Montage rclone en cours, merci de patienter..."
		decompte 15
		checking_errors $?
		echo ""
}

function unionfs_fuse() {
	echo -e "${BLUE}### Unionfs-Fuse ###${NC}"
	UNIONFS="/etc/systemd/system/unionfs-$SEEDUSER.service"
	if [[ ! -e "$UNIONFS" ]]; then
		echo -e " ${BWHITE}* Installation Unionfs${NC}"
		cp "$BASEDIR/includes/config/systemd/unionfs.service" "/etc/systemd/system/unionfs-$SEEDUSER.service" > /dev/null 2>&1
		sed -i "s|%SEEDUSER%|$SEEDUSER|g" /etc/systemd/system/unionfs-$SEEDUSER.service
		systemctl daemon-reload > /dev/null 2>&1
		systemctl enable unionfs-$SEEDUSER.service > /dev/null 2>&1
		systemctl start unionfs-$SEEDUSER.service > /dev/null 2>&1
		checking_errors $?
	else
		echo -e " ${YELLOW}* Unionfs est déjà installé pour l'utilisateur $SEEDUSER !${NC}"
		systemctl restart unionfs-$SEEDUSER.service
	fi
	echo ""
}

function install_docker() {
	echo -e "${BLUE}### DOCKER ###${NC}"
	dpkg-query -l docker > /dev/null 2>&1
  	if [ $? != 0 ]; then
		echo " * Installation Docker"
		curl -fsSL https://get.docker.com -o get-docker.sh > /dev/null 2>&1
		sh get-docker.sh > /dev/null 2>&1
		if [[ "$?" == "0" ]]; then
			echo -e "	${GREEN}* Installation Docker réussie${NC}"
		else
			echo -e "	${RED}* Echec de l'installation Docker !${NC}"
		fi
		service docker start > /dev/null 2>&1
		echo " * Installing Docker-compose"
		curl -L "https://github.com/docker/compose/releases/download/1.23.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose > /dev/null 2>&1
		chmod +x /usr/local/bin/docker-compose > /dev/null 2>&1
		if [[ "$?" == "0" ]]; then
			echo -e "	${GREEN}* Installation Docker-Compose réussie${NC}"
		else
			echo -e "	${RED}* Echec de l'installation Docker-Compose !${NC}"
		fi
		echo ""
	else
		echo -e " ${YELLOW}* Docker est déjà installé !${NC}"
		echo ""
	fi
}

function define_parameters() {
	echo -e "${BLUE}### INFORMATIONS UTILISATEURS ###${NC}"
	USEDOMAIN="y"
	create_user
	CONTACTEMAIL=$(whiptail --title "Adresse Email" --inputbox \
	"Merci de taper votre adresse Email :" 7 50 3>&1 1>&2 2>&3)
	DOMAIN=$(whiptail --title "Votre nom de Domaine" --inputbox \
	"Merci de taper votre nom de Domaine (exemple: nomdedomaine.fr) :" 7 50 3>&1 1>&2 2>&3)
	echo ""
}

function create_user() {
	if [[ ! -f "$GROUPFILE" ]]; then
		touch $GROUPFILE
		SEEDGROUP=$(whiptail --title "Group" --inputbox \
        	"Création d'un groupe pour la Seedbox" 7 50 3>&1 1>&2 2>&3)
		echo "$SEEDGROUP" > "$GROUPFILE"
    		egrep "^$SEEDGROUP" /etc/group >/dev/null
		if [[ "$?" != "0" ]]; then
			echo -e " ${BWHITE}* Création du groupe $SEEDGROUP"
	    	groupadd $SEEDGROUP
	    	checking_errors $?
		else
			SEEDGROUP=$TMPGROUP
	    	echo -e " ${YELLOW}* Le groupe $SEEDGROUP existe déjà.${NC}"
		fi
		if [[ ! -f "$USERSFILE" ]]; then
			touch $USERSFILE
		fi
		SEEDUSER=$(whiptail --title "Administrateur" --inputbox \
			"Nom d'Administrateur de la Seedbox :" 7 50 3>&1 1>&2 2>&3)
		[[ "$?" = 1 ]] && script_plexdrive;
		PASSWORD=$(whiptail --title "Password" --passwordbox \
			"Mot de passe :" 7 50 3>&1 1>&2 2>&3)
		egrep "^$SEEDUSER" /etc/passwd >/dev/null
		if [ $? -eq 0 ]; then
			echo -e " ${YELLOW}* L'utilisateur existe déjà !${NC}"
			USERID=$(id -u $SEEDUSER)
			GRPID=$(id -g $SEEDUSER)
			usermod -a -G docker $SEEDUSER > /dev/null 2>&1
			echo -e " ${BWHITE}* Ajout de $SEEDUSER in $SEEDGROUP"
			usermod -a -G $SEEDGROUP $SEEDUSER
			checking_errors $?
		else
			PASS=$(perl -e 'print crypt($ARGV[0], "password")' $PASSWORD)
			echo -e " ${BWHITE}* Ajout de $SEEDUSER au système"
			useradd -M -g $SEEDGROUP -p $PASS -s /bin/bash $SEEDUSER > /dev/null 2>&1
			usermod -a -G docker $SEEDUSER > /dev/null 2>&1
			mkdir -p /home/$SEEDUSER
			chown -R $SEEDUSER:$SEEDGROUP /home/$SEEDUSER
			chmod 755 /home/$SEEDUSER
			checking_errors $?
			USERID=$(id -u $SEEDUSER)
			GRPID=$(id -g $SEEDUSER)
		fi
		add_user_htpasswd $SEEDUSER $PASSWORD
		echo $SEEDUSER >> $USERSFILE
		return
	else
		TMPGROUP=$(cat $GROUPFILE)
		if [[ "$TMPGROUP" == "" ]]; then
			SEEDGROUP=$(whiptail --title "Group" --inputbox \
        		"Création d'un groupe pour la Seedbox" 7 50 3>&1 1>&2 2>&3)
        	fi
	fi
    	egrep "^$SEEDGROUP" /etc/group >/dev/null
	if [[ "$?" != "0" ]]; then
		echo -e " ${BWHITE}* Création du groupe $SEEDGROUP"
	    groupadd $SEEDGROUP
	    checking_errors $?
	else
		SEEDGROUP=$TMPGROUP
	    echo -e " ${YELLOW}* Le groupe $SEEDGROUP existe déjà.${NC}"
	fi
	if [[ ! -f "$USERSFILE" ]]; then
		touch $USERSFILE
	fi
	SEEDUSER=$(whiptail --title "Utilisateur" --inputbox \
		"Nom d'utilisateur :" 7 50 3>&1 1>&2 2>&3)
	[[ "$?" = 1 ]] && script_plexdrive;
	PASSWORD=$(whiptail --title "Password" --passwordbox \
		"Mot de passe :" 7 50 3>&1 1>&2 2>&3)
	egrep "^$SEEDUSER" /etc/passwd >/dev/null
	if [ $? -eq 0 ]; then
		echo -e " ${YELLOW}* L'utilisateur existe déjà !${NC}"
		USERID=$(id -u $SEEDUSER)
		GRPID=$(id -g $SEEDUSER)
		echo -e " ${BWHITE}* Ajout de $SEEDUSER in $SEEDGROUP"
		usermod -a -G $SEEDGROUP $SEEDUSER
		usermod -a -G docker $SEEDUSER > /dev/null 2>&1
		checking_errors $?
	else
		PASS=$(perl -e 'print crypt($ARGV[0], "password")' $PASSWORD)
		echo -e " ${BWHITE}* Ajout de $SEEDUSER au système"
		useradd -M -g $SEEDGROUP -p $PASS -s /bin/bash $SEEDUSER > /dev/null 2>&1
		usermod -a -G docker $SEEDUSER > /dev/null 2>&1
		mkdir -p /home/$SEEDUSER
		chown -R $SEEDUSER:$SEEDGROUP /home/$SEEDUSER
		chmod 755 /home/$SEEDUSER
		checking_errors $?
		USERID=$(id -u $SEEDUSER)
		GRPID=$(id -g $SEEDUSER)
	fi
	add_user_htpasswd $SEEDUSER $PASSWORD
	echo $SEEDUSER >> $USERSFILE
}


function add_ftp () {
	docker exec -i ftp /bin/bash << EOX
	( echo ${PASSWORD} ; echo ${PASSWORD} )|pure-pw useradd ${SEEDUSER} -f /etc/pure-ftpd/passwd/pureftpd.passwd -m -u ftpuser -d /home/ftpusers/${SEEDUSER}
EOX
}

function del_ftp () {
	docker exec -i ftp /bin/bash << EOC
    pure-pw userdel ${SEEDUSER} -f /etc/pure-ftpd/passwd/pureftpd.passwd
EOC
}

function choose_services() {
	echo -e "${BLUE}### SERVICES ###${NC}"
	echo -e " ${BWHITE}--> Services en cours d'installation : ${NC}"
	for app in $(cat $SERVICESAVAILABLE);
	do
		service=$(echo $app | cut -d\- -f1)
		desc=$(echo $app | cut -d\- -f2)
		echo "$service $desc off" >> /tmp/menuservices.txt
	done
	SERVICESTOINSTALL=$(whiptail --title "Gestion des Applications" --checklist \
	"Applis à ajouter pour $SEEDUSER (Barre espace pour la sélection)" 28 60 17 \
	$(cat /tmp/menuservices.txt) 3>&1 1>&2 2>&3)
	[[ "$?" = 1 ]] && script_plexdrive;
	SERVICESPERUSER="$SERVICESUSER$SEEDUSER"
	touch $SERVICESPERUSER
	for APPDOCKER in $SERVICESTOINSTALL
	do
		echo -e "	${GREEN}* $(echo $APPDOCKER | tr -d '"')${NC}"
		echo $(echo ${APPDOCKER,,} | tr -d '"') >> $SERVICESPERUSER
	done

	if [[ "$DOMAIN" == "" ]]; then
		DOMAIN=$(whiptail --title "Votre nom de Domaine" --inputbox \
		"Merci de taper votre nom de Domaine :" 7 50 3>&1 1>&2 2>&3)
	fi

	rm /tmp/menuservices.txt
}

function choose_media_folder_classique() {
	echo -e "${BLUE}### DOSSIERS MEDIAS ###${NC}"
	echo -e " ${BWHITE}--> Création des dossiers Medias : ${NC}"
	for media in $(cat $MEDIAVAILABLE);
	do
		service=$(echo $media | cut -d\- -f1)
		desc=$(echo $media | cut -d\- -f2)
		echo "$service $desc off" >> /tmp/menumedia.txt
	done
	MEDIASTOINSTALL=$(whiptail --title "Gestion des dossiers Medias" --checklist \
	"Medias à ajouter pour $SEEDUSER (Barre espace pour la sélection)" 28 60 17 \
	$(cat /tmp/menumedia.txt) 3>&1 1>&2 2>&3)
	MEDIASPERUSER="$MEDIASUSER$SEEDUSER"
	touch $MEDIASPERUSER
	for MEDDOCKER in $MEDIASTOINSTALL
	do
		echo -e "	${GREEN}* $(echo $MEDDOCKER | tr -d '"')${NC}"
		echo $(echo ${MEDDOCKER} | tr -d '"') >> $MEDIASPERUSER
	done
	for line in $(cat $MEDIASPERUSER);
	do
	line=$(echo $line | sed 's/\(.\)/\U\1/')
	mkdir -p /home/$SEEDUSER/local/$line
	done
	mkdir -p /home/$SEEDUSER/filebot
	chown -R $SEEDUSER:$SEEDGROUP /home/$SEEDUSER/filebot
	chown -R $SEEDUSER:$SEEDGROUP /home/$SEEDUSER/local
	chmod -R 755 /home/$SEEDUSER/local
	chmod -R 755 /home/$SEEDUSER/filebot
	rm /tmp/menumedia.txt
	echo ""
}

function choose_media_folder_plexdrive() {
	echo -e "${BLUE}### DOSSIERS MEDIAS ###${NC}"
	FOLDER="/mnt/rclone/$SEEDUSER"
	MEDIASPERUSER="$MEDIASUSER$SEEDUSER"
	
	# si le dossier /mnt/rclone/user n'est pas vide
	if [ "$(ls -A /mnt/rclone/$SEEDUSER)" ]; then
		cd /mnt/rclone/$SEEDUSER
		ls -Ad */ | sed 's,/$,,g' > $MEDIASPERUSER
		mkdir -p /home/$SEEDUSER/Medias
		echo -e " ${BWHITE}--> Récupération des dossiers Utilisateur à partir de Gdrive... : ${NC}"
		for line in $(cat $MEDIASPERUSER);
		do
		mkdir -p /home/$SEEDUSER/local/$line
		echo -e "	${GREEN}--> Le dossier ${NC}${YELLOW}$line${NC}${GREEN} a été ajouté avec succès !${NC}"
		done
		mkdir -p /home/$SEEDUSER/filebot
		chown -R $SEEDUSER:$SEEDGROUP /home/$SEEDUSER/filebot
		chown -R $SEEDUSER:$SEEDGROUP /home/$SEEDUSER/local
		chmod -R 755 /home/$SEEDUSER/local
		chmod -R 755 /home/$SEEDUSER/filebot
	else
		mkdir -p /home/$SEEDUSER/Medias
		echo -e " ${BWHITE}--> Création des dossiers Medias ${NC}"
		echo ""
		echo -e " ${YELLOW}--> ### Veuillez patienter, création en cours des dossiers sur Gdrive ### ${NC}"
		for media in $(cat $MEDIAVAILABLE);
		do
			service=$(echo $media | cut -d\- -f1)
			desc=$(echo $media | cut -d\- -f2)
			echo "$service $desc off" >> /tmp/menumedia.txt
		done
		MEDIASTOINSTALL=$(whiptail --title "Gestion des dossiers Medias" --checklist \
		"Medias à ajouter pour $SEEDUSER (Barre espace pour la sélection)" 28 60 17 \
		$(cat /tmp/menumedia.txt) 3>&1 1>&2 2>&3)
		MEDIASPERUSER="$MEDIASUSER$SEEDUSER"
		touch $MEDIASPERUSER
		for MEDDOCKER in $MEDIASTOINSTALL
		do
			echo -e "	${GREEN}* $(echo $MEDDOCKER | tr -d '"')${NC}"
			echo $(echo ${MEDDOCKER} | tr -d '"') >> $MEDIASPERUSER
		done
		for line in $(cat $MEDIASPERUSER);
		do
		line=$(echo $line | sed 's/\(.\)/\U\1/')
		mkdir -p /home/$SEEDUSER/local/$line
		mkdir -p /mnt/rclone/$SEEDUSER/$line 
		done
		mkdir -p /home/$SEEDUSER/filebot
		chown -R $SEEDUSER:$SEEDGROUP /home/$SEEDUSER/filebot
		chown -R $SEEDUSER:$SEEDGROUP /home/$SEEDUSER/local
		chmod -R 755 /home/$SEEDUSER/local
		chmod -R 755 /home/$SEEDUSER/filebot
		rm /tmp/menumedia.txt
	fi
	echo ""
}

function replace_media_compose() {
	MEDIASPERUSER="$MEDIASUSER$SEEDUSER"
	if [[ -e "$MEDIASPERUSER" ]]; then
		FILMS=$(grep -E 'Films' $MEDIASPERUSER)
		SERIES=$(grep -E 'Series' $MEDIASPERUSER)
		ANIMES=$(grep -E 'Animes' $MEDIASPERUSER)
		MUSIC=$(grep -E 'Musiques' $MEDIASPERUSER)
	else
		FILMS=$(grep -E 'Films' /tmp/menumedia.txt)
		SERIES=$(grep -E 'Series' /tmp/menumedia.txt)
		ANIMES=$(grep -E 'Animes' /tmp/menumedia.txt)
		MUSIC=$(grep -E 'Musiques' /tmp/menumedia.txt)
	fi
}

function add_user_htpasswd() {
	HTFOLDER="$CONFDIR/passwd/"
	mkdir -p $CONFDIR/passwd
	HTTEMPFOLDER="/tmp/"
	HTFILE=".htpasswd-$SEEDUSER"
	if [[ $1 == "" ]]; then
		echo ""
		echo -e "${BLUE}## HTPASSWD MANAGER ##${NC}"
		HTUSER=$(whiptail --title "HTUser" --inputbox "Enter username for htaccess" 10 60 3>&1 1>&2 2>&3)
		HTPASSWORD=$(whiptail --title "HTPassword" --passwordbox "Enter password" 10 60 3>&1 1>&2 2>&3)
	else
		HTUSER=$1
		HTPASSWORD=$2
	fi
	if [[ ! -f $HTFOLDER$HTFILE ]]; then
		htpasswd -c -b $HTTEMPFOLDER$HTFILE $HTUSER $HTPASSWORD > /dev/null 2>&1
	else
		htpasswd -b $HTFOLDER$HTFILE $HTUSER $HTPASSWORD > /dev/null 2>&1
	fi
	valid_htpasswd
}

function install_services() {
	replace_media_compose
	USERID=$(id -u $SEEDUSER)
	GRPID=$(id -g $SEEDUSER)
	INSTALLEDFILE="/home/$SEEDUSER/resume"
	touch $INSTALLEDFILE > /dev/null 2>&1

	if [[ ! -d "$CONFDIR/conf" ]]; then
	mkdir -p $CONFDIR/conf > /dev/null 2>&1
	fi

	## port rutorrent 1
	if [[ -f "$FILEPORTPATH" ]]; then
		declare -i PORT=$(cat $FILEPORTPATH | tail -1)
	else
		declare -i PORT=$FIRSTPORT
	fi

	## port rutorrent 2
	if [[ -f "$FILEPORTPATH1" ]]; then
		declare -i PORT1=$(cat $FILEPORTPATH1 | tail -1)
	else
		declare -i PORT1=$FIRSTPORT1
	fi

	## port rutorrent 3
	if [[ -f "$FILEPORTPATH2" ]]; then
		declare -i PORT2=$(cat $FILEPORTPATH2 | tail -1)
	else
		declare -i PORT2=$FIRSTPORT2
	fi

	## port plex
	if [[ -f "$PLEXPORTPATH" ]]; then
		declare -i PORTPLEX=$(cat $PLEXPORTPATH | tail -1)
	else
		declare -i PORTPLEX=32400
	fi

	## préparation du docker-compose
	for line in $(cat $SERVICESPERUSER);
	do
		cp -R /opt/seedbox-compose/includes/dockerapps/$line.yml $CONFDIR/conf/$line.yml
		DOCKERCOMPOSEFILE="$CONFDIR/conf/$line.yml"
		sed -i "s|%TIMEZONE%|$TIMEZONE|g" $DOCKERCOMPOSEFILE
		sed -i "s|%UID%|$USERID|g" $DOCKERCOMPOSEFILE
		sed -i "s|%GID%|$GRPID|g" $DOCKERCOMPOSEFILE
		sed -i "s|%PORT%|$PORT|g" $DOCKERCOMPOSEFILE
		sed -i "s|%PORT1%|$PORT1|g" $DOCKERCOMPOSEFILE
		sed -i "s|%PORT2%|$PORT2|g" $DOCKERCOMPOSEFILE
		sed -i "s|%PORTPLEX%|$PORTPLEX|g" $DOCKERCOMPOSEFILE
		sed -i "s|%VAR%|$VAR|g" $DOCKERCOMPOSEFILE
		sed -i "s|%DOMAIN%|$DOMAIN|g" $DOCKERCOMPOSEFILE
		sed -i "s|%USER%|$SEEDUSER|g" $DOCKERCOMPOSEFILE
		sed -i "s|%EMAIL%|$CONTACTEMAIL|g" $DOCKERCOMPOSEFILE
		sed -i "s|%FILMS%|$FILMS|g" $DOCKERCOMPOSEFILE
		sed -i "s|%SERIES%|$SERIES|g" $DOCKERCOMPOSEFILE
		sed -i "s|%ANIMES%|$ANIMES|g" $DOCKERCOMPOSEFILE
		sed -i "s|%MUSIC%|$MUSIC|g" $DOCKERCOMPOSEFILE

		if [[ "$line" == "plex" ]]; then
			echo -e "${BLUE}### CONFIG POST COMPOSE PLEX ###${NC}"
			echo -e " ${BWHITE}* Processing plex config file...${NC}"
			# CLAIM pour Plex
			echo ""
			echo -e " ${BWHITE}* Un token est nécessaire pour AUTHENTIFIER le serveur Plex ${NC}"
			echo -e " ${BWHITE}* Pour obtenir un identifiant CLAIM, allez à cette adresse et copier le dans le terminal ${NC}"
			echo -e " ${CRED}* https://www.plex.tv/claim/ ${CEND}"
			echo ""
			read -rp "CLAIM = " CLAIM
		fi
		sed -i "s|%CLAIM%|$CLAIM|g" $DOCKERCOMPOSEFILE

		NOMBRE=$(sed -n "/$SEEDUSER/=" $CONFDIR/users)
		if [ $NOMBRE -le 1 ] ; then
			FQDNTMP="$line.$DOMAIN"
		else
			FQDNTMP="$line-$SEEDUSER.$DOMAIN"
		fi
		ACCESSURL=$FQDNTMP
		TRAEFIKURL=(Host:$ACCESSURL)
		sed -i "s|%TRAEFIKURL%|$TRAEFIKURL|g" $DOCKERCOMPOSEFILE
		sed -i "s|%ACCESSURL%|$ACCESSURL|g" $DOCKERCOMPOSEFILE

		cd $CONFDIR/conf
		ansible-playbook $line.yml

		if [[ "$line" == "plex" ]]; then
		plex_sections
		fi

		echo "$line-$PORT-$FQDNTMP" >> $INSTALLEDFILE
		URI="/"
	
		PORT=$PORT+1
		PORT1=$PORT1+1
		PORT2=$PORT2+1
		PORTPLEX=$PORTPLEX+1
		FQDN=""
		FQDNTMP=""
		set PORT
	done
	echo $PORT >> $FILEPORTPATH
	echo $PORT1 >> $FILEPORTPATH1
	echo $PORT2 >> $FILEPORTPATH2
	echo $PORTPLEX >> $PLEXPORTPATH
	config_post_compose
}

function restore_services() {
	replace_media_compose
	USERID=$(id -u $SEEDUSER)
	GRPID=$(id -g $SEEDUSER)
	INSTALLEDFILE="/home/$SEEDUSER/resume"
	touch $INSTALLEDFILE > /dev/null 2>&1

	if [[ ! -d "$CONFDIR/conf" ]]; then
	mkdir -p $CONFDIR/conf > /dev/null 2>&1
	fi

	## port rutorrent 1
	if [[ -f "$FILEPORTPATH" ]]; then
		declare -i PORT=$(cat $FILEPORTPATH | tail -1)
	else
		declare -i PORT=$FIRSTPORT
	fi

	## port rutorrent 2
	if [[ -f "$FILEPORTPATH1" ]]; then
		declare -i PORT1=$(cat $FILEPORTPATH1 | tail -1)
	else
		declare -i PORT1=$FIRSTPORT1
	fi

	## port rutorrent 3
	if [[ -f "$FILEPORTPATH2" ]]; then
		declare -i PORT2=$(cat $FILEPORTPATH2 | tail -1)
	else
		declare -i PORT2=$FIRSTPORT2
	fi

	## port plex
	if [[ -f "$PLEXPORTPATH" ]]; then
		declare -i PORTPLEX=$(cat $PLEXPORTPATH | tail -1)
	else
		declare -i PORTPLEX=32400
	fi

	## préparation du docker-compose
	for line in $(cat $SERVICESPERUSER);
	do
		cp -R /opt/seedbox-compose/includes/dockerapps/$line.yml $CONFDIR/conf/$line.yml
		DOCKERCOMPOSEFILE="$CONFDIR/conf/$line.yml"
		sed -i "s|%TIMEZONE%|$TIMEZONE|g" $DOCKERCOMPOSEFILE
		sed -i "s|%UID%|$USERID|g" $DOCKERCOMPOSEFILE
		sed -i "s|%GID%|$GRPID|g" $DOCKERCOMPOSEFILE
		sed -i "s|%PORT%|$PORT|g" $DOCKERCOMPOSEFILE
		sed -i "s|%PORT1%|$PORT1|g" $DOCKERCOMPOSEFILE
		sed -i "s|%PORT2%|$PORT2|g" $DOCKERCOMPOSEFILE
		sed -i "s|%PORTPLEX%|$PORTPLEX|g" $DOCKERCOMPOSEFILE
		sed -i "s|%VAR%|$VAR|g" $DOCKERCOMPOSEFILE
		sed -i "s|%DOMAIN%|$DOMAIN|g" $DOCKERCOMPOSEFILE
		sed -i "s|%USER%|$SEEDUSER|g" $DOCKERCOMPOSEFILE
		sed -i "s|%EMAIL%|$CONTACTEMAIL|g" $DOCKERCOMPOSEFILE
		sed -i "s|%FILMS%|$FILMS|g" $DOCKERCOMPOSEFILE
		sed -i "s|%SERIES%|$SERIES|g" $DOCKERCOMPOSEFILE
		sed -i "s|%ANIMES%|$ANIMES|g" $DOCKERCOMPOSEFILE
		sed -i "s|%MUSIC%|$MUSIC|g" $DOCKERCOMPOSEFILE

		if [[ "$line" == "plex" ]]; then
			echo -e "${BLUE}### CONFIG POST COMPOSE PLEX ###${NC}"
			echo -e " ${BWHITE}* Processing plex config file...${NC}"
			# CLAIM pour Plex
			echo ""
			echo -e " ${BWHITE}* Un token est nécessaire pour AUTHENTIFIER le serveur Plex ${NC}"
			echo -e " ${BWHITE}* Pour obtenir un identifiant CLAIM, allez à cette adresse et copier le dans le terminal ${NC}"
			echo -e " ${CRED}* https://www.plex.tv/claim/ ${CEND}"
			echo ""
			read -rp "CLAIM = " CLAIM
		fi
		sed -i "s|%CLAIM%|$CLAIM|g" $DOCKERCOMPOSEFILE

		NOMBRE=$(sed -n "/$SEEDUSER/=" $CONFDIR/users)
		if [ $NOMBRE -le 1 ] ; then
			FQDNTMP="$line.$DOMAIN"
		else
			FQDNTMP="$line-$SEEDUSER.$DOMAIN"
		fi
		ACCESSURL=$FQDNTMP
		TRAEFIKURL=(Host:$ACCESSURL)
		sed -i "s|%TRAEFIKURL%|$TRAEFIKURL|g" $DOCKERCOMPOSEFILE
		sed -i "s|%ACCESSURL%|$ACCESSURL|g" $DOCKERCOMPOSEFILE

		cd $CONFDIR/conf
		ansible-playbook $line.yml

		echo "$line-$PORT-$FQDNTMP" >> $INSTALLEDFILE
		URI="/"
	
		PORT=$PORT+1
		PORT1=$PORT1+1
		PORT2=$PORT2+1
		PORTPLEX=$PORTPLEX+1
		FQDN=""
		FQDNTMP=""
		set PORT
	done
	echo $PORT >> $FILEPORTPATH
	echo $PORT1 >> $FILEPORTPATH1
	echo $PORT2 >> $FILEPORTPATH2
	echo $PORTPLEX >> $PLEXPORTPATH
	config_post_compose
}

function config_post_compose() {
for line in $(cat $SERVICESPERUSER);
do

		if [[ "$line" == "subsonic" ]]; then
		echo -e "${BLUE}### CONFIG POST COMPOSE SUBSONIC ###${NC}"
		echo -e " ${BWHITE}* Mise à jour subsonic...${NC}"
		docker exec subsonic-$SEEDUSER update > /dev/null 2>&1
		docker restart subsonic-$SEEDUSER > /dev/null 2>&1
		docker exec subsonic-$SEEDUSER bash -c "echo '127.0.0.1 localhost.localdomain localhost subsonic.org' >> /etc/hosts"
		checking_errors $?
		echo ""
		echo -e "${BLUE}### SUBSONIC PREMIUM ###${NC}"
		echo -e "${BWHITE}	--> foo@bar.com${NC}"
		echo -e "${BWHITE}	--> f3ada405ce890b6f8204094deb12d8a8${NC}"
		echo ""
		fi
echo ""
done
}

decompte() {
    i=$1
    while [[ $i -ge 0 ]]
      do
        echo -e "\033[1;37m\r * "$var ""$i""s" \c\033[0m"
        sleep 1
        i=$(expr $i - 1)
    done
    echo -e ""
}

function plex_sections() {
			echo ""
			echo -e "${BLUE}### CREATION DES BIBLIOTHEQUES PLEX ###${NC}"
			replace_media_compose
			##compteur
			var="Sections en cours de création, patientez..."
			decompte 15

			## création des bibliothèques plex
			for x in $(cat $MEDIASPERUSER);
			do
				if [[ "$x" == "$ANIMES" ]]; then
					docker exec plex-$SEEDUSER /usr/lib/plexmediaserver/Plex\ Media\ Scanner --add-section $x --type 2 --location /data/$x --lang fr
					echo -e "	${BWHITE}* $x ${NC}"
				
				elif [[ "$x" == "$SERIES" ]]; then
					docker exec plex-$SEEDUSER /usr/lib/plexmediaserver/Plex\ Media\ Scanner --add-section $x --type 2 --location /data/$x --lang fr
					echo -e "	${BWHITE}* $x ${NC}"

				elif [[ "$x" == "$MUSIC" ]]; then
					docker exec plex-$SEEDUSER /usr/lib/plexmediaserver/Plex\ Media\ Scanner --add-section $x --type 8 --location /data/$x --lang fr
					echo -e "	${BWHITE}* $x ${NC}"
				else
					docker exec plex-$SEEDUSER /usr/lib/plexmediaserver/Plex\ Media\ Scanner --add-section $x --type 1 --location /data/$x --lang fr
					echo -e "	${BWHITE}* $x ${NC}"
				fi
			done

			## A travailler
			if [[ -f "$SCANPORTPATH" ]]; then
				declare -i PORT=$(cat $SCANPORTPATH | tail -1)
			else
				declare -i PORT=3470
			fi

			PLEXDRIVE="/usr/bin/plexdrive"
			if [[ -e "$PLEXDRIVE" ]]; then

				## installation plex_autoscan
				plex_autoscan
				echo ""

				## installation cloudplow
				cloudplow

				touch /home/$SEEDUSER/scripts/plex_autoscan/plex_autoscan.sh
				##PORT=$(grep SERVER_PORT /home/$SEEDUSER/scripts/plex_autoscan/config/config.json | cut -d ':' -f2 | sed 's/, //' | sed 's/ //')
				IP_DOM=$(grep 'Accepted' /var/log/auth.log | cut -d ' ' -f11 | head -1)
				PASS=$(grep PASS /home/$SEEDUSER/scripts/plex_autoscan/config/config.json | cut -d ':' -f2 | cut -d '"' -f2)
				PLEXCANFILE="/home/$SEEDUSER/scripts/plex_autoscan/plex_autoscan.sh"
				IPADDRESS=$(hostname -I | cut -d\  -f1)
				cat "$BASEDIR/includes/config/roles/plex_autoscan/plex_autoscan.sh" > $PLEXCANFILE

				chmod 755 $PLEXCANFILE

				for line in $(cat $INSTALLEDFILE);
				do
					NOMBRE=$(sed -n "/$SEEDUSER/=" $CONFDIR/users)
					if [ $NOMBRE -le 1 ] ; then
						ACCESSDOMAIN=$(grep plex $INSTALLEDFILE | cut -d\- -f3)
					else
						ACCESSDOMAIN=$(grep plex $INSTALLEDFILE | cut -d\- -f3-4)
					fi
				done
				
				## config plex_autoscan filebot rutorrent
				sed -i "s|%DOMAIN%|$DOMAIN|g" $PLEXCANFILE
				sed -i -e "s/%ANIMES%/${ANIMES}/g" $PLEXCANFILE
				sed -i -e "s/%FILMS%/${FILMS}/g" $PLEXCANFILE
				sed -i -e "s/%SERIES%/${SERIES}/g" $PLEXCANFILE
				sed -i -e "s/%MUSIC%/${MUSIC}/g" $PLEXCANFILE
				#sed -i -e "s/%PORT%/${PORT}/g" $PLEXCANFILE
				sed -i -e "s/%SEEDUSER%/${SEEDUSER}/g" $PLEXCANFILE
				sed -i -e "s/%PASS%/${PASS}/g" $PLEXCANFILE
				sed -i -e "s/%IPADDRESS%/${IPADDRESS}/g" $PLEXCANFILE
			fi

			## installation plex_dupefinder
			echo ""
			plex_dupefinder
			echo ""
}

function valid_htpasswd() {
	if [[ -d "$CONFDIR" ]]; then
		HTFOLDER="$CONFDIR/passwd/"
		mkdir -p $HTFOLDER
		HTTEMPFOLDER="/tmp/"
		HTFILE=".htpasswd-$SEEDUSER"
		cat "$HTTEMPFOLDER$HTFILE" >> "$HTFOLDER$HTFILE"
		VAR=$(sed -e 's/\$/\$/g' "$HTFOLDER$HTFILE")
		cd $HTFOLDER
		touch login
		echo "$HTUSER $HTPASSWORD" >> "$HTFOLDER/login"
		rm "$HTTEMPFOLDER$HTFILE"
	fi
}

function add_app_htpasswd() {
	if [[ -d "$CONFDIR" ]]; then
		HTFOLDER="$CONFDIR/passwd/"
		HTFILE=".htpasswd-$SEEDUSER"
		VAR=$(sed -e 's/\$/\$/g' "$HTFOLDER$HTFILE")
	fi
}

function manage_users() {
	echo -e "${BLUE}##########################################${NC}"
	echo -e "${BLUE}###      Gestions des Utilisateurs     ###${NC}"
	echo -e "${BLUE}##########################################${NC}"
	echo ""
	MANAGEUSER=$(whiptail --title "Management" --menu \
	                "Choisir une action" 10 45 2 \
	                "1" "Nouvelle Seedbox Utilisateur" \
	                "2" "Supprimer Seedbox Utilisateur" 3>&1 1>&2 2>&3)
			[[ "$?" = 1 ]] && script_plexdrive;
	case $MANAGEUSER in
		"1" )
			PLEXDRIVE="/usr/bin/plexdrive"
			echo -e "${GREEN}###   NOUVELLE SEEDBOX USER   ###${NC}"
			echo -e "${GREEN}---------------------------------${NC}"
			echo ""
			define_parameters
			add_ftp > /dev/null 2>&1
			if [[ -e "$PLEXDRIVE" ]]; then
				rclone_service
				choose_media_folder_plexdrive
				unionfs_fuse
				pause
				choose_services
				install_services
				CLOUDPLOWFOLDER="/home/$SEEDUSER/scripts/cloudplow"
				if [[ ! -d "$CLOUDPLOWFOLDER" ]]; then
				cloudplow
				sed -i "s/\"enabled\"\: true/\"enabled\"\: false/g" /home/$SEEDUSER/scripts/cloudplow/config.json
				fi
				filebot
				sauve
				resume_seedbox
				pause
				script_plexdrive
			else
				choose_media_folder_classique
				choose_services
				install_services
				filebot
				resume_seedbox
				pause
				script_classique
			fi
			;;

		"2" )
			echo -e "${GREEN}###   SUPRESSION SEEDBOX USER   ###${NC}"
			echo -e "${GREEN}-----------------------------------${NC}"
			echo ""
			PLEXDRIVE="/usr/bin/plexdrive"
			TMPGROUP=$(cat $GROUPFILE)
			TABUSERS=()
			for USERSEED in $(members $TMPGROUP)
			do
	        		IDSEEDUSER=$(id -u $USERSEED)
	        		TABUSERS+=( ${USERSEED//\"} ${IDSEEDUSER//\"} )
			done
			## CHOOSE USER
			SEEDUSER=$(whiptail --title "Gestion des Applis" --menu \
	                		"Merci de sélectionner l'Utilisateur" 12 50 3 \
	                		"${TABUSERS[@]}"  3>&1 1>&2 2>&3)
			[[ "$?" = 1 ]] && script_plexdrive;

			## RESUME USER INFORMATIONS
			USERRESUMEFILE="/home/$SEEDUSER/resume"
			echo -e "${BLUE}### SUPPRESSION CONTAINERS ###${NC}"
			for SERVICEACTIVATED in $(cat $USERRESUMEFILE)
			do
			        line=$(echo $SERVICEACTIVATED | cut -d\- -f1)
				docker rm -f $line-$SEEDUSER > /dev/null 2>&1
			done
			echo ""
			checking_errors $?

			if [[ -e "$PLEXDRIVE" ]]; then
				echo -e "${BLUE}### SUPPRESSION USER RCLONE/PLEXDRIVE ###${NC}"
				PLEXAUTOSCAN="/etc/systemd/system/plex_autoscan.service"
				if [[ -e "$PLEXAUTOSCAN" ]]; then
					systemctl stop plex_autoscan.service
					systemctl disable plex_autoscan.service > /dev/null 2>&1
					rm /etc/systemd/system/plex_autoscan.service
				fi
				systemctl stop rclone-$SEEDUSER.service
				systemctl disable rclone-$SEEDUSER.service > /dev/null 2>&1
				rm /etc/systemd/system/rclone-$SEEDUSER.service
				systemctl stop cloudplow.service
				systemctl disable cloudplow.service > /dev/null 2>&1
				rm /etc/systemd/system/cloudplow.service
				systemctl stop unionfs-$SEEDUSER.service
				systemctl disable unionfs-$SEEDUSER.service > /dev/null 2>&1
				rm /etc/systemd/system/unionfs-$SEEDUSER.service
				checking_errors $?
				echo""
			fi
		        echo -e "${BLUE}### SUPPRESSION USER ###${NC}"
			rm -rf /home/$SEEDUSER > /dev/null 2>&1
			rm -rf /opt/seedbox/docker/$SEEDUSER > /dev/null 2>&1
			rm /opt/seedbox/media-$SEEDUSER
			userdel -rf $SEEDUSER > /dev/null 2>&1
			sed -i "/$SEEDUSER/d" $CONFDIR/users
			rm $CONFDIR/passwd/.htpasswd-$SEEDUSER
			sed -n -i "/$SEEDUSER/!p" $CONFDIR/passwd/login
			checking_errors $?
			echo""
			echo -e "${BLUE}### $SEEDUSER a été supprimé ###${NC}"
			echo ""
			pause
			if [[ -e "$PLEXDRIVE" ]]; then
				script_plexdrive
			else
				script_classique
			fi
			;;
	esac
}

function manage_apps() {
	echo -e "${BLUE}##########################################${NC}"
	echo -e "${BLUE}###          GESTION DES APPLIS        ###${NC}"
	echo -e "${BLUE}##########################################${NC}"
	TMPGROUP=$(cat $GROUPFILE)
	TABUSERS=()
	for USERSEED in $(members $TMPGROUP)
	do
	        IDSEEDUSER=$(id -u $USERSEED)
	        TABUSERS+=( ${USERSEED//\"} ${IDSEEDUSER//\"} )
	done
	## CHOISIR USER
	SEEDUSER=$(whiptail --title "App Manager" --menu \
	                "Merci de sélectionner l'Utilisateur" 12 50 3 \
	                "${TABUSERS[@]}"  3>&1 1>&2 2>&3)
			[[ "$?" = 1 ]] && script_plexdrive;
	
	## INFORMATIONS UTILISATEUR
	USERRESUMEFILE="/home/$SEEDUSER/resume"
	echo ""
	echo -e "${GREEN}### Gestion des Applis pour: $SEEDUSER ###${NC}"
	echo -e " ${BWHITE}* Resume file: $USERRESUMEFILE${NC}"
	echo ""
	## CHOOSE AN ACTION FOR APPS
	ACTIONONAPP=$(whiptail --title "App Manager" --menu \
	                "Selectionner une action :" 12 50 3 \
	                "1" "Ajout Docker Applis"  \
	                "2" "Supprimer une Appli"  \
			"3" "Réinitialisation Container" 3>&1 1>&2 2>&3)
	[[ "$?" = 1 ]] && script_plexdrive;
	case $ACTIONONAPP in
		"1" ) ## Ajout APP
			choose_services
			add_app_htpasswd
			install_services
			resume_seedbox
			pause
			if [[ -e "$PLEXDRIVE" ]]; then
				script_plexdrive
			else
				script_classique
			fi
			;;
		"2" ) ## Suppression APP
			echo -e " ${BWHITE}* Edit my app${NC}"
			TABSERVICES=()
			for SERVICEACTIVATED in $(cat $USERRESUMEFILE)
			do
			        SERVICE=$(echo $SERVICEACTIVATED | cut -d\- -f1)
			        PORT=$(echo $SERVICEACTIVATED | cut -d\- -f2)
			        TABSERVICES+=( ${SERVICE//\"} ${PORT//\"} )
			done
			APPSELECTED=$(whiptail --title "App Manager" --menu \
			              "Sélectionner l'Appli à supprimer" 19 45 11 \
			              "${TABSERVICES[@]}"  3>&1 1>&2 2>&3)
			[[ "$?" = 1 ]] && script_plexdrive;
			echo -e " ${GREEN}   * $APPSELECTED${NC}"
			docker rm -f "$APPSELECTED"-"$SEEDUSER"
			sed -i "/$APPSELECTED/d" /home/$SEEDUSER/resume
			rm -rf /opt/seedbox/docker/$SEEDUSER/$APPSELECTED
			checking_errors $?
			echo""
			echo -e "${BLUE}### $APPSELECTED a été supprimé ###${NC}"
			echo ""
			pause
			if [[ -e "$PLEXDRIVE" ]]; then
				script_plexdrive
			else
				script_classique
			fi
			;;
		"3" ) 	## Réinitialisation container
			SERVICESPERUSER="$SERVICESUSER$SEEDUSER"
			touch $SERVICESPERUSER
			DOMAIN=$(whiptail --title "Votre nom de Domaine" --inputbox \
			"Merci de taper votre nom de Domaine (exemple: nomdedomaine.fr) :" 7 50 3>&1 1>&2 2>&3)
			echo -e " ${BWHITE}* Les fichiers de configuration ne seront pas effacés${NC}"
			TABSERVICES=()
			for SERVICEACTIVATED in $(cat $USERRESUMEFILE)
			do
			        SERVICE=$(echo $SERVICEACTIVATED | cut -d\- -f1)
			        PORT=$(echo $SERVICEACTIVATED | cut -d\- -f2)
			        TABSERVICES+=( ${SERVICE//\"} ${PORT//\"} )
			done
			line=$(whiptail --title "App Manager" --menu \
			              "Sélectionner le container à réinitialiser" 19 45 11 \
			              "${TABSERVICES[@]}"  3>&1 1>&2 2>&3)
			[[ "$?" = 1 ]] && script_plexdrive;
			echo -e " ${GREEN}   * $line${NC}"
			docker rm -f "$line"-"$SEEDUSER" > /dev/null 2>&1
			sed -i "/$line/d" /home/$SEEDUSER/resume
			echo $line >> $SERVICESPERUSER
			add_app_htpasswd
			restore_services
			checking_errors $?
			echo""
			echo -e "${BLUE}### Le Container $line a été Réinitialisé ###${NC}"
			echo ""
			resume_seedbox
			pause
			if [[ -e "$PLEXDRIVE" ]]; then
				script_plexdrive
			else
				script_classique
			fi
			;;
	esac
}

function resume_seedbox() {
	echo -e "${BLUE}##########################################${NC}"
	echo -e "${BLUE}###     INFORMATION SEEDBOX INSTALL    ###${NC}"
	echo -e "${BLUE}##########################################${NC}"
	echo -e " ${BWHITE}* Accès Applis à partir de URL :${NC}"
	for line in $(cat $INSTALLEDFILE);
	do
		NOMBRE=$(sed -n "/$SEEDUSER/=" $CONFDIR/users)
		if [ $NOMBRE -le 1 ] ; then
			ACCESSDOMAIN=$(echo $line | cut -d\- -f3)
			DOCKERAPP=$(echo $line | cut -d\- -f1)
			echo -e "	--> ${BWHITE}$DOCKERAPP${NC} --> ${YELLOW}$ACCESSDOMAIN${NC}"
		else
			ACCESSDOMAIN=$(echo $line | cut -d\- -f3-4)
			DOCKERAPP=$(echo $line | cut -d\- -f1)
			echo -e "	--> ${BWHITE}$DOCKERAPP${NC} --> ${YELLOW}$ACCESSDOMAIN${NC}"
		fi
	done
	IDENT="$CONFDIR/passwd/.htpasswd-$SEEDUSER"	
	if [[ ! -d $IDENT ]]; then
		PASSE=$(grep $SEEDUSER $CONFDIR/passwd/login | cut -d ' ' -f2)
		echo ""
		echo -e " ${BWHITE}* Vos IDs :${NC}"
		echo -e "	--> Utilisateur: ${YELLOW}$SEEDUSER${NC}"
		echo -e "	--> Password: ${YELLOW}$PASSE${NC}"
		echo ""
	else
		echo -e " ${BWHITE}* Here is your IDs :${NC}"
		echo -e "	--> Utilisateur: ${YELLOW}$HTUSER${NC}"
		echo -e "	--> Password: ${YELLOW}$HTPASSWORD${NC}"
		echo ""
		echo ""
	fi
	rm -Rf $SERVICESPERUSER > /dev/null 2>&1
}

function uninstall_seedbox() {
	clear
	echo -e "${BLUE}##########################################${NC}"
	echo -e "${BLUE}###       DESINSTALLATION SEEDBOX      ###${NC}"
	echo -e "${BLUE}##########################################${NC}"
	SEEDGROUP=$(cat $GROUPFILE)
	PLEXDRIVE="/usr/bin/plexdrive"
	if [[ -e "$PLEXDRIVE" ]]; then
		echo -e " ${BWHITE}* Suppression Plexdrive/rclone...${NC}"
		service plexdrive stop
		rm /etc/systemd/system/plexdrive.service
		rm -rf /mnt/plexdrive
		rm -rf /root/.plexdrive
		checking_errors $?
	fi
	for seeduser in $(cat $USERSFILE)
	do
		USERHOMEDIR="/home/$seeduser"
		PLEXAUTOSCAN="/etc/systemd/system/plex_autoscan.service"
		echo -e " ${BWHITE}* Suppression users $seeduser...${NC}"
		if [[ -e "$PLEXDRIVE" ]]; then
				if [[ -e "$PLEXAUTOSCAN" ]]; then
					systemctl stop plex_autoscan.service
					systemctl disable plex_autoscan.service > /dev/null 2>&1
					rm /etc/systemd/system/plex_autoscan.service
				fi
			systemctl stop rclone-$seeduser.service
			systemctl disable rclone-$seeduser.service > /dev/null 2>&1
			rm /etc/systemd/system/rclone-$seeduser.service
			rm /usr/bin/rclone
			rm -rf /mnt/rclone
			rm -rf /root/.config/rclone
			systemctl stop cloudplow.service
			systemctl disable cloudplow.service > /dev/null 2>&1
			rm /etc/systemd/system/cloudplow.service
			service unionfs-$seeduser stop
			systemctl disable unionfs-$seeduser.service > /dev/null 2>&1
			rm /etc/systemd/system/unionfs-$seeduser.service
		fi
		userdel -rf $seeduser > /dev/null 2>&1
		checking_errors $?
		echo -e " ${BWHITE}* Suppression home $seeduser...${NC}"
		rm -Rf $USERHOMEDIR
		checking_errors $?
		echo ""
	done
	rm /usr/bin/plexdrive > /dev/null 2>&1
	echo -e " ${BWHITE}* Suppression Containers...${NC}"
	docker rm -f $(docker ps -aq) > /dev/null 2>&1
	checking_errors $?
	echo -e " ${BWHITE}* Suppression group...${NC}"
	groupdel $SEEDGROUP > /dev/null 2>&1
	checking_errors $?
	echo -e " ${BWHITE}* Removing Seedbox-compose directory...${NC}"
	rm -Rf $CONFDIR
	checking_errors $?
	cd /opt && rm -Rf seedbox-compose
	pause
}

function pause() {
	echo ""
	echo -e "${YELLOW}###  -->APPUYER SUR ENTREE POUR CONTINUER<--  ###${NC}"
	read
	echo ""
}
