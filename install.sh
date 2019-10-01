#!/bin/sh

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
    apt-transport-https
apt-get update

## Add apt repos
fullrel=$(lsb_release -sd)
osname=$(lsb_release -si)
relno=$(lsb_release -sr)
relno=$(printf "%.0f\n" "$relno")
hostname=$(hostname -I | awk '{print $1}')

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
    lsb-release \
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
