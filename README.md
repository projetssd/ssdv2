
# Introduction

Ce script est basé sur CloudBox [(Lien du GitHub)](https://github.com/Cloudbox/Cloudbox) , il est a été modifier par laster13 permettant d'avoir une installation beaucoup plus libre de ce que propose Cloudbox.

Les images utilisées pour ce projet sont:
* [Traefik](https://traefik.io/) pour gérer les I/O web
* Flood par Kuni
* [xataz/rtorrent-rutorrent](https://hub.docker.com/r/xataz/rtorrent-rutorrent/)  
* [xataz/medusa](https://hub.docker.com/r/xataz/medusa/)  
* [Emby](https://hub.docker.com/r/emby/embyserver/)  

# Installation (en root)

Mise à jour des paquets :
```
apt update && apt upgrade -y
```

Installation de Git :
```
apt install git
```

Clonage du script : 

```
git clone https://github.com/laster13/patxav.git /opt/seedbox-compose
```

Pour rentrer là ou le script est installé :

```
cd /opt/seedbox-compose 
```

Lancer le script : 

```
./seedbox.sh
```
