---
layout: default
title: ssdv2
---
# Partager un compte google


Définition : il y a un "propriétaire" et un "locataire"
Le propriétaire doit déjà avoir un rclone configuré

Le propriétaire n'aura pas accès aux fichiers du locataire et vice-versa.

Le propriétaire peut supprimer les fichiers du locataire ou fermer son compte


## Prérequis

Même si ce n'est pas obligatoire, il est FORTEMENT CONSEILLE d'utiliser les SA (service accounts) et cloudplow. En effet, propriétaire et locataire vont uploader des fichiers depuis le même compte, et on peut vite arriver à la limite des 750Go/jour

Le propriétaire doit configurer les SA via l'application ssd, et transmettre la totalité de son répertoire /opt/sa au locataire. Celui ci doit l'intégrer à son serveur, dans le chemin de son choix (/opt/sa s'il n'utilise pas déjà les sa, ou /opt/sa_proprio pour garde ses sa existants temporairement)


# Méthode

Le propriétaire et le locataire doivent se synchroniser !

Le propriétaire doit envoyer une partie de son rclone.conf au locataire. Cette partie correspond à son drive non chiffré.

Par exemple
```
[seedbox_proprio]
client_id = xxxxxxxxxxxx-xxxxxxxxxxxx.apps.googleusercontent.com
client_secret = xxxxxxxxxxxxxxx
type = drive
scope = drive
token = {"access_token":"xxxx.xxxxxxxxxxxxxxxx","token_type":"Bearer","refresh_token":"1//0en0jLSWNB-xxxxxxxxxxxxxxxxxxxx","expiry":"2022-01-03T12:46:49.895145905+01:00"}
team_drive = xxxxxxxxx_AyyU0RUk9PVA
```

Le locataire rentre cette partie dans son propre rclone.conf, puis teste les accès, en faisant

```
rclone lsd seedbox_proprio
```

Normalement, l'accès doit être refusé.
Il faut lancer la commande

```
rclone config reconnect seedbox_proprio:
```
Et se laisser guider. Au moment de la question "use autoconfig", répondre "N". Le locataire doit alors donner l'url au propriétaire, qui doit accepter l'autorisation. Le propriétaire doit alors donner le code retour au locataire, qui va le rentrer dans la console.

Une fois fait, la commande 
```
rclone lsd seedbox_proprio
```
doit marcher.

## Création d'un répertoire

Le propriétaire doit créer un répertoire dans son google drive, via l'interface graphique. Supposons que ce répertoire soit appelé "locataire"

## Création d'un remote pour le locataire

Le locataire doit créer un nouveau remonte sur son rclone, de type "crypt", et donc la source sera "seedbox_proprio:/locataire" (penser à adapter le nom !)
Le locataire choisit ses clés de chiffrement et ne les communique pas au propriétaire !

Dans notre exemple, le remote s'appelera seedbox_locataire_crypt

## Prise en compte dans ssd

Sourcer l'environnement 
```
cd /opt/seedbox-compose 
source profile.sh
```
lancer la commande
```
manage_account_yml rclone.remote seedbox_crypt
```

# Migration des données

Si le locataire a des données dans son drive actuel, il doit les uploader dans son drive loué. Il faut pour cela utiliser cloudplow

Pour cela, il faut créer un nouveau remote dans le config.json de cloudplow : `
```
       "seedbox_locataire_crypt": {
            "hidden_remote": "",
            "rclone_excludes": [],
            "rclone_extras": {},
            "rclone_sleeps": {},
            "remove_empty_dir_depth": 2,
            "sync_remote": "seedbox_locataire_crypt:",
            "upload_folder": "",
            "upload_remote": ""
        }
```
Puis une section syncer
```
"syncer": {
        "actuel2locataire": {
            "rclone_extras": {
                "--bwlimit": "70M",
                "--checkers": 16,
                "--drive-chunk-size": "64M",
                "--stats": "60s",
                "--transfers": 8,
                "--verbose": 1
            },
            "service": "local",
            "sync_from": "nom_du_remote_actuel",
            "sync_interval": 26,
            "sync_to": "seedbox_locataire_crypt",
            "tool_path": "/usr/bin/rclone",
            "use_copy": true,
            "instance_destroy": false
          }
```

ATTENTION ! Cette opération ne prend pas à ce jour les SA, donc il y a risque de saturation des 750Go/jour, et il faudra compter plusieurs jours d'upload si il y a des grandes quantités à transférer.

Voir la doc : Cloudplow

# Migration des réglages

## rclone 

Une fois les données transférées, il "suffit" de modifier le fichier /etc/systemd/system/rclone.conf pour mettre le bon nom du remote
Une fois que c'est fait
```
systemctl daemon-reload
systemctl restart rclone
```
puis
```
ls /mnt/rclone
```
pour vérifier que tout est ok.

Une fois que c'est fait : 
```
sudo systemctl restart mergerfs
sudo docker restart plex radarr sonarr autoscan
```

## cloudplow

Supprimer si nécessaire la partie syncer, et le remote qu'on a ajouté pour la partie transfert des données. Dans le remote "de base", changer le nom du remote rclone

```
sudo systemctl restart cloudplow
```
