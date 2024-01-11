---
layout: default
title: ssdv2
---
Traktarr utilise Trakt.tv pour rechercher des émissions et des films à ajouter à Sonarr et Radarr, respectivement.  

https://github.com/Cloudbox/Community/wiki/Traktarr-Tips  

Exemple:  
```
traktarr movies -t person -f /home/yohann/Medias/Classiques -a 'fernandel' -l 10
```

#### 1. Types de listes de tâches supportées:

* Listes officielles de trakt
        Tendances
        Populaire
        Anticipé
        Box-office
        Le plus regardé
        Le plus joué 

* Listes publiques

* Listes privées

* Liste de surveillance

* Liste personnalisée (s) 

* Prise en charge de plusieurs utilisateurs (authentifiés). 


<a href="https://asciinema.org/a/180044" target="_blank"><img src="https://asciinema.org/a/180044.svg" /></a>

#### 2. Créer une application Trakt
1. Créez une application Trakt en allant https://trakt.tv/oauth/applications/new

2. Entrez un nom pour votre application. par exemple traktarr

3. Entrez ```urn:ietf:wg:oauth:2.0:oob``` dans le champ Redirect uri

4. Cliquez sur "ENREGISTRER APP"

Ouvrez ensuite  le fichier de configuration config.json et 
insérez votre ID client et votre secret client dans le config.json, comme ceci:
```
      " trakt " : {
         " client_id " : " your_trakt_client_id " ,
         " client_secret " : " your_trakt_client_secret "
     } 
```

#### 3. Authentifier utilisateur (s) (facultatif)

Pour chaque utilisateur auquel vous souhaitez accéder aux listes privées (liste de contrôle et / ou listes personnalisées, par exemple), vous devez vous authentifier.

Répétez les étapes suivantes pour chaque utilisateur à authentifier:

1. Exécuter traktarr trakt_authentication

2. Vous obtiendrez l'invite suivante:
```
     - We're talking to Trakt to get your verification code. Please wait a moment... - Go to: https://trakt.tv/activate on any device and enter A0XXXXXX. We'll be polling Trakt every 5 seconds for a reply 
```
3. Allez à https://trakt.tv/activate

4. Entrez le code que vous voyez dans votre terminal.

5. Cliquez sur Continuer.

6. Si vous n'êtes pas connecté à Trakt, connectez-vous maintenant.

7. Cliquez sur "Accepter".

Vous recevrez le message: "Woohoo! Votre appareil est maintenant connecté et s'actualisera automatiquement dans quelques secondes."

Vous avez maintenant authentifié l'utilisateur.

Vous pouvez répéter cette procédure pour autant d'utilisateurs que vous le souhaitez.

#### Configuration

1. Automatique

Utilisé pour les tâches Traktarr automatiques / planifiées.

Les films peuvent être diffusés séparément, puis à partir de séries.

Remarque: ces paramètres ne sont nécessaires que si vous prévoyez d'utiliser Traktarr sur une planification (par rapport à son utilisation uniquement en tant que commande CLI; voir Utilisation ).
```
"automatic": {
  "movies": {
    "anticipated": 3,
    "boxoffice": 10,
    "interval": 24,
    "popular": 3,
    "trending": 2,
    "watched": 2,
    "played_all": 2,
    "watchlist": {},
    "lists": {},
  },
  "shows": {
    "anticipated": 10,
    "interval": 48,
    "popular": 1,
    "trending": 2,
    "watched_monthly": 2,
    "played": 2,
    "watchlist": {},
    "lists": {}
  }
},
```

interval - Spécifiez la fréquence (en heures) d'exécution de la tâche Traktarr.

anticipated , popular , trending , boxoffice (films uniquement) - Spécifiez le nombre d'éléments à rechercher dans chaque liste Trakt.

watched - Ajoute les éléments les plus regardés par les utilisateurs uniques de Trakt (visionnements multiples exclus).

* watched_weekly / watched_weekly - Les plus regardées de la semaine.

* watched_monthly - Les plus regardées au cours du mois.

* watched_yearly - Le plus regardé de l’année.

* watched_all - Le plus regardé de tous les temps. 

played - Ajoute les éléments les plus souvent lus par les utilisateurs de Trakt (visualisations multiples incluses).

* played / played_weekly - La plupart des played_weekly de la semaine.

* played_monthly - Le plus joué dans le mois.

* played_yearly - La plupart des played_yearly de l’année.

* played_all plus joué de tous les temps. 

watchlist - Spécifiez les listes de surveillance à récupérer (voir les explications ci-dessous).

lists - Spécifiez les listes personnalisées à récupérer (voir les explications ci-dessous).

Les options sont nombreuses, je vous invite à consulter le wiki de https://github.com/l3uddz pour avoir plus d'infos.

#### exemple avec des listes et radarr

Pour les listes publiques et privées, vous aurez besoin de l'URL de cette liste. Lorsque vous consultez la liste sur Trakt, copiez simplement l'URL à partir de la barre d'adresse de votre navigateur.

```
{
  "automatic": {
    "movies": {
      "anticipated": 3,
      "boxoffice": 10,
      "interval": 24,
      "popular": 3,
      "trending": 2,
      "lists": {
      "https://trakt.tv/users/toto/lists":10
      }
    },
    "shows": {
      "anticipated": 10,
      "interval": 48,
      "popular": 1,
      "trending": 2
    }
```

**traktarr movies --list-type watchlist**
![Imgur](https://i.imgur.com/3qawDFd.png)

plugin chrome pour trak.tv francais

https://github.com/nliautaud/trakttvstats