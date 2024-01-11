---
layout: default
title: ssdv2
---
### Attendre la présence d'un membre du staff sur le discord !!!

==========================================================

ATTENTION POUR CEUX QUI SONT EN DEBIAN 10

Avant toute chose, passez root puis tapez "apt update" et acceptez les changements proposés.

Verifiez ensuite avec
```
apt-get update
apt-get upgrade
```
que les commandes passent sans erreur.

============================================================


Il faut un user qui porte le même nom que le user d'admin de la v1. Il faut que cette user soit dans le groupe sudo. 
En root :
```
usermod -aG sudo <user>
```

```
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!! TOUTES LES ACTIONS SUIVANTES SONT A FAIRE EN USER "NORMAL", pas en root           !!!
!!! Déconnectez vous de root, et reconnectez vous avec le bon user avant de continuer !!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
```

Il est fortement conseillé de faire un backup de la seedbox avant de commencer !
```
sudo backup
```

Renommer le répertoire existant
```
sudo mv /opt/seedbox-compose /opt/seedbox-compose.old
```
Cloner le nouveau répertoire
``` 
sudo git clone https://github.com/projetssd/ssdv2.git /opt/seedbox-compose
sudo chown -R ${USER}: /opt/seedbox-compose
```
Lancer la migration
``` 
cd /opt/seedbox-compose && bash -x ./seedbox.sh --migrate
```
Rebooter la machine une fois terminé !