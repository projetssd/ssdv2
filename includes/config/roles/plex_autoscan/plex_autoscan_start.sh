#!/bin/bash
	
SAVEIFS=$IFS
IFS=$(echo -en "\n\b")
FILES=$(find /home/%SEEDUSER%/local \( -path /home/%SEEDUSER%/local/rutorrent -o -path /home/%SEEDUSER%/local/.unionfs-fuse \) -prune -o -name '*.*' -print)

for f in $FILES
do
echo "$f"
curl -d "eventType=Manual&filepath=$f" http://0.0.0.0:3468/%PASS%
done
					
# restore $IFS
IFS=$SAVEIFS
