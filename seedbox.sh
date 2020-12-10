#!/bin/bash

#####################################
# TEST ROOT USER
if [ "$USER" != "root" ]; then
  echo "Ce script doit être lancé par root"
  exit 1
fi

# Absolute path to this script.
CURRENT_SCRIPT=$(readlink -f "$0")
# Absolute path this script is in.
SCRIPTPATH=$(dirname "$CURRENT_SCRIPT")

# shellcheck source=/opt/seedbox-compose/includes/functions.sh
source "${SCRIPTPATH}/includes/functions.sh"
# shellcheck source=/opt/seedbox-compose/includes/variables.sh
source "${SCRIPTPATH}/includes/variables.sh"
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
    grep -q -F 'net.ipv6.conf.all.disable_ipv6 = 1' /etc/sysctl.d/99-sysctl.conf ||
      echo 'net.ipv6.conf.all.disable_ipv6 = 1' >>/etc/sysctl.d/99-sysctl.conf
    grep -q -F 'net.ipv6.conf.default.disable_ipv6 = 1' /etc/sysctl.d/99-sysctl.conf ||
      echo 'net.ipv6.conf.default.disable_ipv6 = 1' >>/etc/sysctl.d/99-sysctl.conf
    grep -q -F 'net.ipv6.conf.lo.disable_ipv6 = 1' /etc/sysctl.d/99-sysctl.conf ||
      echo 'net.ipv6.conf.lo.disable_ipv6 = 1' >>/etc/sysctl.d/99-sysctl.conf
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

  if echo "$osname" "Debian" &>/dev/null; then
    {
      add-apt-repository main
      add-apt-repository non-free
      add-apt-repository contrib
    } >>/dev/null 2>&1
  elif echo "$osname" "Ubuntu" &>/dev/null; then
    {
      add-apt-repository main
      add-apt-repository universe
      add-apt-repository restricted
      add-apt-repository multiverse
    } >>/dev/null 2>&1

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
    python-apt \
    php-curl \
    php-dom \
    nginx \
    php-fpm \
    composer


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
    ansible==${1-$ANSIBLE}

  # Configuration ansible
  mkdir -p /etc/ansible/inventories/ 1>/dev/null 2>&1
  cat <<EOF >/etc/ansible/inventories/local
[local]
127.0.0.1 ansible_connection=local
EOF

  cat <<EOF >/etc/ansible/ansible.cfg
[defaults]
command_warnings = False
callback_whitelist = profile_tasks
deprecation_warnings=False
inventory = /etc/ansible/inventories/local
interpreter_python=/usr/bin/python
EOF
  ## Copy pip to /usr/bin
  cp /usr/local/bin/pip /usr/bin/pip
  cp /usr/local/bin/pip3 /usr/bin/pip3

  clear
  logo
  echo -e "${CCYAN}INSTALLATION SEEDBOX DOCKER${CEND}"
  echo -e "${CGREEN}${CEND}"
  echo -e "${CGREEN}   1) Installation Seedbox via WebUI (En cours de dev)${CEND}"
  echo -e "${CGREEN}   2) Installation Seedbox rclone && gdrive${CEND}"
  echo -e "${CGREEN}   3) Installation Seedbox Classique ${CEND}"
  echo -e "${CGREEN}   4) Restauration Seedbox${CEND}"

  echo -e ""
  read -p "Votre choix [1-3]: " CHOICE
  echo ""
  case $CHOICE in

  1) ## Installation seedbox webui
      mkdir -p /opt/seedbox/variables

      /opt/seedbox-compose/includes/config/scripts/add_user.sh
      echo ""
      status
      update_system
      install_base_packages
      install_docker
      install_traefik

      # on refait le usermod après l'install du docker
      usermod -aG docker $user

      ansible-playbook /opt/seedbox-compose/includes/dockerapps/templates/ansible/ansible.yml
      DOMAIN=$(cat /tmp/domain)
      mkdir /var/www/$DOMAIN > /dev/null 2>&1
      cd /var/www/$DOMAIN > /dev/null 2>&1
      composer install > /dev/null 2>&1
      chown -R www-data:www-data /var/www/$DOMAIN > /dev/null 2>&1
      echo 'www-data ALL=(ALL) NOPASSWD:/var/www/'$DOMAIN'/scripts/manage_service.sh' | sudo EDITOR='tee -a' visudo > /dev/null 2>&1

      echo -e "${CRED}---------------------------------------------------------------${CEND}"
      echo -e "${CRED}          /!\ INSTALLATION EFFECTUEE AVEC SUCCES /!\           ${CEND}"
      echo -e "${CRED}---------------------------------------------------------------${CEND}"
      echo ""
      echo -e "${CRED}---------------------------------------------------------------${CEND}"
      echo -e "${CCYAN}              Adresse de l'interface WebUI                    ${CEND}"
      echo -e "${CCYAN}              https://gui.${DOMAIN}                           ${CEND}"
      echo -e "${CRED}---------------------------------------------------------------${CEND}"
      echo ""

      rm /tmp/domain
      ansible-vault encrypt /opt/seedbox/variables/account.yml > /dev/null 2>&1
      echo -e "\nAppuyer sur ${CCYAN}[ENTREE]${CEND} pour sortir du script..."
      read -r
      exit 1
   ;;

  2) ## Installation de la seedbox Plexdrive

    check_dir "$PWD"
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
      install_watchtower
      install_fail2ban
      choose_media_folder_plexdrive
      unionfs_fuse
      pause
      choose_services
      subdomain
      install_services
      for i in $(docker ps --format "{{.Names}}")
      do
      if [[ "$i" == "plex" ]]; then
        plex_sections
      fi
      done
      projects
      filebot
      sauve
      resume_seedbox
      pause
      ansible-vault encrypt /opt/seedbox/variables/account.yml >/dev/null 2>&1
      script_plexdrive
    else
      script_plexdrive
    fi
    ;;

  3) ## Installation de la seedbox classique

    check_dir "$PWD"
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
      subdomain
      install_services
      filebot
      resume_seedbox
      pause
      ansible-vault encrypt /opt/seedbox/variables/account.yml >/dev/null 2>&1
      touch "/opt/seedbox/media-$SEEDUSER"
      script_classique
    else
      script_classique
    fi
    ;;

  4) ## restauration de la seedbox

    check_dir "$PWD"
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
      rm /etc/systemd/system/mergerfs.service >/dev/null 2>&1
      unionfs_fuse
      cloudflare
      install_traefik
      install_watchtower
      SERVICESPERUSER="$SERVICESUSER$SEEDUSER"
      while read line; do echo $line | cut -d'.' -f1; done <"/home/$SEEDUSER/resume" >"$SERVICESUSER$SEEDUSER"
      rm "/home/$SEEDUSER/resume"
      install_services

      ## restauration plex_dupefinder
      PLEXDUPE=/home/$SEEDUSER/scripts/plex_dupefinder/plex_dupefinder.py
      if [[ -e "$PLEXDUPE" ]]; then
        cd "/home/$SEEDUSER/scripts/plex_dupefinder"
        python3 -m pip install -r requirements.txt
      fi

      ## restauration cloudplow
      CLOUDPLOWSERVICE=/etc/systemd/system/cloudplow.service
      if [[ -e "$CLOUDPLOWSERVICE" ]]; then
        cd "/home/$SEEDUSER/scripts/cloudplow"
        python3 -m pip install -r requirements.txt
        ln -s /home/$SEEDUSER/scripts/cloudplow/cloudplow.py /usr/local/bin/cloudplow
        systemctl start cloudplow.service
      fi

      ## restauration plex_autoscan
      PLEXSCANSERVICE=/etc/systemd/system/plex_autoscan.service
      if [[ -e "$PLEXSCANSERVICE" ]]; then
        cd "/home/$SEEDUSER/scripts/plex_autoscan"
        python -m pip install -r requirements.txt
        systemctl start plex_autoscan.service
      fi

      ## restauration des crons
      (
        crontab -l | grep .
        echo "*/1 * * * * /opt/seedbox/docker/$SEEDUSER/.filebot/filebot-process.sh"
      ) | crontab -
      ln -s "/home/$SEEDUSER/scripts/plex_dupefinder/plex_dupefinder.py" /usr/local/bin/plexdupes
      rm $SERVICESUSER$SEEDUSER
      checking_errors $?
      echo ""
      echo -e "${CRED}---------------------------------------------------------------${CEND}"
      echo -e "${CRED}     /!\ RESTAURATION DU SERVEUR EFFECTUEE AVEC SUCCES /!\     ${CEND}"
      echo -e "${CRED}---------------------------------------------------------------${CEND}"
      echo ""
      pause
      ansible-vault encrypt /opt/seedbox/variables/account.yml >/dev/null 2>&1
      script_plexdrive
    else
      script_plexdrive
    fi
    ;;
  esac

fi
if [ ! -d "/opt/seedbox/status" ]
then
  mkdir -p /opt/seedbox/status
fi
for i in $(docker ps --format "{{.Names}}")
do
  echo "2" > /opt/seedbox/status/${i}
done
PLEXDRIVE="/usr/bin/rclone"
if [[ -e "$PLEXDRIVE" ]]; then
  script_plexdrive
else
  script_classique
fi
