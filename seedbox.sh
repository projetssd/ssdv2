#!/bin/bash

source includes/functions.sh
source includes/variables.sh
clear
logo
echo ""

if [[ ! -d "/etc/seedboxcompose/" ]]; then
echo -e "${CCYAN}INSTALLATION SEEDBOX DOCKER${CEND}"
echo -e "${CGREEN}${CEND}"
echo -e "${CGREEN}   1) Installation Seedbox Classique ${CEND}"
echo -e "${CGREEN}   2) Installation Seedbox Plexdrive${CEND}"
echo -e ""
read -p "Votre choix [1-2]: " -e -i 1 CHOICE

case $CHOICE in
	1) ## Installation de la seedbox classique

	if [ $USER = "root" ] ; then
	check_dir $PWD
		if [[ ! -d "/etc/seedboxcompose/" ]]; then
	    		clear
			conf_dir
			install_base_packages
			checking_system
			install_docker
			install_zsh
			define_parameters
			install_traefik
			choose_media_folder_classique
			choose_services
			install_services
			docker_compose
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
		if [[ ! -d "/etc/seedboxcompose/" ]]; then
	    		clear
			conf_dir
			install_base_packages
			checking_system
			install_docker
			install_zsh
			define_parameters
			install_traefik
			install_plexdrive
			install_rclone
			choose_media_folder_plexdrive
			unionfs_fuse
			pause
			choose_services
			install_services
			docker_compose
			resume_seedbox
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