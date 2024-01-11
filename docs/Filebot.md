---
layout: post
title: ssdv2
---
#### Enregistrer une licence

Mettre le fichier de licence dans /opt/seedbox/docker/${USER}/.filebot/FileBot_License.psm

```
/opt/seedbox/docker/${USER}/.filebot/filebot.sh --license /opt/seedbox/docker/${USER}/.filebot/FileBot_License.psm
```

#### Astuce filebot proposée par @TEALC

Comment séparer les Films 4k des autres (n'oublier pas de remplacer USER par votre pseudo)

1. Créer le dossier Films4k dans /home/USER/local/.

2. Dans les paramètres de Plex, ajouter une Bibliothèques de type Films (donner lui un nom ex: Films 4K, langue: Fr), avec comme dossier dans Plex --> /data/Films4k.

3. En SSH

```cd /home/USER/scripts/plex_autoscan``` 

puis 

```python scan.py update_sections```

4. ``` nano /home/USER/scripts/plex_autoscan/config/config.json```

Au alentour de la ligne 84 il doit y avoir "/data/Films4k/" (NE SURTOUT PAS TOUCHER A LA NUMEROTATION) :

```"PLEX_SECTION_PATH_MAPPINGS": {
    "1": [
      "/data/Animes/"
    ], 
    "2": [
      "/data/Films/"
    ], 
    "3": [
      "/data/Musiques/"
    ], 
    "4": [
      "/data/Series/"
    ], 
    "5": [
      "/data/Films4k/"
    ]
  },

```
5. Rechercher la ligne "SERVER_FILE_EXIST_PATH_MAPPINGS": { et après le dernier ] (juste avant le }, ajouter:

```
, 
    "/home/USER/local/Films4k/": [
      "/data/Films4k/"
    ]
```

6. Rechercher la ligne "SERVER_PATH_MAPPINGS": { et après le dernier ] (juste avant le }, ajouter:

```
,
    "/data/Films4k/": [
      "/movies4k/", 
      "/home/USER/Medias/Films4k/", 
      "/home/USER/local/Films4k/"
    ]
```

7. Rechercher la ligne "SERVER_SCAN_PRIORITIES": { et après le dernier ] (juste avant le }, ajouter (AAA = le nombre suivant):

```,
    "AAA": [
      "/Films4k/"
    ]
```

8. Enregistrer puis fermer.

En SSH

```systemctl restart plex_autoscan.service```

```nano  /opt/seedbox/docker/USER/.filebot/filebot-process.sh```

Remplacer par:

```
#!/bin/bash

sh /opt/seedbox/docker/USER/.filebot/filebot.sh -script fn:amc --output "/home/USER/local" --action move --conflict skip -non-strict --lang fr --log-file amc.log --def unsorted=y music=y --def excludeList=/home/USER/exclude.txt "exec=/home/USER/scripts/plex_autoscan/plex_autoscan_rutorrent.sh" "ut_dir=/home/USER/filebot" --def movieFormat="/home/USER/local/{fn =~ /2160p|4K|4k|UHD/ ? 'Films4k' : 'Films'}/{n} ({y})/{n} ({y}) _ {source}.{vf} - {audioLanguages} - {textLanguages} - {vc}.{ac}-{channels}" seriesFormat="/home/USER/local/Series/{n}/Saison {s}/{n} - {s00e00} - {t} _ {source}.{vf} - {audioLanguages} - {textLanguages} - {vc}.{ac}-{channels}" animeFormat="/home/USER/local/Animes/{n}/{episode.special ? 'Special' : 'Saison '+s}/{n} - {episode.special ? 'S00E'+special.pad(2) : s00e00} - {t} _ {source}.{vf} - {audioLanguages} - {textLanguages} - {vc}.{ac}-{channels}" musicFormat="/home/USER/local/Musiques/{n}/{album+'/'}{pi.pad(2)+'. '}{artist} - {t}"
```

**ATTENTION** ce script déplace les fichiers, pour pouvoir rester en SEED remplacer : --action move par --action copy.

 Enregistrer et fermer.

J'ai modifié le système de renommage, les fichiers auront le format {titre} (année) _ {qualitée}.{format} - [les langues] - [langues sous titres] - {codec vidéo}.{codec audio}-{nombre de channels}.mkv

Pour que filebot trie aussi avant 2005
Créer le dossier FilmsOdl (comme film4k)
Remplacer dans filebot le movieformat par 

```movieFormat="/home/USER/local/{y < 2006 ? 'FilmsOld' : fn =~ /2160p|4K|4k|UHD/ ? 'Films4k' : 'Films'}/{n} ({y})/{n} ({y}) _ {source}.{vf} - {audioLanguages} - {textLanguages} - {vc}.{ac}-{channels}" ```