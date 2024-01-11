---
layout: default
title: ssdv2
---
![](https://nextcloud.teamsyno.com/s/2jzfHCLjTdB2WTF/preview)

#### Login et password pour McMyAdmin 

Login: `admin`

Password: `pass123`

**Il faut changer ça immédiatement après votre première connexion pour une question de sécurité!**

Ne pas négliger cette recommandation, cette option est proposée directement après la première connexion, mais ne passez pas cette étape.

#### Passer de la version de Java 11 à Java 8

Pour beaucoup de (bons) Mods il faudra la version Minecraft 1.12.2, mais cette version **tourne sous Java 8**.

Hors, McMyAdmin est installé avec Java 11 par défaut, ce qui aura pour effet que votre serveur ne se lancera jamais.

Pour remédier à cela il faut suivre ces étapes:

`docker exec -ti minecraft bash`

`apt update`

`echo "deb http://ftp.us.debian.org/debian sid main" >> /etc/apt/sources.list`

`apt update`

`apt install openjdk-8-jdk`

`update-alternatives --config java`

Choisir la version Java 8.

Et enfin, un petit `exit`, on valide... c'est fini.

Bon amusement :)