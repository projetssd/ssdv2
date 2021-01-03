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
  python3 -m pip install --user --disable-pip-version-check --upgrade --force-reinstall \
  setuptools
  python3 -m pip install --user --disable-pip-version-check --upgrade --force-reinstall \
  pyOpenSSL \
  requests \
  netaddr \
  jmespath \
  ansible==${1-$ANSIBLE} \
  docker
  
  
  # Install ansible niveau système
  python3 -m pip install --disable-pip-version-check --upgrade --force-reinstall \
  ansible==${1-$ANSIBLE}


/usr/local/bin/ansible-playbook includes/config/playbooks/sudoers.yml
/usr/local/bin/ansible-playbook includes/config/roles/users/tasks/main.yml
echo "Opération terminée, vous pouvez continuer en tapant ./seedbox.sh"