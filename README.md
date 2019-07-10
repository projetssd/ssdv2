
[![](https://img.shields.io/github/repo-size/laster13/patxav.svg?style=flat)](https://github.com/laster13/patxav)

--- 
# Introduction

Mise à jour avec Ansible le 10/07/2019

Ce script est basé sur CloudBox [(Lien du GitHub)](https://github.com/Cloudbox/Cloudbox) , il a été modifier par laster13 permettant d'avoir une installation beaucoup plus libre de ce que propose Cloudbox.

Les images utilisées pour ce projet sont:
* [Traefik](https://traefik.io/) pour gérer les I/O web
* [xataz/rtorrent-rutorrent](https://hub.docker.com/r/xataz/rtorrent-rutorrent/)  
* [Emby](https://hub.docker.com/r/emby/embyserver/)  
* ...

# Pré-requis

1. Un serveur Ubuntu
2. Un nom de domaine
3. Connaissances en Linux
4. Connaissances en Docker
5. Un compte Google Drive si la seedbox est orienté PlexDrive

# Installation (en root)

1. Mise à jour des paquets :
```
apt update && apt upgrade -y
```

2. Installation de Git :
```
apt install git
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
