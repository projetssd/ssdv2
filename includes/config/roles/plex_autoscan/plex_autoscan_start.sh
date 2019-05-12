#!/bin/bash
	
var=$(ls -a /home/%SEEDUSER%/local/%FILMS% | sed -e "/\.$/d" | wc -l)
var1=$(ls -a /home/%SEEDUSER%/local/%SERIES% | sed -e "/\.$/d" | wc -l)
var2=$(ls -a /home/%SEEDUSER%/local/%ANIMES% | sed -e "/\.$/d" | wc -l)
var3=$(ls -a /home/%SEEDUSER%/local/%MUSIC% | sed -e "/\.$/d" | wc -l)

## On vérifie si les dossiers sont vides, dans le cas contraire plex_autoscan se lance
if [ $var -ge 1 -o $var1 -ge 1 -o $var2 -ge 1 -o $var3 -ge 1 ]; then
SAVEIFS=$IFS
IFS=$(echo -en "\n\b")
FILES=/home/%SEEDUSER%/local/*/*/*
for f in $FILES
do
echo "$f"
curl -d "eventType=Manual&filepath=$f" http://0.0.0.0:3468/%PASS%
done
					
# restore $IFS
IFS=$SAVEIFS
else 
exit 0
fi