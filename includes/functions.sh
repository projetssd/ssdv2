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
		# for line in $(cat $SERVICESAVAILABLE)
		# do
		# 	DOCKERAPPLICATION=$(echo $line | cut -d\- -f1)
		# 	echo -e " ${BWHITE}* Ping $DOCKERAPPLICATION.$TESTDOMAIN...${NC}"
		# 	ping -c 1 ${DOCKERAPPLICATION,,}.$TESTDOMAIN | grep "$IPADDRESS" > /dev/null 2>&1
		# 	checking_errors $?
		# done
	fi
	# pause
}

function check_dir() {
	if [[ $1 != $BASEDIR ]]; then
		cd $BASEDIR
	fi
}

function first_install() {
	if [[ ! -d "/etc/seedboxcompose/" ]]; then
	        clear
		echo -e "${BLUE}##########################################${NC}"
		echo -e "${BLUE}###    INSTALLATION SEEDBOX-COMPOSE    ###${NC}"
		echo -e "${BLUE}##########################################${NC}"
		conf_dir
		## Install base packages
		install_base_packages
		## Checking system version
		checking_system
		## Check for docker on system
		install_docker
		## Installing ZSH
		install_zsh
		## Defines parameters for dockers : password, domains and replace it in docker-compose file
		define_parameters
		## Install Traefik
		install_traefik
	else
		clear
		echo -e " ${RED}--> Seedbox-Compose already installed !${NC}"
	        script_option
	fi
}

function script_option() {
	if [[ -d "$CONFDIR" ]]; then
		ACTION=$(whiptail --title "Seedbox-Compose" --menu "Welcome to Seedbox-Compose Script. Please choose an action below :" 18 80 10 \
			"1" "Seedbox-Compose already installed !" \
			"2" "Manage Users" \
			"3" "Manage Apps" \
			"4" "Manage Backups" \
			"5" "Manage Docker" \
			"6" "Install FTP Server" \
			"7" "Disable htaccess protection" \
			"8" "Uninstall Seedbox-Compose"  3>&1 1>&2 2>&3)
		echo ""
		case $ACTION in
		"1")
		  clear
		  echo ""
		  echo -e "${YELLOW}### Seedbox-Compose already installed !###${NC}"
		  if (whiptail --title "Seedbox already installed" --yesno "You're in trouble with Seedbox-compose ? Uninstall and try again ?" 7 90) then
				uninstall_seedbox
			else
				script_option
			fi
		  ;;
		"2")
			SCRIPT="MANAGEUSERS"
			;;
		"3")
			SCRIPT="MANAGEAPPS"
			;;
		"4")
			ACTIONBACKUP=$(whiptail --title "Manage Backup" --menu "Choose an action for backups !" 10 75 2 \
				"1" "Create a backup now of my Home !" \
				"2" "Schedule a backup for my data !" 3>&1 1>&2 2>&3)
			echo ""
			case $ACTIONBACKUP in
			"1")
			  backup_docker_conf
			  ;;
			"2")
			  schedule_backup_seedbox
			  ;;
			 esac
			;;
		"5")
			# manage_docker
			;;
		"6")
			SCRIPT="INSTALLFTPSERVER"
			;;
		"7")
			SCRIPT="DELETEHTACCESS"
			;;
		"8")
			SCRIPT="UNINSTALL"
			;;
		esac
	else
		ACTION=$(whiptail --title "Seedbox-Compose" --menu "Welcome to Seedbox-Compose installation !" 10 75 2 \
			"1" "Install Seedbox-Compose" 3>&1 1>&2 2>&3)
		echo ""
		case $ACTION in
		"1")
			SCRIPT="INSTALL"
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
	whiptail --title "Base Package" --msgbox "Seedbox-Compose va maintenant installer les packages et vérifier la mise à jour du système" 10 60
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
			#backup_docker_conf
			#schedule_backup_seedbox
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
	[[ "$?" = 1 ]] && break;
	## INFORMATIONS UTILISATEUR
	USERDOCKERCOMPOSEFILE="/home/$SEEDUSER/docker-compose.yml"
	USERRESUMEFILE="/home/$SEEDUSER/resume"
	echo ""
	echo -e "${GREEN}### Gestion des Applis pour : $SEEDUSER ###${NC}"
	echo -e " ${BWHITE}* Docker-Compose file : $USERDOCKERCOMPOSEFILE${NC}"
	echo -e " ${BWHITE}* Resume file : $USERRESUMEFILE${NC}"
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
				#backup_docker_conf
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

			# rm -rf /home/$SEEDUSER/$SERVICE /dev/null 2>&1
			#[[ "$?" = 1 ]] && break;
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
			;;
			
	esac
}

function install_ftp_server() {
	echo -e "${BLUE}##########################################${NC}"
	echo -e "${BLUE}###          INSTALL FTP SERVER        ###${NC}"
	echo -e "${BLUE}##########################################${NC}"
	PROFTPDFOLDER="/etc/proftpd/"
	PROFTPDCONFFILE="proftpd.conf"
	PROFTPDTLSCONFFILE="tls.conf"
	BASEPROFTPDFILE="/opt/seedbox-compose/includes/config/proftpd.conf"
	BASEPROFTPDTLSFILELETSENCRYPT="/opt/seedbox-compose/includes/config/proftpd.tls.letsencrypt.conf"
	BASEPROFTPDTLSFILEOPENSSL="/opt/seedbox-compose/includes/config/proftpd.tls.openssl.conf"
	PROFTPDBAKCONF="/etc/proftpd/proftpd.conf.bak"
	PROFTPDTLSBAKCONF="/etc/proftpd/tls.conf.bak"
	if [[ ! -d "$PROFTPDFOLDER" ]]; then
		if (whiptail --title "Use FTP Server" --yesno "Do you want to install FTP server ?" 7 50) then
			FTPSERVERNAME=$(whiptail --title "FTPServer Name" --inputbox \
			"Please enter a name for your FTP Server :" 7 50 "SeedBox" 3>&1 1>&2 2>&3)
			echo -e " ${BWHITE}--> Installing proftpd...${NC}"
			apt-get -qq install proftpd -y
			checking_errors $?
			if (whiptail --title "FTP Over SSL" --yesno "Do you want to use FTP with SSL ? (FTPs)" 7 60) then
				if (whiptail --title "FTPs Let's Encrypt" --yesno "Do you want to generate a Let's Encrypt certificate for FTPs ?" 7 70) then
					LEEMAIL=$(whiptail --title "Email address" --inputbox \
					"Please enter your email address :" 7 50 "$CONTACTEMAIL" 3>&1 1>&2 2>&3)
					LEDOMAIN=$(whiptail --title "LE Domain" --inputbox \
					"Please enter your domain for FTP access :" 7 50 "ftp.$DOMAIN" 3>&1 1>&2 2>&3)
					echo -e " ${BWHITE}--> Stoping nginx...${NC}"
					service nginx stop
					checking_errors $?
					echo -e " ${BWHITE}--> Generating certificate...${NC}"
					generate_ssl_cert $LEEMAIL $LEDOMAIN
					checking_errors $?
					USEFTPSLE="yes"
				else
					FTPSEMAIL=$(whiptail --title "OpenSSL Generation" --inputbox \
					"Email address" 7 50 "$CONTACTEMAIL" 3>&1 1>&2 2>&3)
					FTPSDOMAIN=$(whiptail --title "OpenSSL Generation" --inputbox \
					"Domain or FQDN" 7 50 "ftp.$DOMAIN" 3>&1 1>&2 2>&3)
					FTPSCC=$(whiptail --title "OpenSSL Generation" --inputbox \
					"Coutry code (FR, GB ...)" 7 50 "FR" 3>&1 1>&2 2>&3)
					FTPSSTATE=$(whiptail --title "OpenSSL Generation" --inputbox \
					"State (Ile de France, Bretagne ...)" 7 50 "Nottingham" 3>&1 1>&2 2>&3)
					FTPSLOCALITY=$(whiptail --title "OpenSSL Generation" --inputbox \
					"Locality (Paris, London ...)" 7 50 "Marseille" 3>&1 1>&2 2>&3)
					FTPSORGANIZATION=$(whiptail --title "OpenSSL Generation" --inputbox \
					"Organization (Apple Inc. ...)" 7 50 "Linux" 3>&1 1>&2 2>&3)
					FTPSORGANIZATIONALUNIT=$(whiptail --title "OpenSSL Generation" --inputbox \
					"Organizationnal Unit (Export, Production ...)" 7 50 "Tech" 3>&1 1>&2 2>&3)
					FTPSPASSWORD=$(whiptail --title "OpenSSL Generation" --passwordbox "Password" 7 50 3>&1 1>&2 2>&3)
					echo -e " ${BWHITE}--> Generating key request...${NC}"
					openssl genrsa -des3 -passout pass:$FTPSPASSWORD -out /etc/ssl/private/$FTPSDOMAIN.key 2048 -noout > /dev/null 2>&1
					checking_errors $?
					echo -e " ${BWHITE}--> Removing passphrase from key...${NC}"
					openssl rsa -in /etc/ssl/private/$FTPSDOMAIN.key -passin pass:$FTPSPASSWORD -out /etc/ssl/private/$FTPSDOMAIN.key > /dev/null 2>&1
					checking_errors $?
					echo -e " ${BWHITE}--> Generating Certificate file...${NC}"
					openssl req -new -x509 -key /etc/ssl/private/$FTPSDOMAIN.key -out /etc/ssl/certs/$FTPSDOMAIN.crt -passin pass:$FTPSPASSWORD \
    					-subj "/C=$FTPSCC/ST=$FTPSSTATE/L=$FTPSLOCALITY/O=$FTPSORGANIZATION/OU=$FTPSORGANIZATIONALUNIT/CN=$FTPSDOMAIN/emailAddress=$FTPSEMAIL" > /dev/null 2>&1
    				checking_errors $?
					USEFTPSOPENSSL="yes"
				fi
		 		if (whiptail --title "Force FTPs" --yesno "Do you want to force FTPs ?" 7 60) then
		 			TLSREQUIRED="on"
		 		else
		 			TLSREQUIRED="off"
		 		fi
			fi
			echo -e " ${BWHITE}--> Creating base configuration file...${NC}"
			mv "$PROFTPDFOLDER$PROFTPDCONFFILE" "$PROFTPDBAKCONF"
	 	 	cat "$BASEPROFTPDFILE" >> "$PROFTPDFOLDER$PROFTPDCONFFILE"
	 	 	sed -i -e "s/ServerName\ \"Debian\"/ServerName\ \"$FTPSERVERNAME\"/g" "$PROFTPDFOLDER$PROFTPDCONFFILE"
	 		checking_errors $?
	 		if [[ "$USEFTPSLE" == "yes" ]]; then
		 		echo -e " ${BWHITE}--> Creating SSL configuration file...${NC}"
		 		sed -i -e "s/#Include\ \/etc\/\proftpd\/tls.conf/Include\ \/etc\/\proftpd\/tls.conf/g" "$PROFTPDFOLDER$PROFTPDCONFFILE"
		 		mv "$PROFTPDFOLDER$PROFTPDTLSCONFFILE" "$PROFTPDTLSBAKCONF"
		 	 	cat "$BASEPROFTPDTLSFILELETSENCRYPT" >> "$PROFTPDFOLDER$PROFTPDTLSCONFFILE"
	 			sed -i "s|%TLSREQUIRED%|$TLSREQUIRED|g" "$PROFTPDFOLDER$PROFTPDTLSCONFFILE"
		 	 	sed -i "s|%DOMAIN%|$LEDOMAIN|g" "$PROFTPDFOLDER$PROFTPDTLSCONFFILE"
		 	 	checking_errors $?
	 		fi
	 		if [[ "$USEFTPSOPENSSL" == "yes" ]]; then
		 		echo -e " ${BWHITE}--> Creating SSL configuration file...${NC}"
		 		sed -i -e "s/#Include\ \/etc\/\proftpd\/tls.conf/Include\ \/etc\/\proftpd\/tls.conf/g" "$PROFTPDFOLDER$PROFTPDCONFFILE"
		 		mv "$PROFTPDFOLDER$PROFTPDTLSCONFFILE" "$PROFTPDTLSBAKCONF"
		 	 	cat "$BASEPROFTPDTLSFILEOPENSSL" >> "$PROFTPDFOLDER$PROFTPDTLSCONFFILE"
	 			sed -i "s|%TLSREQUIRED%|$TLSREQUIRED|g" "$PROFTPDFOLDER$PROFTPDTLSCONFFILE"
		 	 	sed -i "s|%DOMAIN%|$FTPSDOMAIN|g" "$PROFTPDFOLDER$PROFTPDTLSCONFFILE"
		 	 	checking_errors $?
	 		fi
	 		echo -e " ${BWHITE}--> Restarting service...${NC}"
	 		service proftpd restart
	 		checking_errors $?
	 	else
	 		echo -e " ${BWHITE}* Fine, nothing will be installed !${NC}"
		fi
	else
		echo -e " ${YELLOW}* FTP Server already installed !${NC}"
		echo -e "	${RED}--> Please check manually Proftpd configuration${NC}"
		if (whiptail --title "FTP Server" --yesno "FTP Server already exist ! Do you want to reconfigure service ?" 7 75) then
			FTPSERVERNAME=$(whiptail --title "FTPServer Name" --inputbox \
			"Please enter a name for your FTP Server :" 7 50 "SeedBox" 3>&1 1>&2 2>&3)
			echo -e " ${BWHITE}* Reconfigure... ${NC}"
			echo -e " ${BWHITE}* Cleaning files... ${NC}"
			if [[ -f "$PROFTPDBAKCONF" ]]; then
				rm $PROFTPDBAKCONF -R
				checking_errors $?
			fi
			echo -e " ${BWHITE}* Creating configuration file...${NC}"
			mv "$PROFTPDFOLDER$PROFTPDCONFFILE" "$PROFTPDFOLDER$PROFTPDCONFFILE.bak"
	 	 	cat "$BASEPROFTPDFILE" >> "$PROFTPDFOLDER$PROFTPDCONFFILE"
	 	 	sed -i -e "s/ServerName\ \"Debian\"/ServerName\ \"$FTPSERVERNAME\"/g" "$PROFTPDFOLDER$PROFTPDCONFFILE"
	 	 	checking_errors $?
	 	 	echo -e " ${BWHITE}* Restarting proftpd...${NC}"
	 	 	service proftpd restart
	 		checking_errors $?
	 		checking_errors $?
	 	fi
	fi
	echo ""
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
	if [[ -d "$PROFTPDFOLDER" ]]; then
		echo ""
		echo -e " ${BWHITE}* Accès FTP avec IDs de:${NC}"
		echo -e "	--> IP Address : ${YELLOW}$IPADDRESS${NC}"
		if [[ "$DOMAIN" != "localhost" ]]; then
			echo -e "	--> Domain : ${YELLOW}$DOMAIN${NC}"
		fi
	fi

	IDENT="/etc/seedboxcompose/passwd/.htpasswd-$SEEDUSER"	
	if [[ ! -d $IDENT ]]; then
	PASSE=$(grep $SEEDUSER /etc/seedboxcompose/passwd/login | cut -d ' ' -f2)
	echo ""
	echo -e " ${BWHITE}* Vos IDs :${NC}"
	echo -e "	--> Utilisateur : ${YELLOW}$SEEDUSER${NC}"
	echo -e "	--> Password : ${YELLOW}$PASSE${NC}"
	echo ""

	else

	echo -e " ${BWHITE}* Here is your IDs :${NC}"
	echo -e "	--> Utilisateur : ${YELLOW}$HTUSER${NC}"
	echo -e "	--> Password : ${YELLOW}$HTPASSWORD${NC}"
	echo ""
	echo ""
	fi
	rm -Rf $SERVICESPERUSER > /dev/null 2>&1
	# if [[ -f "/home/$SEEDUSER/downloads/medias/supervisord.log" ]]; then
	# 	mv /home/$SEEDUSER/downloads/medias/supervisord.log /home/$SEEDUSER/downloads/medias/.supervisord.log > /dev/null 2>&1
	# 	mv /home/$SEEDUSER/downloads/medias/supervisord.pid /home/$SEEDUSER/downloads/medias/.supervisord.pid > /dev/null 2>&1
	# fi
	# chown $SEEDUSER: -R /home/$SEEDUSER/downloads/{tv;movies;medias}
	# chmod 775: -R /home/$SEEDUSER/downloads/{tv;movies;medias}
}

function backup_docker_conf() {
	BACKUPDIR="/var/backups/"
	BACKUPNAME="backup-sc-$SEEDUSER-"
	echo ""
	BACKUP="$BACKUPDIR$BACKUPNAME$BACKUPDATE.tar.gz"
	if [[ "$SEEDUSER" != "" ]]; then
		if (whiptail --title "Backup Dockers conf" --yesno "Do you want backup configuration for $SEEDUSER ?" 10 60) then
			echo -e "${BLUE}##########################################${NC}"
			echo -e "${BLUE}###         BACKUP DOCKER CONF         ###${NC}"
			echo -e "${BLUE}##########################################${NC}"
			USERBACKUP=$SEEDUSER
		else
			exit 1
		fi
	else
		USERBACKUP=$(whiptail --title "Backup User" --inputbox "Enter username to backup configuration" 10 60 3>&1 1>&2 2>&3)
	fi
	DOCKERCONFDIR="/home/$USERBACKUP/dockers/"
	if [[ -d "$DOCKERCONFDIR" ]]; then
		mkdir -p $BACKUPDIR
		echo -e " ${BWHITE}* Backing up Dockers conf..."
		tar cvpzf $BACKUP $DOCKERCONFDIR > /dev/null 2>&1
		echo -e "	${GREEN}--> Backup successfully created in $BACKUP${NC}"
	else
		echo -e "	${YELLOW}--> Please launch the script to install Seedbox before make a Backup !${NC}"
	fi
}

function schedule_backup_seedbox() {
	CRONTABFILE="/etc/crontab"
	if (whiptail --title "Schedule Backup" --yesno "Do you want to schedule a configuration backup ?" 10 60) then
		if [[ "$SEEDUSER" == "" ]]; then
			SEEDUSER=$(whiptail --title "Username" --inputbox \
			"Please enter your username :" 7 50 \
			3>&1 1>&2 2>&3)
		fi
		MODELSCRIPT="/opt/seedbox-compose/includes/config/model-backup.sh"
		BACKUPSCRIPT="/home/$SEEDUSER/backup-dockers.sh"
		TMPCRONFILE="/tmp/crontab"
		if [[ -d "/home/$SEEDUSER" ]]; then
			grep -R "$SEEDUSER" "$CRONTABFILE" > /dev/null 2>&1
			if [[ "$?" != "0" ]]; then
				BACKUPDIR=$(whiptail --title "Schedule Backup" --inputbox \
					"Please choose backup destination" 7 65 "/var/backups/" \
					3>&1 1>&2 2>&3)
				DAILYRET=$(whiptail --title "Schedule Backup" --inputbox \
					"How many days you want to keep your daily backups ? (Default : 14 backups)" 9 85 "14" \
					3>&1 1>&2 2>&3)
				WEEKLYRET=$(whiptail --title "Schedule Backup" --inputbox \
					"How many days you want to keep your weekly backups ? (Default : 8 backups)" 9 85 "60" \
					3>&1 1>&2 2>&3)
				MONTHLYRET=$(whiptail --title "Schedule Backup" --inputbox \
					"How many days you want to keep your monthly backups ? (Default : 10 backups)" 9 85 "300" \
					3>&1 1>&2 2>&3)
				touch $BACKUPSCRIPT
				cat $MODELSCRIPT >> $BACKUPSCRIPT
				sed -i "s|%USER%|$SEEDUSER|g" "$BACKUPSCRIPT"
				sed -i "s|%BACKUPDIR%|$BACKUPDIR|g" "$BACKUPSCRIPT"
				sed -i "s|%DAILYRET%|$DAILYRET|g" "$BACKUPSCRIPT"
				sed -i "s|%WEEKLYRET%|$WEEKLYRET|g" "$BACKUPSCRIPT"
				sed -i "s|%MONTHLYRET%|$MONTHLYRET|g" "$BACKUPSCRIPT"
				SCHEDULEBACKUP="@daily bash $BACKUPSCRIPT >/dev/null 2>&1"
				echo $SCHEDULEBACKUP >> $TMPCRONFILE
				cat "$TMPCRONFILE" >> "$CRONTABFILE"
				echo -e " ${BWHITE}* Backup successfully scheduled :${NC}"
				echo -e "	${BWHITE}-->${NC} In ${YELLOW}$BACKUPDIR ${NC}"
				echo -e "	${BWHITE}-->${NC} For ${YELLOW}$SEEDUSER ${NC}"
				echo -e "	${BWHITE}-->${NC} Keep ${YELLOW}$DAILYRET days daily backups ${NC}"
				echo -e "	${BWHITE}-->${NC} Keep ${YELLOW}$WEEKLYRET days weekly backups ${NC}"
				echo -e "	${BWHITE}-->${NC} Keep ${YELLOW}$MONTHLYRET days monthly backups ${NC}"
				echo ""
				rm $TMPCRONFILE
			else
				if (whiptail --title "Schedule Backup" --yesno "A cronjob is already configured for $SEEDUSER. Do you want to delete this job ?" 10 80) then
					USERLINE=$(grep -n "$SEEDUSER" $CRONTABFILE | cut -d: -f1)
					sed -i ''$USERLINE'd' $CRONTABFILE
					echo -e " ${BWHITE}* Cronjob for $SEEDUSER has been deleted !${NC}"
					rm -Rf $BACKUPSCRIPT
					schedule_backup_seedbox
				else
					break
				fi
			fi
		else
			echo -e " ${YELLOW}--> Please install Seedbox for $SEEDUSER before backup${NC}"
			echo ""
		fi
	fi
}

function uninstall_seedbox() {
	clear
	echo -e "${BLUE}##########################################${NC}"
	echo -e "${BLUE}###          UNINSTALL SEEDBOX         ###${NC}"
	echo -e "${BLUE}##########################################${NC}"
	BACKUPDIR="/var/backups"
	CRONTABFILE="/etc/crontab"
	SEEDGROUP=$(cat $GROUPFILE)
	UNINSTALL=$(whiptail --title "Seedbox-Compose" --menu "Choose what you want uninstall" 10 75 2 \
			"1" "Full uninstall (all files and dockers)" \
			"2" "User uninstall (delete a suer)" 3>&1 1>&2 2>&3)
		case $UNINSTALL in
		"1")
		  	if (whiptail --title "Uninstall Seedbox" --yesno "Do you really want to uninstall Seedbox ?" 7 75) then
		  		echo -e " ${BWHITE}* All files, dockers and configuration will be uninstall${NC}"
				if (whiptail --title "Dockers configuration" --yesno "Do you want to backup your Dockers configuration ?" 7 75) then
					DOBACKUP="yes"
				else
					for seeduser in $(cat $USERSFILE)
					do
						if [[ "$DOBACKUP" == "yes" ]]; then
							BACKUPNAME="$BACKUPDIR/backup-seedbox-$seeduser-$backupdate.tar.gz"
							DOCKERCONFDIR="/home/$seeduser/dockers/"
							echo -e " ${BWHITE}* Backing up dockers configuration for $seeduser...${NC}"
							tar cvpzf $BACKUPNAME $DOCKERCONFDIR > /dev/null 2>&1
							checking_errors $?
						fi
						USERHOMEDIR="/home/$seeduser"
						echo -e " ${BWHITE}* Deleting user...${NC}"
						userdel -rf $seeduser > /dev/null 2>&1
						checking_errors $?
						echo -e " ${BWHITE}* Deleting data in your Home directory...${NC}"
						rm -Rf $USERHOMEDIR
						checking_errors $?
						echo -e " ${BWHITE}* Deleting nginx configuration${NC}"
						service nginx stop > /dev/null 2>&1
						rm -Rf /etc/nginx/conf.d/*
						checking_errors $?
						echo -e " ${BWHITE}* Deleting group...${NC}"
						groupdel $SEEDGROUP > /dev/null 2>&1
						checking_errors $?
						echo -e " ${BWHITE}* Stopping Dockers...${NC}"
						docker stop $(docker ps) > /dev/null 2>&1
						checking_errors $?
						echo -e " ${BWHITE}* Removing Dockers...${NC}"
						docker rm $(docker ps -a) > /dev/null 2>&1
						checking_errors $?
						echo -e " ${BWHITE}* Removing Cronjob...${NC}"
						USERLINE=$(grep -n "$seeduser" $CRONTABFILE | cut -d: -f1)
						sed -i ''$USERLINE'd' $CRONTABFILE
						checking_errors $?
					done
					echo -e " ${BWHITE}* Removing Seedbox-compose directory...${NC}"
					rm -Rf /etc/seedboxcompose
					checking_errors $?
					cd /opt && rm -Rf seedbox-compose
					if (whiptail --title "Cloning repo" --yesno "Do you want to redownload Seedbox-compose ?" 7 75) then
						git clone https://github.com/bilyboy785/seedbox-compose.git > /dev/null 2>&1
					fi
					clear
				fi
			fi
		;;
		"2")
			if (whiptail --title "Uninstall Seedbox" --yesno "Do you really want to uninstall Seedbox ?" 7 75) then
				if (whiptail --title "Dockers configuration" --yesno "Do you want to backup your Dockers configuration ?" 7 75) then
					echo -e " ${BWHITE}* All files, dockers and configuration will be uninstall${NC}"
					echo -e "	${RED}--> Under developpment${NC}"
				else
					echo -e " ${BWHITE}* Everything will be deleted !${NC}"
					echo -e "	${RED}--> Under developpment${NC}"
				fi
			fi
		;;
		esac
	echo ""
}

function pause() {
	echo ""
	echo -e "${YELLOW}###  -->PRESS ENTER TO CONTINUE<--  ###${NC}"
	read
	echo ""
}
