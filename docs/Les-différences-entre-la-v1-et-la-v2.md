---
layout: default
title: ssdv2
---
Rappel, les sources de la v1 se trouvent ici : [https://github.com/laster13/patxav](V1 (par Laster13))

## Principales différences

- **la v1 n'est plus maintenue**, plus de nouvelles applications, plus de correctifs
- la v2 se lance avec un user non root, la v1 doit être lancée en root
- la v2 utilise un [https://docs.python.org/fr/3/library/venv.html](environnement virtuel) pour installer tout ce qui est lié à python, et donc : 
  - pip
  - ansible
  - les dépendances d'outils tiers (cloudplow, plex_autoscan, ...)

Cela est fait pour toucher le moins possible au système. Vous pouvez avoir un ansible 2.8 sur le système et un ansible 2.10 pour ssd. En cas de désinstallation de ssd, le système reste fonctionnel
- refonte du code pour factoriser au maximum et éviter les doublons (toujours en cours), notamment sur les playbooks de lancement des applis containerisées
- utilisation de fonctions, qui peuvent être appelées autrement que par le script (soit en ligne de commande, soit par des outils à venir)

## Evolutions

Le développement de la v2 a été lancée en octobre 2020. En plus des modifications de base exposées ci dessus, il y a eu des évolutions fonctionnelles : 
- nouvelles applications (gotify, ...)
- refonte de l'affichage et de la gestion des menus
- stockage des informations dans une base sqlite qui pourra être exploitée par d'autres outils à terme

## Des chiffres

En septembre 2021, la v2 correspond à près de 600 commits et près de 18 000 lignes de code modifiées depuis la v1.

