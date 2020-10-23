Mise à jour du 23/10/2020
Parmis les nouveautés, crop, autoscan, un menu personnalisé pour les migrations Gdrive/Share Drive => Share Drive.
Création auto des services de comptes, possibilité de créer le rclone.conf dans le déroulé du script. Le script est clairement orienté vers le Share Drive en prévision des nouvelles dispositions de google.
Un menu spécifique est désormais dispo pour installer plex_autoscan, crop, cloudplow, autoscan avec possibilité de changer comme bon bon vous semble.
Par defaut, rclone vfs remplace plexdrive. Enfin quelques applis supplémentaires pour agrémenter le tout.

Pour vous accompagner dans la phase de migration -> https://wiki.kesurof.fr/shelves/4-migration-gdrive-vers-sharedrive

pour plus de détail avant et après installation --> direction le [wiki](https://github.com/laster13/patxav/wiki)

# Introduction

### Pour se lancer dans l’installation, il faut au préalable avoir suivi les étapes suivantes:

- Avoir une machine (serveur ou NAS) (5000 score passmark minimum)
- Obtenir un nom de domaine
- Utiliser un compte Gsuite illimité avec création de dossier partagés disponible 
- Connexion en root via ssh/ (pas user puis root) [Activer root tuto simple pour debian](https://cloriou.fr/2016/12/05/debian-autoriser-acces-root-via-ssh/)
- une fois toutes ces étapes validées vous pouvez suivre les Prérequis.

***

# Pré-requis

Je vous recommande de suivre les étapes dans l'ordre suivant :

- [Transfert de gestion DNS Cloudflare](https://github.com/laster13/patxav/wiki/Transfert-de-gestion-DNS-Cloudflare)
- [Création des projets Google](https://github.com/laster13/patxav/wiki/Création-des-projets-Google)

***

# Installation en root

1. Mise à jour des paquets :
```
apt update && apt upgrade -y
```

2. Installation de Git :
```
apt install git -y
```

3. Clonage du script : 

```
git clone https://github.com/laster13/patxav.git /opt/seedbox-compose
```

4. Pour rentrer là ou le script est installé :

```
cd /opt/seedbox-compose 
```

5. Lancer le script : 

```
./seedbox.sh
```

***
# Suite de l'installation [suite du tuto](https://github.com/laster13/patxav/wiki/Installation)

***

Ce script est proposé à des fins d'expérimentation uniquement, le téléchargement d’oeuvre copyrightées est illégal.
Merci de vous conformer à la législation en vigueur en fonction de vos pays respectifs en faisant vos tests sur des fichiers libres de droits
