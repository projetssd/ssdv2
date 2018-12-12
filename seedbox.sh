#!/bin/bash

source includes/functions.sh
source includes/variables.sh
clear
logo
echo ""

if [[ ! -d "/etc/seedboxcompose/" ]]; then
echo -e "${CCYAN}INSTALLATION${CEND}"
echo -e "${CGREEN}${CEND}"
echo -e "${CGREEN}   1) Installation Seedbox ${CEND}"
echo -e "${CGREEN}   2) Ajout/Supression d'utilisateurs${CEND}"
echo -e "${CGREEN}   3) Ajout/Supression d'Applis${CEND}"
echo -e ""
read -p "Votre choix [1-3]: " -e -i 1 PORT_CHOICE

case $PORT_CHOICE in
	1) ## Installation de la seedbox

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
			choose_services
			install_services
			docker_compose
			resume_seedbox
			pause
			script_option
		else
		script_option
		fi
	fi
	;;

	2)
	clear
	manage_users
 	;;

	3)
	clear
	manage_apps
	;;
esac

else
	script_option
fi