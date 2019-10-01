#!/bin/sh
#################################################################################
# Title:         Cloudbox: Dependencies Installer                               #
# Author(s):     L3uddz, Desimaniac, EnorMOZ                                    #
# URL:           https://github.com/Cloudbox/Cloudbox                           #
# Description:   Installs dependencies needed for Cloudbox.                     #
# --                                                                            #
#             Part of the Cloudbox project: https://cloudbox.works              #
#################################################################################
#                     GNU General Public License v3.0                           #
#################################################################################
# Usage:                                                                        #
# ======                                                                        #
# curl -s https://cloudbox.works/scripts/dep.sh | sudo sh                       #
# wget -qO- https://cloudbox.works/scripts/dep.sh | sudo sh                     #
#                                                                               #
# Custom Ansible Version:                                                       #
# curl -s https://cloudbox.works/scripts/dep.sh | sudo sh -s <version>          #
# wget -qO- https://cloudbox.works/scripts/dep.sh | sudo sh -s <version>        #
#################################################################################

## Constants
readonly PIP="9.0.3"
readonly ANSIBLE="2.5.14"

## AppVeyor
if [ "$SUDO_USER" = "appveyor" ]; then
    rm /etc/apt/sources.list.d/*
    rm /etc/apt/sources.list
    curl https://cloudbox.works/scripts/apt-sources/xenial.txt | tee /etc/apt/sources.list
    apt-get update
fi

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
    apt-transport-https
apt-get update

## Add apt repos
add-apt-repository main
add-apt-repository universe
add-apt-repository restricted
add-apt-repository multiverse
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
    python-pip

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

## Copy pip to /usr/bin
cp /usr/local/bin/pip /usr/bin/pip
cp /usr/local/bin/pip3 /usr/bin/pip3
