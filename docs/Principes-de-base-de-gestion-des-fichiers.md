---
layout: default
title: ssdv2
---
## Principe de gestion des fichiers

### Généralités

Dans les exemples ci-dessous, nous allons imaginer que le [user] télécharge
un film de vacances qui fait 100 Mo, via Rutorrent. Son répertoire sera nommé /home/[user] 
L'architecture de fichier est la suivante :
- **/mnt/rclone/<user>** : le montage de rclone (chiffré sur cloud)
- **/home/[user]/local** : fichier local (disque dur local)
- **/home/[user]/Medias** : systeme de fichier mergerfs, fusion de /mnt/rclone/[user] et /home/[user]/local
- **/data/Films** : montage correspondant à **/home/[user]/Medias** (petite explication : Plex tourne en container, et le répertoire /data est mappé sur /home/[user]/Medias. Cela veut dire que le contenu du répertoire /data du container Plex est égal au contenu /home/[user]/Medias de son hôte. Chaque modification sur /data de plex impacte /home/[user]/Medias et inversement)

### Téléchargement du fichier

Rutorrent télécharge le fichier dans **/home/[user]/local/Rutorrent**. 100 Mo sont occupé sur le disque

Grace à mergerfs, le fichier est visible dans **/home/[user]/local/Rutorrent** et aussi dans **/home/[user]/Medias/Rutorrent**

### Traitement par Radarr (ou équivalent)

Radarr voit le fichier dans **/home/[user]/Medias/Rutorrent**. Il peut donc faire un "hard link" de **/home/[user]/Medias/Rutorrent/monfilm.mkv** vers **/home/[user]/Medias/Films/MonFilm/monfilm.mkv**

Il va ensuite "prévenir" autoscan (ou plex_autoscan) qu'il a traité un fichier à cet emplacement

#### Quel est l'intérêt de cette pratique ?
- cela ne prend qu'une fraction de seconde de faire un hard link, contrairement à une copie
- Plex est prévenu qu'il y a un "nouveau fichier" dans **/data/Films/MonFilm**, et peut analyser uniquement ce répertoire (et non pas toute la bibliothèque, et heureusement, car une grande partie de cette bibliothèque est distante, et provoquerait un grand nombre d'appel api)
- Même si le fichier est visible par le système à deux endroits différents, il ne prend qu'une fois l'espace disque. Seuls 100 Mo sont consommés

### Petite explication technique : c'est quoi un hard link ?

C'est quand le système attribue plusieurs entrées à sa table d'allocation pour un seul fichier.

Sous linux, le stockage d'un fichier est un représenté par un inode. Chaque fichier, chaque dossier a son propre inode. Dans le cas d'un hard link, plusieurs
entrée de la table d'allocation ont le même inode. Le système voit donc plusieurs fois le même fichier, mais en réalité, il n'est stocké qu'une seule fois.

Tant qu'on n'a pas effacé tous les fichiers pointant vers cet inode, les autres continuent d'exister et ne sont pas impactés. On peut en renommer un sans toucher aux autres (il parait que la formule ["ça m'en touche une sans faire bouger l'autre"](https://fr.wiktionary.org/wiki/cela_m%E2%80%99en_touche_une_sans_faire_bouger_l%E2%80%99autre) vient de là, comme quoi Chirac était un linuxien accompli). 

Les principales limitations du hardlink sont :
- on ne peut pas en faire sur un dossier ou sur un fichier spécial
- On ne peut pas faire de hardlink d'un fichier vers un autre filesystem (ou point de montage) que le fichier d'origine.

Du coup, on ne peut pas faire de hardlink de **/home/[user]/local/Rutorrent** vers ****/home/[user]/Medias/Films (puisque /home/[user]/Medias est un point de montage), mais on peut faire un hardlink de **/home/[user]/Medias/Rutorrent** vers **/home/[user]/Medias/Films**


### Et après ?

Le système voit deux fichiers distincts, même si en réalité c'est le même fichier (un seul stockage).
- un des deux fichiers (celui dans **/home/[user]/Medias/Rutorrent**)reste en seed aussi longtemps que l'on veut
- l'autre fichier est lisible par plex.

Ce dernier "fichier logique" va un jour être traité par cloudplow (ou crop) pour être envoyé sur le drive.
Concrètement, il va passer de **/home/[user]/local/Films (branche "locale" de Medias) à /mnt/rclone/[user]/Films** (branche "distante" de Medias).
En réalité, même s'il est physiquement déplacé, il reste visible par le système (et donc plex) dans **/data/Films** (car comme on l'a dit, le répertoire /data du container Plex est égal au /home/[user]/Medias)

Comme il n'a pas changé de place, Plex peut le lire sans avoir à l'analyser de nouveau

### Conclusion

Grace à ce système, le fichier ne prend jamais plus de place que son stockage réél. Il n'est jamais réellement copié.

On peut envoyer le fichier sur le drive tout en restant en seed sur Rutorrent, et on peut supprimer de Rutorrent sans toucher au fichier lisible par plex (qu'il soit local ou distant)