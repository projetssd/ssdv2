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
read -p "Votre choix [1-3]: " CHOICE
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
			filebot
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
			#checking_system
			#install_base_packages
			#install_docker
			define_parameters
			#install_traefik
			#install_plexdrive
			#install_rclone
		#	install_portainer
			#install_watchtower
			#install_fail2ban
			#choose_media_folder_plexdrive
			#unionfs_fuse
			#pause
			#choose_services
			##install_services
			#CLOUDPLOWFILE="/home/$SEEDUSER/scripts/cloudplow/config.json"
			#if [[ ! -e "$CLOUDPLOWFILE" ]]; then
			#	cloudplow
		#		sed -i "s/\"enabled\"\: true/\"enabled\"\: false/g" /home/$SEEDUSER/scripts/cloudplow/config.json
			#fi
			#filebot
			#sauve
			#resume_seedbox
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
			define_parameters
			install_docker
			install_plexdrive
			install_rclone
			install_fail2ban
			sauve
			restore
			choose_media_folder_plexdrive
			unionfs_fuse
			docker network create traefik_proxy
			install_traefik
			install_portainer
			install_watchtower
			SERVICESPERUSER="$SERVICESUSER$SEEDUSER"
			while read line; do echo $line | cut -d'-' -f1; done < /home/$SEEDUSER/resume > $SERVICESUSER$SEEDUSER
			mv /home/$SEEDUSER/resume /tmp
			restore_services

			## restauration plex_dupefinder
			PLEXDUPE=/home/$SEEDUSER/scripts/plex_dupefinder/plexdupes.py
			if [[ -e "$PLEXDUPE" ]]; then
			cd /home/$SEEDUSER/scripts/plex_dupefinder
			python3 -m pip install -r requirements.txt > /dev/null 2>&1
			fi

			## restauration cloudplow
			CLOUDPLOWSERVICE=/etc/systemd/system/cloudplow.service
			if [[ -e "$CLOUDPLOWFILE" ]]; then
			cd /home/$SEEDUSER/scripts/cloudplow
			python3 -m pip install -r requirements.txt > /dev/null 2>&1
			ln -s /home/$SEEDUSER/scripts/cloudplow/cloudplow.py /usr/local/bin/cloudplow
			systemctl start cloudplow.service
			fi

			## restauration plex_autoscan
			PLEXSCANSERVICE=/etc/systemd/system/plex_autoscan.service
			if [[ -e "$PLEXSCANSERVICE" ]]; then
			cd /home/$SEEDUSER/scripts/plex_autoscan
			python -m pip install -r requirements.txt > /dev/null 2>&1
			systemctl start plex_autoscan.service
			fi

			## restauration des crons
			(crontab -l | grep . ; echo "*/1 * * * * /opt/seedbox/docker/$SEEDUSER/.filebot/filebot-process.sh") | crontab -

			mv /tmp/resume /home/$SEEDUSER/
			rm $SERVICESUSER$SEEDUSER
			checking_errors $?
    			echo ""
    			echo -e "${CRED}---------------------------------------------------------------${CEND}"
    			echo -e "${CRED}     /!\ RESTAURATION DU SERVEUR EFFECTUEE AVEC SUCCES /!\     ${CEND}"
    			echo -e "${CRED}---------------------------------------------------------------${CEND}"
			echo ""
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
