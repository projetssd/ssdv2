#!/bin/bash
###############################################################
# SSD : prerequis.sh                                          #
# Installe les prérequis avant l'installation d'une seedbox   #
# Si un fichier de configuration existe déjà                  #
# il ne sera pas touché                                       #
###############################################################

if [ "$USER" != "root" ]; then
  echo "Ce script doit être lancé par root ou en sudo"
  exit 1
fi

## Constants
readonly PIP="9.0.3"
readonly ANSIBLE="2.9"

## Environmental Variables
export DEBIAN_FRONTEND=noninteractive

## Install Pre-Dependencies
apt-get update
apt-get install -y --reinstall \
  software-properties-common \
  apt-transport-https \
  lsb-release \
  sudo
## Add apt repos
osname=$(lsb_release -si)
osversion=$(lsb_release -sr)

if [[ "$osname" == "Debian" ]]; then
  # Si c'est Debian, nous vérifions la version
  if [[ "$osversion" == "11" ]]; then
    # Si c'est Debian 11, nous installons python3-apt-dbg
    apt-get install -y --reinstall python3-apt-dbg
  fi

  # Ajout des dépôts
  add-apt-repository main <<< 'yes'
  add-apt-repository non-free <<< 'yes'
  add-apt-repository contrib <<< 'yes'
elif [[ "$osname" == "Ubuntu" ]]; then
  # Ajout des dépôts pour Ubuntu
  add-apt-repository main <<< 'yes'
  add-apt-repository universe <<< 'yes'
  add-apt-repository restricted <<< 'yes'
  add-apt-repository multiverse <<< 'yes'
fi

apt-get update

## Install apt Dependencies
apt-get install -y --reinstall \
  nano \
  build-essential \
  libssl-dev \
  libffi-dev \
  python3-dev \
  python3-pip \
  python3-venv \
  sqlite3 \
  apache2-utils \
  dnsutils \
  python3-apt \
  python-apt-doc \
  python-apt-common \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  fuse3 \
  apparmor


rm -f /usr/bin/python

ln -s /usr/bin/python3 /usr/bin/python

cat <<EOF >/etc/logrotate.d/ansible
${SETTINGS_SOURCE}/logs/*.log {
  rotate 7
  daily
  compress
  missingok
}
EOF

if [ ! -f /etc/sudoers.d/${1} ]; then
  echo "${1} ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/${1}
fi
