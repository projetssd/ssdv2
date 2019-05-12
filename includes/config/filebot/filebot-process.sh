#!/bin/bash

# EXIT IF SCRIPT IF ALREADY RUNNING
if pidof -o %PPID -x "$0"; then
   echo "$(date "+%d.%m.%Y %T") Already running, exiting."
   exit 1
fi

sh /opt/seedbox/docker/%SEEDUSER%/.filebot/filebot.sh -script fn:amc --output "/home/%SEEDUSER%/local" --action hardlink --conflict skip -non-strict --lang fr --log-file amc.log --def unsorted=y music=y --def excludeList=/home/%SEEDUSER%/exclude.txt "exec=/home/%SEEDUSER%/scripts/plex_autoscan/plex_autoscan_rutorrent.sh" "ut_dir=/home/%SEEDUSER%/filebot" --def movieFormat="/home/%SEEDUSER%/local/Films/{n} ({y})/{n} ({y})" seriesFormat="/home/%SEEDUSER%/local/Series/{n}/Saison {s.pad(2)}/{n} - {s00e00} - {t}" musicFormat="/home/%SEEDUSER%/local/Musique/{n}/{album+'/'}{pi.pad(2)+'. '}{artist} - {t}"

## rajouter les chemins de dossiers a traiter ici