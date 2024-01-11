---
layout: default
title: ssdv2
---
Plex Autoscan [(de l3uddz)](https://github.com/l3uddz/plex_autoscan) est un script qui assiste Plex dans l'ajout de fichiers multimédias importés par Sonarr / Radarr en analysant uniquement le dossier importé et non pas toute la bibliothèque, empêchant ainsi les interdictions de Google API.

Plex Autoscan est automatiquement configuré par le script. Toutefois vous avez la possibilité de le modifier à votre convenance

Ce qu'il est important de savoir est qu'avant la première utilisation de plex_autoscan il vous faudra faire un scan manuel de chaque librairie avec au moins un media dans chacune d'entre elles.

#### Exemple

```
{
  "DOCKER_NAME": "plex",
  "GDRIVE": {
    "CLIENT_ID": "",
    "CLIENT_SECRET": "",
    "ENABLED": false,
    "TEAMDRIVE": false,
    "POLL_INTERVAL": 60,
    "IGNORE_PATHS": [],
    "SCAN_EXTENSIONS":[
      "webm","mkv","flv","vob","ogv","ogg","drc","gif",
      "gifv","mng","avi","mov","qt","wmv","yuv","rm",
      "rmvb","asf","amv","mp4","m4p","m4v","mpg","mp2",
      "mpeg","mpe","mpv","m2v","m4v","svi","3gp","3g2",
      "mxf","roq","nsv","f4v","f4p","f4a","f4b","mp3",
      "flac","ts"
    ]
  },
  "PLEX_ANALYZE_DIRECTORY": true,
  "PLEX_ANALYZE_TYPE": "basic",
  "PLEX_DATABASE_PATH": "/var/lib/plexmediaserver/Library/Application Support/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.db",
  "PLEX_EMPTY_TRASH": false,
  "PLEX_EMPTY_TRASH_CONTROL_FILES": [
    "/mnt/unionfs/mounted.bin"
  ],
  "PLEX_EMPTY_TRASH_MAX_FILES": 100,
  "PLEX_EMPTY_TRASH_ZERO_DELETED": false,
  "PLEX_LD_LIBRARY_PATH": "/usr/lib/plexmediaserver",
  "PLEX_LOCAL_URL": "http://localhost:32400",
  "PLEX_SCANNER": "/usr/lib/plexmediaserver/Plex\\ Media\\ Scanner",
  "PLEX_SECTION_PATH_MAPPINGS": {
    "1": [
      "/Movies/"
    ],
    "2": [
      "/TV/"
    ]
  },
  "PLEX_SUPPORT_DIR": "/var/lib/plexmediaserver/Library/Application\\ Support",
  "PLEX_TOKEN": "",
  "PLEX_USER": "plex",
  "PLEX_WAIT_FOR_EXTERNAL_SCANNERS": true,
  "RCLONE_RC_CACHE_EXPIRE": {
    "ENABLED": false,
    "MOUNT_FOLDER": "/mnt/rclone",
    "RC_URL": "http://localhost:5572"
  },
  "RUN_COMMAND_BEFORE_SCAN": "",
  "RUN_COMMAND_AFTER_SCAN": "",
  "SERVER_ALLOW_MANUAL_SCAN": false,
  "SERVER_FILE_EXIST_PATH_MAPPINGS": {
      "/mnt/unionfs/media/": [
          "/data/"
      ]
  },
  "SERVER_IGNORE_LIST": [
    "/.grab/",
    ".DS_Store",
    "Thumbs.db"
  ],
  "SERVER_IP": "0.0.0.0",
  "SERVER_MAX_FILE_CHECKS": 10,
  "SERVER_FILE_CHECK_DELAY": 60,
  "SERVER_PASS": "9c4b81fe234e4d6eb9011cefe514d915",
  "SERVER_PATH_MAPPINGS": {
      "/mnt/unionfs/": [
          "/home/seed/media/fused/"
      ]
  },
  "SERVER_PORT": 3468,
  "SERVER_SCAN_DELAY": 180,
  "SERVER_SCAN_FOLDER_ON_FILE_EXISTS_EXHAUSTION": false,
  "SERVER_SCAN_PRIORITIES": {
    "1": [
      "/Movies/"
    ],
    "2": [
      "/TV/"
    ]
  },
  "SERVER_USE_SQLITE": true,
  "USE_DOCKER": false,
  "USE_SUDO": false
}
```

#### Pour modifier ou rajouter des sections

```
cd /home/user/scripts/plex_autoscan
python scan.py sections

```

Un exemple de sortie  

```
 2018-06-23 08:28:26,910 -     INFO -    CONFIG [140425529542400]: Using default setting --loglevel=INFO
 2018-06-23 08:28:26,910 -     INFO -    CONFIG [140425529542400]: Using default setting --cachefile=cache.db
 2018-06-23 08:28:26,910 -     INFO -    CONFIG [140425529542400]: Using default setting --tokenfile=token.json
 2018-06-23 08:28:26,910 -     INFO -    CONFIG [140425529542400]: Using default setting --queuefile=queue.db
 2018-06-23 08:28:26,910 -     INFO -    CONFIG [140425529542400]: Using default setting --logfile=plex_autoscan.log
 2018-06-23 08:28:26,910 -     INFO -    CONFIG [140425529542400]: Using default setting --config=config/config.json
 2018-06-23 08:28:27,069 -     INFO -  AUTOSCAN [140425529542400]:
        _                         _
  _ __ | | _____  __   __ _ _   _| |_ ___  ___  ___ __ _ _ __
 | '_ \| |/ _ \ \/ /  / _` | | | | __/ _ \/ __|/ __/ _` | '_ \
 | |_) | |  __/>  <  | (_| | |_| | || (_) \__ \ (_| (_| | | | |
 | .__/|_|\___/_/\_\  \__,_|\__,_|\__\___/|___/\___\__,_|_| |_|
 |_|

#########################################################################
# Author:   l3uddz                                                      #
# URL:      https://github.com/l3uddz/plex_autoscan                     #
# --                                                                    #
# Part of the Cloudbox project: https://cloudbox.works                  #
#########################################################################
# GNU General Public License v3.0                                       #
#########################################################################

 2018-06-23 08:28:27,070 -     INFO -      PLEX [140425529542400]: Using Plex Scanner
  1: Movies
  2: TV
```

#### Modifications à effectuer

```
"PLEX_SECTION_PATH_MAPPINGS": {
  "1": [
    "/Movies/"
  ],
  "2": [
    "/TV/"
  ]
},
```
ainsi que  

```
"SERVER_PATH_MAPPINGS": {
    "/path/in/plex/container/": [
        "/path/from/sonarr/container/"
    ]
},
```
#### Modification de la fréquence de déclenchement de plex_autoscan

```
"SERVER_SCAN_DELAY": 180,
```

Les options de configurations sont nombreuses et détaillées sur le git de l3uddz
https://github.com/l3uddz/plex_autoscan