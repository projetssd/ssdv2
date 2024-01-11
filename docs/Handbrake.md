---
layout: default
title: ssdv2
---
# Handbrake

Ceci est un conteneur Docker pour HandBrake .

L'interface graphique de l'application est accessible via un navigateur Web moderne (aucune installation ni configuration nécessaire côté client) ou via n'importe quel client VNC.

Un mode entièrement automatisé est également disponible : déposez les fichiers dans un dossier de surveillance et laissez HandBrake les traiter sans aucune interaction de l'utilisateur.

![handbrake](https://user-images.githubusercontent.com/64525827/147670229-0f9f3e36-b734-42ae-ac55-de82570b4489.png)


### HandBrake est un outil permettant de convertir des vidéos de presque tous les formats en une sélection de codecs modernes et largement pris en charge.

* $HOME: cet emplacement contient les fichiers de votre hébergeur qui doivent être accessibles par l'application.
* $HOME/USER/local/HandBrake/watch: C'est ici que se trouvent les vidéos à convertir automatiquement.
* $HOME/USER/local/HandBrake/output: C'est là que les fichiers vidéo convertis automatiquement sont écrits.

Naviguez jusqu'à http://your-host-ip:5800pour accéder à l'interface graphique HandBrake. Les fichiers de l'hôte apparaissent sous le /storagedossier dans le conteneur.