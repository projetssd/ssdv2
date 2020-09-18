#!/bin/bash	

#source includes/functions.sh
#source includes/variables.sh

## supression des variables dans account.yml, ainsi que des remotes ds rclone.conf
sed -i '/#Debut remote crypt/,/#Fin remote crypt/d' /root/.config/rclone/rclone.conf > /dev/null 2>&1
sed -i '/#Debut remote plexdrive/,/#Fin remote plexdrive/d' /root/.config/rclone/rclone.conf > /dev/null 2>&1
sed -i '/crypt/d' /opt/seedbox/variables/account.yml > /dev/null 2>&1
sed -i '/remote/d' /opt/seedbox/variables/account.yml > /dev/null 2>&1

## si rclone n'existe pas dans /usr/bin install rclone
rclone="/usr/bin/rclone"
if [ ! -f "$rclone" ]; then
 curl https://rclone.org/install.sh | bash
 rclone config
fi

## si rclone.conf contient des remotes crypt exit
grep "crypt" /root/.config/rclone/rclone.conf > /dev/null 2>&1
if [ $? -eq 0 ]; then
exit
fi

## sinon creation des remotes crypt
grep -E "type = drive" /root/.config/rclone/rclone.conf | uniq > /tmp/remote.txt
grep -E "type = drive" /root/.config/rclone/rclone.conf > /dev/null 2>&1

if [ $? -eq 0 ]; then
  while read line; do

    crypt="_crypt"
    plexdrive="_plexdrive"
    remote=$(grep -iC 1 "$line" /root/.config/rclone/rclone.conf | head -n 1 | sed "s/\[//g" | sed "s/\]//g")
    grep "password" /root/.config/rclone/rclone.conf

    if [ $? -eq 1 ]; then
    echo -e "#Debut remote crypt\n[$remote$crypt] \ntype = crypt\nremote = $remote:Medias\nfilename_encryption = standard" >> /root/.config/rclone/rclone.conf
    
    rclone config password $remote$crypt password yohann > /dev/null 2>&1
    rclone config password $remote$crypt password2 yohann > /dev/null 2>&1
    password=$(grep "password" /root/.config/rclone/rclone.conf)
    password2=$(grep "password2" /root/.config/rclone/rclone.conf | head -1)
    sed -i "/password2/a #Fin remote crypt" /root/.config/rclone/rclone.conf

   else
     echo -e "#Debut remote crypt\n[$remote$crypt] \ntype = crypt\nremote = $remote:Medias\nfilename_encryption = standard" >> /root/.config/rclone/rclone.conf
     password=$(grep "password" /root/.config/rclone/rclone.conf | sort -u -r)
     echo -e "$password\n#Fin remote crypt\n" >> /root/.config/rclone/rclone.conf
   fi

  done < /tmp/remote.txt

## creation du remote plexdrive
echo -e "#Debut remote plexdrive\n[plexdrive] \ntype = crypt\nremote = /mnt/plexdrive/Medias\nfilename_encryption = standard" >> /root/.config/rclone/rclone.conf
password=$(grep "password" /root/.config/rclone/rclone.conf | sort -u -r)
echo -e "$password\n#Fin remote plexdrive\n" >> /root/.config/rclone/rclone.conf

## insertion des variables dans account.yml
sed -i "/rclone/a \ \ \ remote: $remote$crypt" /opt/seedbox/variables/account.yml
sed -i "/remote/a \ \ \ crypt: plexdrive" /opt/seedbox/variables/account.yml

fi
