---
layout: default
title: ssdv2
---
Attention : première écriture.

## Vous avez envie de synchroniser vos lectures avec votre compte Trakt.tv, vous êtes à la bonne adresse.

### prérequis : 
* un compte trakt.tv "gratuit"
* un compte plex "gratuit"

comme vous l'avez compris, il n'y as pas besoin d'être VIP, nous n'utiliserons pas les webhooks

> Avantage de cette solution (il en existe une autre mais je n'en parlerai pas) vous allez pouvoir synchroniser chaque utilisateurs de votre server plex avec sont propre compte Trakt.tv

## on commence : 

### Installation du plugin trakt (Plex-Trakt-Scrobbler)

Download the latest release of the Trakt.tv plugin :
````
wget https://github.com/trakt/Plex-Trakt-Scrobbler/archive/master.zip -O Plex-Trakt-Scrobbler.zip
````
Extract the downloaded ZIP archive : 
````
unzip Plex-Trakt-Scrobbler.zip
````

Déplacement : (remplacer USER votre votre user)
````
cp -r Plex-Trakt-Scrobbler-*/Trakttv.bundle "/opt/seedbox/docker/USER/plex/config/Library/Application Support/Plex Media Server/Plug-ins"
````

Changement des droits : 
````
cd "/opt/seedbox/docker/USER/plex/config/Library/Application Support/Plex Media Server/Plug-ins/"
````
````
chown -R 1000:1000 Trakttv.bundle && chmod -R 775 Trakttv.bundle
````

Restart Plex Media Server : 
````
docker restart plex
```` 

### Installation de Kitana : 

Direction le menu du script pour y ajouter l'application "kitana"


### Parametrage de la solution : 

Rendez-vous à l'adresse suivante [trakt-scrobbler](http://trakt-for-plex.github.io/configuration/#/login)

Connexion à votre compte plex : 

![login](https://user-images.githubusercontent.com/64525827/119456089-94f88580-bd3a-11eb-946a-e2f2eb956c94.png)

puis sélectionner votre serveur dans la fenêtre "connect" 

![configuration](https://user-images.githubusercontent.com/64525827/119456303-d7ba5d80-bd3a-11eb-90a2-0eb725f0cf9f.png)  
cliquer sur Rules et reproduisez ceci  
![rules](https://user-images.githubusercontent.com/64525827/119456424-f28cd200-bd3a-11eb-8d3a-ffcb8caafc57.png)  

Dans "Accounts" il faut ajouter les différents compte que vous souhaitez synchroniser avec Trakt.tv 

> IMPORTANT : il faut suivre dans le sens exact les consignes suivantes  

Pour Plex : 
Cliquer sur le lien https://plex.tv/pin pour entrer le code présent à l'écran, attendez que ça soit bien pris en compte puis ENREGISTRER avec le bouton bleu en haut à droite.  

Pour Trakt : 
Cliquer sur "Get PIN" connectez vous à votre compte Trakt afin de voir le code généré, ensuite coller le dans la config et cliquer sur "Sign in" puis ENREGISTRER avec le bouton bleu

Résultat attendu : 

![authentification](https://user-images.githubusercontent.com/64525827/119457702-43e99100-bd3c-11eb-9b8b-5c64ecafe6b9.png)  

## Suite de l'installation avec Kitana

Rendez vous à l'adresse de votre kitana (exemple : https://kitana.votrendd.fr)

connectez vous avec votre compte PLEX  
![kitana connect](https://user-images.githubusercontent.com/64525827/119457858-6c718b00-bd3c-11eb-86d7-a7e0982448bc.png)  

Cliquer sur l'adresse IP local "172.18.0.xx" puis sur le plugin trakt  

Dans l'onglet "sync" vous avez plusieurs possibilités j'en présente deux : 

Ce choix, permet de récupérer l'htistorique de vue depuis Trakt afin de marquer comme vu dans Plex tout ce qui est marqué comme vu dans Trakt  
![Pull](https://user-images.githubusercontent.com/64525827/119458238-d12ce580-bd3c-11eb-9196-237f146ed463.png)  


Ce choix, permet d'envoyer à Trakt tout les contenus marqué comme vu dans votre Plex  
![Push](https://user-images.githubusercontent.com/64525827/119458428-089b9200-bd3d-11eb-8543-2d9b1dd0cfea.png)


> Pour vérifier le bon fonctionnement, il vous suffit de lancer une lecture et d'aller sur trakt.tv, vous devriez voir ceci  
![Capture d’écran 2021-05-25 à 09 41 58](https://user-images.githubusercontent.com/64525827/119458868-79db4500-bd3d-11eb-8450-9df1430724e6.png)

Fin 👍🏻 