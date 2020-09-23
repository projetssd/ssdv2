#!/bin/bash

source includes/functions.sh
source includes/variables.sh

i=1
grep "team_drive" /root/.config/rclone/rclone.conf | uniq > /tmp/crop.txt
grep "team_drive" /root/.config/rclone/rclone.conf > /dev/null 2>&1

if [ $? -eq 0 ]; then
  echo -e " ${BWHITE}* Teamdrives disponibles${NC}"
  echo ""
    while read line; do
      team=$(grep -iC 6 "$line" /root/.config/rclone/rclone.conf | head -n 1 | sed "s/\[//g" | sed "s/\]//g")
      echo "$team" >> /tmp/team.txt
      echo -e "${CGREEN}   $i. $team${CEND}"
      let "i+=1"
      done < /tmp/crop.txt
    echo ""
else
echo -e " ${BWHITE}* Aucun teamdrive/share drive détecté${NC}"
echo ""
exit
fi

  nombre=$(wc -l /tmp/team.txt | cut -d ' ' -f1)
  while :
  do
  read -rp $'\e[36m   Choisir le share drive associé à plexdrive: \e[0m' RTYPE
    if [ "$RTYPE" -le "$nombre" -a "$RTYPE" -ge "1"  ]; then
   break
  else
  echo -e " ${CRED}* /!\ erreur de saisie /!\{NC}"
  echo ""
  fi
  done

 i="$RTYPE"
 id=$(sed -n "$i"p /tmp/crop.txt | cut -d '=' -f2)
 echo "$id"

