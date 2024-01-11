---
layout: default
title: ssdv2
---
#### Synchroniser deux drives avec 2 remotes nommés respectivement google et tata

Cloudplow upload vers le 1er drive et ensuite, dans un delais préalablement defini, synchonise le 1er drive avec le 2ème drive

le rclone.conf intègre donc 5 remotes

avec les mêmes mots de passe

Le remote plexdrive concernant le 2ème remote à synchroniser n'est pas nécessaire  
#### Exemple de config.json pour la synchro sur un 2eme drive:    

```{
    "core": {
        "dry_run": false,
        "rclone_binary_path": "/usr/bin/rclone",
        "rclone_config_path": "/root/.config/rclone/rclone.conf"
    },
    "hidden": {
        "/home/yohann/local/.unionfs-fuse": {
            "hidden_remotes": [
                "google"
            ]
        }
    },
    "notifications": {},
    "nzbget": {
        "enabled": false,
        "url": "https://user:password@nzbget.domain.com"
    },
    "plex": {
        "enabled": false,
        "max_streams_before_throttle": 1,
        "notifications": false,
        "poll_interval": 60,
        "rclone": {
            "throttle_speeds": {
                "0": "1000M",
                "1": "50M",
                "2": "40M",
                "3": "30M",
                "4": "20M",
                "5": "10M"
            },
            "url": "http://localhost:7949"
        },
        "token": "FXrhQE28zND-YDc",
        "url": "https://plex.domaine.com",
        "verbose_notifications": false
    },
    "remotes": {
        "google": {
            "hidden_remote": "google:/yohann",
            "rclone_command": "move",
            "rclone_excludes": [
                "**partial~",
                "**_HIDDEN~",
                ".unionfs/**",
                ".unionfs-fuse/**",
                ".fuse_hidden**",
                "rutorrent/**",
                "sabnzbd/**",
                "Unsorted/**"
            ],
            "rclone_extras": {
                "--checkers": 16,
                "--drive-chunk-size": "128M",
                "--low-level-retries": 2,
                "--retries": 1,
                "--skip-links": null,
                "--stats": "60s",
                "--transfers": 8,
                "--verbose": 1
            },
            "rclone_sleeps": {
                " 0/s,": {
                    "count": 16,
                    "sleep": 25,
                    "timeout": 62
                },
                "Failed to copy: googleapi: Error 403: User rate limit exceeded": {
                    "count": 10,
                    "sleep": 25,
                    "timeout": 7200
                }
            },
            "remove_empty_dir_depth": 2,
            "sync_remote": "google:/yohann",
            "upload_folder": "/home/yohann/local",
            "upload_remote": "google:/yohann"
        },

        "yohann": {
            "hidden_remote": "",
            "rclone_excludes": [],
            "rclone_extras": {},
            "rclone_sleeps": {},
            "remove_empty_dir_depth": 2,
            "sync_remote": "yohann:/yohann",
            "upload_folder": "",
            "upload_remote": ""
        }
    },
    "syncer": {
        "google2yohann": {
            "rclone_extras": {
                "--bwlimit": "70M",
                "--checkers": 16,
                "--drive-chunk-size": "64M",
                "--stats": "60s",
                "--transfers": 8,
                "--verbose": 1
            },
            "service": "local",
            "sync_from": "google",
            "sync_interval": 26,
            "sync_to": "yohann",
            "tool_path": "/usr/bin/rclone",
            "use_copy": true,
            "instance_destroy": false
          }
},
    "uploader": {
        "google": {
            "check_interval": 30,
            "exclude_open_files": false,
            "max_size_gb": 20,
            "opened_excludes": [
                "/rutorrent/"
            ],
            "service_account_path": "",
            "size_excludes": [
                "rutorrent/*"
            ]
        }
    }
}
```