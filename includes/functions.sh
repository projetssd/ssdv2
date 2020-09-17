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

function cloudflare() {
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
			read -rp $'\e[33mSouhaitez vous utiliser les DNS Cloudflare ? (o/n)\e[0m :' OUI

			if [[ "$OUI" = "o" ]] || [[ "$OUI" = "O" ]]; then
				ansible-vault decrypt /opt/seedbox/variables/account.yml > /dev/null 2>&1
				if [ -z "$cloud_email" ] || [ -z "$cloud_api" ]; then
    				cloud_email=$1
    				cloud_api=$2
				fi

				while [ -z "$cloud_email" ]; do
    				>&2 echo -n -e "${BWHITE}Votre Email Cloudflare: ${CEND}"
    				read cloud_email
				sed -i "/login:/c\   login: $cloud_email" /opt/seedbox/variables/account.yml
				done

				while [ -z "$cloud_api" ]; do
    				>&2 echo -n -e "${BWHITE}Votre API Cloudflare: ${CEND}"
    				read cloud_api
				sed -i "/api:/c\   api: $cloud_api" /opt/seedbox/variables/account.yml
				done
			fi
		echo ""
}

function oauth() {
		grep -w "client" /opt/seedbox/variables/account.yml | cut -d: -f2 | tr -d ' ' > /dev/null 2>&1
		if [[ "$?" != "0" ]]; then
		echo -e "${BLUE}### Google OAuth2 avec Traefik – Secure SSO pour les services Docker ###${NC}"
		echo ""
			echo -e "${CCYAN}------------------------------------------------------------------${CEND}"
			echo -e "${CCYAN}    Protocole d'identification via Google OAuth2		   ${CEND}"
			echo -e "${CCYAN}    Securisation SSO pour les services Docker			   ${CEND}"
			echo -e "${CCYAN}------------------------------------------------------------------${CEND}"
			echo ""
    			echo -e "${CRED}-------------------------------------------------------------------${CEND}"
    			echo -e "${CRED}    /!\ IMPORTANT: Au préalable créer un projet et vos identifiants${CEND}"
    			echo -e "${CRED}    https://github.com/laster13/patxav/wiki /!\ 		   ${CEND}"
    			echo -e "${CRED}-------------------------------------------------------------------${CEND}"
			echo ""
			read -rp $'\e[33mSouhaitez vous sécuriser vos Applis avec Google OAuth2 ? (o/n)\e[0m :' OUI

			if [[ "$OUI" = "o" ]] || [[ "$OUI" = "O" ]]; then
				if [ -z "$oauth_client" ] || [ -z "$oauth_secret" ] || [ -z "$email" ]; then
    				oauth_client=$1
    				oauth_secret=$2
    				email=$3
				fi

				while [ -z "$oauth_client" ]; do
    				>&2 echo -n -e "${BWHITE}Oauth_client: ${CEND}"
    				read oauth_client
				sed -i "s/client:/client: $oauth_client/" /opt/seedbox/variables/account.yml
				done

				while [ -z "$oauth_secret" ]; do
    				>&2 echo -n -e "${BWHITE}Oauth_secret: ${CEND}"
    				read oauth_secret
				sed -i "s/secret:/secret: $oauth_secret/" /opt/seedbox/variables/account.yml
				done

				while [ -z "$email" ]; do
    				>&2 echo -n -e "${BWHITE}Compte Gmail utilisé(s), séparés d'une virgule si plusieurs: ${CEND}"
    				read email
				sed -i "s/account:/account: $email/" /opt/seedbox/variables/account.yml
				done

				openssl=$(openssl rand -hex 16)
				sed -i "s/openssl:/openssl: $openssl/" /opt/seedbox/variables/account.yml

				echo ""
    				echo -e "${CRED}---------------------------------------------------------------${CEND}"
    				echo -e "${CCYAN}    IMPORTANT:	Avant la 1ere connexion			       ${CEND}"
    				echo -e "${CCYAN}    		- Nettoyer l'historique de votre navigateur    ${CEND}"
    				echo -e "${CCYAN}    		- déconnection de tout compte google	       ${CEND}"
    				echo -e "${CRED}---------------------------------------------------------------${CEND}"
				echo ""
				echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
				read -r
			fi
		fi
		echo ""
}

function rtorrent-cleaner() {
			#configuration de rtorrent-cleaner avec ansible
			echo -e "${BLUE}### RTORRENT-CLEANER ###${NC}"
			echo ""
			echo -e " ${BWHITE}* Installation RTORRENT-CLEANER${NC}"

			## choix de l'utilisateur
			SEEDUSER=$(ls /opt/seedbox/media* | cut -d '-' -f2)
			cp -r $BASEDIR/includes/config/rtorrent-cleaner/rtorrent-cleaner /usr/local/bin
			sed -i "s|%SEEDUSER%|$SEEDUSER|g" /usr/local/bin/rtorrent-cleaner
}

function motd() {
			#configuration d'un motd avec ansible
			echo -e "${BLUE}### MOTD ###${NC}"
			echo -e " ${BWHITE}* Installation MOTD${NC}"
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

function crop() {
			#configuration crop avec ansible
			echo -e "${BLUE}### CROP ###${NC}"
                        /opt/seedbox-compose/includes/config/scripts/crop.sh
			echo -e " ${BWHITE}* Installation crop${NC}"
			ansible-playbook /opt/seedbox-compose/includes/config/roles/crop/tasks/main.yml
			checking_errors $?
}

function backupList() {

    echo ""
    read -rp $'\e[32mSaisir le numéro du teamdrive\e[0m :' n

    if [[ $n -lt 1 ]] || [[ $n -gt $i ]]; then
        echo -e "\n${CRED}/!\ ERREUR: Numéro invalide !${CEND}"
        echo ""
        exit 1
    fi
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
	echo -e "${CGREEN}   1) Désinstaller la seedbox ${CEND}"
	echo -e "${CGREEN}   2) Ajout/Supression d'Applis${CEND}"
	echo -e "${CGREEN}   3) Outils${CEND}"
	echo -e "${CGREEN}   4) Quitter${CEND}"

	echo -e ""
	read -p "Votre choix [1-4]: " PORT_CHOICE

	case $PORT_CHOICE in
		1) ## Installation de la seedbox
		clear
		echo ""
		echo -e "${YELLOW}### Seedbox-Compose déjà installée !###${NC}"
		if (whiptail --title "Seedbox-Compose déjà installée" --yesno "Désinstaller complètement la Seedbox ?" 7 50) then
			if (whiptail --title "ATTENTION" --yesno "Etes vous sur de vouloir désintaller la seedbox ?" 7 55) then
			    uninstall_seedbox
			else
			    script_classique
			fi
		else
			script_classique
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
			echo -e "${CGREEN}   1) Sécuriser la Seedbox${CEND}"
			echo -e "${CGREEN}   2) Mise à jour Seedbox avec Cloudflare${CEND}"
			echo -e "${CGREEN}   3) Changement du nom de Domaine${CEND}"
			if docker ps | grep -q mailserver; then
			echo -e "${YELLOW}   4) Desinstaller Mailserver ${CCYAN}@Hardware-Mondedie.fr${CEND}${NC}"
			else
			echo -e "${CGREEN}   4) Installer Mailserver ${CCYAN}@Hardware-Mondedie.fr${CEND}${NC}"
			fi
			echo -e "${CGREEN}   5) Modèle Création Appli Personnalisée Docker${CEND}"
			echo -e "${CGREEN}   6) Installation du motd${CEND}"
			echo -e "${CGREEN}   7) Traktarr${CEND}"
			echo -e "${CGREEN}   8) Webtools${CEND}"
			echo -e "${CGREEN}   9) rtorrent-cleaner de ${CCYAN}@Magicalex-Mondedie.fr${CEND}${NC}"
			echo -e "${CGREEN}   10) Plex_Patrol${CEND}"
			echo -e "${CGREEN}   11) Retour menu principal${CEND}"
			echo -e ""
			read -p "Votre choix [1-12]: " OUTILS

			case $OUTILS in

			1) ## Mise en place Google OAuth avec Traefik
				clear
				logo
				echo ""
				echo -e "${CCYAN}SECURISER APPLIS DOCKER${CEND}"
				echo -e "${CGREEN}${CEND}"
				echo -e "${CGREEN}   1) Sécuriser Traefik avec Google OAuth2${CEND}"
				echo -e "${CGREEN}   2) Sécuriser avec Authentification Classique${CEND}"
				echo -e "${CGREEN}   3) Ajout / Supression adresses mail autorisées pour Google OAuth2${CEND}"
				echo -e "${CGREEN}   4) Modification port SSH, mise à jour fail2ban, installation Iptables${CEND}"
				echo -e "${CGREEN}   5) Retour menu principal${CEND}"

				echo -e ""
				read -p "Votre choix [1-5]: " OAUTH
				case $OAUTH in

				1)
				clear
				echo ""
				/opt/seedbox-compose/includes/config/scripts/oauth.sh
				script_classique
				;;

				2)
				clear
				echo ""
				ansible-vault decrypt /opt/seedbox/variables/account.yml > /dev/null 2>&1
				sed -i "/client:/c\   client: " /opt/seedbox/variables/account.yml
				sed -i "/secret:/c\   secret: " /opt/seedbox/variables/account.yml
				sed -i "/account:/c\   account: " /opt/seedbox/variables/account.yml
				sed -i "/openssl:/c\   openssl: " /opt/seedbox/variables/account.yml
				/opt/seedbox-compose/includes/config/scripts/basique.sh
				script_classique
				;;

				3)
				clear
				logo
				echo ""
				ansible-vault decrypt /opt/seedbox/variables/account.yml > /dev/null 2>&1
    				>&2 echo -n -e "${BWHITE}Compte(s) Gmail utilisé(s), séparés d'une virgule si plusieurs: ${CEND}"
    				read email
				sed -i "/account:/c\   account: $email" /opt/seedbox/variables/account.yml
				ansible-playbook /opt/seedbox-compose/includes/dockerapps/traefik.yml
				ansible-vault encrypt /opt/seedbox/variables/account.yml > /dev/null 2>&1

				echo -e "${CRED}---------------------------------------------------------------${CEND}"
    				echo -e "${CRED}     /!\ MISE A JOUR EFFECTUEE AVEC SUCCES /!\      ${CEND}"
    				echo -e "${CRED}---------------------------------------------------------------${CEND}"

				echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
				read -r

				script_classique
				;;

				4)
				clear
				echo ""
				/opt/seedbox-compose/includes/config/scripts/iptables.sh
				script_classique
				;;

				5)
				script_classique
				;;

				esac
			;;

			2) ## Mise à jour Cloudflare
			/opt/seedbox-compose/includes/config/scripts/cloudflare.sh
			script_classique
			;;

			3) ## Changement du nom de domaine
			/opt/seedbox-compose/includes/config/scripts/domain.sh
			script_classique
			;;

			4) ## Installation du mailserver @Hardware
			if docker ps | grep -q mailserver; then
			    echo -e "${BLUE}### DESINSTALLATION DU MAILSERVER ###${NC}"
			    echo ""
			    echo -e " ${BWHITE}* désinstallation mailserver @Hardware${NC}"
			    docker rm -f mailserver postfixadmin mariadb redis rainloop > /dev/null 2>&1
			    rm -rf /mnt/docker > /dev/null 2>&1
			    checking_errors $?
			    echo""
			    echo -e "${BLUE}### Mailserver a été supprimé ###${NC}"
			    echo ""
			else
			    echo -e "${BLUE}### INSTALLATION DU MAILSERVER ###${NC}"
			    echo ""
			    echo -e " ${BWHITE}* Installation mailserver @Hardware${NC}"
			    ansible-playbook /opt/seedbox-compose/includes/config/roles/mailserver/tasks/main.yml
			    echo ""
			    echo -e " ${CCYAN}* https://github.com/laster13/patxav/wiki/Configuration-Mailserver-@Hardware${NC}"
			fi
			pause
			script_classique
			;;

			5) ## Modèle création appli docker
			clear
			echo ""
			/opt/seedbox-compose/includes/config/scripts/docker_create.sh
			script_classique
			;;

			6) ## Installation du motd
			clear
			echo ""
			motd
			pause
			script_classique
			;;

			7) ## Installation de traktarr
			clear
			echo ""
			traktarr
			pause
			script_classique
			;;

			8) ## Installation de Webtools
			clear
			echo ""
			webtools
			pause
			script_classique
			;;

			9) ## Installation de rtorrent-cleaner
			clear
			echo ""
			rtorrent-cleaner
			docker run -it --rm -v /home/$SEEDUSER/local/rutorrent:/home/$SEEDUSER/local/rutorrent -v /run/php:/run/php magicalex/rtorrent-cleaner
			pause
			script_classique
			;;

			10) ## Installation Plex_Patrol
			ansible-playbook /opt/seedbox-compose/includes/config/roles/plex_patrol/tasks/main.yml
			SEEDUSER=$(ls /opt/seedbox/media* | cut -d '-' -f2)
			DOMAIN=$(cat /home/$SEEDUSER/resume | tail -1 | cut -d. -f2-3)
			FQDNTMP="plex_patrol.$DOMAIN"
			echo "$FQDNTMP" >> /home/$SEEDUSER/resume
			cp "/opt/seedbox-compose/includes/config/roles/plex_patrol/tasks/main.yml" "$CONFDIR/conf/plex_patrol.yml" > /dev/null 2>&1
    			echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour revenir au menu principal..."
    			read -r
			script_classique
			;;

			11)
			script_classique
			;;

			esac
                ;;

		4)
		exit
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
	echo -e "${CGREEN}   3) Gestion${CEND}"
	echo -e "${CGREEN}   4) Quitter${CEND}"

	echo -e ""
	read -p "Votre choix [1-4]: " PORT_CHOICE

	case $PORT_CHOICE in
		1) ## Installation de la seedbox
		clear
		echo ""
		echo -e "${YELLOW}### Seedbox-Compose déjà installée !###${NC}"
		if (whiptail --title "Seedbox-Compose déjà installée" --yesno "Désinstaller complètement la Seedbox ?" 7 50) then
			if (whiptail --title "ATTENTION" --yesno "Etes vous sur de vouloir désintaller la seedbox ?" 7 55) then
			    uninstall_seedbox
			else
			    script_plexdrive
			fi
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
			echo -e "${CCYAN}GESTION${CEND}"
			echo -e "${CGREEN}${CEND}"
			echo -e "${CGREEN}   1) Sécurisation Syteme${CEND}"
			echo -e "${CGREEN}   2) Utilitaires${CEND}"
			echo -e "${CGREEN}   3) Outils (autoscan, crop, cloudplow etc..)${CEND}"
			echo -e "${CGREEN}   4) Comptes de Service${CEND}"
			echo -e "${CGREEN}   5) Migration drive classique teamdrive/share drive${CEND}"
			echo -e "${CGREEN}   6) Retour menu principal${CEND}"
			echo -e ""
			read -p "Votre choix [1-6]: " GESTION

			case $GESTION in

			1) ## sécurisation systeme
				clear
				logo
				echo ""
				echo -e "${CCYAN}SECURISER APPLIS DOCKER${CEND}"
				echo -e "${CGREEN}${CEND}"
				echo -e "${CGREEN}   1) Sécuriser Traefik avec Google OAuth2${CEND}"
				echo -e "${CGREEN}   2) Sécuriser avec Authentification Classique${CEND}"
				echo -e "${CGREEN}   3) Ajout / Supression adresses mail autorisées pour Google OAuth2${CEND}"
				echo -e "${CGREEN}   4) Modification port SSH, mise à jour fail2ban, installation Iptables${CEND}"
			        echo -e "${CGREEN}   5) Mise à jour Seedbox avec Cloudflare${CEND}"
			        echo -e "${CGREEN}   6) Changement du nom de Domaine${CEND}"
				echo -e "${CGREEN}   7) Retour menu principal${CEND}"

				echo -e ""
				read -p "Votre choix [1-7]: " OAUTH
				case $OAUTH in

				1)
				clear
				echo ""
				/opt/seedbox-compose/includes/config/scripts/oauth.sh
				script_plexdrive
				;;

				2)
				clear
				echo ""
				ansible-vault decrypt /opt/seedbox/variables/account.yml > /dev/null 2>&1
				sed -i "/client:/c\   client: " /opt/seedbox/variables/account.yml
				sed -i "/secret:/c\   secret: " /opt/seedbox/variables/account.yml
				sed -i "/openssl:/c\   openssl: " /opt/seedbox/variables/account.yml
				sed -i "/account:/c\   account: " /opt/seedbox/variables/account.yml

				/opt/seedbox-compose/includes/config/scripts/basique.sh
				script_plexdrive
				;;

				3)
				clear
				logo
				echo ""
				ansible-vault decrypt /opt/seedbox/variables/account.yml > /dev/null 2>&1
    				>&2 echo -n -e "${BWHITE}Compte(s) Gmail utilisé(s), séparés d'une virgule si plusieurs: ${CEND}"
    				read email
				sed -i "/account:/c\   account: $email" /opt/seedbox/variables/account.yml
				ansible-playbook /opt/seedbox-compose/includes/dockerapps/traefik.yml
				ansible-vault encrypt /opt/seedbox/variables/account.yml > /dev/null 2>&1

				echo -e "${CRED}---------------------------------------------------------------${CEND}"
    				echo -e "${CRED}     /!\ MISE A JOUR EFFECTUEE AVEC SUCCES /!\      ${CEND}"
    				echo -e "${CRED}---------------------------------------------------------------${CEND}"

				echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
				read -r

				script_plexdrive
				;;

				4)
				clear
				echo ""
				/opt/seedbox-compose/includes/config/scripts/iptables.sh
				script_plexdrive
				;;

			        5) ## Mise à jour Cloudflare
			        /opt/seedbox-compose/includes/config/scripts/cloudflare.sh
			        script_plexdrive
			        ;;

			        6) ## Changement du nom de domaine
			        /opt/seedbox-compose/includes/config/scripts/domain.sh
			        script_plexdrive
			        ;;

				7)
				script_plexdrive
				;;
				esac
			;;
			2) ## utilitaires
				clear
				logo
				echo ""
				echo -e "${CCYAN}UTILITAIRES${CEND}"
				echo -e "${CGREEN}${CEND}"
			        echo -e "${CGREEN}   1) Installation du motd${CEND}"
			        echo -e "${CGREEN}   2) Traktarr${CEND}"
			        echo -e "${CGREEN}   3) Webtools${CEND}"
			        echo -e "${CGREEN}   4) rtorrent-cleaner de ${CCYAN}@Magicalex-Mondedie.fr${CEND}${NC}"
			        echo -e "${CGREEN}   5) Plex_Patrol${CEND}"
			        echo -e "${CGREEN}   6) Modèle Création Appli Personnalisée Docker${CEND}"
			        if docker ps | grep -q mailserver; then
			        echo -e "${YELLOW}   7) Desinstaller Mailserver ${CCYAN}@Hardware-Mondedie.fr${CEND}${NC}"
			        else
			        echo -e "${CGREEN}   7) Installer Mailserver ${CCYAN}@Hardware-Mondedie.fr${CEND}${NC}"
			        fi
				echo -e "${CGREEN}   8) Retour menu principal${CEND}"


				echo -e ""
				read -p "Votre choix [1-8]: " UTIL
				case $UTIL in


			        1) ## Installation du motd
			        clear
			        echo ""
			        motd
			        pause
			        script_plexdrive
			        ;;

			        2) ## Installation de traktarr
			        clear
			        echo ""
			        traktarr
			        pause
			        script_plexdrive
			        ;;

			        3) ## Installation de Webtools
			        clear
			        echo ""
			        webtools
			        pause
			        script_plexdrive
			        ;;

			        4) ## Installation de rtorrent-cleaner
			        clear
			        echo ""
			        rtorrent-cleaner
			        docker run -it --rm -v /home/$SEEDUSER/local/rutorrent:/home/$SEEDUSER/local/rutorrent -v /run/php:/run/php magicalex/rtorrent-cleaner
			        pause
			        script_plexdrive
			        ;;

			        5) ## Installation Plex_Patrol
			        ansible-playbook /opt/seedbox-compose/includes/config/roles/plex_patrol/tasks/main.yml
			        SEEDUSER=$(ls /opt/seedbox/media* | cut -d '-' -f2)
			        DOMAIN=$(cat /home/$SEEDUSER/resume | tail -1 | cut -d. -f2-3)
			        FQDNTMP="plex_patrol.$DOMAIN"
			        echo "$FQDNTMP" >> /home/$SEEDUSER/resume
			        cp "/opt/seedbox-compose/includes/config/roles/plex_patrol/tasks/main.yml" "$CONFDIR/conf/plex_patrol.yml" > /dev/null 2>&1
    			        echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour revenir au menu principal..."
    			        read -r
			        script_plexdrive
			        ;;

			        6) ## Modèle création appli docker
			        clear
			        echo ""
			        /opt/seedbox-compose/includes/config/scripts/docker_create.sh
			        script_plexdrive
			        ;;

			        7) ## Installation du mailserver @Hardware
			        if docker ps | grep -q mailserver; then
			            echo -e "${BLUE}### DESINSTALLATION DU MAILSERVER ###${NC}"
			            echo ""
			            echo -e " ${BWHITE}* désinstallation mailserver @Hardware${NC}"
			            docker rm -f mailserver postfixadmin mariadb redis rainloop > /dev/null 2>&1
			            rm -rf /mnt/docker > /dev/null 2>&1
			            checking_errors $?
			            echo""
			            echo -e "${BLUE}### Mailserver a été supprimé ###${NC}"
			            echo ""
			        else
			            echo -e "${BLUE}### INSTALLATION DU MAILSERVER ###${NC}"
			            echo ""
			            echo -e " ${BWHITE}* Installation mailserver @Hardware${NC}"
			            ansible-playbook /opt/seedbox-compose/includes/config/roles/mailserver/tasks/main.yml
			            echo ""
			            echo -e " ${CCYAN}* https://github.com/laster13/patxav/wiki/Configuration-Mailserver-@Hardware${NC}"
			        fi
			        pause
			        script_plexdrive
			        ;;

				8)
				script_plexdrive
				;;
			        esac
                        ;;

			3) ## Outils
				clear
				logo
				echo ""
				echo -e "${CCYAN}OUTILS${CEND}"
				echo -e "${CGREEN}${CEND}"
			        echo -e "${CGREEN}   1) Plex_autoscan${CEND}"
			        echo -e "${CGREEN}   2) Autoscan (Nouvelle version de Plex_autoscan)${CEND}"
			        echo -e "${CGREEN}   3) Cloudplow${CEND}"
			        echo -e "${CGREEN}   4) Crop (Nouvelle version de Cloudplow)${CEND}"
			        echo -e "${CGREEN}   5) Plex_dupefinder${CEND}"
				echo -e "${CGREEN}   6) Retour menu principal${CEND}"

				echo -e ""
				read -p "Votre choix [1-6]: " OUTILS
				case $OUTILS in

			        1) ## Installation Plex_autoscan
			        clear
			        echo ""
                                plex_autoscan
			        pause
			        script_plexdrive
			        ;;

			        2) ## Installation Autoscan
			        clear
			        echo ""
		                ansible-playbook /opt/seedbox-compose/includes/config/roles/autoscan/tasks/main.yml
			        pause
			        script_plexdrive
			        ;;

			        3) ## Installation Cloudplow
				        clear
				        logo
				        echo ""
				        echo -e "${CCYAN}OUTILS${CEND}"
				        echo -e "${CGREEN}${CEND}"
			                echo -e "${CGREEN}   1) Cloudplow${CEND}"
			                echo -e "${CGREEN}   2) Configuration Drive backup${CEND}"
				        echo -e "${CGREEN}   3) Retour menu principal${CEND}"

				        echo -e ""
				        read -p "Votre choix [1-3]: " CLOUDPLOW
				        case $CLOUDPLOW in

                                           1) ## Cloudplow
			                   clear
			                   echo ""
                                           cloudplow
			                   pause
			                   script_plexdrive
                                           ;;

                                           2) ## Configuration Drive backup
			                   clear
                                           echo "" 
                                           echo -e "${CCYAN}----------------------------------------------------------------------------------------${CEND}"
                                           echo -e "${CCYAN} 💬  Avant de poursuivre, veillez à ce que votre rclone.conf soit correctement configuré${CEND}"
                                           echo -e "${CCYAN} 💬  Il doit contenir en tout 5 remotes et ressembler à la structure ci dessous         ${CEND}"
                                           echo -e "${CCYAN} 💬  Sinon CTRL^C, préparer le rclone.conf et revenez ensuite sur ce menu               ${CEND}"
                                           echo -e "${CCYAN}----------------------------------------------------------------------------------------${CEND}"
                                           echo ""
                                           echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
                                           read -r

tee <<-EOF
🚀 Cloudplow                           📓 Reference: https://github.com/laster13/patxav
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[exemple]
type = drive
client_id = 950647425050-9s3pd2c1opjch0h1h4mhtrq3fv9jj0gq.apps.googleusercontent.com
client_secret = Gf_3WSMRDDz_fVk3iKYsHs6o
token = {"access_token":"ya29.a0Adw1xeWBiGqEWmZj3ISD5btrRxJDJQ","token_type":"Bearer","refresh_token":"1/Hb8be1u5Dq835U_xDChOIJhs-U9jla6d8kZpO7IYvY0","expiry":"2020-03-13T09:13:49.149678054+01:00"}
root_folder_id = 0AAFkVZtnmiPJUk9PVA

[google]
type = crypt
remote = exemple:Medias
filename_encryption = standard
password = t8zQONXIsAAh0BSbHosblYbCkdDQ
password2 = PjV8d2CRzb6mPUWSGsIeqNw

[plexdrive]
type = crypt
remote = /mnt/plexdrive/Medias
filename_encryption = standard
password = t8zQONXIsAAh0BSbHosblYbCkdDQ
password2 = PjV8d2CRzb6mPUWSGsIeqNw

[toto]
type = drive
client_id = 739487169629-ujunsbvecsi0hmnp1udsd2eb1hj6u3ap.apps.googleusercontent.com
client_secret = Wubh3N7TTt4CEQGmjyUJTJJK
token = {"access_token":"ya29.ImG8BxU8sBZYUIQotF_wt9dhZNGP_T8XQp1v","token_type":"Bearer","refresh_token":"1//03cd7KQXCkky2CgYIARAAGAMSNwF-L9Ira3666CB0VPKSH9XFUivr9z4jTvDOK0wUY5BOWC9wCKK3lGpTWvoiSntZIop7d3p5NFI","expiry":"2020-02-04T07:14:36.525324142+01:00"}
root_folder_id = 0AMF4ckdiP8suUk9PVA

[yohann]
type = crypt
remote = toto:Medias
filename_encryption = standard
password = t8zQONXIsAAh0BSbHosblYbCkdDQ
password2 = PjV8d2CRzb6mPUWSGsIeqNw
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀 Cloudplow                           📓 Reference: https://github.com/laster13/patxav
					EOF

                                         echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer ou CTRL^C pour stopper..."
                                         read -r
                                         /opt/seedbox-compose/includes/config/scripts/syncdrive.sh
                                         script_plexdrive
                                         ;;

                                         3) ## Menu principal
				         script_plexdrive
				         ;;
                                         esac
                                ;;

			        4) ## Installation Crop
			        clear
                                crop
			        echo ""
			        pause
			        script_plexdrive
			        ;;

			        5) ## Installation plex_dupefinder
			        clear
                                plex_dupefinder
			        echo ""
			        pause
			        script_plexdrive
			        ;;

				6)
				script_plexdrive
				;;
                                esac
                        ;;

			4) ## Comptes de Services
				clear
				logo
				echo ""
				echo -e "${CCYAN}COMPTES DE SERVICES${CEND}"
				echo -e "${CGREEN}${CEND}"
			        echo -e "${CGREEN}   1) Création des SA avec sa_gen${CEND}"
			        echo -e "${CGREEN}   2) Création des SA avec safire${CEND}"
				echo -e "${CGREEN}   3) Retour menu principal${CEND}"
				echo -e ""
				read -p "Votre choix [1-3]: " SERVICES
				case $SERVICES in

				1) ## Création des SA avec gen-sa
                                /opt/seedbox-compose/includes/config/scripts/sa-gen.sh
			        script_plexdrive
				;;

				2) ## Creation des SA avec safire
                                /opt/seedbox-compose/includes/config/scripts/safire.sh
			        script_plexdrive
				;;

				3)
				script_plexdrive
				;;
                                esac
                       ;;

                       5) ## Migration my drive --> teamdrive /share drive
                             /opt/seedbox-compose/includes/config/scripts/sasync.sh
                             pause
			     script_plexdrive
                             ;;      

                       6) ## retour menu principal
                             script_plexdrive
		             ;;
                             esac            
                       ;;
                
		4)
		exit
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
	oauth
	echo -e "${BLUE}### TRAEFIK ###${NC}"
		echo -e " ${BWHITE}* Installation Traefik${NC}"
		ansible-playbook /opt/seedbox-compose/includes/dockerapps/traefik.yml
		checking_errors $?		
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
		wget https://github.com/plexdrive/plexdrive/releases/download/5.0.0/plexdrive-linux-amd64 -q -O plexdrive > /dev/null 2>&1
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
        /opt/seedbox-compose/includes/config/scripts/rclone.sh
        /opt/seedbox-compose/includes/config/roles/rclone/tasks/main.yml
	checking_errors $?
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
	cp /opt/seedbox-compose/includes/config/account.yml /opt/seedbox/variables/account.yml
	create_user
	CONTACTEMAIL=$(whiptail --title "Adresse Email" --inputbox \
	"Merci de taper votre adresse Email :" 7 50 3>&1 1>&2 2>&3)
	sed -i "s/mail:/mail: $CONTACTEMAIL/" /opt/seedbox/variables/account.yml

	DOMAIN=$(whiptail --title "Votre nom de Domaine" --inputbox \
	"Merci de taper votre nom de Domaine (exemple: nomdedomaine.fr) :" 7 50 3>&1 1>&2 2>&3)
	sed -i "s/domain:/domain: $DOMAIN/" /opt/seedbox/variables/account.yml
	echo ""
}

function create_user() {
		SEEDGROUP=$(whiptail --title "Group" --inputbox \
        	"Création d'un groupe pour la Seedbox" 7 50 3>&1 1>&2 2>&3)
    		egrep "^$SEEDGROUP" /etc/group >/dev/null
		if [[ "$?" != "0" ]]; then
			echo -e " ${BWHITE}* Création du groupe $SEEDGROUP"
	    	groupadd $SEEDGROUP
	    	checking_errors $?
		else
	    	echo -e " ${YELLOW}* Le groupe $SEEDGROUP existe déjà.${NC}"
		fi
		sed -i "s/group:/group: $SEEDGROUP/" /opt/seedbox/variables/account.yml

		SEEDUSER=$(whiptail --title "Administrateur" --inputbox \
			"Nom d'Administrateur de la Seedbox :" 7 50 3>&1 1>&2 2>&3)
		[[ "$?" = 1 ]] && script_plexdrive;
		PASSWORD=$(whiptail --title "Password" --passwordbox \
			"Mot de passe :" 7 50 3>&1 1>&2 2>&3)
		sed -i "s/pass:/pass: $PASSWORD/" /opt/seedbox/variables/account.yml
		egrep "^$SEEDUSER" /etc/passwd >/dev/null
		if [ $? -eq 0 ]; then
			echo -e " ${YELLOW}* L'utilisateur existe déjà !${NC}"
			USERID=$(id -u $SEEDUSER)
			GRPID=$(id -g $SEEDUSER)
			sed -i "s/userid:/userid: $USERID/" /opt/seedbox/variables/account.yml
			sed -i "s/groupid:/groupid: $GRPID/" /opt/seedbox/variables/account.yml
			usermod -a -G docker $SEEDUSER > /dev/null 2>&1
			echo -e " ${BWHITE}* Ajout de $SEEDUSER à $SEEDGROUP"
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
			sed -i "s/userid:/userid: $USERID/" /opt/seedbox/variables/account.yml
			sed -i "s/groupid:/groupid: $GRPID/" /opt/seedbox/variables/account.yml
		fi
		htpasswd -c -b /tmp/.htpasswd $SEEDUSER $PASSWORD > /dev/null 2>&1
		htpwd=$(cat /tmp/.htpasswd)
		sed -i "/htpwd:/c\   htpwd: $htpwd" /opt/seedbox/variables/account.yml
		sed -i "s/name:/name: $SEEDUSER/" /opt/seedbox/variables/account.yml
		echo $PASSWORD > ~/.vault_pass
		echo "vault_password_file = ~/.vault_pass" >> /etc/ansible/ansible.cfg
		return
}

function choose_services() {
	echo -e "${BLUE}### SERVICES ###${NC}"
	echo -e " ${BWHITE}--> Services en cours d'installation : ${NC}"
	SERVICESPERUSER="$SERVICESUSER$SEEDUSER"
	rm -Rf $SERVICESPERUSER > /dev/null 2>&1
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
	"Appuyer sur la barre espace pour la sélection" 28 64 21 \
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

function choose_other_services() {
	echo -e "${BLUE}### SERVICES ###${NC}"
	echo -e " ${BWHITE}--> Services en cours d'installation : ${NC}"
	SERVICESPERUSER="$SERVICESUSER$SEEDUSER"
	rm -Rf $SERVICESPERUSER > /dev/null 2>&1
	menuservices="/tmp/menuservices.txt"
	if [[ -e "$menuservices" ]]; then
	rm /tmp/menuservices.txt
	fi

	for app in $(cat /opt/seedbox-compose/includes/config/other-services-available);
	do
		service=$(echo $app | cut -d\- -f1)
		desc=$(echo $app | cut -d\- -f2)
		echo "$service $desc off" >> /tmp/menuservices.txt
	done
	SERVICESTOINSTALL=$(whiptail --title "Gestion des Applications" --checklist \
	"Appuyer sur la barre espace pour la sélection" 28 64 21 \
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
	grep 'mariadb' /opt/seedbox/docker/$SEEDUSER/webserver/resume > /dev/null 2>&1
	if [[ "$?" == "0" ]]; then
	   sed -i "/Mariadb/d" /tmp/menuservices.txt
	fi

	grep 'phpmyadmin' /opt/seedbox/docker/$SEEDUSER/webserver/resume > /dev/null 2>&1
	if [[ "$?" == "0" ]]; then
	   sed -i "/Phpmyadmin/d" /tmp/menuservices.txt
	fi

	SERVICESTOINSTALL=$(whiptail --title "Gestion Webserver" --checklist \
	"Applis à ajouter pour $SEEDUSER" 17 54 10 \
	$(cat /tmp/menuservices.txt) 3>&1 1>&2 2>&3)
	[[ "$?" = 1 ]] && script_plexdrive;


	SERVICESPERUSER="$SERVICESUSER$SEEDUSER"
	touch $SERVICESPERUSER
	for APPDOCKER in $SERVICESTOINSTALL
	do
		echo -e "	${GREEN}* $(echo $APPDOCKER | tr -d '"')${NC}"
		echo $(echo ${APPDOCKER,,} | tr -d '"') >> $SERVICESPERUSER
	done
	echo ""
	rm /tmp/menuservices.txt
}

function choose_media_folder_classique() {
	echo -e "${BLUE}### DOSSIERS MEDIAS ###${NC}"
	echo -e " ${BWHITE}--> Création des dossiers Medias : ${NC}"
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

function install_services() {
	INSTALLEDFILE="/home/$SEEDUSER/resume"
	touch $INSTALLEDFILE > /dev/null 2>&1

	if [[ ! -d "$CONFDIR/conf" ]]; then
		mkdir -p $CONFDIR/conf > /dev/null 2>&1
	fi

	## préparation installation
	for line in $(cat $SERVICESPERUSER);
	do
		if [ -e "$CONFDIR/conf/$line.yml" ]; then
			ansible-playbook "$CONFDIR/conf/$line.yml"

		elif [[ "$line" == "plex" ]]; then
			echo -e "${BLUE}### CONFIG POST COMPOSE PLEX ###${NC}"
			echo -e " ${BWHITE}* Processing plex config file...${NC}"
			echo ""
			echo -e " ${GREEN}ATTENTION IMPORTANT - NE PAS FAIRE D'ERREUR - SINON DESINSTALLER ET REINSTALLER${NC}"
			ansible-vault decrypt /opt/seedbox/variables/account.yml > /dev/null 2>&1
			token=$(. /opt/seedbox-compose/includes/config/roles/plex_autoscan/plex_token.sh)
			sed -i "/token:/c\   token: $token" /opt/seedbox/variables/account.yml
			ansible-playbook /opt/seedbox-compose/includes/config/roles/plex/tasks/main.yml
			ansible-vault encrypt /opt/seedbox/variables/account.yml > /dev/null 2>&1

		elif [[ "$line" == "mattermost" ]]; then
			/opt/seedbox-compose/includes/dockerapps/templates/mattermost/mattermost.sh

		else
			ansible-playbook "$BASEDIR/includes/dockerapps/$line.yml"
			cp "$BASEDIR/includes/dockerapps/$line.yml" "$CONFDIR/conf/$line.yml" > /dev/null 2>&1
		fi

		if [[ "$line" == "plex" ]]; then
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
		checking_errors $?
		echo ""
		echo -e "${BLUE}### SUBSONIC PREMIUM ###${NC}"
		echo -e "${BWHITE}	--> laster13@hotmail.com${NC}"
		echo -e "${BWHITE}	--> e402ff7ee47915446e7c2d8c8f83fad9${NC}"
		echo -e "\nNoter les ${CCYAN}informations du dessus${CEND} et appuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
		read -r
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

		if [[ "$line" == "piwigo" ]]; then
		echo ""
		echo -e "${BLUE}### CONFIG POST COMPOSE PIWIGO ###${NC}"
		echo -e " ${BWHITE}* Configuration piwigo...${NC}"
		echo ""
			echo -e "${CCYAN}-----------------------------------------------------------------------------------${CEND}"
			echo -e "${CGREEN}		Localhost: 'db-piwigo'						    ${CEND}"
			echo -e "${CGREEN}		MYSQL_DATABASE: 'piwigodb'					    ${CEND}"
 			echo -e "${YELLOW}		MYSQL_USER: 'piwigo'						    ${CEND}"
			echo -e "${YELLOW}		MYSQL_PASSWORD: 'piwigo'					    ${CEND}"
			echo -e "${CGREEN}		MYSQL_ROOT_PASSWORD: 'piwigo'					    ${CEND}"
			echo -e "${CCYAN}-----------------------------------------------------------------------------------${CEND}"
		echo ""
		echo -e "\nNoter les ${CCYAN}informations du dessus${CEND} et appuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
		read -r
		fi

		if [[ "$line" == "pydio" ]]; then
		echo ""
		echo -e "${BLUE}### CONFIG POST COMPOSE PYDIO ###${NC}"
		echo -e " ${BWHITE}* Configuration pydio...${NC}"
		echo ""
			echo -e "${CCYAN}-----------------------------------------------------------------------------------${CEND}"
			echo -e "${CGREEN}		Localhost: 'db-pydio'						    ${CEND}"
			echo -e "${CGREEN}		MYSQL_DATABASE: 'pydio'					            ${CEND}"
 			echo -e "${YELLOW}		MYSQL_USER: 'pydio'						    ${CEND}"
			echo -e "${YELLOW}		MYSQL_PASSWORD: 'pydio'					            ${CEND}"
			echo -e "${CGREEN}		MYSQL_ROOT_PASSWORD: 'pydio'					    ${CEND}"
			echo -e "${CCYAN}-----------------------------------------------------------------------------------${CEND}"
		echo ""
		echo -e "\nNoter les ${CCYAN}informations du dessus${CEND} et appuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
		read -r
		fi

		if [[ "$line" == "authelia" ]]; then
		echo ""
		echo -e "${BLUE}### CONFIG POST COMPOSE AUTHELIA ###${NC}"
		echo -e " ${BWHITE}* Configuration Apllications avec Authelia...${NC}"
		echo ""
		/opt/seedbox-compose/includes/config/scripts/authelia.sh
		echo ""
		echo -e "\nNoter les ${CCYAN}informations du dessus${CEND} et appuyer sur ${CCYAN}[ENTREE]${CEND} pour continuer..."
		read -r
		fi

		if [[ "$line" == "wordpress" ]]; then
		echo ""
		echo -e "${BLUE}### CONFIG POST COMPOSE WORDPRESS ###${NC}"
		echo ""
echo -e "${CCYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
					tee <<-EOF
🚀 Wordpress                           📓 Reference: https://github.com/laster13/patxav
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💬 Réglages pour modifier le site complet en SSL (Section admin comprise)

[1] Télécharger l'extension SSL Insecure Content Fixer
[2] Séléctionner ' HTTP_X_FORWARDED_PROTO (ex. load balancer, reverse proxy, NginX)'
[3] Réglages/Général modifier par https dans les url

💬 Infos base de données

Nom de la base de données: wordpress
Identifiant: wordpress
Mot de passe: wordpress
Adresse de la base de données: db-wordpress
Préfixe des tables: laisser par défault

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀 Wordpress                           📓 Reference: https://github.com/laster13/patxav
					EOF
echo -e "${CCYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
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
                        fi
}

function manage_apps() {
	echo -e "${BLUE}##########################################${NC}"
	echo -e "${BLUE}###          GESTION DES APPLIS        ###${NC}"
	echo -e "${BLUE}##########################################${NC}"
        ansible-playbook /opt/seedbox-compose/includes/dockerapps/templates/ansible/ansible.yml
	SEEDUSER=$(cat /tmp/name)
	DOMAIN=$(cat /tmp/domain)
        SEEDGROUP=$(cat /tmp/group)
        rm /tmp/name /tmp/domain /tmp/group
	USERRESUMEFILE="/home/$SEEDUSER/resume"
	echo ""
	echo -e "${GREEN}### Gestion des Applis pour: $SEEDUSER ###${NC}"
	## CHOOSE AN ACTION FOR APPS
	ACTIONONAPP=$(whiptail --title "App Manager" --menu \
	                "Selectionner une action :" 12 50 4 \
	                "1" "Ajout Applications"  \
	                "2" "Suppression Applications"  \
			"3" "Réinitialisation Container" \
 			"4" "Ajout/Supression Sites Web" 3>&1 1>&2 2>&3)
	[[ "$?" = 1 ]] && if [[ -e "$PLEXDRIVE" ]]; then script_plexdrive; else script_classique; fi;


	case $ACTIONONAPP in
		"1" ) ## Ajout APP
	                APPLISEEDBOX=$(whiptail --title "App Manager" --menu \
	                                "Selectionner une action :" 12 50 4 \
	                                "1" "Applications Seedbox"  \
 			                "2" "Autres Applications" 3>&1 1>&2 2>&3)
	                [[ "$?" = 1 ]] && if [[ -e "$PLEXDRIVE" ]]; then script_plexdrive; else script_classique; fi;
                        case $APPLISEEDBOX in
                                 "1" ) ## Ajout Applications Seedbox
			                  echo -e " ${BWHITE}* Resume file: $USERRESUMEFILE${NC}"
			                  echo ""
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

                                 "2" )  ## Autres Applications
			                  echo -e " ${BWHITE}* Resume file: $USERRESUMEFILE${NC}"
			                  echo ""
			                  choose_other_services
			                  install_services
			                  resume_seedbox
			                  pause
			                  if [[ -e "$PLEXDRIVE" ]]; then
				             script_plexdrive
			                  else
				             script_classique
			                  fi
                                          ;;
                        esac
                 ;;

		"2" ) ## Suppression APP
			echo -e " ${BWHITE}* Resume file: $USERRESUMEFILE${NC}"
			echo ""

			[ -s /home/$SEEDUSER/resume ]
			if [[ "$?" == "1" ]]; then
				echo -e " ${BWHITE}* Pas d'Applis à Désinstaller ${NC}"
				pause
				ansible-vault encrypt /opt/seedbox/variables/account.yml
				if [[ -e "$PLEXDRIVE" ]]; then
					script_plexdrive
				else
					script_classique
				fi
			fi

			echo -e " ${BWHITE}* Application en cours de suppression${NC}"
			TABSERVICES=()
			for SERVICEACTIVATED in $(cat $USERRESUMEFILE)
			do
			        SERVICE=$(echo $SERVICEACTIVATED | cut -d\. -f1)
			        TABSERVICES+=( ${SERVICE//\"} " " )
			done
			APPSELECTED=$(whiptail --title "App Manager" --menu \
			              "Sélectionner l'Appli à supprimer" 19 45 11 \
			              "${TABSERVICES[@]}"  3>&1 1>&2 2>&3)
			[[ "$?" = 1 ]] && if [[ -e "$PLEXDRIVE" ]]; then script_plexdrive; else script_classique; fi;
			echo -e " ${GREEN}   * $APPSELECTED${NC}"
			docker rm -f "$APPSELECTED"
			sed -i "/$APPSELECTED/d" /home/$SEEDUSER/resume
			rm -rf /opt/seedbox/docker/$SEEDUSER/$APPSELECTED

			if [[ "$APPSELECTED" != "plex" ]]; then
			rm $CONFDIR/conf/$APPSELECTED.yml > /dev/null 2>&1
			fi

			if [[ "$APPSELECTED" = "seafile" ]]; then
			docker rm -f db-seafile memcached 
			fi

			if docker ps | grep -q db-$APPSELECTED; then
			docker rm -f db-$APPSELECTED
			fi

			if [[ "$APPSELECTED" = "varken" ]]; then
			docker rm -f influxdb telegraf grafana
			rm -rf /opt/seedbox/docker/$SEEDUSER/telegraf
			rm -rf /opt/seedbox/docker/$SEEDUSER/grafana
			rm -rf /opt/seedbox/docker/$SEEDUSER/influxdb
			fi

			if [[ "$APPSELECTED" = "jitsi" ]]; then
			docker rm -f prosody jicofo jvb
			rm -rf /opt/seedbox/docker/$SEEDUSER/.jitsi-meet-cfg
			fi

			if [[ "$APPSELECTED" = "nextcloud" ]]; then
			docker rm -f collabora coturn office
			rm -rf /opt/seedbox/docker/$SEEDUSER/coturn
			fi

			if [[ "$APPSELECTED" = "rtorrentvpn" ]]; then
			rm /opt/seedbox/conf/rutorrent-vpn.yml
			fi

			if [[ "$APPSELECTED" = "authelia" ]]; then
			/opt/seedbox-compose/includes/config/scripts/authelia.sh
			sed -i '/authelia/d' /home/$SEEDUSER/resume > /dev/null 2>&1
			fi

			docker system prune -af > /dev/null 2>&1
			checking_errors $?
			docker volume rm $(docker volume ls -qf "dangling=true") > /dev/null 2>&1
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
			[[ "$?" = 1 ]] && if [[ -e "$PLEXDRIVE" ]]; then script_plexdrive; else script_classique; fi;
			echo -e " ${GREEN}   * $line${NC}"

			if [ $line = "php5" ] || [ $line = "php7" ]; then
				image=$(docker images | grep "php" | awk '{print $3}')
			elif [ $line = "sonarr3" ]; then
				image=$(docker images | grep "sonarr" | awk '{print $3}')
			else
				image=$(docker images | grep "$line" | awk '{print $3}')
			fi

			docker rm -f "$line" > /dev/null 2>&1
			docker system prune -af > /dev/null 2>&1
			docker volume rm $(docker volume ls -qf "dangling=true") > /dev/null 2>&1
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
			INSTALLEDFILE="/opt/seedbox/docker/$SEEDUSER/webserver/resume"
			touch $INSTALLEDFILE > /dev/null 2>&1
			echo -e " ${BWHITE}* Resume file: $INSTALLEDFILE ${NC}"
			echo ""

			## CHOOSE AN ACTION FOR SITE
			ACTIONONAPP=$(whiptail --title "Site Web - Nginx" --menu \
	                		"Selectionner une action :" 12 50 4 \
	                		"1" "Ajout Site Web"  \
 					"2" "Supression Site Web" 3>&1 1>&2 2>&3)
			[[ "$?" = 1 ]] && if [[ -e "$PLEXDRIVE" ]]; then script_plexdrive; else script_classique; fi;

			case $ACTIONONAPP in
				"1" ) ## Ajout Site Web
					var="/tmp/menuservices.txt"
					if [[ -e "$var" ]]; then
						rm $var
					fi
					webserver
					for line in $(cat $SERVICESPERUSER);
					do
						ansible-playbook "$BASEDIR/includes/webserver/$line.yml"
					done
					rm -Rf $SERVICESPERUSER > /dev/null 2>&1

					if [[ "$line" == "mariadb" ]]; then
					clear
					echo ""
echo -e "${CCYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
					tee <<-EOF
🚀 Mariadb                            📓 Reference: https://github.com/laster13/patxav
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💬 Création d'une base de donnée Mariadb (Exemple pour wordpress)

[1] docker exec -ti mariadb bash
[2] mysql -u root -p (mot de passe: mysql)
[3] CREATE DATABASE wordpress;
[4] CREATE USER 'wordpress'@'localhost' IDENTIFIED BY 'mysql';
[5] GRANT USAGE ON *.* TO 'wordpress'@'localhost';
[6] GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress'@'localhost';
[7] FLUSH PRIVILEGES;
[8] exit

En suivant ce procédé vous pouvez créer autant de base de données que nécessaire
Ou bien utiliser Phpmyadmin

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀 Mariadb                            📓 Reference: https://github.com/laster13/patxav
					EOF
echo -e "${CCYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
					fi
					pause
					if [[ -e "$PLEXDRIVE" ]]; then
						script_plexdrive
					else
						script_classique
					fi
					;;

				"2" ) ## Suppression APP
					echo -e " ${BWHITE}* Site Web en cours de suppression${NC}"
					[ -s /opt/seedbox/docker/$SEEDUSER/webserver/resume ]
					if [[ "$?" == "1" ]]; then
					echo -e " ${BWHITE}* Pas de Sites à Désinstaller ${NC}"
					pause
					script_plexdrive
					fi
					TABSERVICES=()
					for SERVICEACTIVATED in $(cat $INSTALLEDFILE)
					do
			        		SERVICE=$(echo $SERVICEACTIVATED)
			        		TABSERVICES+=( ${SERVICE//\"} " " )
					done
					APPSELECTED=$(whiptail --title "App Manager" --menu \
			              		"Sélectionner l'Appli à supprimer" 19 45 11 \
			              		"${TABSERVICES[@]}"  3>&1 1>&2 2>&3)
					[[ "$?" = 1 ]] && if [[ -e "$PLEXDRIVE" ]]; then script_plexdrive; else script_classique; fi;

					docker rm -f "$APPSELECTED"
					sed -i "/$APPSELECTED/d" $INSTALLEDFILE
					rm -rf /opt/seedbox/docker/$SEEDUSER/webserver/$APPSELECTED
					checking_errors $?
 					docker rm -f php7-$APPSELECTED > /dev/null 2>&1
					docker rm -f php5-$APPSELECTED > /dev/null 2>&1

					docker system prune -af > /dev/null 2>&1
					docker volume rm $(docker volume ls -qf "dangling=true") > /dev/null 2>&1

					echo ""
					echo -e " ${CCYAN}* $APPSELECTED à bien été désinstallé ${NC}"
					pause
					if [[ -e "$PLEXDRIVE" ]]; then
						script_plexdrive
					else
						script_classique
					fi

					;;
			                esac
	          esac
}

function resume_seedbox() {
	echo -e "${BLUE}##########################################${NC}"
	echo -e "${BLUE}###     INFORMATION SEEDBOX INSTALL    ###${NC}"
	echo -e "${BLUE}##########################################${NC}"
	echo -e " ${BWHITE}* Accès Applis à partir de URL :${NC}"
	PASSE=$(cat ~/.vault_pass)
	for line in $(cat $INSTALLEDFILE);
	do
		ACCESSDOMAIN=$(echo $line)
		DOCKERAPP=$(echo $line | cut -d\. -f1)
		echo -e "	--> ${BWHITE}$DOCKERAPP${NC} --> ${YELLOW}$ACCESSDOMAIN${NC}"
	done
	echo ""
	echo -e " ${BWHITE}* Vos IDs :${NC}"
	echo -e "	--> Utilisateur: ${YELLOW}$SEEDUSER${NC}"
	echo -e "	--> Password: ${YELLOW}$PASSE${NC}"
	echo ""
	rm -Rf $SERVICESPERUSER > /dev/null 2>&1
	ansible-vault encrypt /opt/seedbox/variables/account.yml
}

function uninstall_seedbox() {
	clear
	echo -e "${BLUE}##########################################${NC}"
	echo -e "${BLUE}###       DESINSTALLATION SEEDBOX      ###${NC}"
	echo -e "${BLUE}##########################################${NC}"

	## variables
        ansible-playbook /opt/seedbox-compose/includes/dockerapps/templates/ansible/ansible.yml
	SEEDUSER=$(cat /tmp/name)
	DOMAIN=$(cat /tmp/domain)
        SEEDGROUP=$(cat /tmp/group)
        rm /tmp/name /tmp/domain /tmp/group

	USERHOMEDIR="/home/$SEEDUSER"
	PLEXDRIVE="/usr/bin/plexdrive"
        PLEXSCAN="$USERHOMEDIR/scripts/plex_autoscan/scan.py"
        CLOUDPLOW="$USERHOMEDIR/scripts/cloudplow/cloudplow.py"
        CROP="$USERHOMEDIR/scripts/crop/crop"

	if [[ -e "$PLEXDRIVE" ]]; then
		echo -e " ${BWHITE}* Suppression Plexdrive${NC}"
		service plexdrive stop > /dev/null 2>&1
		rm /etc/systemd/system/plexdrive.service > /dev/null 2>&1
		rm -rf /mnt/plexdrive > /dev/null 2>&1
		rm -rf /root/.plexdrive > /dev/null 2>&1
		rm /usr/bin/plexdrive > /dev/null 2>&1
		checking_errors $?
                
                if [[ -e "$PLEXSCAN" ]]; then
		echo -e " ${BWHITE}* Suppression plex_autoscan${NC}"
		systemctl stop plex_autoscan.service > /dev/null 2>&1
		systemctl disable plex_autoscan.service > /dev/null 2>&1
		rm /etc/systemd/system/plex_autoscan.service > /dev/null 2>&1
		checking_errors $?
                fi

		echo -e " ${BWHITE}* Suppression rclone${NC}"
		systemctl stop rclone.service > /dev/null 2>&1
		systemctl disable rclone.service > /dev/null 2>&1
		rm /etc/systemd/system/rclone.service > /dev/null 2>&1
		rm /usr/bin/rclone > /dev/null 2>&1
		rm -rf /mnt/rclone > /dev/null 2>&1
		rm -rf /root/.config/rclone > /dev/null 2>&1
		checking_errors $?

                if [[ -e "$CLOUDPLOW" ]]; then
		echo -e " ${BWHITE}* Suppression cloudplow${NC}"
		systemctl stop cloudplow.service > /dev/null 2>&1
		systemctl disable cloudplow.service > /dev/null 2>&1
		rm /etc/systemd/system/cloudplow.service > /dev/null 2>&1
		checking_errors $?
                fi

                if [[ -e "$CROP" ]]; then
		echo -e " ${BWHITE}* Suppression cloudplow${NC}"
		systemctl stop crop_upload.service > /dev/null 2>&1
		systemctl stop crop_sync.service > /dev/null 2>&1
		systemctl stop crop_upload.timer > /dev/null 2>&1
		systemctl stop crop_sync.timer > /dev/null 2>&1

		systemctl disable crop_upload.service > /dev/null 2>&1
		systemctl disable crop_sync.service > /dev/null 2>&1
		systemctl disable crop_upload.timer > /dev/null 2>&1
		systemctl disable crop_sync.service > /dev/null 2>&1

		rm /etc/systemd/system/crop_upload.service > /dev/null 2>&1
		rm /etc/systemd/system/crop_sync.service > /dev/null 2>&1
		rm /etc/systemd/system/crop_upload.timer > /dev/null 2>&1
		rm /etc/systemd/system/crop_sync.timer > /dev/null 2>&1

		checking_errors $?
                fi

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
