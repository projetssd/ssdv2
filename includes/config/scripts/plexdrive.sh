#!/bin/bash	

source /opt/seedbox-compose/includes/functions.sh
source /opt/seedbox-compose/includes/variables.sh

ansible-playbook /opt/seedbox-compose/includes/dockerapps/templates/ansible/ansible.yml
USER=$(cat /tmp/name)

ansible-vault decrypt /opt/seedbox/variables/account.yml > /dev/null 2>&1
sed -i '/plexdrive*/d' /opt/seedbox/variables/account.yml > /dev/null 2>&1
mkdir /mnt/rclone > /dev/null 2>&1
fusermount -uz /mnt/rclone > /dev/null 2>&1
fusermount -uz /mnt/rcloneSeed > /dev/null 2>&1
fusermount -uz /mnt/plexdrive > /dev/null 2>&1
fusermount -uz /home/$USER/Medias > /dev/null 2>&1
fusermount -uz /home/$USER/SeedCloud > /dev/null 2>&1


## detection remote plexdrive ##
grep "plexdrive" /root/.config/rclone/rclone.conf > /dev/null 2>&1
if [ $? -eq 0 ]; then
  REMOTE_PLEXDRIVE=$(grep -iC 2 "/mnt/plexdrive/Medias" /root/.config/rclone/rclone.conf | head -n 1 | sed "s/\[//g" | sed "s/\]//g")
  sed -i "/remote/a \ \ \ plexdrive: $REMOTE_PLEXDRIVE" /opt/seedbox/variables/account.yml
else
  PASSWORD=$(grep password /root/.config/rclone/rclone.conf | head -1)
  PASSWORD2=$(grep password /root/.config/rclone/rclone.conf | head -2 | tail -1)
  echo "" >> /root/.config/rclone/rclone.conf
  echo "[plexdrive]" >> /root/.config/rclone/rclone.conf
  echo "type = crypt" >> /root/.config/rclone/rclone.conf
  echo "remote = /mnt/plexdrive/Medias" >> /root/.config/rclone/rclone.conf
  echo "filename_encryption = standard" >> /root/.config/rclone/rclone.conf
  echo "$PASSWORD" >> /root/.config/rclone/rclone.conf
  echo "$PASSWORD2" >> /root/.config/rclone/rclone.conf
  echo ""
  sed -i "/remote/a \ \ \ plexdrive: plexdrive" /opt/seedbox/variables/account.yml
fi
ansible-vault encrypt /opt/seedbox/variables/account.yml > /dev/null 2>&1

