---
layout: default
title: ssdv2
---
## on commence !!!
> Vous avez suivi les Prérequis alors on passe à l'installation du script qui installera toutes les dépendances (y compris docker).

### il faut un user NON root, qui ait les droits de faire du sudo

Sur debian, il faut commencer par installer sudo
``` 
apt-get update
apt install -y sudo
```

Si vous n'avez que root :
``` 
adduser seed # changez "seed" par le user que vous voulez, et répondez aux questions
usermod -aG sudo seed # changez "seed" par le user que vous voulez
```
Une fois que tout ça est fait, déconnectez vous de votre session root, et reconnectez vous avec le user qui vient d'être créé

Ensuite

## Installation du script
### Mise à jour des paquets :
```
sudo apt-get update && sudo apt upgrade -y
```
### Installation de Git :
```
sudo apt install -y git
```
### Clonage du script :
```
sudo git clone https://github.com/projetssd/ssdv2.git /home/${USER}/seedbox-compose
```
### Changement des droits
```
sudo chown -R ${USER}: /home/${USER}/seedbox-compose
```
Pour lancer le script :
```
cd /home/${USER}/seedbox-compose && ./seedbox.sh
```

### Vous aurez ce message : 
```
IMPORTANT !
===================================================
Votre utilisateur n'était pas dans le groupe docker
Il a été ajouté, mais vous devez vous déconnecter/reconnecter pour que la suite du process puisse fonctionner
```
Alors déconnexion puis Reconnexion et on continue avec la même commande
```
cd /home/${USER}/seedbox-compose && ./seedbox.sh
```

### INFORMATIONS UTILISATEURS
il suffit de répondre aux questions  

### Installation de cloudflare 
* Souhaitez vous utiliser les DNS Cloudflare ? (o/n - default n) : o
recommandation ``oui`` afin de mettre à jour les sous-domaines automatiquement  

* Votre Email Cloudflare: ``mail du compte cloudflare``
* Votre API Cloudflare: ``API globale``

### Google OAuth2 avec Traefik – Secure SSO pour les services Docker
* Souhaitez vous sécuriser vos Applis avec Google OAuth2 ? (o/n - default n) : n
* Dans un premier temps répondez ``n`` nous reviendrons dessus plus tard

## Fin de la création du fichier account.yml

Lors de l'installation du script celui-ci prendra du temps et restera un moment sur

```
TASK [Add Debian repositories] ***************************************************************
TASK [Install common packages] ***************************************************************
```
> Ne vous inquiétez pas, laissez faire car cela prendra plus ou moins du temps en fonction de la puissance de votre serveur et vous verrez le script redémarrer au bout d'un moment.


### Installation de Traefik
* Souhaitez vous personnaliser le sous domaine? (o/n): ``n``
* Choix de Authentification pour traefik [ Enter ] 1 => basique | 2 => oauth | 3 => authelia: ``1``
Pour le moment, il faut choisir ``basique``plus tard vous pourrez installer Oauth Google ou Authlia

### Les composants sont maintenants tous installés/réglés, poursuite de l'installation
* Appuyez sur entrée pour continuer, ou ctrl+c pour sortir


# Vous avez réussi à atteindre l'accueil du script ``BRAVO``


### Le premier choix à faire : installation local ou Gdrive
* Installation Seedbox Classique = Stockage uniquement sur la capacité de votre disque dur
* Installation Seedbox Rclone = Stockage sur le cloud
* Restauration Seedbox = Restauration à partir du BACKUP

### Gestion du rclone.conf
> vous avez 3 possibilités :

* Copier/coller un rclone.conf déjà existant **(fortement recommandé)**
* ~~Création rclone.conf~~
* ~~rclone.conf déjà existant sur le serveur~~  

### CHOIX 1 -> Copier/coller un rclone.conf déjà existant  

Vous devez suivre la procédure suivante selon votre système : [Pour MacOS](Cr%C3%A9ation-remote-rclone-(MacOS)) | [Pour Windows](Cr%C3%A9ation-remote-rclone-(Windows)) | [Pour Linux](Cr%C3%A9ation-remote-rclone-(Linux))

Coller le rclone, puis retour à la ligne et taper STOP puis à nouveau ENTRER pour valider.  


### Choisir le remote principal :

   1) Share Drive 
   2) Gdrive 

* Votre choix: 1
Nous vous conseillons l'utilisation de Sharedrive  


### Médias à ajouter :  
* Avec la barre d'espace sélectionner les dossiers à créer
* Tabulation, puis taper entrer sur le bouton OK  

# Vous avez réussi l'installation du script ``BRAVO``


### Commençon par installer une application (ou deux)
* Entrez le chiffre 1) Ajout/ Suppression d'Applis
* Ajout d'applications (naviguer avec les flêches et tabulation)
* Vous pouvez selectionner plusieurs applications 
> Sélection des applications à installer:  
Appuyer sur le barre espace pour sélectionner les applications, puis tabulation et taper ENTRER sur `OK`  
* une fois toutes les apps sélectionner, aller sur OK

### Personnaliser les sous domaines: (o/N) ? N
Dans un premier temps je vous conseille de conserver les sous-domaines par défaut


### Retour à l'accueil 
* pour sortir d'ici, il faut faire CTRL c

### Désormais vous pouvez lancer le menu en faisant 
```
cd /home/${USER}/seedbox-compose && ./seedbox.sh
```

### Première chose à faire l'installation de cloudplow et Plex_Autoscan
* choix 2 puis choix 4
* Ensuite lancer l'installation de Plex_Autoscan
* et ensuite celle de cloudplow



# FIN 👍