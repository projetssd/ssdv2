# Eraserr

Eraserr marche en ligne de commande et n'a pas d'interface graphique.

Par défaut, il est installé en "dry run" et ne supprimera aucune ressource tant que vous n'aurez pas modifié le fichier de configuration.

## Lire les logs

### GUI 

Il faut se connecter au dashboard kubernetes, et chercher le pod "eraser-xxxxx" pour afficher ses logs

### Ligne de commande

faire
```
kubectl get pods
kubectl logs -f eraserr-xxxxx # mettre le nom du pod trouvé précédemment 
```

## Protégér ses medias

Dans radarr et sonarr, il faut mettre le tag *do-not-delete* pour qu'eraserr n'efface pas le fichier

## Modifier le fichier de conf

Le fichier *${APP_SETTINGS}/eraserr/app/config.json* s'édite avec sudo

Fichier exemple :

```
{
    "tautulli": {
        "api_key": "xxxxxxxxxxxxxxxxxxxxxx",
        "base_url": "http://tautulli:8181/api/v2",
        "fetch_limit": 25
    },
    "radarr": {
        "api_key": "xxxxxxxxxxxxxxxxxxxxxxx",
        "base_url": "http://radarr:7878/api/v3", # changer radarr en radarrnightly par exemple
        "exempt_tag_names": [
            "do-not-delete"
        ]
    },
    "sonarr": {
        "api_key": "xxxxxxxxxxxxxxxxxxxx",
        "base_url": "http://sonarr:8989/api/v3",
        "monitor_continuing_series": true,
        "exempt_tag_names": [
            "do-not-delete"
        ]
    },
    "overseerr": {
        "api_key": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
        "base_url": "http://overseerr:5055/api/v1",
        "fetch_limit": 10
    },
    "plex": {
        "base_url": "http://plex:32400",
        "token": "R24sRqmRvCzA_egLLUxv",
        "refresh": true
    },
    "last_watched_days_deletion_threshold": 90,
    "unwatched_days_deletion_threshold": 90,
    "dry_run": true, # mettre a true pour sortir du dry run
    "schedule_interval": 86400
}
```

Une fois le fichier modifié, faire
``` 
ks_restart_deployment eraserr
```

pour relancer avec les bonnes valeurs