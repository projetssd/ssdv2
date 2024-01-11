---
layout: default
title: ssdv2
---
### Testé sur une vm (sous vmware  esxi 7) avec le choix 
* Installation Seedbox Classique = Stockage uniquement sur la capacité de votre disque dur

Pour ceux qui veulent installer le script « SSD » en home et qui n’ont pas les ports :  
* 80 ; 443 ; 8080  de disponible parce que leurs FAI soit les bloques ou contrôle leurs box avec.  

Ou tout simplement avoir une Seedbox de test a côté pour pas flingué son prod.  

> Le seul problème c’est qu’il vous faudra rajouter le port  
Exemple : « https:// plex.ndd.com :2053 »  voilà c’est tout.

### Donc pour se faire… après avoir fait :  

#### Installation du script

Mise à jour des paquets :
```
apt update && apt upgrade –y
```

Installation de Git :
```
apt install git
```
« Tapez Y (pour YES) »  


Clonage du script :
```
git clone https://github.com/laster13/patxav.git /opt/seedbox-compose
```

Il vous faudra changer les ports 80 ; 443 ; 8080 dans « traefik.yml »  
qui se trouve ici :  
```
/opt/seedbox-compose/includes/dockerapps
``` 

> Part les ports suivant : http > 2058  https > 2053  et 38080 pour l’interface « traefik »

        command:   <<  (ligne 181)
          - --global.checkNewVersion=true
          - --global.checkNewVersion=true
          - --global.sendAnonymousUsage=true
          - --entryPoints.http.address=:2058
          - --entryPoints.https.address=:2053
***
           
        command:    <<  (ligne 213)
          - --global.checkNewVersion=true
          - --global.checkNewVersion=true
          - --global.sendAnonymousUsage=true
          - --entryPoints.http.address=:2058
          - --entryPoints.https.address=:2053
          - --entryPoints.traefik.address=:38080
          - --api=true
***
        published_ports:
          - "2053:2053"    <<  (ligne 246)
          - "2058:2058"
          - "38080:38080"
        command: '{{command}}'
        security_opts:

***

Enregistré puis suivre la procédure d’installation classique : 
Voilà  ….

> PS : Merci à @lulu80 pour la rédaction
