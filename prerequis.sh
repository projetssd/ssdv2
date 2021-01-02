#!/bin/bash
###############################################################
if [ "$USER" != "root" ]; then
 echo "Ce script doit être lancé en sudo ou par root !"
  exit 1
fi
ansible-playbook includes/config/playbooks/sudoers.yml
echo "Opération terminée, vous pouvez continuer en tapant ./seedbox.sh"