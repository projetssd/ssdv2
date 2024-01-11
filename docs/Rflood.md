---
layout: default
title: ssdv2
---
# installation de Rflood :

Depuis le menu ou avec la commande `launch_service rflood`  

## paramètres à modifier :  

<img width="828" alt="chemin" src="https://user-images.githubusercontent.com/64525827/149654327-93ebf2b6-de91-42a4-be70-5139719bd5b1.png">

## Informations importante :  

* Non compatible avec radarr  
* Pas d'autotools pour définir un chemin particulier à la fin du téléchargement  
* Pas de plugin ratio, donc pas de gestion automatique selon le ratio  


***

### Il faut abosulement modifier le fichier config.json de cloudplow afin d'y ajouter le dossier `rflood` dans les exclusions  

* chemin => `home/${USER}/scripts/cloudplow/config.json` 
prenez exemple sur chaque élément déjà existant (attention c'est écrit de manières différentes pour chaque endroit)
***



