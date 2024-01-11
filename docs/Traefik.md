---
layout: default
title: ssdv2
---
#### Ajouter un 2ème Domaine à traefik  
En considérant que vous utilisez cloudflare, ce qui à mon sens est le meilleur choix.  Dans un 1er temps on supprime le container traefik  

```
docker rm -f traefik
rm -rf /opt/seedbox/docker/traefik
```  
Sauvegarder le dossier rules si vous avez créé des règles spécifiques  
Configurer cloudflare pour le nouveau domaine concerné (les 2 domaines doivent appartenir au même compte cloudflare)  
Ensuite modifier le fichier suivant:  

```/opt/seedbox-compose/includes/dockerapps/traefik.yml```

```
    - name: label traefik with cloudflare
      set_fact:
        labels:
          traefik.enable: 'true'
          ## HTTP-to-HTTPS Redirect
          traefik.http.routers.http-catchall.entrypoints: 'http'
          traefik.http.routers.http-catchall.rule: 'HostRegexp(`{host:.+}`)'
          traefik.http.routers.http-catchall.middlewares: 'redirect-to-https'
          traefik.http.middlewares.redirect-to-https.redirectscheme.scheme: 'https'
          ## HTTP Routers
          traefik.http.routers.traefik-rtr.entrypoints: 'https'
          traefik.http.routers.traefik-rtr.rule: 'Host(`traefik.{{user.domain}}`)'
          traefik.http.routers.traefik-rtr.tls: 'true'
          traefik.http.routers.traefik-rtr.tls.certresolver: 'letsencrypt' 
          traefik.http.routers.traefik-rtr.tls.domains[0].main: '{{user.domain}}'
          traefik.http.routers.traefik-rtr.tls.domains[0].sans: '*.{{user.domain}}'
          traefik.http.routers.traefik-rtr.tls.domains[1].main: 'second-domaine.com'
          traefik.http.routers.traefik-rtr.tls.domains[1].sans: '*.second-domaine.com'
          ....
```
Reinstaller Traefik  
```
ansible-playbook /opt/seedbox-compose/includes/dockerapps/traefik.yml
```
Vérification:  
```cat /opt/seedbox/docker/traefik/acme/acme.json```  
```
{
  "letsencrypt": {
    "Account": {
      "Email": "xxxxxxx@gmail.com",
      "Registration": {
        "body": {
          "status": "valid",
          "contact": [
            "mailto:xxxxxx@gmail.com"
          ]
        },
        "uri": "https://acme-staging-v02.api.letsencrypt.org/acme/acct/16387697"
      },
      "PrivateKey": "MIIJKAI................Nz9NTZXRDc=",
      "KeyType": "4096"
    },
    "Certificates": [
      {
        "domain": {
          "main": "PremierDomaine.com",
          "sans": [
            "*.PremierDomaine.com"
          ]
        },
        "certificate": "t...............LS0K",
        "Store": "default"
      },
      {
        "domain": {
          "main": "SecondDomaine.fr",
          "sans": [
            "*.SecondDomaine.fr"
          ]
        },
        "certificate": "S0..............K",
        "key": "0K.........",
        "Store": "default"
      }
    ]
  }
}
```
Modifier les labels traefik des applis de cette facon (/opt/seedbox/conf)    

```
        pg_labels:
          traefik.enable: 'true'
          ## HTTP Routers
          traefik.http.routers.lidarr-rtr.entrypoints: 'https'
          traefik.http.routers.lidarr-rtr.rule: 'Host(`lidarr.{{user.domain}}`) || Host(`lidarr.secondDomaine.com`)'
          traefik.http.routers.lidarr-rtr.tls: 'true'
          ## Middlewares
          ##traefik.http.routers.lidarr-rtr.middlewares: "{{ 'chain-oauth@file' if oauth_enabled | default(false) else 'chain-basic-auth@file' }}"
          ## HTTP Services
          traefik.http.routers.lidarr-rtr.service: 'lidarr-svc'
          traefik.http.services.lidarr-svc.loadbalancer.server.port: '8686'
```
Enfin réinitialiser via le script