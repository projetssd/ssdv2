---
layout: default
title: ssdv2
---
# Tuto migration Google vers Dropbox

***

> Attention cela concerne ma propre migration, il peut y avoir des divergences pour vous. N'hésitez pas à demander de l'aide sur le discord

***


## Mise à jour de Rclone, il faut au minimum la version 1.58

- `rclone version` pour connaitre votre version actuelle
- `rclone selfupdate` pour mettre à jour vers la dernière version dispo

> à partir de 1.62.2, il faut installer fuse3 `sudo apt install fuse3` et par conséquent être en Ubuntu 20.04

## Dropbox :

Vous devez ajouter un dossier nommé “Medias” à la racine de Dropbox

### Création du remote Dropbox :

- création de dropbox non crypté : ne pas rentrer d'id ni de password pour générer le token
- création de dropbox crypté : penser à voir dans les options pour 3 (Encode using base32768) voir l’exemple plus bas

### Ajout du remote dropbox dans le rclone.config du serveur : (ça doit ressembler à ce qui est ci-dessous)

```jsx
[dropbox]
type = dropbox
token = {"access_token":"sl.BgNdT0uK1-fq","token_type":"bearer","refresh_token":"sN4vbcqQXsclGm6","expiry":"2023-06-1302:00"}

[dropbox_crypt]
type = crypt
filename_encoding = base32768
suffix = none
remote = dropbox:Medias
password = ******************
password2 = ******************

[teamdrive]
type = drive
client_id = ******************-8h5ontent.com
client_secret = ******************
scope = drive
token = {"access_token":"ya29.a0AW0169","token_type":"Bearer","refresh_token":"1//03ECegslU4M","expiry":"202302:00"}
team_drive = ******************
root_folder_id = 

[teamdrive_crypt]
type = crypt
remote = teamdrive:Medias
filename_encryption = standard
password = ******************
password2 = ******************
```

### Ajout du service rclone-dropbox et ajout du point de montage dans Mergerfs :

- Création du point de montage pour dropbox :
```zsh
mkdir /mnt/dropbox
```
- Création du service : `rclone-dropbox.service`
```zsh
nano /etc/systemd/system/rclone-dropbox.service
```

> **Warning**
> Remplacer `$USER`, `$GROUP`, `$UID` et `$GID` par vos paramètres.

```jsx
[Unit]
Description=Dropbox Rclone VFS Mount
AssertPathIsDirectory=/mnt/rclone
After=network-online.target

[Service]
User=$USER
Group=$GROUP
Type=notify
ExecStart=/usr/bin/rclone mount \
  --config=/home/$USER/.config/rclone/rclone.conf \
  --uid=$uid --gid=$gid \
  --umask=002 \
  --allow-other -v \
  --async-read=true \
  --allow-non-empty \
  --buffer-size=256M \
  --size-only \
  --dir-cache-time=5000h \
  --log-systemd \
  --user-agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.131 Safari/537.36' \
  --cache-dir=/home/$USER/.config/rclone/cache \
  --use-mmap \
  --vfs-read-ahead=128M \
  --vfs-read-chunk-size=256M \
  --vfs-read-chunk-size-limit=2G \
  --vfs-fast-fingerprint \
  --vfs-cache-max-age=504h \
  --vfs-cache-mode=full \
  --vfs-cache-poll-interval=30s \
  --vfs-cache-max-size=250G \
  dropbox_crypt: /mnt/rclone/
ExecStop=/bin/fusermount -uz /mnt/rclone
Restart=on-abort
RestartSec=5

[Install]
WantedBy=default.target
```

- enregistrer le fichier. `ctrl+X`

## On modifie maintenant mergerfs

```jsx
systemctl --system stop mergerfs.service
```
- On édite `mergerfs.service`
```jsx
nano /etc/systemd/system/mergerfs.service
```

> **Warning**
> Remplacer $USER par le votre

```jsx
[Unit]
Description=gmedia mergerfs mount
Requires=rclone.service rclone-dropbox.service
After=rclone.service rclone-dropbox.service

[Service]
Type=forking
ExecStart=/usr/bin/mergerfs /home/$USER/local=RW:/mnt/rclone/$USER=NC:/mnt/dropbox=NC /home/$USER/Medias -o rw,use_ino,allow_other,func.getattr=newest,category.action=all,category.create=ff,cache.files=auto-full
ExecStop=/bin/fusermount -u /home/$USER/Medias
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
```
- Rechargement des service : 
```jsx
sudo systemctl daemon-reload
```
- Démarage du montage dropbox :
```jsx
service rclone-dropbox start
```

- A ce stade on vérifie que le service et fonctionel :
```zsh
ls -lsha /mnt/dropbox
```

> **Note**
> Vérifiez que tout vos fichiers de dropbox sont bien visible

> **Warning**
> 
> Si ce n'est pas le cas, on s'arette la et on debug : 
>
> - On regarde déja se qu'il se passe dans le log systemd :
> 
> Sa peut étre une simple faute de frappe ou de cc : 
> `sudo systemctl --system status rclone-dropbox.service` 
> 
> - Si il n'y a pas assez de détail vous pouvez nous demander de l'aide sur le discord:
> 
> `journalctl -u rclone-dropbox.service`
>
> - Fournir le log complet

- Activation du service au boot
```zsh
sudo systemctl --system enable rclone-dropbox.service
```
- Démarage de mergerfs
```jsx
service mergerfs start
```

> **Note**
remplacer start par status pour confirmer que tout fonctionne correctement, vous pouvez également vérifier dans le /mnt/rclone et /mnt/dropbox que vous avez vos fichiers

### il faut ensuite relancer certain container

```jsx
docker restart sonarr radarr plex ""et tout ceux qui utilises les données Medias""
```

### Commande de migration des données (à faire depuis un VPS):

attention à vérifier si à la racine de google vous avez oui ou non un dossier correspondant à votre pseudo — `rclone lsd teamdrive_crypt:`

je vous conseil de faire dossier par dossier 

```jsx
rclone move -Pv teamdrive_crypt:kesurof/Films4K dropbox_crypt:Films4K --fast-list --max-backlog=2000000 --dropbox-batch-size 70 --dropbox-batch-mode async --dropbox-batch-timeout 20s --tpslimit-burst=1 --tpslimit=10 --transfers=8 --use-mmap --no-update-modtime --dropbox-chunk-size=64M --progress -v --max-transfer 9T --cutoff-mode=soft --drive-stop-on-download-limit
```

### Il faut également modifier cloudplow ou crop pour indiquer le nom du remote correspondant à Dropbox ainsi que le script de backup

- `/usr/local/bin/backup` il faut remplacer teamdrive_crypt par dropbox_crypt
- `/usr/local/bin/restore` il faut remplacer teamdrive_crypt par dropbox_crypt