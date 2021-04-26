# Principes de base

## Les applis génériques

Ce sont les applis dont les réglages sont très simples : des variables d'environnement, un 
port pour traefik et des volumes.

Pour celles ci, on crée un fichier de variables dans le répertoire dockerapps/vars. 
Ce fichier sera lancé par generique.yml

## Les applis complexes

Par exemple celles qui doivent ouvrir un port particulier (plex, qbittorrent, ...)

Pour celles ci on crée un playbook dans dockerapps

## Pretasks et posttasks

Pour toutes les applis (generiques ou complexes), on peut créer des playbooks dans dockerapps/pretasks et/ou dockerapp/posttasks.

Ces playbooks seront lancés avant et/ou après le paybook principal.
C'est le cas des applis qui nécessitent une base de données (wordpress,...) ou des réglages particuliers (verif de xml pour emby)

## Fonctionnement

Au lancement, on regarde :
- On lance TOUJOURS le /opt/seedbox-compose/includes/dockerapps/pretasks/<appli>.yml s'il existe
- existe-t-il un playbook dans /opt/seedbox/conf/<appli.yml> ? Si oui on le lance et on passe au posttasks
- existe-t-il un playbook dans /opt/seedbox-compose/includes/dockerapps/<appli.yml> ?
Si oui on le copie dans /opt/seedbox/conf/<appli.yml> et on le lance, et on passe au posttasks
- existe-t-il un fichier de variables dans /opt/seedbox/vars/<appli.yml>  ? 
Si oui on lance le générique avec ce fichier de variales, et on passe au posttasks
- existe-t-il un fichier de variables dans /opt/seedbox-compose/includes/dockerapps/vars/<appli.yml> ?
Si oui, on le copie dans /opt/seedbox/vars/<appli.yml> et on le lance, et on passe au posttasks
- on lance TOUJOURS le /opt/seedbox-compose/includes/dockerapps/posttasks/<appli>.yml s'il existe