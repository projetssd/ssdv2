---
layout: default
title: ssdv2
---
# La mise en forme du fichier rclone.conf

> Ce fichier est placé dans le dossier suivant `/home/${USER}/.config/rclone/`

## Afin qu'il soit correctement analysé par l'outil automatique il faut qu'il respecte un standard de mise en forme

````
[teamdrive]
type = drive
client_id = AA.apps.googleusercontent.com
client_secret = AAAAAAAAAAAAAAAAA
scope = drive
token = {"access_token":"}
team_drive = EEEEEEEEEEEEEEE
root_folder_id =

[teamdrive_crypt]
type = crypt
remote = teamdrive:Medias
filename_encryption = standard
password = BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
password2 = CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
`````

