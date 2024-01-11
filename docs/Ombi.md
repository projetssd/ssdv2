---
layout: default
title: ssdv2
---
> > La première chose est d'enlever authentification sur Ombi pour que les autres utilisateurs puissent accéder au site.
Rassurez-vous, il y a déjà un système de connexion intégrée sur Ombi.

Pour retirer l'authentification:
```
nano /home/pseudo/docker-compose.yml
```
![](https://i.imgur.com/o33y2R1.png)

Retirer tout la ligne encadré en rouge, sauvegarder puis taper la commande suivante:

```
docker-compose up -d ombi-pseudo
```
Une fois la configuration effectué, si vous utilisez Plex il faut le configurer dans Ombi car les paramètres de bases ne sont pas corrects:

![](https://i.imgur.com/6oVRP24.png)

Effectuez un test pour voir que la connexion s'effectue bien.

Pour ensuite paramétrer Sonarr ou Radarr, il vous faut des paramètres, que vous retrouvez via Sonarr ou Radarr:
![](https://i.imgur.com/VtdFgKK.png)

Une fois ces informations récupérées, retourner sur Ombi et sélectionner TV (pour Sonarr) ou Movies (pour Radarr), et paramétrez selons vos settings:

![](https://i.imgur.com/OHnCvyj.png)

Si vous cliquez sur "Load Qualities" et que vous récupérez bien vos profils, c'est que la connexion est bien effectué, ensuite à vous de paramétrer comme vous le souhaitez et d'enregistrer.