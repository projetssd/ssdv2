#!/bin/bash

function logo() {

color1='\033[1;31m'    # light red
color2='\033[1;35m'    # light purple
color3='\033[0;33m'    # light yellow
nocolor='\033[0m'      # no color
companyname='\033[1;34mPour Christophe\033[0m'
divisionname='\033[1;32mDe la part de Patrick\033[0m'
descriptif='\033[1;31mHeimdall - Syncthing - sonerezh - Portainer - Nextcloud - Lidarr\033[0m'
appli='\033[0;36mPlex - Sonarr - Medusa - Rtorrent - Radarr - Jackett - Pyload - Traefik\033[0m'



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

function rclone_aide() {
echo ""
echo -e "${CCYAN}### TRES IMPORTANT - RESPECTER L ORDRE D AFFICHAGE DES REMOTES ###${NC}"
echo ""
echo -e "    ${YELLOW}1) Remote non chiffré${NC}"
echo -e "    ${YELLOW}2) Remote chiffré Plexdrive${NC}"
echo -e "    ${YELLOW}3) Remote chiffré Rclone${NC}"
echo ""
echo -e "${BWHITE}[remote non chiffré]${NC}"
echo -e "${CGREEN}type = drive${CEND}"
echo -e "${CGREEN}token = {"access_token":"XXXXXXXXXXXX"}${CEND}"
echo ""
echo -e "${BWHITE}[remote_chiffré_plexdrive]${NC}"
echo -e "${CGREEN}type = crypt${CEND}"
echo -e "${CGREEN}remote = /mnt/plexdrive/Media${CEND}"
echo -e "${CGREEN}filename_encryption = standard${CEND}"
echo -e "${CGREEN}password = -XXXXXXXXXXXXXXXXXX${CEND}"
echo -e "${CGREEN}password2 = XXXXXXXXXXXXXXXXXXXX${CEND}"
echo ""
echo -e "${BWHITE}[remote_chiffré_rclone]${NC}"
echo -e "${CGREEN}type = crypt${CEND}"
echo -e "${CGREEN}remote = ${CEND}${BWHITE}<remote non chiffré>:${NC}${CGREEN}Media${CEND}"
echo -e "${CGREEN}filename_encryption = standard${CEND}"
echo -e "${CGREEN}password = XXXXXXXXXXXXXXX${CEND}"
echo -e "${CGREEN}password2 = XXXXXXXXXXXXXXX${CEND}"
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
	whiptail --title "Base Package" --msgbox "Seedbox-Compose va maintenant installer les Pré-Requis et vérifier la mise à jour du système" 10 60
	echo -e " ${BWHITE}* Installation apache2-utils, unzip, git, curl ...${NC}"
	{
	NUMPACKAGES=$(cat $PACKAGESFILE | wc -l)
	for package in $(cat $PACKAGESFILE);
	do
		apt-get install -y $package
		echo $NUMPACKAGES
		NUMPACKAGES=$(($NUMPACKAGES+(100/$NUMPACKAGES)))
	done
	} | whiptail --gauge "Merci de patienter pendant l'installation des packages !" 6 70 0
	checking_errors $?
	echo ""
}

function checking_system() {
	echo -e "${BLUE}### VERIFICATION SYSTEME ###${NC}"
	echo -e " ${BWHITE}* Vérification du système OS${NC}"
	TMPSYSTEM=$(gawk -F= '/^NAME/{print $2}' /etc/os-release)
	TMPCODENAME=$(lsb_release -sc)
	TMPRELEASE=$(cat /etc/debian_version)
	if [[ $(echo $TMPSYSTEM | sed 's/\"//g') == "Debian GNU/Linux" ]]; then
		SYSTEMOS="Debian"
		if [[ $(echo $TMPRELEASE | grep "7") != "" ]]; then
			SYSTEMRELEASE="7"
			SYSTEMCODENAME="wheezy"
		elif [[ $(echo $TMPRELEASE | grep "8") != "" ]]; then
			SYSTEMRELEASE="8"
			SYSTEMCODENAME="jessie"
		elif [[ $(echo $TMPRELEASE | grep "9") != "" ]]; then
			SYSTEMRELEASE="9"
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
		fi
	fi
	echo -e "	${YELLOW}--> System OS : $SYSTEMOS${NC}"
	echo -e "	${YELLOW}--> Release : $SYSTEMRELEASE${NC}"
	echo -e "	${YELLOW}--> Codename : $SYSTEMCODENAME${NC}"
	echo -e " ${BWHITE}* Updating & upgrading system${NC}"
	apt-get update > /dev/null 2>&1
	apt-get upgrade -y > /dev/null 2>&1
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

function install_traefik() {
	echo -e "${BLUE}### TRAEFIK ###${NC}"
	TRAEFIK="$CONFDIR/docker/traefik/"
	TRAEFIKCOMPOSEFILE="$TRAEFIK/docker-compose.yml"
	TRAEFIKTOML="$TRAEFIK/traefik.toml"
	INSTALLEDFILE="$CONFDIR/resume"
	if [[ ! -f "$INSTALLEDFILE" ]]; then
	touch $INSTALLEDFILE> /dev/null 2>&1
	fi

	if [[ ! -d "$TRAEFIK" ]]; then
		echo -e " ${BWHITE}* Installation Traefik${NC}"
		mkdir -p $TRAEFIK
		touch $TRAEFIKCOMPOSEFILE
		touch $TRAEFIKTOML
		cat "/opt/seedbox-compose/includes/dockerapps/traefik.yml" >> $TRAEFIKCOMPOSEFILE
		cat "/opt/seedbox-compose/includes/dockerapps/traefik.toml" >> $TRAEFIKTOML
		sed -i "s|%DOMAIN%|$DOMAIN|g" $TRAEFIKCOMPOSEFILE
		sed -i "s|%TRAEFIK%|$TRAEFIK|g" $TRAEFIKCOMPOSEFILE
		sed -i "s|%EMAIL%|$CONTACTEMAIL|g" $TRAEFIKTOML
		sed -i "s|%DOMAIN%|$DOMAIN|g" $TRAEFIKTOML
		sed -i "s|%VAR%|$VAR|g" $TRAEFIKCOMPOSEFILE
		cd $TRAEFIK
		docker network create traefik_proxy > /dev/null 2>&1
		docker-compose up -d > /dev/null 2>&1
		echo "traefik-port-traefik.$DOMAIN" >> $INSTALLEDFILE
		checking_errors $?
	else
		echo -e " ${YELLOW}* Traefik est déjà installé !${NC}"
	fi
	echo ""
}

function install_portainer() {
	echo -e "${BLUE}### PORTAINER ###${NC}"
	INSTALLEDFILE="$CONFDIR/resume"
	if [[ ! -f "$INSTALLEDFILE" ]]; then
	touch $INSTALLEDFILE> /dev/null 2>&1
	fi
	PORTAINER="$CONFDIR/docker/portainer/"
	PORTAINERCOMPOSEFILE="$PORTAINER/docker-compose.yml"

	if [[ ! -d "$PORTAINER" ]]; then
		mkdir -p $PORTAINER
		touch $PORTAINERCOMPOSEFILE

		if (whiptail --title "Docker Portainer" --yesno "Voulez vous installer portainer" 7 50) then
			echo -e " ${BWHITE}* Installation de portainer !${NC}"
			cat /opt/seedbox-compose/includes/dockerapps/head.docker > $PORTAINERCOMPOSEFILE
			cat "/opt/seedbox-compose/includes/dockerapps/portainer.yml" >> $PORTAINERCOMPOSEFILE
			cat /opt/seedbox-compose/includes/dockerapps/foot.docker >> $PORTAINERCOMPOSEFILE
			sed -i "s|%DOMAIN%|$DOMAIN|g" $PORTAINERCOMPOSEFILE
			sed -i "s|%PORTAINER%|$PORTAINER|g" $PORTAINERCOMPOSEFILE
			cd $PORTAINER
			docker-compose up -d > /dev/null 2>&1
			echo "portainer-port-portainer.$DOMAIN" >> $INSTALLEDFILE
			checking_errors $?
		else
			echo -e " ${BWHITE}--> portainer n'est pas installé !${NC}"
		fi
	else
		echo -e " ${BWHITE}--> portainer est déjà installé !${NC}"
	fi
	echo ""
}

function install_watchtower() {
	echo -e "${BLUE}### WATCHTOWER ###${NC}"
	INSTALLEDFILE="$CONFDIR/resume"
	if [[ ! -f "$INSTALLEDFILE" ]]; then
	touch $INSTALLEDFILE> /dev/null 2>&1
	fi
	WATCHTOWER="$CONFDIR/docker/watchtower/"
	WATCHTOWERCOMPOSEFILE="$WATCHTOWER/docker-compose.yml"

	if [[ ! -d "$WATCHTOWER" ]]; then
		mkdir -p $WATCHTOWER
		touch $WATCHTOWERCOMPOSEFILE

		if (whiptail --title "Docker watchtower" --yesno "Voulez vous installer watchtower" 7 50) then
			echo -e " ${BWHITE}* Installation de portainer !${NC}"
			cat /opt/seedbox-compose/includes/dockerapps/head.docker > $WATCHTOWERCOMPOSEFILE
			cat "/opt/seedbox-compose/includes/dockerapps/watchtower.yml" >> $WATCHTOWERCOMPOSEFILE
			cat /opt/seedbox-compose/includes/dockerapps/foot.docker >> $WATCHTOWERCOMPOSEFILE
			sed -i "s|%DOMAIN%|$DOMAIN|g" $WATCHTOWERCOMPOSEFILE
			sed -i "s|%PORTAINER%|$PORTAINER|g" $WATCHTOWERCOMPOSEFILE
			cd $WATCHTOWER
			docker-compose up -d > /dev/null 2>&1
			checking_errors $?
		else
			echo -e " ${BWHITE}--> watchtower n'est pas installé !${NC}"
		fi
	else
		echo -e " ${BWHITE}--> watchtower est déjà installé !${NC}"
	fi
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
		echo -e " ${YELLOW}* Une fois la configuration Plexdrive terminée, tapez ${NC}${CPURPLE}CTRL + C${NC}${YELLOW} pour poursuivre le script !${NC}"
		echo ""
		plexdrive mount -c /root/.plexdrive -o allow_other /mnt/plexdrive
		cp "$BASEDIR/includes/config/plexdrive.service" "/etc/systemd/system/plexdrive.service" > /dev/null 2>&1
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
		REMOTEPLEX=$(grep -iC 2 "/mnt/plexdrive" /root/.config/rclone/rclone.conf | head -n 1 | sed "s/\[//g" | sed "s/\]//g")
		REMOTECRYPT=$(grep "\[" /root/.config/rclone/rclone.conf | sed -n 3p | sed "s/\]//g" | sed "s/\[//g")
		clear
		echo -e " ${BWHITE}* Remote chiffré rclone${NC} --> ${YELLOW}$REMOTECRYPT:${NC}"
		checking_errors $?
		echo ""
		echo -e " ${BWHITE}* Remote chiffré plexdrive${NC} --> ${YELLOW}$REMOTEPLEX:${NC}"
		checking_errors $?
		echo ""
		cp "$BASEDIR/includes/config/rclone.service" "/etc/systemd/system/rclone.service" > /dev/null 2>&1
		sed -i "s|%REMOTEPLEX%|$REMOTEPLEX:|g" /etc/systemd/system/rclone.service
		systemctl daemon-reload > /dev/null 2>&1
		systemctl enable rclone.service > /dev/null 2>&1
		service rclone start
		echo -e " ${BWHITE}* Montage rclone en cours, merci de patienter... ${NC}"
		sleep 15
		checking_errors $?
	else
		REMOTEPLEX=$(grep -iC 2 "/mnt/plexdrive" /root/.config/rclone/rclone.conf | head -n 1 | sed "s/\[//g" | sed "s/\]//g")
		REMOTECRYPT=$(grep "\[" /root/.config/rclone/rclone.conf | sed -n 3p | sed "s/\]//g" | sed "s/\[//g")
		clear
		echo -e " ${BWHITE}* Remote chiffré rclone${NC} --> ${YELLOW}$REMOTECRYPT:${NC}"
		checking_errors $?
		echo ""
		echo -e " ${BWHITE}* Remote chiffré plexdrive${NC} --> ${YELLOW}$REMOTEPLEX:${NC}"
		checking_errors $?
		echo ""
		cp "$BASEDIR/includes/config/rclone.service" "/etc/systemd/system/rclone.service" > /dev/null 2>&1
		sed -i "s|%REMOTEPLEX%|$REMOTEPLEX:|g" /etc/systemd/system/rclone.service
		systemctl daemon-reload > /dev/null 2>&1
		systemctl enable rclone.service > /dev/null 2>&1
		service rclone start
		echo -e " ${BWHITE}* Montage rclone en cours, merci de patienter... ${NC}"
		sleep 15
		checking_errors $?
	fi
	echo ""
}

function unionfs_fuse() {
	echo -e "${BLUE}### Unionfs-Fuse ###${NC}"
	UNIONFS="/etc/systemd/system/unionfs-$SEEDUSER.service"
	if [[ ! -e "$UNIONFS" ]]; then
		echo -e " ${BWHITE}* Installation Unionfs${NC}"
		cp "$BASEDIR/includes/config/unionfs.service" "/etc/systemd/system/unionfs-$SEEDUSER.service" > /dev/null 2>&1
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
		curl -fsSL https://get.docker.com -o get-docker.sh
		sh get-docker.sh
		if [[ "$?" == "0" ]]; then
			echo -e "	${GREEN}* Installation Docker réussie${NC}"
		else
			echo -e "	${RED}* Echec de l'installation Docker !${NC}"
		fi
		service docker start > /dev/null 2>&1
		echo " * Installing Docker-compose"
		curl -L "https://github.com/docker/compose/releases/download/1.23.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
		chmod +x /usr/local/bin/docker-compose
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

function install_cloudplow() {
	echo -e "${BLUE}### CLOUDPLOW ###${NC}"
	echo -e " ${BWHITE}* Installation cloudplow${NC}"

	## install cloudplow
	git clone https://github.com/l3uddz/cloudplow /home/$SEEDUSER/cloudplow > /dev/null 2>&1
	chown -R $SEEDUSER:$SEEDGROUP /home/$SEEDUSER/cloudplow
	cd /home/$SEEDUSER/cloudplow
	python3 -m pip install -r requirements.txt > /dev/null 2>&1
	mv /home/$SEEDUSER/cloudplow/config.json.sample /home/$SEEDUSER/cloudplow/config.json

	## récupération des variables
	SEEDGROUP=$(cat $GROUPFILE)
	docker ps | grep -q plex-$SEEDUSER
	if [ $? = 0 ]; then
	docker exec -ti plex-$SEEDUSER grep -E -o "PlexOnlineToken=.{0,22}" /config/Library/Application\ Support/Plex\ Media\ Server/Preferences.xml > /home/$SEEDUSER/token.txt
	TOKEN=$(grep PlexOnlineToken /home/$SEEDUSER/token.txt | cut -d '=' -f2 | cut -c2-21)
	NOMBRE=$(sed -n "/$SEEDUSER/=" $CONFDIR/users)
			if [ $NOMBRE -le 1 ] ; then
				ACCESSDOMAIN=$(grep plex $INSTALLEDFILE | cut -d\- -f3)
			else
				ACCESSDOMAIN=$(grep plex $INSTALLEDFILE | cut -d\- -f3-4)
			fi
	fi

	REMOTECRYPT=$(grep "\[" /root/.config/rclone/rclone.conf | sed -n 3p | sed "s/\]//g" | sed "s/\[//g")


	## intégration des variables dans config.json
	CLOUDPLOW="/home/$SEEDUSER/cloudplow/config.json"
	cat "$BASEDIR/includes/config/cloudplow/config.json" > $CLOUDPLOW
	sed -i "s|%SEEDUSER%|$SEEDUSER|g" $CLOUDPLOW
	sed -i "s|%SEEDGROUP%|$SEEDGROUP|g" $CLOUDPLOW
	sed -i "s|%TOKEN%|$TOKEN|g" $CLOUDPLOW
	sed -i "s|%ACCESSDOMAIN%|$ACCESSDOMAIN|g" $CLOUDPLOW
	sed -i "s|%REMOTECRYPT%|$REMOTECRYPT|g" $CLOUDPLOW

	## configuration cloudplow.service
	cp "$BASEDIR/includes/config/cloudplow.service" "/etc/systemd/system/cloudplow-$SEEDUSER.service" > /dev/null 2>&1
	sed -i "s|%SEEDUSER%|$SEEDUSER|g" /etc/systemd/system/cloudplow-$SEEDUSER.service
	sed -i "s|%SEEDGROUP%|$SEEDGROUP|g" /etc/systemd/system/cloudplow-$SEEDUSER.service
	systemctl daemon-reload > /dev/null 2>&1
	systemctl enable cloudplow-$SEEDUSER.service > /dev/null 2>&1
	systemctl start cloudplow-$SEEDUSER.service > /dev/null 2>&1
	checking_errors $?
	echo ""
}

function install_plex_autoscan() {
	echo -e "${BLUE}### PLEX_AUTOSCAN ###${NC}"
	echo -e " ${BWHITE}* Installation plex_autoscan${NC}"

	## install plex_autoscan
	SEEDGROUP=$(cat $GROUPFILE)
	git clone https://github.com/l3uddz/plex_autoscan /home/$SEEDUSER/plex_autoscan > /dev/null 2>&1
	chown -R $SEEDUSER:$SEEDGROUP /home/$SEEDUSER/plex_autoscan
	cd /home/$SEEDUSER/plex_autoscan
	python -m pip install -r requirements.txt > /dev/null 2>&1

	## configuration plex_autoscan.service
	cp "$BASEDIR/includes/config/plex_autoscan/plex_autoscan.service" "/etc/systemd/system/plex_autoscan-$SEEDUSER.service" > /dev/null 2>&1
	sed -i "s|%SEEDUSER%|$SEEDUSER|g" /etc/systemd/system/plex_autoscan-$SEEDUSER.service
	sed -i "s|%SEEDGROUP%|$SEEDGROUP|g" /etc/systemd/system/plex_autoscan-$SEEDUSER.service
	systemctl daemon-reload > /dev/null 2>&1
	systemctl enable plex_autoscan-$SEEDUSER.service > /dev/null 2>&1
	checking_errors $?
	echo ""
}

function define_parameters() {
	echo -e "${BLUE}### INFORMATIONS UTILISATEURS ###${NC}"
	USEDOMAIN="y"
	CURRTIMEZONE=$(cat /etc/timezone)
	create_user
	CONTACTEMAIL=$(whiptail --title "Adresse Email" --inputbox \
	"Merci de taper votre adresse Email :" 7 50 3>&1 1>&2 2>&3)
	TIMEZONEDEF=$(whiptail --title "Timezone" --inputbox \
	"Merci de vérifier votre timezone" 7 66 "$CURRTIMEZONE" \
	3>&1 1>&2 2>&3)
	if [[ $TIMEZONEDEF == "" ]]; then
		TIMEZONE=$CURRTIMEZONE
	else
		TIMEZONE=$TIMEZONEDEF
	fi
	DOMAIN=$(whiptail --title "Votre nom de Domaine" --inputbox \
	"Merci de taper votre nom de Domaine :" 7 50 3>&1 1>&2 2>&3)
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
		PASSWORD=$(whiptail --title "Password" --passwordbox \
			"Mot de passe :" 7 50 3>&1 1>&2 2>&3)
		egrep "^$SEEDUSER" /etc/passwd >/dev/null
		if [ $? -eq 0 ]; then
			echo -e " ${YELLOW}* L'utilisateur existe déjà !${NC}"
			USERID=$(id -u $SEEDUSER)
			GRPID=$(id -g $SEEDUSER)
			echo -e " ${BWHITE}* Ajout de $SEEDUSER in $SEEDGROUP"
			usermod -a -G $SEEDGROUP $SEEDUSER
			checking_errors $?
		else
			PASS=$(perl -e 'print crypt($ARGV[0], "password")' $PASSWORD)
			echo -e " ${BWHITE}* Ajout de $SEEDUSER au système"
			useradd -g $SEEDGROUP -p $PASS -s /bin/false $SEEDUSER > /dev/null 2>&1
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
	PASSWORD=$(whiptail --title "Password" --passwordbox \
		"Mot de passe :" 7 50 3>&1 1>&2 2>&3)
	egrep "^$SEEDUSER" /etc/passwd >/dev/null
	if [ $? -eq 0 ]; then
		echo -e " ${YELLOW}* L'utilisateur existe déjà !${NC}"
		USERID=$(id -u $SEEDUSER)
		GRPID=$(id -g $SEEDUSER)
		echo -e " ${BWHITE}* Ajout de $SEEDUSER in $SEEDGROUP"
		usermod -a -G $SEEDGROUP $SEEDUSER
		checking_errors $?
	else
		PASS=$(perl -e 'print crypt($ARGV[0], "password")' $PASSWORD)
		echo -e " ${BWHITE}* Ajout de $SEEDUSER au système"
		useradd -m -g $SEEDGROUP -p $PASS -s /bin/false $SEEDUSER > /dev/null 2>&1
		checking_errors $?
		USERID=$(id -u $SEEDUSER)
		GRPID=$(id -g $SEEDUSER)
	fi
	add_user_htpasswd $SEEDUSER $PASSWORD
	echo $SEEDUSER >> $USERSFILE
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
		echo $(echo ${MEDDOCKER,,} | tr -d '"') >> $MEDIASPERUSER
	done
	for line in $(cat $MEDIASPERUSER);
	do
	line=$(echo $line | sed 's/\(.\)/\U\1/')
	mkdir -p /home/$SEEDUSER/Medias/$line
	done
	rm /tmp/menumedia.txt
	echo ""
}

function choose_media_folder_plexdrive() {
	echo -e "${BLUE}### DOSSIERS MEDIAS ###${NC}"
	FOLDER="/mnt/rclone/$SEEDUSER"
	if [[ -d "$FOLDER" ]]; then
		cd /mnt/rclone/$SEEDUSER
		ls -Ad */ | sed 's,/$,,g' > /home/media.txt
		mkdir -p /home/$SEEDUSER/Medias
		echo -e " ${BWHITE}--> Récupération des dossiers Utilisateur à partir de Gdrive... : ${NC}"
		for line in $(cat /home/media.txt);
		do
		mkdir -p /home/$SEEDUSER/local/$line
		echo -e "	${GREEN}--> Le dossier ${NC}${YELLOW}$line${NC}${GREEN} a été ajouté avec succès !${NC}"
		done
	else
		mkdir -p /mnt/rclone/$SEEDUSER
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
			echo $(echo ${MEDDOCKER,,} | tr -d '"') >> $MEDIASPERUSER
		done
		for line in $(cat $MEDIASPERUSER);
		do
		line=$(echo $line | sed 's/\(.\)/\U\1/')
		mkdir -p /home/$SEEDUSER/local/$line
		mkdir -p /mnt/rclone/$SEEDUSER/$line 
		done
		rm /tmp/menumedia.txt
	fi
	echo ""
	MEDIA="/home/media.txt"
	if [[ -e "$MEDIA" ]]; then
		rm /home/media.txt
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
	USERID=$(id -u $SEEDUSER)
	GRPID=$(id -g $SEEDUSER)
	INSTALLEDFILE="/home/$SEEDUSER/resume"
	touch $INSTALLEDFILE > /dev/null 2>&1

	## port rtorrent
	if [[ -f "$FILEPORTPATH" ]]; then
		declare -i PORT=$(cat $FILEPORTPATH | tail -1)
	else
		declare -i PORT=$FIRSTPORT
	fi

	## poRt plex
	if [[ -f "$PLEXPORTPATH" ]]; then
		declare -i PORTPLEX=$(cat $PLEXPORTPATH | tail -1)
	else
		declare -i PORTPLEX=32400
	fi

	## préparation du docker-compose
	DOCKERCOMPOSEFILE="/home/$SEEDUSER/docker-compose.yml"
	if [[ ! -f "$DOCKERCOMPOSEFILE" ]]; then
	cat /opt/seedbox-compose/includes/dockerapps/head.docker > $DOCKERCOMPOSEFILE
	cat /opt/seedbox-compose/includes/dockerapps/foot.docker >> $DOCKERCOMPOSEFILE
	fi
	for line in $(cat $SERVICESPERUSER);
	do
		sed -i -n -e :a -e '1,5!{P;N;D;};N;ba' $DOCKERCOMPOSEFILE
		cat "/opt/seedbox-compose/includes/dockerapps/$line.yml" >> $DOCKERCOMPOSEFILE
		sed -i "s|%TIMEZONE%|$TIMEZONE|g" $DOCKERCOMPOSEFILE
		sed -i "s|%UID%|$USERID|g" $DOCKERCOMPOSEFILE
		sed -i "s|%GID%|$GRPID|g" $DOCKERCOMPOSEFILE
		sed -i "s|%PORT%|$PORT|g" $DOCKERCOMPOSEFILE
		sed -i "s|%PORTPLEX%|$PORTPLEX|g" $DOCKERCOMPOSEFILE
		sed -i "s|%VAR%|$VAR|g" $DOCKERCOMPOSEFILE
		sed -i "s|%DOMAIN%|$DOMAIN|g" $DOCKERCOMPOSEFILE
		sed -i "s|%USER%|$SEEDUSER|g" $DOCKERCOMPOSEFILE
		sed -i "s|%EMAIL%|$CONTACTEMAIL|g" $DOCKERCOMPOSEFILE
		cat /opt/seedbox-compose/includes/dockerapps/foot.docker >> $DOCKERCOMPOSEFILE
		NOMBRE=$(sed -n "/$SEEDUSER/=" $CONFDIR/users)
		if [ $NOMBRE -le 2 ] ; then
			FQDNTMP="$line.$DOMAIN"
		else
			FQDNTMP="$line-$SEEDUSER.$DOMAIN"
		fi
		FQDN=$(whiptail --title "SSL Subdomain" --inputbox \
		"Souhaitez vous utiliser un autre Sous Domaine pour $line ? default :" 7 75 "$FQDNTMP" 3>&1 1>&2 2>&3)
		ACCESSURL=$FQDN
		TRAEFIKURL=(Host:$ACCESSURL)
		sed -i "s|%TRAEFIKURL%|$TRAEFIKURL|g" /home/$SEEDUSER/docker-compose.yml
		check_domain $ACCESSURL
		echo "$line-$PORT-$FQDN" >> $INSTALLEDFILE
		URI="/"
	
		PORT=$PORT+1
		PORTPLEX=$PORTPLEX+1
		FQDN=""
		FQDNTMP=""
	done
	echo $PORT >> $FILEPORTPATH
	echo $PORTPLEX >> $PLEXPORTPATH
	echo ""
}

function docker_compose() {
	echo -e "${BLUE}### DOCKERCOMPOSE ###${NC}"
	ACTDIR="$PWD"
	cd /home/$SEEDUSER/
	echo -e " ${BWHITE}* Docker-composing, Merci de patienter...${NC}"
	docker-compose up -d > /dev/null 2>&1
	checking_errors $?
	echo ""
	cd $ACTDIR
	config_post_compose
}

function config_post_compose() {
for line in $(cat $SERVICESPERUSER);
do
		if [[ "$line" == "plex" ]]; then
			echo -e "${BLUE}### CONFIG POST COMPOSE PLEX ###${NC}"
			echo -e " ${BWHITE}* Processing plex config file...${NC}"
			PLEXDRIVE="/usr/bin/plexdrive"
			cd /home/$SEEDUSER
			# CLAIM pour Plex
			echo ""
			echo -e " ${BWHITE}* Un token est nécéssaire pour AUTHENTIFIER le serveur Plex ${NC}"
			echo -e " ${BWHITE}* Pour obtenir un identifiant CLAIM, allez à cette adresse et copier le dans le terminal ${NC}"
			echo -e " ${CRED}* https://www.plex.tv/claim/ ${CEND}"
			echo ""
			read -rp "CLAIM = " CLAIM
			if [ -n "$CLAIM" ]
			then
				sed -i "s|%CLAIM%|$CLAIM|g" /home/$SEEDUSER/docker-compose.yml
			fi
			checking_errors $?
			echo""
			if [[ -e "$PLEXDRIVE" ]]; then
				plex_sections
			fi
			echo ""
		fi
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
			echo -e "${BLUE}### CREATION DES BIBLIOTHEQUES PLEX ###${NC}"

			## récupération de la liste des dossiers user
			cd /mnt/rclone/$SEEDUSER
			ls -Ad */ | sed 's,/$,,g' > /home/$SEEDUSER/sections.txt

			FILMS=$(grep -E 'films|film|Films|FILMS|MOVIES|Movies|movies|movie|VIDEOS|VIDEO|Video|Videos' /home/$SEEDUSER/sections.txt)
			SERIES=$(grep -E 'series|TV|tv|Series|SERIES|SERIES TV|Series TV|series tv|serie tv|serie TV|series TV|Shows' /home/$SEEDUSER/sections.txt)
			ANIMES=$(grep -E 'ANIMES|ANIME|Animes|Anime|Animation|ANIMATION|animes|anime' /home/$SEEDUSER/sections.txt)
			MUSIC=$(grep -E 'MUSIC|Music|music|Musiques|Musique|MUSIQUE|MUSIQUES|musiques|musique' /home/$SEEDUSER/sections.txt)

			##compteur
			var="Sections en cours de création, patientez..."
			decompte 15

			## création des bibliothèques plex
			for x in $(cat /home/$SEEDUSER/sections.txt);
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

			## configuration plex_autoscan
			cd /home/$SEEDUSER
			sed -i '/PATH/d' docker-compose.yml
			docker-compose rm -fs plex-$SEEDUSER > /dev/null 2>&1 && docker-compose up -d plex-$SEEDUSER > /dev/null 2>&1
			checking_errors $?
			echo""
			install_plex_autoscan
			##compteur
			var="Plex_autoscan en cours de configuration, patientez..."
			#decompte 15
			mv /home/$SEEDUSER/plex_autoscan/config/default.config /home/$SEEDUSER/plex_autoscan/config/config.json
			sed -i 's/\/var\/lib\/plexmediaserver/\/config/g' /home/$SEEDUSER/plex_autoscan/config/config.json
			sed -i 's/"DOCKER_NAME": ""/"DOCKER_NAME": "plex-'$SEEDUSER'"/g' /home/$SEEDUSER/plex_autoscan/config/config.json
			sed -i 's/"USE_DOCKER": false/"USE_DOCKER": true/g' /home/$SEEDUSER/plex_autoscan/config/config.json
			/home/$SEEDUSER/plex_autoscan/scan.py sections > /dev/null 2>&1
			/home/$SEEDUSER/plex_autoscan/scan.py sections > plex.log

			## Récupération du token de plex
			echo -e " ${BWHITE}* Récupération du token Plex${NC}"
			docker exec -ti plex-$SEEDUSER grep -E -o "PlexOnlineToken=.{0,22}" /config/Library/Application\ Support/Plex\ Media\ Server/Preferences.xml > /home/$SEEDUSER/token.txt
			TOKEN=$(grep PlexOnlineToken /home/$SEEDUSER/token.txt | cut -d '=' -f2 | cut -c2-21)
			for i in `seq 1 50`;
			do
   				var=$(grep "$i: " plex.log | cut -d: -f2 | cut -d ' ' -f2-3)
   				if [ -n "$var" ]
   				then
     				echo "$i" "$var"
   				fi 
			done > categories.log
			PLEXCANFILE="/home/$SEEDUSER/plex_autoscan/config/config.json"
			cat "$BASEDIR/includes/config/plex_autoscan/config.json" > $PLEXCANFILE

			ID_FILMS=$(grep -E 'films|film|Films|FILMS|MOVIES|Movies|movies|movie|VIDEOS|VIDEO|Video|Videos' categories.log | cut -d: -f1 | cut -d ' ' -f1)
			ID_SERIES=$(grep -E 'series|TV|tv|Series|SERIES|SERIES TV|Series TV|series tv|serie tv|serie TV|series TV|Shows' categories.log | cut -d: -f1 | cut -d ' ' -f1)
			ID_ANIMES=$(grep -E 'ANIMES|ANIME|Animes|Anime|Animation|ANIMATION|animes|anime' categories.log | cut -d: -f1 | cut -d ' ' -f1)
			ID_MUSIC=$(grep -E 'MUSIC|Music|music|Musiques|Musique|MUSIQUE|MUSIQUES|musiques|musique' categories.log | cut -d: -f1 | cut -d ' ' -f1)

			if [[ -f "$SCANPORTPATH" ]]; then
				declare -i PORT=$(cat $SCANPORTPATH | tail -1)
			else
				declare -i PORT=3470
			fi

			
			sed -i "s|%TOKEN%|$TOKEN|g" $PLEXCANFILE
			sed -i "s|%PORT%|$PORT|g" $PLEXCANFILE
			sed -i "s|%FILMS%|$FILMS|g" $PLEXCANFILE
			sed -i "s|%SERIES%|$SERIES|g" $PLEXCANFILE
			sed -i "s|%MUSIC%|$MUSIC|g" $PLEXCANFILE
			sed -i "s|%ANIMES%|$ANIMES|g" $PLEXCANFILE
			sed -i "s|%ID_FILMS%|$ID_FILMS|g" $PLEXCANFILE
			sed -i "s|%ID_SERIES%|$ID_SERIES|g" $PLEXCANFILE
			sed -i "s|%ID_ANIMES%|$ID_ANIMES|g" $PLEXCANFILE
			sed -i "s|%ID_MUSIC%|$ID_MUSIC|g" $PLEXCANFILE
			sed -i "s|%SEEDUSER%|$SEEDUSER|g" $PLEXCANFILE
			systemctl start plex_autoscan-$SEEDUSER.service > /dev/null 2>&1
			checking_errors $?
			PORT=$PORT+1
			echo $PORT >> $SCANPORTPATH

			echo ""
}

function valid_htpasswd() {
	if [[ -d "$CONFDIR" ]]; then
		HTFOLDER="$CONFDIR/passwd/"
		mkdir -p $HTFOLDER
		HTTEMPFOLDER="/tmp/"
		HTFILE=".htpasswd-$SEEDUSER"
		cat "$HTTEMPFOLDER$HTFILE" >> "$HTFOLDER$HTFILE"
		VAR=$(sed -e 's/\$/\$$/g' "$HTFOLDER$HTFILE")
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
		VAR=$(sed -e 's/\$/\$$/g' "$HTFOLDER$HTFILE")
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
	case $MANAGEUSER in
		"1" )
			PLEXDRIVE="/usr/bin/plexdrive"
			echo -e "${GREEN}###   NOUVELLE SEEDBOX USER   ###${NC}"
			echo -e "${GREEN}---------------------------------${NC}"
			echo ""
			define_parameters
			if [[ -e "$PLEXDRIVE" ]]; then
				choose_media_folder_plexdrive
				unionfs_fuse
				pause
				choose_services
				install_services
				docker_compose
				install_cloudplow
				resume_seedbox
				pause
				script_plexdrive
			else
				choose_media_folder_classique
				choose_services
				install_services
				docker_compose
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
			#[[ "$?" = 1 ]] && break;
			## RESUME USER INFORMATIONS
			USERDOCKERCOMPOSEFILE="/home/$SEEDUSER/docker-compose.yml"
			USERRESUMEFILE="/home/$SEEDUSER/resume"
			cd /home/$SEEDUSER
			echo -e "${BLUE}### SUPPRESSION CONTAINERS ###${NC}"
			checking_errors $?
			docker-compose rm -fs > /dev/null 2>&1
			echo ""
			if [[ -e "$PLEXDRIVE" ]]; then
				echo -e "${BLUE}### SUPPRESSION USER RCLONE/PLEXDRIVE ###${NC}"
				systemctl stop cloudplow-$SEEDUSER.service
				systemctl stop unionfs-$SEEDUSER.service  
				rm /etc/systemd/system/unionfs-$SEEDUSER.service
				rm /etc/systemd/system/cloudplow-$SEEDUSER.service
				checking_errors $?
				echo""
			fi
		        echo -e "${BLUE}### SUPPRESSION USER ###${NC}"
			rm -rf /home/$SEEDUSER > /dev/null 2>&1
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
	
	## INFORMATIONS UTILISATEUR
	USERDOCKERCOMPOSEFILE="/home/$SEEDUSER/docker-compose.yml"
	USERRESUMEFILE="/home/$SEEDUSER/resume"
	echo ""
	echo -e "${GREEN}### Gestion des Applis pour: $SEEDUSER ###${NC}"
	echo -e " ${BWHITE}* Docker-Compose file: $USERDOCKERCOMPOSEFILE${NC}"
	echo -e " ${BWHITE}* Resume file: $USERRESUMEFILE${NC}"
	echo ""
	## CHOOSE AN ACTION FOR APPS
	ACTIONONAPP=$(whiptail --title "App Manager" --menu \
	                "Selectionner une action :" 12 50 3 \
	                "1" "Ajout Docker Applis"  \
	                "2" "Supprimer une Appli" 3>&1 1>&2 2>&3)
			#[[ "$?" = 1 ]] && break;
	case $ACTIONONAPP in
		"1" ) ## Ajout APP
			choose_services
			add_app_htpasswd
			install_services
			docker_compose
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

			echo -e " ${GREEN}   * $APPSELECTED${NC}"
			cd /home/$SEEDUSER
			docker-compose rm -fs "$APPSELECTED"-"$SEEDUSER"
			sed -i "/#START"$APPSELECTED"#/,/#END"$APPSELECTED"#/d" /home/$SEEDUSER/docker-compose.yml
			sed -i "/$APPSELECTED/d" /home/$SEEDUSER/resume
			rm -rf /home/$SEEDUSER/$APPSELECTED
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
	ADMIN=$(head -1 $CONFDIR/users)
	if [[ -e "$PLEXDRIVE" ]]; then
		echo -e " ${BWHITE}* Suppression Plexdrive/rclone...${NC}"
		service rclone stop
		service plexdrive stop
		rm /etc/systemd/system/rclone.service
		rm /etc/systemd/system/plexdrive.service
		rm /usr/bin/rclone
		rm -rf /mnt/plexdrive
		rm -rf /mnt/rclone
		rm -rf /root/.plexdrive
		rm -rf /root/.config/rclone
		checking_errors $?
	fi
	for seeduser in $(cat $USERSFILE)
	do
		USERHOMEDIR="/home/$seeduser"
		echo -e " ${BWHITE}* Suppression users $seeduser...${NC}"
		if [[ -e "$PLEXDRIVE" ]] && [[ "$seeduser" != "$ADMIN" ]]; then
			service unionfs-$seeduser stop
			service cloudplow-$seeduser stop
			rm /etc/systemd/system/unionfs-$seeduser.service
			rm /etc/systemd/system/cloudplow-$seeduser.service
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
