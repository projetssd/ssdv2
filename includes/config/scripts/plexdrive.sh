#!/bin/bash	

source /opt/seedbox-compose/includes/functions.sh
source /opt/seedbox-compose/includes/variables.sh

RCLONE_CONFIG_FILE=${HOME}/.config/rclone/rclone.conf

#ansible-playbook /opt/seedbox-compose/includes/dockerapps/templates/ansible/ansible.yml
#USER=$(cat ${TMPNAME})



sudo mkdir /mnt/rclone > /dev/null 2>&1
sudo chown ${USER}: /mnt/plexdrive
## detection remote plexdrive ##
grep "plexdrive" ${RCLONE_CONFIG_FILE} > /dev/null 2>&1
if [ $? -eq 0 ]; then
  REMOTE_PLEXDRIVE=$(grep -iC 2 "/mnt/plexdrive/Medias" ${RCLONE_CONFIG_FILE} | head -n 1 | sed "s/\[//g" | sed "s/\]//g")
  manage_account_yml remote.plexdrive $REMOTE_PLEXDRIVE
else
  PASSWORD=$(grep password ${RCLONE_CONFIG_FILE} | head -1)
  PASSWORD2=$(grep password ${RCLONE_CONFIG_FILE} | head -2 | tail -1)
  echo "" >> ${RCLONE_CONFIG_FILE}
  echo "[plexdrive]" >> ${RCLONE_CONFIG_FILE}
  echo "type = crypt" >> ${RCLONE_CONFIG_FILE}
  echo "remote = /mnt/plexdrive/Medias" >> ${RCLONE_CONFIG_FILE}
  echo "filename_encryption = standard" >> ${RCLONE_CONFIG_FILE}
  echo "$PASSWORD" >> ${RCLONE_CONFIG_FILE}
  echo "$PASSWORD2" >> ${RCLONE_CONFIG_FILE}
  echo ""
  manage_account_yml remote.plexdrive plexdrive
fi

