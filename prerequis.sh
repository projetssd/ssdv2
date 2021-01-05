#!/bin/bash
###############################################################
if [ "$USER" != "root" ]; then
 echo "Ce script doit être lancé en sudo ou par root !"
  exit 1
fi

# Absolute path to this script.
CURRENT_SCRIPT=$(readlink -f "$0")
# Absolute path this script is in.
export SCRIPTPATH=$(dirname "$CURRENT_SCRIPT")
cd ${SCRIPTPATH}

readonly PIP="9.0.3"
readonly ANSIBLE="2.9"
${SCRIPTPATH}/includes/config/scripts/prerequis_root.sh ${SCRIPTPATH}

## Install pip3 Dependencies
python3 -m pip install --user --disable-pip-version-check --upgrade --force-reinstall \
pip==${PIP}
python3 -m pip install --user --disable-pip-version-check --upgrade --force-reinstall \
setuptools
python3 -m pip install --user --disable-pip-version-check --upgrade  --force-reinstall \
pyOpenSSL \
requests \
netaddr \
jmespath \
ansible==${1-$ANSIBLE} \
docker


  
## Copy pip to /usr/bin
rm -f /usr/bin/pip3
ln -s ${HOME}/.local/bin/pip3 /usr/bin/pip3
ln -s ${HOME}/.local/bin/pip3 /usr/bin/pip

${HOME}/.local/bin/ansible-playbook includes/config/playbooks/sudoers.yml
${HOME}/.local/bin/ansible-playbook includes/config/roles/users/tasks/main.yml
echo "---------------------------------------"
echo "Si c'est la première fois que vous lancez ce script, il est TRES FORTEMENT conseillé de redémmarer le serveur avant de continuer"
echo "Vous pourrez ensuite lancer "
echo "cd /opt/seedbox-compose"
echo "./seedbox.sh "
echo "pour installer la seedbox"
touch ${SCRIPTPATH}/.prerequis.lock