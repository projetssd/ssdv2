---
layout: default
title: ssdv2
---
## Obtenir un serveur distant

* Vous aurez besoin d'un serveur dédié, disponible par exemple chez Hetzner, Kimsufi, OVH, Oneprovider, etc...

### Le script est actuellement compatible avec
* Ubuntu Server 18.014 et 20.04
* Debian 9 - 10 - 11

Nous vous conseillons de ne pas utiliser de serveur VPS, vous n'aurez pas les performances suffisantes pour profiter pleinement du script.

Votre serveur doit être vierge, n'installez aucun élément c'est le script qui va le faire.

### Partitionnement

Si vous avez plusieurs disque durs sur le serveur, nous vous conseillons de passer en RAID pour utiliser tout l'espace disponible.
* Le serveur ne doit pas posséder de "/home" séparé au partitionnement.
* La partition accueillant les données devant être à la racine "/".
* Une partition pour le boot, d'une taille mini conseillée de 512Mo.

### Utilisateur

Pour le moment l'installation doit être faite depuis un utilisateur qui a les droits de faire du sudo. Pas de connexion directe en root ! De même il ne faut pas se connecter en root puis faire un "su - <user>" mais établir une connexion directement avec le bon user.