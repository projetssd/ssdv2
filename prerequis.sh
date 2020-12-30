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

# Absolute path to this script.
CURRENT_SCRIPT=$(readlink -f "$0")
# Absolute path this script is in.
SCRIPTPATH=$(dirname "$CURRENT_SCRIPT")

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

## Install pip3 Dependencies
python3 -m pip install --disable-pip-version-check --upgrade --force-reinstall \
pip==${PIP}
python3 -m pip install --disable-pip-version-check --upgrade --force-reinstall \
setuptools
python3 -m pip install --disable-pip-version-check --upgrade --force-reinstall \
pyOpenSSL \
requests \
netaddr \
jmespath \
ansible==${1-$ANSIBLE} \
docker

# Configuration ansible
mkdir -p /etc/ansible/inventories/ 1>/dev/null 2>&1
cat <<EOF >/etc/ansible/inventories/local
[local]
127.0.0.1 ansible_connection=local
EOF

chmod 777 ${SCRIPTPATH}/logs

cat <<EOF >/etc/ansible/ansible.cfg
[defaults]
command_warnings = False
callback_whitelist = profile_tasks
deprecation_warnings=False
inventory = /etc/ansible/inventories/local
interpreter_python=/usr/bin/python3
vault_password_file = ~/.vault_pass
log_path=${SCRIPTPATH}/logs/ansible.log
EOF

cat << EOF > /etc/logrotate.d/ansible
${SCRIPTPATH}/logs/ansible.log {
  rotate 7
  daily
  compress
  missingok
}
EOF

## Copy pip to /usr/bin
cp /usr/local/bin/pip /usr/bin/pip
cp /usr/local/bin/pip3 /usr/bin/pip3
pip uninstall -y cryptography

if test -f "${SCRIPTPATH}/ssddb"; then
  echo "Une configuration de seedbox existe déjà, elle ne sera pas écrasée"
else
  echo "Création de la configuration en cours"
  # On créé la database
  sqlite3 ${SCRIPTPATH}/ssddb <<EOF
    create table seedbox_params(param varchar(50) PRIMARY KEY, value varchar(50));
    replace into seedbox_params (param,value) values ('installed',0);
    replace into seedbox_params (param,value) values ('seedbox_path','/opt/seedbox');
    
EOF
fi
