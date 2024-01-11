---
layout: default
title: ssdv2
---
Google OAuth2 vous permet d'utiliser votre compte Google pour vous connecter à vos services. 

L’utilisation de Google OAuth avec Traefik permet d’inscrire des comptes dans la liste blanche, de mettre en œuvre la norme 2FA de Google et de fournir une authentification unique (SSO) à vos services.  

Cela offre, non seulement l'avantage de ne pas avoir de demandes de connexions fréquentes, mais améliore également la sécurité.


## Configuration Google OAuth2 Service 

> #### Note  
> Pour ceux qui utilisent Cloudflare, la création du CNAME est automatisée par le script, pour les autres pensez à le créer auprès de votre Registrar.  
![01-clouldflare-dns-records-for-traefik-google-oauth-740x265](https://user-images.githubusercontent.com/64525827/105626357-56f06100-5e2f-11eb-815d-684ea953c4c8.png)


### Nous allons à nouveau créer un projet cette fois pour traefik Google oAuth

* Rendez vous à l'adresse suivante et connectez vous avec votre compte Gsuite :  
[Google Apps Script API](https://href.li/?https://console.cloud.google.com/cloud-resource-manager)

> ATTENTION : Vous devez être sur et certains de vous connecter au bon compte Google.
Si vous en avez plusieurs, connectez-vous alors en fenêtre de navigation privée !

* ### Cliquez sur Créer un projet
![creer_un_projet](https://user-images.githubusercontent.com/64525827/119948392-14839000-bf99-11eb-96a0-c7509bde74e9.png)  
<br><br>
* ### Entrer le nom du projet ``oauth`` puis cliquer sur Créer  
![creation_projet](https://user-images.githubusercontent.com/64525827/119948566-3f6de400-bf99-11eb-8ddf-ce61d54a76b4.png)  
<br><br>
* ### Dans la notification en haut à droite, cliquer sur "sélectionner un projet"  
![notification](https://user-images.githubusercontent.com/64525827/119949044-c28f3a00-bf99-11eb-8c9f-3342f6c0649e.png)  

### Après l'installation cliquer sur "identifiants"  
![identifiant](https://user-images.githubusercontent.com/64525827/119950352-0a629100-bf9b-11eb-923c-fd49240cc6e0.png)
<br><br>
Dans la nouvelel fenetre, cliquer sur "Créer des identifiants" puis sur "ID client OAuth"
![creation_identifiant](https://user-images.githubusercontent.com/64525827/119950515-33832180-bf9b-11eb-9e12-14995ab54f3c.png)  
<br><br>
Il y a une étape intermédiaire, cliquer sur "Configurer l'écran d'autorisation"  
![configurer oauth](https://user-images.githubusercontent.com/64525827/119950915-af7d6980-bf9b-11eb-9d4a-f51a90294427.png)  
<br><br>
puis sélectionner "externe" et Créer  
![externe](https://user-images.githubusercontent.com/64525827/119951092-dc318100-bf9b-11eb-8fb2-79b59052fecf.png)
<br><br>
Dans la nouvelle fenêtre, remplissez les champs : 
* Nom de l'application => ``identique au nom du projet``
* Adresse e-mail d'assistance utilisateur => ``sélectionner celle du compte google``
* Coordonnées du développeur (Adresse email) => ``Entrer votre email``  

### Sur chaque étapes, cliqurer en bas sur enregistrer  
![etapes](https://user-images.githubusercontent.com/64525827/119951704-8a3d2b00-bf9c-11eb-9632-8c3698a45e5d.png)
<br><br>
Une fois terminé, cliquer à nouveau sur "Identifiants" sur la gauche de l'écran  
Puis :
* Créer des identifiants
* ID client OAuth
* Type d'application  => ``Application web``
* Nom => ``identique au nom du projet``
* URI => ``https://oauth.example.com/_oauth``  
![oauth](https://user-images.githubusercontent.com/64525827/119953309-2451a300-bf9e-11eb-9a85-fb8414e3c667.png)   
<br><br>

### Vous aurez besoin par la suite de ces identifiants pour créer votre Rclone.  
![identifians_ok](https://user-images.githubusercontent.com/64525827/119952283-236c4180-bf9d-11eb-9937-86ca1d319f1c.png)
<br><br>


* ### Copier sur un bloc note le CLIENT ID et le CLIENT SECRET  
![google-apps-script-api-client-id-et-secret](https://user-images.githubusercontent.com/64525827/105181463-1ee5d700-5b2c-11eb-85b1-55a14668ea34.jpeg)

### Vous aurez besoin par la suite de ces identifiants.  


Si vous avez fermer la fenêtre avec vos identifiants, vous pouvez les retrouver dans la rubrique identifiant de projet drive. [Dashboard API](https://href.li/?https://console.developers.google.com).  

![projets-google-api-identifiants](https://user-images.githubusercontent.com/64525827/105181488-2907d580-5b2c-11eb-9b8b-cc39e3e2ed04.jpg)


***
> ## BONUS
***
#### Google OAuth et NZB360, LunaSea etc...  
L'idée est d'utiliser des règles spécifiques par exemple, si l'en-tête de requête contient l'API sabnzbd, radarr, sonarr etc .. on contourne l'authentification.  

Du coup c'est un amalgame de middleware avec et sans authentification qui d'une manière plus générale déclenche l'authentification google Oauth via le web tout en permettant l'accès sur NZB360 et en préservant la sécurité d'accés.   

La procédure est très simple, il suffit juste de changer les labels de traefik dans les applis sabnzbd, lidarr, sonarr, radarr, rutorrent.  

#### Sabnzbd  

Avant

```
traefik.enable: 'true'
## HTTP Routers
traefik.http.routers.sabnzbd-rtr.entrypoints: 'https'
traefik.http.routers.sabnzbd-rtr.rule: 'Host(`sabnzbd.{{user.domain}}`)'
traefik.http.routers.sabnzbd-rtr.tls: 'true'
## Middlewares
traefik.http.routers.sabnzbd-rtr.middlewares: "{{ 'chain-oauth@file' if oauth_enabled | default(false) else 'chain-basic-auth@file' }}"
## HTTP Services
traefik.http.routers.sabnzbd-rtr.service: 'sabnzbd-svc'
traefik.http.services.sabnzbd-svc.loadbalancer.server.port: '8080'
```
Après  
```
traefik.enable: 'true'
traefik.http.routers.sabnzbd-rtr-bypass.entrypoints: 'https'
traefik.http.routers.sabnzbd-rtr-bypass.rule: 'Query(`apikey`, `api_de_sabnzbd`)'
traefik.http.routers.sabnzbd-rtr-bypass.priority: '100'
traefik.http.routers.sabnzbd-rtr-bypass.tls: 'true'
## HTTP Routers Auth
traefik.http.routers.sabnzbd-rtr.entrypoints: 'https'
traefik.http.routers.sabnzbd-rtr.rule: 'Host(`sabnzbd.{{user.domain}}`)
traefik.http.routers.sabnzbd-rtr.priority: '99'
traefik.http.routers.sabnzbd-rtr.tls: 'true'
## Middlewares
traefik.http.routers.sabnzbd-rtr-bypass.middlewares: 'chain-no-auth@file'
traefik.http.routers.sabnzbd-rtr.middlewares: 'chain-oauth@file'
## HTTP Services
traefik.http.routers.sabnzbd-rtr.service: 'sabnzbd-svc'
traefik.http.routers.sabnzbd-rtr-bypass.service: 'sabnzbd-svc'
traefik.http.services.sabnzbd-svc.loadbalancer.server.port: '8080'
```
Ne pas oublier de mettre la clé API à la place de api_de_sabnzbd. Ensuite réinitialiser avec le script

#### sonarr, radarr, lidarr  
Même procédure que pour sabnzbd sauf un label que l'on va modifier.
```
traefik.http.routers.sonarr-rtr-bypass.rule: 'Headers(`X-Api-Key`, `api_sonarr`)'
```  
#### rutorrent
Remplacer vos middlewares par ce qui suit :
``` 
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
Par mesure de sécurité on rajoute une couche d'authentification basique pour l'acces à nzb360  
Du coup pour faire fonctionner sonarr, radarr, lidarr à la fois sur NZb360 et LunaSea tu modifies le label de cette façon

```
traefik.http.routers.sonarr-rtr-bypass.rule: 'Headers(`X-Api-Key`, `b12d1732186a4376b80bdb3875a0f39d`) || Query(`apikey`, `b12d1732186a4376b80bdb3875a0f39d`)'
```