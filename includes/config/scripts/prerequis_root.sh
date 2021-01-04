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
lsb-release
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
python-apt \
sqlite3 \
apache2-utils

rm -f /usr/bin/python

ln -s /usr/bin/python3 /usr/bin/python


chmod 777 ${1}/logs


cat << EOF > /etc/logrotate.d/ansible
${SCRIPTPATH}/logs/ansible.log {
  rotate 7
  daily
  compress
  missingok
}
EOF

## Copy pip to /usr/bin
ln -s /usr/local/bin/pip3 /usr/bin/pip3
python3 -m pip uninstall -y cryptography




