<br /><img src="https://user-images.githubusercontent.com/64525827/107496602-ceddbb80-6b91-11eb-9a05-ac311eedf150.png" width="450">
<br />
[![Discord: https://discordapp.com/invite/kkwEvV6dfj](https://img.shields.io/badge/Discord-gray.svg?style=for-the-badge)](https://discordapp.com/invite/kkwEvV6dfj)


## Le script SSD permet l'installation d'une seedbox complète avec Docker

#### Pour se lancer dans l’installation, il faut au préalable suivre les étapes suivantes:
* [Un serveur distant](https://github.com/laster13/patxav/wiki/Serveur)
* [Un nom de domaine](https://github.com/laster13/patxav/wiki/Nom-de-domaine)
* [Un abonnement à cloud workspace](https://github.com/laster13/patxav/wiki/Les-offres-Cloud-Google)
* [DNS Cloudflare](https://github.com/laster13/patxav/wiki/Cloudflare)
* [Création API Google Drive](https://github.com/laster13/patxav/wiki/Cr%C3%A9ation-API-Google)

Vous aurez besoin d'un utilisateur standard (non root), mais qui aura les droits en sudo sans mot de passe (http://www.desmoulins.fr/index.php?pg=informatique!linux!sudo)
Vous devez vous connecter sur votre serveur avec cet utilisateur (pas de connection root puis su - )

Les étapes à accomplir sont :
```
sudo apt-get update
sudo apt install git
sudo git clone git clone https://github.com/projetssd/ssdv2.git /opt/seedbox-compose
sudo chown -R ${USER} /opt/seedbox-compose
cd /opt/seedbox-compose
sudo ./prerequis.sh
```
Il faut ensuite rebooter votre machine, puis se reconnecter et finir l'installation
``` 
cd /opt/seedbox-compose
./seddbox.sh
```
###


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
