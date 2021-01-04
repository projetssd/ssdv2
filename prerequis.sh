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

  readonly PIP="9.0.3"
  readonly ANSIBLE="2.9"
  ${SCRIPTPATH}/includes/config/scripts/prerequis_root.sh ${SCRIPTPATH}
  
  ## Install pip3 Dependencies
  python3 -m pip install --user --disable-pip-version-check --upgrade --force-reinstall \
  pip==${PIP}
  python3 -m pip install --user --disable-pip-version-check --upgrade  \
  setuptools
  python3 -m pip install --user --disable-pip-version-check --upgrade  \
  pyOpenSSL \
  requests \
  netaddr \
  jmespath \
  ansible==${1-$ANSIBLE} \
  docker
  
  
  # Install ansible niveau système
  python3 -m pip install --disable-pip-version-check --upgrade \
  ansible==${1-$ANSIBLE} \
  pip==${PIP}
  
## Copy pip to /usr/bin
ln -s $(which pip3) /usr/bin/pip3
ln -s $(which pip3) /usr/bin/pip

$(which ansible-playbook) includes/config/playbooks/sudoers.yml
$(which ansible-playbook) includes/config/roles/users/tasks/main.yml
echo -e "${RED}-----------------------${CEND}"
echo "Si c'est la première fois que vous lancez ce script, vous devez vous déconnecter/reconnecter pour continuer"
echo "Vous pourrez ensuite lancer ./seedbox.sh pour isntaller la seedbox"