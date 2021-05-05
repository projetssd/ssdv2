<br /><img src="https://user-images.githubusercontent.com/64525827/107496602-ceddbb80-6b91-11eb-9a05-ac311eedf150.png" width="450">
<br />
[![Discord: https://discordapp.com/invite/HZNMGjDRhp](https://img.shields.io/badge/Discord-gray.svg?style=for-the-badge)](https://discordapp.com/invite/HZNMGjDRhp)

## Comment migrer de la v1 vers la v2 ?

Il faut un user qui porte le même nom que le user d'admin de la v1. Il faut ce user soit dans le groupe sudo. 
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
cd /opt/seedbox-compose
./seedbox.sh --migrate
```
Rebooter la machine une fois terminé !

## Le script SSD permet l'installation d'une seedbox complète avec Docker

#### Pour se lancer dans l’installation, il faut au préalable suivre les étapes suivantes:
* [Un serveur distant](https://github.com/laster13/patxav/wiki/Serveur)
* [Un nom de domaine](https://github.com/laster13/patxav/wiki/Nom-de-domaine)
* [Un abonnement à cloud workspace](https://github.com/laster13/patxav/wiki/Les-offres-Cloud-Google)
* [DNS Cloudflare](https://github.com/laster13/patxav/wiki/Cloudflare)
* [Création API Google Drive](https://github.com/laster13/patxav/wiki/Cr%C3%A9ation-API-Google)

###


Une fois les pré requis validé pous pouvez suivre le guide :  
* [Pas à pas d'installation](https://github.com/laster13/patxav/wiki/pas-%C3%A0-pas)

<br/><br/>

***

# Demande d'ajout de fonctionnalité 
https://feathub.com/projetssd/ssdv2

### Demande en cours de vote
[![Feature Requests](https://feathub.com/projetssd/ssdv2?format=svg)](https://feathub.com/projetssd/ssdv2)

<br/><br/>

***

> L'installation peut également ce faire sur un home serveur, cependant ce wiki ne parlera que de l'installation cloud sur serveur distant.


***

> Ce script est proposé à des fins d'expérimentation uniquement, le téléchargement d’oeuvre copyrightées est illégal.
Merci de vous conformer à la législation en vigueur en fonction de vos pays respectifs en faisant vos tests sur des fichiers libres de droits
***
