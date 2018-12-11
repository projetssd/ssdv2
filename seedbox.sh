#!/bin/bash

source includes/functions.sh
source includes/variables.sh
clear
logo
echo ""
echo -e "${CCYAN}INSTALLATION${CEND}"
	echo -e "${CGREEN}${CEND}"
	echo -e "${CGREEN}   1) Installation/réinstallation seedbox ${CEND}"
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
				## install traefik
				install_traefik
	    		else
				clear
				echo -e " ${RED}--> Seedbox-Compose already installed !${NC}"
			fi
	    	fi

		;;

		2)
		clear
		logo
		## Ajout d'Utilisateurs
		## Defines parameters for dockers : password, domains and replace it in docker-compose file
		manage_users
 		;;

		3)
		clear
		logo
		echo -e "${CGREEN}   2) Ajout/Supression d'Applis${CEND}"
		echo""
		manage_apps
		;;

	esac	





