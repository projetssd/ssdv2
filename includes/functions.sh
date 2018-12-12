#!/bin/bash

function logo () {

## Black        0;30     Dark Gray     1;30
## Red          0;31     Light Red     1;31
## Green        0;32     Light Green   1;32
## Brown/Orange 0;33     Yellow        1;33
## Blue         0;34     Light Blue    1;34
## Purple       0;35     Light Purple  1;35
## Cyan         0;36     Light Cyan    1;36
## Light Gray   0;37     White         1;37

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
	if (whiptail --title "Domain access" --yesno "Etes vous sûr que vos dns sont bien configurés ? On peut les tester maintenant ;)" 10 90) then
		TESTDOMAIN=$1
		echo -e " ${BWHITE}* Checking domain - ping $TESTDOMAIN...${NC}"
		ping -c 1 $TESTDOMAIN | grep "$IPADDRESS" > /dev/null
		checking_errors $?
	fi
}

function check_dir() {
	if [[ $1 != $BASEDIR ]]; then
		cd $BASEDIR
	fi
}

function script_option() {
	if [[ -d "$CONFDIR" ]]; then
	clear
	logo
	echo ""
	echo -e "${CCYAN}INSTALLATION${CEND}"
	echo -e "${CGREEN}${CEND}"
	echo -e "${CGREEN}   1) Seedbox déjà installée ${CEND}"
	echo -e "${CGREEN}   2) Ajout/Supression d'utilisateurs${CEND}"
	echo -e "${CGREEN}   3) Ajout/Supression d'Applis${CEND}"

	echo -e ""
	read -p "Votre choix [1-3]: " -e -i 1 PORT_CHOICE

	case $PORT_CHOICE in
		1) ## Installation de la seedbox
		clear
		echo ""
		echo -e "${YELLOW}### Seedbox-Compose déjà installée !###${NC}"
		if (whiptail --title "Seedbox-Compose déjà installée" --yesno "Désinstaller complètement la Seedbox ?" 7 90) then
			uninstall_seedbox
		else
			script_option
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
		echo -e "${CGREEN}   2) Ajout/Supression d'Applis${CEND}"
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
	#sed -ri 's/deb\ cdrom/#deb\ cdrom/g' /etc/apt/sources.list
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
	TMPSOURCESDIR="/opt/seedbox-compose/includes/sources.list"
	TMPSYSTEM=$(gawk -F= '/^NAME/{print $2}' /etc/os-release)
	TMPCODENAME=$(lsb_release -sc)
	TMPRELEASE=$(cat /etc/debian_version)
	if [[ $(echo $TMPSYSTEM | sed 's/\"//g') == "Debian GNU/Linux" ]]; then
		SYSTEMOS="Debian"
		if [[ $(echo $TMPRELEASE | grep "8") != "" ]]; then
			SYSTEMRELEASE="8"
			SYSTEMCODENAME="jessie"
		elif [[ $(echo $TMPRELEASE | grep "7") != "" ]]; then
			SYSTEMRELEASE="7"
			SYSTEMCODENAME="wheezy"
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
	case $SYSTEMCODENAME in
		"jessie" )
			echo -e " ${BWHITE}* Creating sources.list${NC}"
			rm /etc/apt/sources.list -R
			cp "$TMPSOURCESDIR/debian.jessie" "$SOURCESLIST"
			checking_errors $?
			;;
		"wheezy" )
			echo -e "	${YELLOW}--> Please upgrade to Debian Jessie !${NC}"
			;;
	esac
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
		checking_errors $?
		echo ""

	else
		echo -e " ${YELLOW}* traefik is already installed !${NC}"
	fi
	echo ""
}

function install_zsh() {
	echo -e "${BLUE}### ZSH-OHMYZSH ###${NC}"
	ZSHDIR="/usr/share/zsh"
	OHMYZSHDIR="/root/.oh-my-zsh/"
	if [[ ! -d "$OHMYZSHDIR" ]]; then
		echo -e " * Installation ZSH"
		apt-get install -y zsh > /dev/null 2>&1
		checking_errors $?
		echo -e " * Cloning Oh-My-ZSH"
		wget -q https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O - | sh > /dev/null 2>&1
		sed -i -e 's/^\ZSH_THEME=\"robbyrussell\"/ZSH_THEME=\"bira\"/g' ~/.zshrc > /dev/null 2>&1
		sed -i -e 's/^\# DISABLE_AUTO_UPDATE=\"true\"/DISABLE_AUTO_UPDATE=\"true\"/g' ~root/.zshrc > /dev/null 2>&1
	else
		echo -e " ${YELLOW}* ZSH est délà installé !${NC}"
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

	if (whiptail --title "Nom de Domaine" --yesno "Souhaitez vous utiliser un nom de Domaine?" 7 50) then
		DOMAIN=$(whiptail --title "Votre nom de Domaine" --inputbox \
		"Merci de taper votre nom de Domaine :" 7 50 3>&1 1>&2 2>&3)
	else
		DOMAIN="localhost"
fi
	echo ""
}

function create_user() {
	if [[ ! -f "$GROUPFILE" ]]; then
		touch $GROUPFILE
		SEEDGROUP=$(whiptail --title "Group" --inputbox \
        	"Création d'un groupe pour la Seedbox" 7 50 3>&1 1>&2 2>&3)
		echo "$SEEDGROUP" > "$GROUPFILE"
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
		echo -e " ${BWHITE}* Adding $SEEDUSER in $SEEDGROUP"
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
	INSTALLEDFILE="/home/$SEEDUSER/resume"
	touch $INSTALLEDFILE > /dev/null 2>&1
	if [[ -f "$FILEPORTPATH" ]]; then
		declare -i PORT=$(cat $FILEPORTPATH | tail -1)
	else
		declare -i PORT=$FIRSTPORT
	fi

	DOCKERCOMPOSEFILE="/home/$SEEDUSER/docker-compose.yml"
	touch $DOCKERCOMPOSEFILE
	cat /opt/seedbox-compose/includes/dockerapps/head.docker > $DOCKERCOMPOSEFILE
	for line in $(cat $SERVICESPERUSER);
	do
		#check_domain "$line.$DOMAIN"
		
		cat "/opt/seedbox-compose/includes/dockerapps/$line.yml" >> $DOCKERCOMPOSEFILE
		sed -i "s|%TIMEZONE%|$TIMEZONE|g" $DOCKERCOMPOSEFILE
		sed -i "s|%UID%|$USERID|g" $DOCKERCOMPOSEFILE
		sed -i "s|%GID%|$GRPID|g" $DOCKERCOMPOSEFILE
		sed -i "s|%PORT%|$PORT|g" $DOCKERCOMPOSEFILE
		sed -i "s|%VAR%|$VAR|g" $DOCKERCOMPOSEFILE
		sed -i "s|%DOMAIN%|$DOMAIN|g" $DOCKERCOMPOSEFILE
		sed -i "s|%USER%|$SEEDUSER|g" $DOCKERCOMPOSEFILE
		sed -i "s|%EMAIL%|$CONTACTEMAIL|g" $DOCKERCOMPOSEFILE
		sed -i "s|%IPADDRESS%|$IPADDRESS|g" $DOCKERCOMPOSEFILE


		SUBURI=$(whiptail --title "Type d'Accès" --menu \
	            "Accès aux Applis :" 10 45 2 \
	            "1" "Sous Domaine" \
	            "2" "URI" 3>&1 1>&2 2>&3)

	    	case $SUBURI in
	        	"1" )
				PROXYACCESS="SUBDOMAIN"
				FQDNTMP="$line.$DOMAIN"
				FQDN=$(whiptail --title "SSL Sous Domaine" --inputbox \
				"Souhaitez vous utiliser un autre Sous Domaine pour $line ? default :" 7 75 "$FQDNTMP" 3>&1 1>&2 2>&3)
				ACCESSURL=$FQDN
				check_domain $ACCESSURL
				TRAEFIKURL=(Host:$ACCESSURL)
				sed -i "s|%TRAEFIKURL%|$TRAEFIKURL|g" /home/$SEEDUSER/docker-compose.yml
				echo "$line-$PORT-$FQDN" >> $INSTALLEDFILE
				URI="/"
	        	;;

	        	"2" )
				PROXYACCESS="URI"
				FQDN=$DOMAIN
				FQDNTMP="/$SEEDUSER"_"$line"
				ACCESSURL=$(whiptail --title "SSL Subdomain" --inputbox \
				"Souhaitez vous utiliser une autre URI pour $line ? default :" 7 75 "$FQDNTMP" 3>&1 1>&2 2>&3)
				URI=$ACCESSURL
				TRAEFIKURL=(Host:$DOMAIN';'PathPrefix:$URI)
				sed -i "s|%TRAEFIKURL%|$TRAEFIKURL|g" /home/$SEEDUSER/docker-compose.yml
				sed -i "s|%URI%|$URI|g" /home/$SEEDUSER/docker-compose.yml
				check_domain $DOMAIN
				echo "$line-$PORT-$FQDN$URI" >> $INSTALLEDFILE
				
			;;
				
	    	esac
		PORT=$PORT+1
		FQDN=""
		FQDNTMP=""
	done
	cat /opt/seedbox-compose/includes/dockerapps/foot.docker >> $DOCKERCOMPOSEFILE
	echo $PORT >> $FILEPORTPATH
	echo ""
}

function add_install_services() {
	USERID=$(id -u $SEEDUSER)
	GRPID=$(id -g $SEEDUSER)
	INSTALLEDFILE="/home/$SEEDUSER/resume"
	touch $INSTALLEDFILE > /dev/null 2>&1
	if [[ -f "$FILEPORTPATH" ]]; then
		declare -i PORT=$(cat $FILEPORTPATH | tail -1)
	else
		declare -i PORT=$FIRSTPORT
	fi

	DOCKERCOMPOSEFILE="/home/$SEEDUSER/docker-compose.yml"
	for line in $(cat $SERVICESPERUSER);
	do
		#check_domain "$line.$DOMAIN"
		sed -i -n -e :a -e '1,5!{P;N;D;};N;ba' $DOCKERCOMPOSEFILE
		cat "/opt/seedbox-compose/includes/dockerapps/$line.yml" >> $DOCKERCOMPOSEFILE
		sed -i "s|%TIMEZONE%|$TIMEZONE|g" $DOCKERCOMPOSEFILE
		sed -i "s|%UID%|$USERID|g" $DOCKERCOMPOSEFILE
		sed -i "s|%GID%|$GRPID|g" $DOCKERCOMPOSEFILE
		sed -i "s|%PORT%|$PORT|g" $DOCKERCOMPOSEFILE
		sed -i "s|%VAR%|$VAR|g" $DOCKERCOMPOSEFILE
		sed -i "s|%DOMAIN%|$DOMAIN|g" $DOCKERCOMPOSEFILE
		sed -i "s|%USER%|$SEEDUSER|g" $DOCKERCOMPOSEFILE
		sed -i "s|%EMAIL%|$CONTACTEMAIL|g" $DOCKERCOMPOSEFILE
		sed -i "s|%IPADDRESS%|$IPADDRESS|g" $DOCKERCOMPOSEFILE
		cat /opt/seedbox-compose/includes/dockerapps/foot.docker >> $DOCKERCOMPOSEFILE

		SUBURI=$(whiptail --title "Type d'Accès" --menu \
	            "Accès aux Applis :" 10 45 2 \
	            "1" "Sous Domaine" \
	            "2" "URI" 3>&1 1>&2 2>&3)

	    	case $SUBURI in
	        	"1" )
				PROXYACCESS="SUBDOMAIN"
				FQDNTMP="$line.$DOMAIN"
				FQDN=$(whiptail --title "SSL Subdomain" --inputbox \
				"Souhaitez vous utiliser un autre Sous Domaine pour $line ? default :" 7 75 "$FQDNTMP" 3>&1 1>&2 2>&3)
				ACCESSURL=$FQDN
				TRAEFIKURL=(Host:$ACCESSURL)
				sed -i "s|%TRAEFIKURL%|$TRAEFIKURL|g" /home/$SEEDUSER/docker-compose.yml
				check_domain $ACCESSURL
				echo "$line-$PORT-$FQDN" >> $INSTALLEDFILE
				URI="/"
	        	;;

	        	"2" )
				PROXYACCESS="URI"
				FQDN=$DOMAIN
				FQDNTMP="/$SEEDUSER"_"$line"
				ACCESSURL=$(whiptail --title "SSL Subdomain" --inputbox \
				"Souhaitez vous utiliser une autre URI pour $line ? default :" 7 75 "$FQDNTMP" 3>&1 1>&2 2>&3)
				URI=$ACCESSURL
				TRAEFIKURL=(Host:$DOMAIN';'PathPrefix:$URI)
				sed -i "s|%TRAEFIKURL%|$TRAEFIKURL|g" /home/$SEEDUSER/docker-compose.yml
				sed -i "s|%URI%|$URI|g" /home/$SEEDUSER/docker-compose.yml
				check_domain $DOMAIN
				echo "$line-$PORT-$FQDN$URI" >> $INSTALLEDFILE
			;;
				
	    	esac
		PORT=$PORT+1
		FQDN=""
		FQDNTMP=""
		
	done
	
	echo $PORT >> $FILEPORTPATH
	echo ""
}


function docker_compose() {
	echo -e "${BLUE}### DOCKERCOMPOSE ###${NC}"
	ACTDIR="$PWD"
	cd /home/$SEEDUSER/
	echo -e " ${BWHITE}* Starting docker...${NC}"
	service docker restart
	checking_errors $?
	echo -e " ${BWHITE}* Docker-composing, Merci de patienter...${NC}"
	docker-compose up -d > /dev/null 2>&1
	checking_errors $?
	echo ""
	cd $ACTDIR
	config_post_compose
}

function config_post_compose() {
	if [[ "$PROXYACCESS" == "URI" ]]; then
		echo -e "${BLUE}### CONFIG POST COMPOSE ###${NC}"
		grep -R "sonarr" "$INSTALLEDFILE" > /dev/null 2>&1	
		if [[ "$?" == "0" ]]; then
			SONARR=$(grep -R "sonarr" /home/$SEEDUSER/resume | cut -d'/' -f2)
			echo -e " ${BWHITE}* Processing sonarr config file...${NC}"
			rm "/home/$SEEDUSER/sonarr/config/config.xml" > /dev/null 2>&1
			cp "$BASEDIR/includes/config/sonarr.config.xml" "/home/$SEEDUSER/sonarr/config/config.xml" > /dev/null 2>&1
			sed -i "s|%URI%|$SONARR|g" /home/$SEEDUSER/sonarr/config/config.xml
			sed -i "s|%URI%|$SONARR|g" /home/$SEEDUSER/docker-compose.yml
			docker restart sonarr-$SEEDUSER > /dev/null 2>&1
			checking_errors $?
		fi

		grep -R "radarr" "$INSTALLEDFILE" > /dev/null 2>&1	
		if [[ "$?" == "0" ]]; then
			RADARR=$(grep -R "radarr" /home/$SEEDUSER/resume | cut -d'/' -f2)
			echo -e " ${BWHITE}* Processing radarr config file...${NC}"
			rm "/home/$SEEDUSER/radarr/config/config.xml" > /dev/null 2>&1
			cp "$BASEDIR/includes/config/radarr.config.xml" "/home/$SEEDUSER/radarr/config/config.xml" > /dev/null 2>&1
			sed -i "s|%URI%|$RADARR|g" /home/$SEEDUSER/radarr/config/config.xml
			sed -i "s|%URI%|$RADARR|g" /home/$SEEDUSER/docker-compose.yml
			docker restart radarr-$SEEDUSER > /dev/null 2>&1
			checking_errors $?
		fi

	else
		
		echo -e "${BLUE}### CONFIG POST COMPOSE ###${NC}"
		grep -R "medusa" "$INSTALLEDFILE" > /dev/null 2>&1
		if [[ "$?" == "0" ]]; then
			echo -e " ${BWHITE}* Processing medusa config file...${NC}"
			cd /home/$SEEDUSER/
			sed -i '/MEDUSA_WEBROOT/d' docker-compose.yml
			docker-compose rm -fs medusa-$SEEDUSER > /dev/null 2>&1 && docker-compose up -d medusa-$SEEDUSER > /dev/null 2>&1
			checking_errors $?
		fi

		grep -R "sonarr" "$INSTALLEDFILE" > /dev/null 2>&1
		if [[ "$?" == "0" ]]; then
			echo -e " ${BWHITE}* Processing sonarr config file...${NC}"
			cd /home/$SEEDUSER/
			sed -i '/WEBROOT/d' docker-compose.yml
			docker-compose rm -fs sonarr-$SEEDUSER > /dev/null 2>&1 && docker-compose up -d sonarr-$SEEDUSER > /dev/null 2>&1
			checking_errors $?
		fi

		grep -R "radarr" "$INSTALLEDFILE" > /dev/null 2>&1
		if [[ "$?" == "0" ]]; then
			echo -e " ${BWHITE}* Processing radarr config file...${NC}"
			cd /home/$SEEDUSER/
			sed -i '/WEBROOT/d' docker-compose.yml
			docker-compose rm -fs radarr-$SEEDUSER > /dev/null 2>&1 && docker-compose up -d radarr-$SEEDUSER > /dev/null 2>&1
			checking_errors $?
		fi

		grep -R "rtorrent" "$INSTALLEDFILE" > /dev/null 2>&1
		if [[ "$?" == "0" ]]; then
			echo -e " ${BWHITE}* Processing rtorrent config file...${NC}"
			cd /home/$SEEDUSER/
			rm -rf rtorrent
			sed -i '/WEBROOT/d' docker-compose.yml
			docker-compose rm -fs rtorrent-$SEEDUSER > /dev/null 2>&1 && docker-compose up -d rtorrent-$SEEDUSER > /dev/null 2>&1
			checking_errors $?
		fi

	fi
}

function valid_htpasswd() {
	if [[ -d "/etc/seedboxcompose/" ]]; then
		HTFOLDER="/etc/seedboxcompose/passwd/"
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
	if [[ -d "/etc/seedboxcompose/" ]]; then
		HTFOLDER="/etc/seedboxcompose/passwd/"
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
			echo -e "${GREEN}###   NOUVELLE SEEDBOX USER   ###${NC}"
			echo -e "${GREEN}---------------------------------${NC}"
			echo ""
			define_parameters
			choose_services
			install_services
			docker_compose
			resume_seedbox
			pause
			script_option
			;;

		"2" )
			echo -e "${GREEN}###   SUPRESSION SEEDBOX USER   ###${NC}"
			echo -e "${GREEN}-----------------------------------${NC}"
			echo ""
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
			[[ "$?" = 1 ]] && break;
			## RESUME USER INFORMATIONS
			USERDOCKERCOMPOSEFILE="/home/$SEEDUSER/docker-compose.yml"
			USERRESUMEFILE="/home/$SEEDUSER/resume"
			cd /home/$SEEDUSER
			echo -e "${BLUE}### SUPPRESSION CONTAINERS ###${NC}"
			checking_errors $?
			docker-compose rm -fs > /dev/null 2>&1
			echo ""
		        echo -e "${BLUE}### SUPPRESSION USER ###${NC}"
			rm -rf /home/$SEEDUSER > /dev/null 2>&1
			userdel -rf $SEEDUSER > /dev/null 2>&1
			sed -i "/$SEEDUSER/d" /etc/seedboxcompose/users
			rm /etc/seedboxcompose/passwd/.htpasswd-$SEEDUSER
			sed -n -i "/$SEEDUSER/!p" /etc/seedboxcompose/passwd/login
			checking_errors $?
			echo""
			echo -e "${BLUE}### $SEEDUSER a été supprimé ###${NC}"
			echo ""
			pause
			script_option
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
				add_install_services
				docker_compose
				resume_seedbox
				pause
				script_option
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
			script_option
			;;
			
	esac
}

function resume_seedbox() {
	echo ""
	echo -e "${BLUE}##########################################${NC}"
	echo -e "${BLUE}###     INFORMATION SEEDBOX INSTALL    ###${NC}"
	echo -e "${BLUE}##########################################${NC}"
	echo -e " ${BWHITE}* Accès Applis à partir de URL :${NC}"
	if [[ "$DOMAIN" != "localhost" ]]; then
		for line in $(cat $INSTALLEDFILE);
		do
			ACCESSDOMAIN=$(echo $line | cut -d\- -f3)
			DOCKERAPP=$(echo $line | cut -d\- -f1)
			echo -e "	--> ${BWHITE}$DOCKERAPP${NC} --> ${YELLOW}$ACCESSDOMAIN${NC}"
		done
	else
		for line in $(cat $INSTALLEDFILE);
		do
			APPINSTALLED=$(echo $line | cut -d\- -f1)
			PORTINSTALLED=$(echo $line | cut -d\- -f2 | sed 's! !!g')
			echo -e "	--> $APPINSTALLED --> ${YELLOW}$IPADDRESS:$PORTINSTALLED${NC}"
		done
	fi
	
	IDENT="/etc/seedboxcompose/passwd/.htpasswd-$SEEDUSER"	
	if [[ ! -d $IDENT ]]; then
	PASSE=$(grep $SEEDUSER /etc/seedboxcompose/passwd/login | cut -d ' ' -f2)
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
	echo -e "${BLUE}###          UNINSTALL SEEDBOX         ###${NC}"
	echo -e "${BLUE}##########################################${NC}"
	SEEDGROUP=$(cat $GROUPFILE)
	for seeduser in $(cat $USERSFILE)
	do
		USERHOMEDIR="/home/$seeduser"
		echo -e " ${BWHITE}* Suppression users...${NC}"
		userdel -rf $seeduser > /dev/null 2>&1
		checking_errors $?
		echo -e " ${BWHITE}* Suppression home...${NC}"
		rm -Rf $USERHOMEDIR
		checking_errors $?
		echo -e " ${BWHITE}* Suppression group...${NC}"
		groupdel $SEEDGROUP > /dev/null 2>&1
		checking_errors $?
		echo -e " ${BWHITE}* Suppression Containers...${NC}"
		docker rm -f $(docker ps -aq) > /dev/null 2>&1
		checking_errors $?
	done
	echo -e " ${BWHITE}* Removing Seedbox-compose directory...${NC}"
	rm -Rf /etc/seedboxcompose
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
