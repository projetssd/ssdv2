---
layout: default
title: ssdv2
---
Plex Dupefinder [(par l3uddz)](https://github.com/l3uddz/plex_dupefinder) est une application python qui recherche les versions dupliquées de médias (épisodes et films) dans votre bibliothèque Plex et demande à Plex de supprimer les versions de qualité la plus basse (basées sur un algorithme de scoring), de manière automatique ou interactive (c'est-à-dire une invite à chaque recherche), vous laissant avec un fichier multimédia de haute qualité.  

La configuration est automatisée par le script, mais vous pouvez modifier certains paramètres dans /home/user/scripts/plex_dupefinder/config.json

#### Exemple  

```
{
    "AUDIO_CODEC_SCORES": {
        "aac": 1000,
        "ac3": 1000,
        "dca": 2000,
        "dca-ma": 4000,
        "eac3": 1250,
        "flac": 2500,
        "mp2": 500,
        "mp3": 1000,
        "pcm": 2500,
        "truehd": 4500,
        "Unknown": 0,
        "wmapro": 200
    },
    "AUTO_DELETE": false,
    "FILENAME_SCORES": {
        "*.avi": -1000,
        "*.ts": -1000,
        "*.vob": -5000,
        "*1080p*BluRay*": 15000,
        "*720p*BluRay*": 10000,
        "*dvd*": -1000,
        "*HDTV*": -1000,
        "*PROPER*": 1500,
        "*Remux*": 20000,
        "*REPACK*": 1500,
        "*WEB*CasStudio*": 5000,
        "*WEB*KINGS*": 5000,
        "*WEB*NTB*": 5000,
        "*WEB*QOQ*": 5000,
        "*WEB*SiGMA*": 5000,
        "*WEB*TBS*": -1000,
        "*WEB*TROLLHD*": 2500,
        "*WEB*VISUM*": 5000
    },
    "PLEX_SECTIONS": {
        "Movies": 1,
        "TV": 2
    },
    "PLEX_SERVER": "https://plex.yourdomain.com",
    "PLEX_TOKEN": "",
    "SCORE_FILESIZE": true,
    "SKIP_LIST": [],
    "VIDEO_CODEC_SCORES": {
        "h264": 10000,
        "h265": 5000,
        "hevc": 5000,
        "mpeg1video": 250,
        "mpeg2video": 250,
        "mpeg4": 500,
        "msmpeg4": 100,
        "msmpeg4v2": 100,
        "msmpeg4v3": 100,
        "Unknown": 0,
        "vc1": 3000,
        "vp9": 1000,
        "wmv2": 250,
        "wmv3": 250
    },
    "VIDEO_RESOLUTION_SCORES": {
        "480": 3000,
        "720": 5000,
        "1080": 10000,
        "4k": 20000,
        "sd": 1000,
        "Unknown": 0
    }
}
```


![](https://camo.githubusercontent.com/87d1f9ea365016f35689d475be385e3d484dfe5c/68747470733a2f2f692e696d6775722e636f6d2f643173444e6c452e706e67)

Le scoring est basé sur: des paramètres non configurables et configurables.

* Les paramètres non configurables sont: le débit , la durée , la hauteur , la largeur et le canal audio .

* Les paramètres configurables sont: les scores de codec audio , les scores de codec vidéo , les scores de résolution vidéo , les scores de nom de fichier et la taille des fichiers (ne peuvent être activés ou désactivés).

Remarque: le débit binaire, la durée, la hauteur, la largeur, le canal audio, les codecs audio et vidéo, les résolutions vidéo (par exemple, SD, 480p, 720p, 1080p, 4K, etc.) et la taille des fichiers sont tous extraits des métadonnées que Plex récupère lors de l'analyse des médias. 

## Demo
https://asciinema.org/a/180157?cols=180&rows=50