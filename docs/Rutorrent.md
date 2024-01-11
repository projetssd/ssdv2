---
layout: default
title: ssdv2
---
## Séparation des Téléchargement terminés
> Vous devrez ensuite indiquer le chemin dans Radarr et Sonarr.

<img width="582" alt="Rutorrent" src="https://user-images.githubusercontent.com/64525827/105710575-998d6880-5f17-11eb-853c-ff649a4c7f20.png">


## Pour ceux qui auraient ponctuellement un core bloqué à 100% avec rutorrent

	docker exec rutorrent-user sh -c "curl --version"
	docker exec rutorrent-user sh -c "echo http://dl-cdn.alpinelinux.org/alpine/edge/main >> /etc/apk/repositories"
	docker exec rutorrent-user sh -c "apk update"
	docker exec rutorrent-user sh -c "apk add libcurl=7.65.0-r0"
	docker exec rutorrent-user sh -c "apk add curl=7.65.0-r0"
	docker exec rutorrent-user sh -c "curl --version"


D'une manière générale aller sur http://dl-cdn.alpinelinux.org/alpine/edge/main, chercher la version curl la plus récente, et remplacez la dans les lignes de commande ci dessus

## Commandes rtorrent-cleaner de @Magicalex

	rtorrent-cleaner report
	rtorrent-cleaner rm
	rtorrent-cleaner mv /data/old
	rtorrent-cleaner torrents
	rtorrent-cleaner --version
