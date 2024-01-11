# Eraserr

Eraserr works in CLI only, and doesn't have a graphical interface.

It is installed in "dry run" mode, and won't remove any of your media until you decide to modify the configuration

## Read the logs

### GUI 

USe the k8s dashboard, find the  "eraser-xxxxx" pod, and watch the logs

### CLI

```
kubectl get pods
kubectl logs -f eraserr-xxxxx # get the pod name you fount on the previous command 
```

## Protect medias

In *arr, use the tag *do-not-delete* So eraserr won't delete this media

## Edit configuration

The file *${APP_SETTINGS}/eraserr/app/config.json* has to be modified using sudo

Example :

```
{
    "tautulli": {
        "api_key": "xxxxxxxxxxxxxxxxxxxxxx",
        "base_url": "http://tautulli:8181/api/v2",
        "fetch_limit": 25
    },
    "radarr": {
        "api_key": "xxxxxxxxxxxxxxxxxxxxxxx",
        "base_url": "http://radarr:7878/api/v3", # change radarr as radarrnightly if needed
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
    "dry_run": true, # set to true if you want to get out of dry run mode
    "schedule_interval": 86400
}
```

Once the file has been modified :
``` 
ks_restart_deployment eraserr
```
in order to relaunch the service