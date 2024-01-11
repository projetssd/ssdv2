---
layout: default
title: ssdv2
---
Tout d'abord, Authelia est un outil open-source qui agit comme un portail où l'utilisateur est invité à s'authentifier.

Une fois connecté, Authelia permet de gérer si un utilisateur peut accéder ou non à des ressources données avec une granularitée assez fine sur l'url. Par exemple, on peut permettre à l'utilisateur de se connecter à un nom de domaine, tout en interdisant à celui-ci d'accéder à un dossier spécifique (/admin).

Cet outil gère jusqu'à deux facteurs d'authentification et permet d'utiliser une connexion unique (SSO) à travers l'ensemble des applications configurées à travers celui-ci.

Enfin, Authelia s'intègre facilement avec les outils de type proxy inverse (reverse proxy) tels que Traefik, NGINX voire même HAProxy comme vous pouvez le voir sur l'architecture ci-dessous:

![authelia-architecture](https://user-images.githubusercontent.com/64525827/105358641-b9125180-5bf6-11eb-929c-4eb7131d5a84.png)


Important: Créer un mot de passe de l'application en suivant cette procédure  

[Créer et utiliser des mots de passe d'application](https://support.google.com/mail/answer/185833?hl=fr)

Enfin exemple de parametre de connection avec gmail

smtp: smtp.gmail.com
port 587
mot de passe application: celui creé precédement en suivant le lien