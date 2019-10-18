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
printf "     ${color3}/   \\ ${color2}'\`\`-.   \`   ${color3}`lsb_release -sd`${nocolor}\n"
printf "   ${color2}.-.  ${color3},       ${color2}\`___:  ${nocolor}`uname -srmo`${nocolor}\n"
printf "  ${color2}(   ) ${color3}:       ${color1} ___   ${nocolor}`date +"%A, %e %B %Y, %r"`${nocolor}\n"
printf "   ${color2}\`-\`  ${color3}\`      ${color1} ,   :${nocolor}  Seedbox docker\n"
printf "     ${color3}\\   / ${color1},..-\`   ,${nocolor}   ${descriptif} ${nocolor}\n"
printf "      ${color3}\`./${color1} /    ${color3}.-.${color1}\`${nocolor}    ${appli}\n"
printf "         ${color1}\`-..-${color3}(   )${nocolor}    Uptime: `/usr/bin/uptime -p`\n"
printf "               ${color3}\`-\`${nocolor}\n" 
echo ""

}

function update_system() {
		#Mise à jour systeme
			echo -e "${BLUE}### MISE A JOUR DU SYTEME ###${NC}"
			ansible-playbook /opt/seedbox-compose/includes/config/roles/system/tasks/main.yml
			checking_errors $?
}

function check_domain() {
		TESTDOMAIN=$1
		echo -e " ${BWHITE}* Checking domain - ping $TESTDOMAIN...${NC}"
		ping -c 1 $TESTDOMAIN | grep "$IPADDRESS" > /dev/null
		checking_errors $?
}

function cloudflare() {
		cloudflare="/opt/seedbox/variables/cloudflare_api"
		if [[ ! -e "$cloudflare" ]]; then
		echo -e "${BLUE}### Gestion des DNS ###${NC}"
		echo ""
			echo -e "${CCYAN}------------------------------------------------------------------${CEND}"
			echo -e "${CCYAN}   CloudFlare protège et accélère les sites internet.             ${CEND}"
			echo -e "${CCYAN}   CloudFlare optimise automatiquement la déliverabilité          ${CEND}"
 			echo -e "${CCYAN}   de vos pages web afin de diminuer le temps de chargement       ${CEND}"
			echo -e "${CCYAN}   et d’améliorer les performances. CloudFlare bloque aussi       ${CEND}"
			echo -e "${CCYAN}   les menaces et empêche certains robots illégitimes de          ${CEND}"
			echo -e "${CCYAN}   consommer votre bande passante et les ressources serveur.      ${CEND}"
			echo -e "${CCYAN}------------------------------------------------------------------${CEND}"
		echo ""
                	#read -rp "Souhaitez vous utiliser les DNS Cloudflare ? (o/n) : " OUI
			read -rp $'\e[33mSouhaitez vous utiliser les DNS Cloudflare ? (o/n)\e[0m :' OUI

			if [[ "$OUI" = "o" ]] || [[ "$OUI" = "O" ]]; then
				if [ -z "$cloud_email" ] || [ -z "$cloud_api" ]; then
    				cloud_email=$1
    				cloud_api=$2
				fi

				while [ -z "$cloud_email" ]; do
    				>&2 echo -n -e "${BWHITE}Votre Email Cloudflare: ${CEND}"
    				read cloud_email
    				echo $cloud_email > /opt/seedbox/variables/cloudflare_email
				done

				while [ -z "$cloud_api" ]; do
    				>&2 echo -n -e "${BWHITE}Votre API Cloudflare: ${CEND}"
    				read cloud_api
    				echo $cloud_api > /opt/seedbox/variables/cloudflare_api
				done
			fi
		echo ""
		fi
}

function rtorrent-cleaner() {
			#configuration de rtorrent-cleaner avec ansible
			echo -e "${BLUE}### RTORRENT-CLEANER ###${NC}"
			echo -e " ${BWHITE}* Installation RTORRENT-CLEANER${NC}"

			## choix de l'utilisateur
			SEEDUSER=$(cat /opt/seedbox/variables/users)
			cp -r $BASEDIR/includes/config/rtorrent-cleaner/rtorrent-cleaner /usr/local/bin
			sed -i "s|%SEEDUSER%|$SEEDUSER|g" /usr/local/bin/rtorrent-cleaner
			checking_errors $?
}

function motd() {
			#configuration d'un motd avec ansible
			echo -e "${BLUE}### MOTD ###${NC}"
			echo -e " ${BWHITE}* Installation MOTD${NC}"
			
			#variables
			SEEDUSER=$(cat /opt/seedbox/variables/users)
			APPLITAUTULLI="/opt/seedbox/docker/$SEEDUSER/tautulli"
			PLEXCAN="/home/$SEEDUSER/scripts/plex_autoscan"

			if [ -d "$APPLITAUTULLI" ]; then
			tautulli=$(grep "api_key" /opt/seedbox/docker/$SEEDUSER/tautulli/config.ini | cut -d '=' -f2 | tr -d ' ' | head -1)
			echo $tautulli > /opt/seedbox/variables/tautulli
			fi

			if [ -d "$PLEXCAN" ]; then
			plexautoscan=$(grep "3468" /home/$SEEDUSER/scripts/plex_autoscan/plex_autoscan.sh | cut -d '/' -f4 | tr -d ' ')
			echo $plexautoscan > /opt/seedbox/variables/plexautoscan
			fi

			ansible-playbook /opt/seedbox-compose/includes/config/roles/motd/tasks/start.yml
			checking_errors $?
			echo ""
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
			ansible-playbook /opt/seedbox-compose/includes/config/roles/backup/tasks/main.yml
			checking_errors $?
			echo ""
}

function plex_dupefinder() {
			#configuration plex_dupefinder avec ansible
			echo -e "${BLUE}### PLEX_DUPEFINDER ###${NC}"
			echo -e " ${BWHITE}* Installation plex_dupefinder${NC}"
			ansible-playbook /opt/seedbox-compose/includes/config/roles/plex_dupefinder/tasks/main.yml
			checking_errors $?
}

function traktarr() {
			##configuration traktarr avec ansible
			echo -e "${BLUE}### TRAKTARR ###${NC}"
			echo -e " ${BWHITE}* Installation traktarr${NC}"
			ansible-playbook /opt/seedbox-compose/includes/config/roles/traktarr/tasks/main.yml
			checking_errors $?
}

function webtools() {
			##configuration Webtools avec ansible
			echo -e "${BLUE}### WEBTOOLS ###${NC}"
			echo -e " ${BWHITE}* Installation Webtools${NC}"
			ansible-playbook /opt/seedbox-compose/includes/config/roles/webtools/tasks/main.yml
			docker restart plex
			checking_errors $?
}

function plex_autoscan() {
			#configuration plex_autoscan avec ansible
			echo -e "${BLUE}### PLEX_AUTOSCAN ###${NC}"
			echo -e " ${BWHITE}* Installation plex_autoscan${NC}"
			ansible-playbook /opt/seedbox-compose/includes/config/roles/plex_autoscan/tasks/main.yml
			checking_errors $?
}

function cloudplow() {
			#configuration plex_autoscan avec ansible
			echo -e "${BLUE}### CLOUDPLOW ###${NC}"
			echo -e " ${BWHITE}* Installation cloudplow${NC}"			
			ansible-playbook /opt/seedbox-compose/includes/config/roles/cloudplow/tasks/main.yml
			checking_errors $?
}

function filebot() {
			#configuration filebot avec ansible
			echo ""
			echo -e "${BLUE}### FILEBOT ###${NC}"
			echo -e " ${BWHITE}* Installation filebot${NC}"
			ansible-playbook /opt/seedbox-compose/includes/config/roles/filebot/tasks/main.yml
			checking_errors $?
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

	# Vérification installation modt
	confmodt="/opt/motd"
	if [ -d "$confmodt" ]; then
	insert_mod
	else
	logo
	fi

	echo ""
	echo -e "${CCYAN}SEEDBOX CLASSIQUE${CEND}"
	echo -e "${CGREEN}${CEND}"
	echo -e "${CGREEN}   1) Desinstaller la seedbox ${CEND}"
	echo -e "${CGREEN}   2) Ajout/Supression d'Applis${CEND}"
	echo -e "${CGREEN}   3) Outils${CEND}"

	echo -e ""
	read -p "Votre choix [1-3]: " PORT_CHOICE

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
		## Ajout d'Applications
		echo""
		clear
			manage_apps
		;;
		3)
			clear
			logo
			echo ""
			echo -e "${CCYAN}OUTILS${CEND}"
			echo -e "${CGREEN}${CEND}"
			echo -e "${CGREEN}   1) Mise à jour Cloudflare${CEND}"
			echo -e "${CGREEN}   2) Installation du motd${CEND}"
			echo -e "${CGREEN}   3) Traktarr${CEND}"
			echo -e "${CGREEN}   4) Webtools${CEND}"
			echo -e "${CGREEN}   5) rtorrent-cleaner de ${CCYAN}@Magicalex-Mondedie.fr${CEND}${NC}"
			echo -e "${CGREEN}   6) Openvpn${CEND}"
			echo -e "${CGREEN}   7) Retour menu principal${CEND}"
			echo -e ""
			read -p "Votre choix [1-7]: " OUTILS

			case $OUTILS in

			1) ## Mise à jour - Nouvelle version du script
			clear
			echo ""
			/opt/seedbox-compose/includes/config/update/update
			pause
			script_classique
			;;

			2) ## Installation du motd
			clear
			echo ""
			motd
			pause
			script_classique			;;

			3) ## Installation de traktarr
			clear
			echo ""
			traktarr
			pause
			script_classique
			;;

			4) ## Installation de Webtools
			clear
			echo ""
			webtools
			pause
			script_classique
			;;

			5) ## Installation de rtorrent-cleaner
			clear
			echo ""
			rtorrent-cleaner
			docker run -it --rm -v /home/$SEEDUSER/local/rutorrent:/home/$SEEDUSER/local/rutorrent -v /run/php:/run/php magicalex/docker-rtorrent-cleaner
			pause
			script_classique			;;

			6)
			openvpn
			pause
			script_classique
			;;

			7)
			script_classique
			;;

			esac
		;;
	esac
	fi
}

function insert_mod() {
	sed -i 's/\/etc\/update-motd.d/\/opt\/motd\/motd/g' /opt/motd/motd/04-load-average
	sed -i 's/\/etc\/update-motd.d/\/opt\/motd\/motd/g' /opt/motd/motd/10-plex-stats
	sed -i 's/\/etc\/update-motd.d/\/opt\/motd\/motd/g' /opt/motd/motd/12-rtorrent-stats
	/opt/motd/motd/01-banner
	/opt/motd/motd/04-load-average
	/opt/motd/motd/10-plex-stats
	/opt/motd/motd/12-rtorrent-stats
}

function script_plexdrive() {
	if [[ -d "$CONFDIR" ]]; then
	clear

	# Vérification installation modt
	confmodt="/opt/motd"
	if [ -d "$confmodt" ]; then
	insert_mod
	else
	logo
	fi

	echo ""
	echo -e "${CCYAN}SEEDBOX RCLONE/PLEXDRIVE${CEND}"
	echo -e "${CGREEN}${CEND}"
	echo -e "${CGREEN}   1) Désinstaller la seedbox ${CEND}"
	echo -e "${CGREEN}   2) Ajout/Supression d'Applis${CEND}"
	echo -e "${CGREEN}   3) Outils${CEND}"

	echo -e ""
	read -p "Votre choix [1-3]: " PORT_CHOICE

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
		## Ajout d'Applications
		echo""
		clear
			manage_apps
		;;
		3)
			clear
			logo
			echo ""
			echo -e "${CCYAN}OUTILS${CEND}"
			echo -e "${CGREEN}${CEND}"
			echo -e "${CGREEN}   1) Mise à jour Cloudflare${CEND}"
			echo -e "${CGREEN}   2) Installation du motd${CEND}"
			echo -e "${CGREEN}   3) Traktarr${CEND}"
			echo -e "${CGREEN}   4) Webtools${CEND}"
			echo -e "${CGREEN}   5) rtorrent-cleaner de ${CCYAN}@Magicalex-Mondedie.fr${CEND}${NC}"
			echo -e "${CGREEN}   6) Openvpn${CEND}"
			echo -e "${CGREEN}   7) Retour menu principal${CEND}"
			echo -e ""
			read -p "Votre choix [1-7]: " OUTILS

			case $OUTILS in

			1) ## Installation de la sauvegarde
			clear
			echo ""
			/opt/seedbox-compose/includes/config/update/update
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
	ansible-playbook /opt/seedbox-compose/includes/config/roles/install/tasks/main.yml
	checking_errors $?
	echo ""
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
	ansible-playbook /opt/seedbox-compose/includes/config/roles/fail2ban/tasks/main.yml
	checking_errors $?
	echo ""
}	

function install_traefik() {
	echo -e "${BLUE}### TRAEFIK ###${NC}"
		echo -e " ${BWHITE}* Installation Traefik${NC}"
		ansible-playbook /opt/seedbox-compose/includes/dockerapps/traefik.yml
		checking_errors $?		
	echo ""
}

function install_portainer() {
	echo -e "${BLUE}### PORTAINER ###${NC}"
	INSTALLEDFILE="/home/$SEEDUSER/resume"
	if docker ps | grep -q portainer; then
		echo -e " ${BWHITE}--> portainer est déjà installé !${NC}"
		else
		if (whiptail --title "Docker Portainer" --yesno "Voulez vous installer portainer" 7 50) then
			echo -e " ${BWHITE}* Installation Portainer${NC}"
			cd /opt/seedbox-compose/includes/dockerapps
			ansible-playbook portainer.yml
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
	mkdir -p /mnt/rclone/$SEEDUSER > /dev/null 2>&1
	RCLONECONF="/root/.config/rclone/rclone.conf"
	USERID=$(id -u $SEEDUSER)
	GRPID=$(id -g $SEEDUSER)

	if [[ ! -f "$RCLONECONF" ]]; then
		echo -e " ${BWHITE}* Installation rclone${NC}"
		mkdir -p /root/.config/rclone/ > /dev/null 2>&1
		clear
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

		## Mise en variables des remotes
		REMOTE=$(grep -iC 4 "token" /root/.config/rclone/rclone.conf | head -n 1 | sed "s/\[//g" | sed "s/\]//g")
		REMOTEPLEX=$(grep -iC 2 "/mnt/plexdrive" /root/.config/rclone/rclone.conf | head -n 1 | sed "s/\[//g" | sed "s/\]//g")
		REMOTECRYPT=$(grep -v -e $REMOTEPLEX -e $REMOTE /root/.config/rclone/rclone.conf | grep "\[" | sed "s/\[//g" | sed "s/\]//g" | head -n 1)
		echo $REMOTEPLEX > /opt/seedbox/variables/remoteplex
		echo $REMOTECRYPT > /opt/seedbox/variables/remote

		ansible-playbook /opt/seedbox-compose/includes/config/roles/rclone/tasks/main.yml

		clear
		echo -e " ${BWHITE}* Remote chiffré rclone${NC} --> ${YELLOW}$REMOTECRYPT:${NC}"
		checking_errors $?
		echo ""
		echo -e " ${BWHITE}* Remote chiffré plexdrive${NC} --> ${YELLOW}$REMOTEPLEX:${NC}"
		checking_errors $?
		#var="Montage rclone en cours, merci de patienter..."
		#decompte 15
		#checking_errors $?
		echo ""
	else
		echo -e " ${YELLOW}* rclone est déjà installé !${NC}"
	fi
	echo ""
}

function unionfs_fuse() {
	echo -e "${BLUE}### Unionfs-Fuse ###${NC}"
	echo -e " ${BWHITE}* Installation Unionfs${NC}"
	ansible-playbook /opt/seedbox-compose/includes/config/roles/unionfs/tasks/main.yml
	checking_errors $?
	echo ""
}

function install_docker() {
	echo -e "${BLUE}### DOCKER ###${NC}"
	echo -e " ${BWHITE}* Installation Docker${NC}"
	file="/usr/bin/docker"
	if [ ! -e "$file" ]; then
		cp -r /usr/local/lib/python2.7/dist-packages/backports/ssl_match_hostname/ /usr/lib/python2.7/dist-packages/backports
		ansible-playbook /opt/seedbox-compose/includes/config/roles/docker/tasks/main.yml
	else
		echo -e " ${YELLOW}* docker est déjà installé !${NC}"
	fi
	echo ""
}

function define_parameters() {
	echo -e "${BLUE}### INFORMATIONS UTILISATEURS ###${NC}"
	mkdir -p $CONFDIR/variables
	create_user
	CONTACTEMAIL=$(whiptail --title "Adresse Email" --inputbox \
	"Merci de taper votre adresse Email :" 7 50 3>&1 1>&2 2>&3)
	echo $CONTACTEMAIL > $MAILFILE

	DOMAIN=$(whiptail --title "Votre nom de Domaine" --inputbox \
	"Merci de taper votre nom de Domaine (exemple: nomdedomaine.fr) :" 7 50 3>&1 1>&2 2>&3)
	echo $DOMAIN > $DOMAINFILE
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
		echo $PASSWORD > $CONFDIR/variables/pass
		egrep "^$SEEDUSER" /etc/passwd >/dev/null
		if [ $? -eq 0 ]; then
			echo -e " ${YELLOW}* L'utilisateur existe déjà !${NC}"
			USERID=$(id -u $SEEDUSER)
			GRPID=$(id -g $SEEDUSER)
			echo $USERID > $CONFDIR/variables/userid
			echo $GRPID > $CONFDIR/variables/groupid

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
			echo $USERID > $CONFDIR/variables/userid
			echo $GRPID > $CONFDIR/variables/groupid
		fi
		add_user_htpasswd $SEEDUSER $PASSWORD
		echo $SEEDUSER > $USERSFILE
		return
	else
		TMPGROUP=$(cat $GROUPFILE)
		if [[ "$TMPGROUP" == "" ]]; then
			SEEDGROUP=$(whiptail --title "Group" --inputbox \
        		"Création d'un groupe pour la Seedbox" 7 50 3>&1 1>&2 2>&3)
        	fi
	fi
}

function choose_services() {
	echo -e "${BLUE}### SERVICES ###${NC}"
	echo -e " ${BWHITE}--> Services en cours d'installation : ${NC}"

	menuservices="/tmp/menuservices.txt"
	if [[ -e "$menuservices" ]]; then
	rm /tmp/menuservices.txt
	fi

	for app in $(cat $SERVICESAVAILABLE);
	do
		service=$(echo $app | cut -d\- -f1)
		desc=$(echo $app | cut -d\- -f2)
		echo "$service $desc off" >> /tmp/menuservices.txt
	done
	SERVICESTOINSTALL=$(whiptail --title "Gestion des Applications" --checklist \
	"Appuyer sur la barre espace pour la sélection" 28 60 21 \
	$(cat /tmp/menuservices.txt) 3>&1 1>&2 2>&3)
	[[ "$?" = 1 ]] && script_plexdrive && rm /tmp/menuservices.txt;
	SERVICESPERUSER="$SERVICESUSER$SEEDUSER"
	touch $SERVICESPERUSER
	for APPDOCKER in $SERVICESTOINSTALL
	do
		echo -e "	${GREEN}* $(echo $APPDOCKER | tr -d '"')${NC}"
		echo $(echo ${APPDOCKER,,} | tr -d '"') >> $SERVICESPERUSER
	done
}

function webserver() {
	echo -e "${BLUE}### SERVICES ###${NC}"
	echo -e " ${BWHITE}--> Services en cours d'installation : ${NC}"
	for app in $(cat $WEBSERVERAVAILABLE);
	do
		service=$(echo $app | cut -d\- -f1)
		desc=$(echo $app | cut -d\- -f2)
		echo "$service $desc off" >> /tmp/menuservices.txt
	done
	SERVICESTOINSTALL=$(whiptail --title "Gestion Webserver" --checklist \
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
	rm /tmp/menuservices.txt
}

function choose_media_folder_classique() {
	echo -e "${BLUE}### DOSSIERS MEDIAS ###${NC}"
	echo -e " ${BWHITE}--> Création des dossiers Medias : ${NC}"
	SEEDUSER=$(cat /opt/seedbox/variables/users)
	mkdir -p /home/$SEEDUSER/filebot
	mkdir -p /home/$SEEDUSER/local/{Films,Series,Musiques,Animes}
	chown -R $SEEDUSER:$SEEDGROUP /home/$SEEDUSER
	chmod -R 755 /home/$SEEDUSER
	checking_errors $?
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
		chown -R $SEEDUSER:$SEEDGROUP /home/$SEEDUSER
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
	DOMAIN=$(cat /opt/seedbox/variables/domain)
	SEEDUSER=$(cat /opt/seedbox/variables/users)
	INSTALLEDFILE="/home/$SEEDUSER/resume"
	touch $INSTALLEDFILE > /dev/null 2>&1

	if [[ ! -d "$CONFDIR/conf" ]]; then
		mkdir -p $CONFDIR/conf > /dev/null 2>&1
	fi

	## préparation installation
	for line in $(cat $SERVICESPERUSER);
	do
		if [ $line = "nginx" ] || [ $line = "php5" ] || [ $line = "php7" ] || [ $line = "mariadb" ] || [ $line = "phpmyadmin" ] && [ -e "$CONFDIR/conf/$line.yml" ]; then
			ansible-playbook "$CONFDIR/conf/$line.yml"
				php=$(docker ps -a | awk '{print $NF}' | grep php)
				if [ "docker ps | grep php" ] && [ "$line" != "$php" ]; then
					ansible-playbook "$CONFDIR/conf/$php.yml"
				fi

		elif [ $line = "nginx" ] || [ $line = "php5" ] || [ $line = "php7" ] || [ $line = "mariadb" ] || [ $line = "phpmyadmin" ]; then
			ansible-playbook "$BASEDIR/includes/webserver/$line.yml"
			cp "$BASEDIR/includes/webserver/$line.yml" "$CONFDIR/conf/$line.yml" > /dev/null 2>&1

		elif [ -e "$CONFDIR/conf/$line.yml" ]; then
			ansible-playbook "$CONFDIR/conf/$line.yml"

		elif [[ "$line" == "plex" ]]; then
			echo -e "${BLUE}### CONFIG POST COMPOSE PLEX ###${NC}"
			echo -e " ${BWHITE}* Processing plex config file...${NC}"
			echo ""
			echo -e " ${GREEN}ATTENTION IMPORTANT - NE PAS FAIRE D'ERREUR - SINON DESINSTALLER ET REINSTALLER${NC}"
			. /opt/seedbox-compose/includes/config/roles/plex_autoscan/plex_token.sh > "/opt/seedbox/variables/token"
			ansible-playbook /opt/seedbox-compose/includes/config/roles/plex/tasks/main.yml

		else
			ansible-playbook "$BASEDIR/includes/dockerapps/$line.yml"
			cp "$BASEDIR/includes/dockerapps/$line.yml" "$CONFDIR/conf/$line.yml" > /dev/null 2>&1
		fi

		if [[ "$line" == "plex" ]] && [[ ! -d "/home/$SEEDUSER/scripts/plex_dupefinder" ]]; then
		plex_sections
		fi

		FQDNTMP="$line.$DOMAIN"
		echo "$FQDNTMP" >> $INSTALLEDFILE
		FQDNTMP=""
	done
	config_post_compose
}

function config_post_compose() {
for line in $(cat $SERVICESPERUSER);
do

		if [[ "$line" == "subsonic" ]]; then
		echo -e "${BLUE}### CONFIG POST COMPOSE SUBSONIC ###${NC}"
		echo -e " ${BWHITE}* Mise à jour subsonic...${NC}"
		docker exec subsonic update > /dev/null 2>&1
		docker restart subsonic > /dev/null 2>&1
		docker exec subsonic bash -c "echo '127.0.0.1 localhost.localdomain localhost subsonic.org' >> /etc/hosts"
		checking_errors $?
		echo ""
		echo -e "${BLUE}### SUBSONIC PREMIUM ###${NC}"
		echo -e "${BWHITE}	--> foo@bar.com${NC}"
		echo -e "${BWHITE}	--> f3ada405ce890b6f8204094deb12d8a8${NC}"
		echo ""
		fi

		if [[ "$line" == "seafile" ]]; then
		echo ""
		echo -e "${BLUE}### CONFIG POST COMPOSE SEAFILE ###${NC}"
		echo -e " ${BWHITE}* Configuration seafile...${NC}"
		echo ""
			echo -e "${CCYAN}-----------------------------------------------------------------------------------${CEND}"
			echo -e "${CGREEN}   1 ) Connexion: Votre mail et mot de passe             			    ${CEND}"
			echo -e "${CGREEN}   2 ) Administrateur Système/Paramètres:					    ${CEND}"
 			echo -e "${YELLOW}       - SERVICE_URL ---> https://seafile.domain.com				    ${CEND}"
			echo -e "${YELLOW}       - FILE_SERVER_ROOT ---> https://seafile.domaine.com/seafhttp		    ${CEND}"
			echo -e "${CGREEN}   3 ) Définir compte Admin							    ${CEND}"
			echo -e "${YELLOW}       - docker exec -it seafile /opt/seafile/seafile-server-latest/reset-admin.sh ${CEND}"
			echo -e "${CGREEN}   4 ) Déconnexion Seafile							    ${CEND}"
			echo -e "${CGREEN}   5 ) Reconnexion avec nouveau compte Admin					    ${CEND}"
			echo -e "${CCYAN}-----------------------------------------------------------------------------------${CEND}"
		echo ""
		echo -e "\nNoter les ${CCYAN}informations du dessus${CEND} et appuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
		read -r

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

function replace_media_compose() {
	MEDIASPERUSER="$MEDIASUSER$SEEDUSER"
	if [[ -e "$MEDIASPERUSER" ]]; then
		FILMS=$(grep -E 'Films' $MEDIASPERUSER)
		SERIES=$(grep -E 'Series' $MEDIASPERUSER)
		ANIMES=$(grep -E 'Animes' $MEDIASPERUSER)
		MUSIC=$(grep -E 'Musiques' $MEDIASPERUSER)
	fi
}

function plex_sections() {
			echo ""
			##compteur
			replace_media_compose
			var="Sections en cours de création, patientez..."
			PLEXDRIVE="/usr/bin/plexdrive"
			if [[ -e "$PLEXDRIVE" ]]; then
			echo -e "${BLUE}### CREATION DES BIBLIOTHEQUES PLEX ###${NC}"
			decompte 15

			## création des bibliothèques plex

			for x in $(cat $MEDIASPERUSER);
			do
				if [[ "$x" == "$ANIMES" ]]; then
					docker exec plex /usr/lib/plexmediaserver/Plex\ Media\ Scanner --add-section $x --type 2 --location /data/$x --lang fr
					echo -e "	${BWHITE}* $x ${NC}"
				
				elif [[ "$x" == "$SERIES" ]]; then
					docker exec plex /usr/lib/plexmediaserver/Plex\ Media\ Scanner --add-section $x --type 2 --location /data/$x --lang fr
					echo -e "	${BWHITE}* $x ${NC}"

				elif [[ "$x" == "$MUSIC" ]]; then
					docker exec plex /usr/lib/plexmediaserver/Plex\ Media\ Scanner --add-section $x --type 8 --location /data/$x --lang fr
					echo -e "	${BWHITE}* $x ${NC}"
				else
					docker exec plex /usr/lib/plexmediaserver/Plex\ Media\ Scanner --add-section $x --type 1 --location /data/$x --lang fr
					echo -e "	${BWHITE}* $x ${NC}"
				fi
			done
			echo ""

			## Installation plex_autoscan et cloudplow si install plexdrive
				## installation plex_autoscan
				plex_autoscan
				echo ""
				## installation cloudplow
				cloudplow	
			fi

			## installation plex_dupefinder
			echo ""
			plex_dupefinder
}

function valid_htpasswd() {
	if [[ -d "$CONFDIR" ]]; then
		HTFOLDER="$CONFDIR/passwd/"
		mkdir -p $HTFOLDER
		HTTEMPFOLDER="/tmp/"
		HTFILE=".htpasswd-$SEEDUSER"
		cat "$HTTEMPFOLDER$HTFILE" >> "$HTFOLDER$HTFILE"
		cd $HTFOLDER
		touch login
		echo "$HTUSER $HTPASSWORD" >> "$HTFOLDER/login"
		rm "$HTTEMPFOLDER$HTFILE"
	fi
}

function manage_apps() {
	echo -e "${BLUE}##########################################${NC}"
	echo -e "${BLUE}###          GESTION DES APPLIS        ###${NC}"
	echo -e "${BLUE}##########################################${NC}"
	DOMAIN=$(cat /opt/seedbox/variables/domain)
	SEEDUSER=$(cat /opt/seedbox/variables/users)
	USERRESUMEFILE="/home/$SEEDUSER/resume"
	echo ""
	echo -e "${GREEN}### Gestion des Applis pour: $SEEDUSER ###${NC}"
	echo -e " ${BWHITE}* Resume file: $USERRESUMEFILE${NC}"
	echo ""
	## CHOOSE AN ACTION FOR APPS
	ACTIONONAPP=$(whiptail --title "App Manager" --menu \
	                "Selectionner une action :" 12 50 4 \
	                "1" "Ajout Docker Applis"  \
	                "2" "Supprimer une Appli"  \
			"3" "Réinitialisation Container" \
 			"4" "Installation Serveur Web" 3>&1 1>&2 2>&3)
	[[ "$?" = 1 ]] && script_plexdrive;
	case $ACTIONONAPP in
		"1" ) ## Ajout APP
			choose_services
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
			        SERVICE=$(echo $SERVICEACTIVATED | cut -d\. -f1)
			        TABSERVICES+=( ${SERVICE//\"} " " )
			done
			APPSELECTED=$(whiptail --title "App Manager" --menu \
			              "Sélectionner l'Appli à supprimer" 19 45 11 \
			              "${TABSERVICES[@]}"  3>&1 1>&2 2>&3)
			[[ "$?" = 1 ]] && script_plexdrive;
			echo -e " ${GREEN}   * $APPSELECTED${NC}"
			docker rm -f "$APPSELECTED"
			sed -i "/$APPSELECTED/d" /home/$SEEDUSER/resume
			rm -rf /opt/seedbox/docker/$SEEDUSER/$APPSELECTED

			if [[ "$APPSELECTED" != "plex" ]]; then
			rm $CONFDIR/conf/$APPSELECTED.yml
			fi

			if [[ "$APPSELECTED" = "seafile" ]]; then
			rm -rf /opt/seedbox/docker/$SEEDUSER/mariadb
			docker rm -f db memcached 
			fi

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
			echo -e " ${BWHITE}* Les fichiers de configuration ne seront pas effacés${NC}"
			TABSERVICES=()
			for SERVICEACTIVATED in $(cat $USERRESUMEFILE)
			do
			        SERVICE=$(echo $SERVICEACTIVATED | cut -d\. -f1)
			        TABSERVICES+=( ${SERVICE//\"} " " )
			done
			line=$(whiptail --title "App Manager" --menu \
			              "Sélectionner le container à réinitialiser" 19 45 11 \
			              "${TABSERVICES[@]}"  3>&1 1>&2 2>&3)
			[[ "$?" = 1 ]] && script_plexdrive;
			echo -e " ${GREEN}   * $line${NC}"

			if [ $line = "php5" ] || [ $line = "php7" ]; then
				image=$(docker images | grep "php" | awk '{print $3}')
			elif [ $line = "sonarr3" ]; then
				image=$(docker images | grep "sonarr" | awk '{print $3}')
			else
				image=$(docker images | grep "$line" | awk '{print $3}')
			fi

			docker rm -f "$line" > /dev/null 2>&1
			docker rmi $image
			echo ""
			sed -i "/$line/d" /home/$SEEDUSER/resume
			echo $line >> $SERVICESPERUSER

			install_services
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
		"4" ) 	## Installation webserver
			var="/tmp/menuservices.txt"

			if [[ -e "$var" ]]; then
				rm $var
			fi
			webserver
			install_services
			echo ""
			echo -e "${CCYAN}#######################################################################################${CEND}"
			echo ""
			echo -e "${GREEN}        		SERVEUR WEB INSTALLE AVEC SUCCES                                ${CEND}"
			echo ""
			echo -e "${CCYAN}#######################################################################################${CEND}"
			echo ""
			echo -e "${GREEN}        		PENSEZ A CHANGER LE MOT DE PASSE MYSQL                          ${CEND}"
			echo ""
			echo -e "${CCYAN}#######################################################################################${CEND}"
			echo ""
			echo -e "${GREEN}        	PAR DEFAUT root:mysql    DOSSIER POUR LES SITES /var/www                $CEND}"
			echo ""
			echo -e "${CCYAN}#######################################################################################${CEND}"
			echo ""
			rm -Rf $SERVICESPERUSER > /dev/null 2>&1
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
		ACCESSDOMAIN=$(echo $line)
		DOCKERAPP=$(echo $line | cut -d\. -f1)
		echo -e "	--> ${BWHITE}$DOCKERAPP${NC} --> ${YELLOW}$ACCESSDOMAIN${NC}"
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

	## variables
	SEEDUSER=$(cat /opt/seedbox/variables/users)
	USERHOMEDIR="/home/$SEEDUSER"
	SEEDGROUP=$(cat $GROUPFILE)
	PLEXDRIVE="/usr/bin/plexdrive"

	if [[ -e "$PLEXDRIVE" ]]; then
		echo -e " ${BWHITE}* Suppression Plexdrive${NC}"
		service plexdrive stop > /dev/null 2>&1
		rm /etc/systemd/system/plexdrive.service > /dev/null 2>&1
		rm -rf /mnt/plexdrive > /dev/null 2>&1
		rm -rf /root/.plexdrive > /dev/null 2>&1
		rm /usr/bin/plexdrive > /dev/null 2>&1
		checking_errors $?

		echo -e " ${BWHITE}* Suppression plex_autoscan${NC}"
		systemctl stop plex_autoscan.service > /dev/null 2>&1
		systemctl disable plex_autoscan.service > /dev/null 2>&1
		rm /etc/systemd/system/plex_autoscan.service > /dev/null 2>&1
		checking_errors $?

		echo -e " ${BWHITE}* Suppression rclone${NC}"
		systemctl stop rclone.service > /dev/null 2>&1
		systemctl disable rclone.service > /dev/null 2>&1
		rm /etc/systemd/system/rclone.service > /dev/null 2>&1
		rm /usr/bin/rclone > /dev/null 2>&1
		rm -rf /mnt/rclone > /dev/null 2>&1
		rm -rf /root/.config/rclone > /dev/null 2>&1
		checking_errors $?

		echo -e " ${BWHITE}* Suppression cloudplow${NC}"
		systemctl stop cloudplow.service > /dev/null 2>&1
		systemctl disable cloudplow.service > /dev/null 2>&1
		rm /etc/systemd/system/cloudplow.service > /dev/null 2>&1
		checking_errors $?

		echo -e " ${BWHITE}* Suppression unionfs/mergerfs${NC}"
		service unionfs stop > /dev/null 2>&1
		systemctl disable unionfs.service > /dev/null 2>&1
		rm /etc/systemd/system/unionfs.service > /dev/null 2>&1
			
		service mergerfs stop > /dev/null 2>&1
		systemctl disable mergerfs.service > /dev/null 2>&1
		rm /etc/systemd/system/mergerfs.service > /dev/null 2>&1
		checking_errors $?
	fi

	echo -e " ${BWHITE}* Suppression user: $SEEDUSER...${NC}"
	userdel -rf $SEEDUSER > /dev/null 2>&1
	checking_errors $?

	echo -e " ${BWHITE}* Suppression home $SEEDUSER...${NC}"
	rm -Rf $USERHOMEDIR > /dev/null 2>&1
	checking_errors $?
	echo ""

	echo -e " ${BWHITE}* Suppression Containers...${NC}"
	docker rm -f $(docker ps -aq) > /dev/null 2>&1
	docker volume rm $(docker volume ls -qf "dangling=true") > /dev/null 2>&1
	checking_errors $?

	echo -e " ${BWHITE}* Suppression group...${NC}"
	groupdel $SEEDGROUP > /dev/null 2>&1
	checking_errors $?

	echo -e " ${BWHITE}* Supression du dossier /opt/seedbox...${NC}"
	rm -Rf $CONFDIR
	checking_errors $?

	pause
}

function pause() {
	echo ""
	echo -e "${YELLOW}###  -->APPUYER SUR ENTREE POUR CONTINUER<--  ###${NC}"
	read
	echo ""
}
