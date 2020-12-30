#!/bin/bash

ansible-playbook /opt/seedbox-compose/includes/dockerapps/templates/ansible/ansible.yml
USER=$(cat /tmp/name)
fusermount -uz /mnt/rclone > /dev/null 2>&1
fusermount -uz /mnt/plexdrive > /dev/null 2>&1
fusermount -uz /home/$USER/Medias > /dev/null 2>&1
fusermount -uz /home/$USER/PlexdriveSeed > /dev/null 2>&1
fusermount -uz /mnt/PlexdriveSeed > /dev/null 2>&1
rm -rf /mnt/plexdrive
rm -rf /mnt/PlexdriveSeed > /dev/null 2>&1
rm -rf /home/$USER/PlexdriveSeed > /dev/null 2>&1
