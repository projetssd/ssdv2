---
layout: default
title: ssdv2
---
***

> La documentation complète de Radarr est [ICI](https://href.li/?https://wiki.servarr.com/Radarr).  
La documentation complète de Sonarr est [ICI](https://href.li/?https://wiki.servarr.com/Sonarr).  
Je vous conseille de commencer par la rubrique Quick Start Guide [Radarr](https://href.li?https://wiki.servarr.com/Radarr_Quick_Start_Guide), [Sonarr](https://href.li?https://wiki.servarr.com/sonarr_Quick_Start_Guide)

***


Ci dessous vous trouverez les réglage prope au script SSD

## Downloads Client (Rutorrent)


![Radarr - Download client](https://user-images.githubusercontent.com/64525827/105706539-f6862000-5f11-11eb-9dc8-2ec81241c9dd.png)


## Indiquer le chemin vers les fichiers à importer (Remote Patch)

![Radarr - Remote patch](https://user-images.githubusercontent.com/64525827/105707017-99d73500-5f12-11eb-82b5-6baa35dc918c.png)


## Ajouter un indexer

![Radarr - Indexer](https://user-images.githubusercontent.com/64525827/105706541-f71eb680-5f11-11eb-9f3b-10c05197b985.png)

Il faut utiliser la ligne ci-dessous comme base de lien vers Jackett
> http://jackett:9117/api/v2.0/indexers/nametracker/results/torznab/

## Ajouter autoscan pour informer Plex de l'ajout de fichier

> rendez vous dans le menu seedbox et faites le choix suivants : 2 - 4 - 2) Autoscan (Nouvelle version de Plex_autoscan)

Il n'y a pas de réglage à effectuer, c'est une vérification temps réel des modifications de fichier.  
Une fois le nouveau fichier détecté il est mis en attente pendant 5 min puis Plex est alerté.

## Import manuel

Vous avez téléchargez du contenu avant de le mettre en surveillance dans *arr ou vous avez une erreur à l'importation.  

Alors vous devez utilisez la fonction "manual import" :  
* Il faut utiliser le chemin vers le dossier contenant vos données (attention vous devez utilisez le chemin "Medias"
* Ensuite "interactive import" et enfin vous pouvez sélectionner les fichiers à importés en ayant pris soins de cocher selon vos besoins "hardlink ou "move"
<img width="1057" alt="manual import" src="https://user-images.githubusercontent.com/64525827/105092410-7a1eb780-5aa1-11eb-94ba-77e194d359e0.png">