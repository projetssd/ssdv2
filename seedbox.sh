#!/bin/bash

source includes/functions.sh
source includes/variables.sh
clear
if [[ ! -d "$CONFDIR" ]]; then
echo -e "${CCYAN}
 ___  ____  ____  ____  ____  _____  _  _ 
/ __)( ___)(  _ \(  _ \(  _ \(  _  )( \/ )
\__ \ )__)  )(_) ))(_) )) _ < )(_)(  )  ( 
(___/(____)(____/(____/(____/(_____)(_/\_)

${CEND}"

echo ""
echo -e "${CCYAN}---------------------------------${CEND}"
echo -e "${CCYAN}[  INSTALLATION DES PRÉ-REQUIS  ]${CEND}"
echo -e "${CCYAN}---------------------------------${CEND}"
echo ""
echo -e "\n${CGREEN}Appuyer sur ${CEND}${CCYAN}[ENTREE]${CEND}${CGREEN} pour lancer le script${CEND}"
read -r

## Constants
readonly PIP="9.0.3"
readonly ANSIBLE="2.5.14"

## Environmental Variables
export DEBIAN_FRONTEND=noninteractive

## Disable IPv6
if [ -f /etc/sysctl.d/99-sysctl.conf ]; then
    grep -q -F 'net.ipv6.conf.all.disable_ipv6 = 1' /etc/sysctl.d/99-sysctl.conf || \
        echo 'net.ipv6.conf.all.disable_ipv6 = 1' >> /etc/sysctl.d/99-sysctl.conf
    grep -q -F 'net.ipv6.conf.default.disable_ipv6 = 1' /etc/sysctl.d/99-sysctl.conf || \
        echo 'net.ipv6.conf.default.disable_ipv6 = 1' >> /etc/sysctl.d/99-sysctl.conf
    grep -q -F 'net.ipv6.conf.lo.disable_ipv6 = 1' /etc/sysctl.d/99-sysctl.conf || \
        echo 'net.ipv6.conf.lo.disable_ipv6 = 1' >> /etc/sysctl.d/99-sysctl.conf
    sysctl -p
fi

## Install Pre-Dependencies
apt-get install -y --reinstall \
    software-properties-common \
    apt-transport-https \
    lsb-release
apt-get update

## Add apt repos
osname=$(lsb_release -si)

if echo $osname "Debian" &>/dev/null; then
	add-apt-repository main 2>&1 >> /dev/null
	add-apt-repository non-free 2>&1 >> /dev/null
	add-apt-repository contrib 2>&1 >> /dev/null
elif echo $osname "Ubuntu" &>/dev/null; then
	add-apt-repository main 2>&1 >> /dev/null
	add-apt-repository universe 2>&1 >> /dev/null
	add-apt-repository restricted 2>&1 >> /dev/null
	add-apt-repository multiverse 2>&1 >> /dev/null
fi
apt-get update

## Install apt Dependencies
apt-get install -y --reinstall \
    nano \
    git \
    build-essential \
    libssl-dev \
    libffi-dev \
    python3-dev \
    python3-pip \
    python-dev \
    python-pip \
    python-apt

## Install pip3 Dependencies
python3 -m pip install --disable-pip-version-check --upgrade --force-reinstall \
    pip==${PIP}
python3 -m pip install --disable-pip-version-check --upgrade --force-reinstall \
    setuptools
python3 -m pip install --disable-pip-version-check --upgrade --force-reinstall \
    pyOpenSSL \
    requests \
    netaddr

## Install pip2 Dependencies
python -m pip install --disable-pip-version-check --upgrade --force-reinstall \
    pip==${PIP}
python -m pip install --disable-pip-version-check --upgrade --force-reinstall \
    setuptools
python -m pip install --disable-pip-version-check --upgrade --force-reinstall \
    pyOpenSSL \
    requests \
    netaddr \
    jmespath \
    cryptography==2.9.2 \
    ansible==${1-$ANSIBLE}

# Configuration ansible
mkdir -p /etc/ansible/inventories/ 1>/dev/null 2>&1
echo "[local]" > /etc/ansible/inventories/local
echo "127.0.0.1 ansible_connection=local" >> /etc/ansible/inventories/local

### Reference: https://docs.ansible.com/ansible/2.4/intro_configuration.html
echo "[defaults]" > /etc/ansible/ansible.cfg
echo "command_warnings = False" >> /etc/ansible/ansible.cfg
echo "callback_whitelist = profile_tasks" >> /etc/ansible/ansible.cfg
echo "deprecation_warnings=False" >> /etc/ansible/ansible.cfg
echo "inventory = /etc/ansible/inventories/local" >> /etc/ansible/ansible.cfg
echo "interpreter_python=/usr/bin/python" >> /etc/ansible/ansible.cfg

## Copy pip to /usr/bin
cp /usr/local/bin/pip /usr/bin/pip
cp /usr/local/bin/pip3 /usr/bin/pip3
fi

clear
if [[ ! -d "$CONFDIR" ]]; then
logo
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
			update_system
			install_base_packages
			install_docker
			define_parameters
			cloudflare
			oauth
			install_traefik
			install_watchtower
			install_fail2ban
			choose_media_folder_classique
			choose_services
			install_services
			filebot
			resume_seedbox
			pause
			ansible-vault encrypt /opt/seedbox/variables/account.yml > /dev/null 2>&1
			touch /opt/seedbox/media-$SEEDUSER
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
			update_system
			install_base_packages
			install_docker
			define_parameters
			cloudflare
                        oauth
			install_traefik
                        install_rclone
			install_plexdrive
			install_watchtower
			install_fail2ban
			choose_media_folder_plexdrive
			unionfs_fuse
			pause
			choose_services
			install_services
                        projects
			filebot
			sauve
			resume_seedbox
			pause
			ansible-vault encrypt /opt/seedbox/variables/account.yml > /dev/null 2>&1
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
			update_system
			install_base_packages
			install_docker
			define_parameters
			install_plexdrive
			install_rclone
			install_fail2ban
			sauve
			restore
			choose_media_folder_plexdrive
			rm /etc/systemd/system/mergerfs.service > /dev/null 2>&1
			unionfs_fuse
			cloudflare
			install_traefik
			install_watchtower
			SERVICESPERUSER="$SERVICESUSER$SEEDUSER"
			while read line; do echo $line | cut -d'.' -f1; done < /home/$SEEDUSER/resume > $SERVICESUSER$SEEDUSER
			rm /home/$SEEDUSER/resume
			install_services

			## restauration plex_dupefinder
			PLEXDUPE=/home/$SEEDUSER/scripts/plex_dupefinder/plex_dupefinder.py
			if [[ -e "$PLEXDUPE" ]]; then
			cd /home/$SEEDUSER/scripts/plex_dupefinder
			python3 -m pip install -r requirements.txt
			fi

			## restauration cloudplow
			CLOUDPLOWSERVICE=/etc/systemd/system/cloudplow.service
			if [[ -e "$CLOUDPLOWSERVICE" ]]; then
			cd /home/$SEEDUSER/scripts/cloudplow
			python3 -m pip install -r requirements.txt
			ln -s /home/$SEEDUSER/scripts/cloudplow/cloudplow.py /usr/local/bin/cloudplow
			systemctl start cloudplow.service
			fi

			## restauration plex_autoscan
			PLEXSCANSERVICE=/etc/systemd/system/plex_autoscan.service
			if [[ -e "$PLEXSCANSERVICE" ]]; then
			cd /home/$SEEDUSER/scripts/plex_autoscan
			python -m pip install -r requirements.txt
			systemctl start plex_autoscan.service
			fi

			## restauration des crons
			(crontab -l | grep . ; echo "*/1 * * * * /opt/seedbox/docker/$SEEDUSER/.filebot/filebot-process.sh") | crontab -
			ln -s /home/$SEEDUSER/scripts/plex_dupefinder/plex_dupefinder.py /usr/local/bin/plexdupes
			rm $SERVICESUSER$SEEDUSER
			checking_errors $?
    			echo ""
    			echo -e "${CRED}---------------------------------------------------------------${CEND}"
    			echo -e "${CRED}     /!\ RESTAURATION DU SERVEUR EFFECTUEE AVEC SUCCES /!\     ${CEND}"
    			echo -e "${CRED}---------------------------------------------------------------${CEND}"
			echo ""
			pause
			ansible-vault encrypt /opt/seedbox/variables/account.yml > /dev/null 2>&1
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
