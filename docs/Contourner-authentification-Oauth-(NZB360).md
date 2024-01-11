---
layout: default
title: ssdv2
---
## Outrepasser la sécurité oAuth afin d'utiliser (NZB360, Transdroid ou autre)


> Remplacer les middlewares existantes par celle ci-dessous :

<p class="callout info">Après avoir modifier le fichier de config.yml il faut depuis le menu réinitiliaser l'application.</p>

#### Sonnar :
   N'oubliez pas d'ajouter votre API sur la ligne suivante :
```
traefik.http.routers.radarr-rtr-bypass.rule: 'Headers(`X-Api-Key`, `API_Radarr`)'
```
``` 
    # LABELS ######################################################################
    - name: 'Ajout label traefik'
      set_fact:
        pg_labels:
          traefik.enable: 'true'
          traefik.http.routers.sonarr-rtr-bypass.entrypoints: 'https'
          traefik.http.routers.sonarr-rtr-bypass.rule: 'Headers(`X-Api-Key`, `API_Sonarr`)'
          traefik.http.routers.sonarr-rtr-bypass.priority: '100'
          traefik.http.routers.sonarr-rtr-bypass.tls: 'true'
          ## HTTP Routers Auth
          traefik.http.routers.sonarr-rtr.entrypoints: 'https'
          traefik.http.routers.sonarr-rtr.rule: 'Host(`sonarr.{{user.domain}}`)'
          traefik.http.routers.sonarr-rtr.priority: '99'
          traefik.http.routers.sonarr-rtr.tls: 'true'
          ## Middlewares
          traefik.http.routers.sonarr-rtr-bypass.middlewares: 'chain-no-auth@file'
          traefik.http.routers.sonarr-rtr.middlewares: 'chain-oauth@file'
          ## HTTP Services
          traefik.http.routers.sonarr-rtr.service: 'sonarr-svc'
          traefik.http.routers.sonarr-rtr-bypass.service: 'sonarr-svc'
          traefik.http.services.sonarr-svc.loadbalancer.server.port: '8989'
```
    
   #### Radarr :
   N'oubliez pas d'ajouter votre API sur la ligne suivante :
```
traefik.http.routers.radarr-rtr-bypass.rule: 'Headers(`X-Api-Key`, `API_Radarr`)'
```

``` 
    # LABELS ######################################################################
    - name: 'Ajout label traefik'
      set_fact:
        pg_labels:
          traefik.enable: 'true'
          traefik.http.routers.radarr-rtr-bypass.entrypoints: 'https'
          traefik.http.routers.radarr-rtr-bypass.rule: 'Headers(`X-Api-Key`, `API_Radarr`)'
          traefik.http.routers.radarr-rtr-bypass.priority: '100'
          traefik.http.routers.radarr-rtr-bypass.tls: 'true'
          ## HTTP Routers Auth
          traefik.http.routers.radarr-rtr.entrypoints: 'https'
          traefik.http.routers.radarr-rtr.rule: 'Host(`radarr.{{user.domain}}`)'
          traefik.http.routers.radarr-rtr.priority: '99'
          traefik.http.routers.radarr-rtr.tls: 'true'
          ## Middlewares
          traefik.http.routers.radarr-rtr-bypass.middlewares: 'chain-no-auth@file'
          traefik.http.routers.radarr-rtr.middlewares: 'chain-oauth@file'
          ## HTTP Services
          traefik.http.routers.radarr-rtr.service: 'radarr-svc'
          traefik.http.routers.radarr-rtr-bypass.service: 'radarr-svc'
          traefik.http.services.radarr-svc.loadbalancer.server.port: '7878'
``` 

   #### Rutorrent :
``` 
    # LABELS ######################################################################
    - name: 'Ajout label traefik'
      set_fact:
        pg_labels:
          traefik.enable: 'true'
          traefik.http.routers.rutorrent-rtr-bypass.entrypoints: 'https'
          traefik.http.routers.rutorrent-rtr-bypass.rule: 'Path(`/RPC2`)'
          traefik.http.routers.rutorrent-rtr-bypass.priority: '100'
          traefik.http.routers.rutorrent-rtr-bypass.tls: 'true'
          ## HTTP Routers Auth
          traefik.http.routers.rutorrent-rtr.entrypoints: 'https'
          traefik.http.routers.rutorrent-rtr.rule: 'Host(`rutorrent.{{user.domain}}`)'
          traefik.http.routers.rutorrent-rtr.priority: '99'
          traefik.http.routers.rutorrent-rtr.tls: 'true'
          ## Middlewares
          traefik.http.routers.rutorrent-rtr-bypass.middlewares: 'chain-basic-auth@file'
          traefik.http.routers.rutorrent-rtr.middlewares: 'chain-oauth@file'
          ## HTTP Services
          traefik.http.routers.rutorrent-rtr.service: 'rutorrent-svc'
          traefik.http.routers.rutorrent-rtr-bypass.service: 'rutorrent-svc'
          traefik.http.services.rutorrent-svc.loadbalancer.server.port: '8080'
```

-
Par mesure de sécurité on rajoute une couche d'authentification basique pour l'acces à nzb360
Du coup pour faire fonctionner sonarr, radarr, lidarr à la fois sur NZb360 et LunaSea tu modifies le label de cette façon

```
traefik.http.routers.sonarr-rtr-bypass.rule: 'Headers(`X-Api-Key`, `b12d1732186a4376b80bdb3875a0f39d`) || Query(`apikey`, `b12d1732186a4376b80bdb3875a0f39d`)'
```