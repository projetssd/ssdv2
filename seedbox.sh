#!/bin/bash

source includes/functions.sh
source includes/variables.sh
clear
logo
echo ""

if [[ ! -d "$CONFDIR" ]]; then
echo -e "${CCYAN}INSTALLATION SEEDBOX DOCKER${CEND}"
echo -e "${CGREEN}${CEND}"
echo -e "${CGREEN}   1) Installation Seedbox Classique ${CEND}"
echo -e "${CGREEN}   2) Installation Seedbox Plexdrive${CEND}"
echo -e "${CGREEN}   3) Restauration Seedbox${CEND}"
echo -e ""
read -p "Votre choix [1-3]: " -e -i 1 CHOICE
echo ""
case $CHOICE in
	1) ## Installation de la seedbox classique

	if [ $USER = "root" ] ; then
	check_dir $PWD
		if [[ ! -d "$CONFDIR" ]]; then
	    		clear
			conf_dir
			checking_system
			install_base_packages
			install_docker
			define_parameters
			install_traefik
			add_ftp > /dev/null 2>&1
			install_portainer
			install_watchtower
			install_fail2ban
			choose_media_folder_classique
			choose_services
			install_services
			docker_compose
			install_filebot
			resume_seedbox
			pause
			script_classique
		else
		script_classique
		fi
	fi
	;;

	2) ## Installation de la seedbox Plexdrive

	if [ $USER = "root" ] ; then
	check_dir $PWD
		if [[ ! -d "$CONFDIR" ]]; then
	    		clear
			conf_dir
			checking_system
			install_base_packages
			install_docker
			define_parameters
			install_traefik
			add_ftp > /dev/null 2>&1
			install_plexdrive
			install_rclone
			install_portainer
			install_watchtower
			install_fail2ban
			choose_media_folder_plexdrive
			unionfs_fuse
			pause
			choose_services
			install_services
			docker_compose
			CLOUDPLOWFILE="/home/$SEEDUSER/scripts/cloudplow/config.json"
			if [[ ! -e "$CLOUDPLOWFILE" ]]; then
				cloudplow
				sed -i "s/\"enabled\"\: true/\"enabled\"\: false/g" /home/$SEEDUSER/scripts/cloudplow/config.json
			fi
			install_filebot
			sauve
			resume_seedbox
			pause
			script_plexdrive
		else
		script_plexdrive
		fi
	fi
	;;

	3) ## restauration de la seedbox

	if [ $USER = "root" ] ; then
	check_dir $PWD
		if [[ ! -d "$CONFDIR" ]]; then
			clear
    			echo ""
    			echo -e "${CRED}---------------------------------------------------------------${CEND}"
    			echo -e "${CRED} /!\ ATTENTION : PREPARATION DE LA RESTAURATION DU SERVEUR /!\ ${CEND}"
    			echo -e "${CRED}---------------------------------------------------------------${CEND}"
			echo ""
			conf_dir
			checking_system
			install_base_packages
			install_docker
			create_user
			install_plexdrive
			install_rclone
			install_fail2ban
			sauve
			restore
			choose_media_folder_plexdrive
			unionfs_fuse
			cd /opt/seedbox/docker/traefik
			docker-compose up -d > /dev/null 2>&1
			install_portainer
			install_watchtower
			cd /home/$SEEDUSER
			echo -e "${BLUE}### DOCKERCOMPOSE ###${NC}"
			echo -e " ${BWHITE}* Docker-composing, Merci de patienter...${NC}"
			docker-compose up -d > /dev/null 2>&1
			CLOUDPLOWSERVICE=/etc/systemd/system/cloudplow.service
			if [[ -e "$CLOUDPLOWFILE" ]]; then
			systemctl start cloudplow.service
			fi
			PLEXSCANSERVICE=/etc/systemd/system/plex_autoscan.service
			if [[ -e "$PLEXSCANSERVICE" ]]; then
			systemctl start plex_autoscan.service
			fi
			checking_errors $?
			pause
			script_plexdrive
		else
		script_plexdrive
		fi
	fi
	;;
esac

else
	PLEXDRIVE="/usr/bin/plexdrive"
	if [[ -e "$PLEXDRIVE" ]]; then
		script_plexdrive
	else
		script_classique
	fi
fi
