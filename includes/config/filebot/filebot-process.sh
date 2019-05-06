#!/bin/bash

# EXIT IF SCRIPT IF ALREADY RUNNING
if pidof -o %PPID -x "$0"; then
   echo "$(date "+%d.%m.%Y %T") Already running, exiting."
   exit 1
fi

PLEXDRIVE="/usr/bin/plexdrive"
if [[ -e "$PLEXDRIVE" ]]; then

films=$(ls -a /home/%SEEDUSER%/local/rutorrent/Films | sed -e "/\.$/d" | wc -l)
series=$(ls -a /home/%SEEDUSER%/local/rutorrent/Series | sed -e "/\.$/d" | wc -l)
musiques=$(ls -a /home/%SEEDUSER%/local/rutorrent/Musiques | sed -e "/\.$/d" | wc -l)
animes=$(ls -a /home/%SEEDUSER%/local/rutorrent/Animes | sed -e "/\.$/d" | wc -l)

	## On vérifie si les dossiers sont vides, dans le cas contraire filebot se lance
	if [ $films -ge 1 -o $series -ge 1 -o $musiques -ge 1 -o $animes -ge 1 ]; then
		SAVEIFS=$IFS
		IFS=$(echo -en "\n\b")
		FILES=/home/corinne/Pre/*/*/*
			for f in $FILES
			do
			echo "$f"
			sh /opt/seedbox/docker/%SEEDUSER%/.filebot/filebot.sh -script fn:amc --output "/home/%SEEDUSER%/local" --action hardlink --conflict skip -non-strict --lang fr --log-file amc.log --def unsorted=y music=y --def excludeList=/home/%SEEDUSER%/exclude.txt "ut_dir=/home/%SEEDUSER%/local/rutorrent" --def movieFormat="/home/%SEEDUSER%/local/Films/{n} ({y})/{n} ({y})" seriesFormat="/home/%SEEDUSER%/local/Series/{n}/Saison {s.pad(2)}/{n} - {s00e00} - {t}" musicFormat="/home/%SEEDUSER%/local/Musique/{n}/{album+'/'}{pi.pad(2)+'. '}{artist} - {t}"
			done
					
		# restore $IFS
		IFS=$SAVEIFS
	else 
	exit 0
	fi
else

films=$(ls -a /home/%SEEDUSER%/Medias/rutorrent/Films | sed -e "/\.$/d" | wc -l)
series=$(ls -a /home/%SEEDUSER%/Medias/rutorrent/Series | sed -e "/\.$/d" | wc -l)
musiques=$(ls -a /home/%SEEDUSER%/Medias/rutorrent/Musiques | sed -e "/\.$/d" | wc -l)
animes=$(ls -a /home/%SEEDUSER%/Medias/rutorrent/Animes | sed -e "/\.$/d" | wc -l)

	## On vérifie si les dossiers sont vides, dans le cas contraire filebot se lance
	if [ $films -ge 1 -o $series -ge 1 -o $musiques -ge 1 -o $animes -ge 1 ]; then
		SAVEIFS=$IFS
		IFS=$(echo -en "\n\b")
		FILES=/home/corinne/Pre/*/*/*
			for f in $FILES
			do
			echo "$f"
			sh /opt/seedbox/docker/%SEEDUSER%/.filebot/filebot.sh -script fn:amc --output "/home/%SEEDUSER%/Medias" --action hardlink --conflict skip -non-strict --lang fr --log-file amc.log --def unsorted=y music=y --def excludeList=/home/%SEEDUSER%/exclude.txt "ut_dir=/home/%SEEDUSER%/Medias/rutorrent" --def movieFormat="/home/%SEEDUSER%/Medias/Films/{n} ({y})/{n} ({y})" seriesFormat="/home/%SEEDUSER%/Medias/Series/{n}/Saison {s.pad(2)}/{n} - {s00e00} - {t}" musicFormat="/home/%SEEDUSER%/Medias/Musique/{n}/{album+'/'}{pi.pad(2)+'. '}{artist} - {t}"
			done
					
		# restore $IFS
		IFS=$SAVEIFS
	else 
	exit 0
	fi

fi
