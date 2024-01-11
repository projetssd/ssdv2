---
layout: default
title: ssdv2
---
## Réglages Qbittorrent

Par défaut il faut utiliser comme identifant (admin/adminadmin)

### Chemin d'enregistrement des fichiers

source des données : /home/USER/local/qbittorrent/downloads/...

!! ATTENTION !!
Si vous utilisez un chemin spécifique (par exemple /home/user/local/qbittorrent), il faut penser à modifier la configuration de cloudplow/crop pour que le dossier ne soit pas pris en compte pour les uploads

> Depuis l'interface, il faut il faut utiliser le chemin complet `/home/USER/local/qbittorrent/downloads/...`  

On va commencer par sécuriser et mettre en Français l'interface 

#### Language   (Outils/Option/interface web)
![francais](https://user-images.githubusercontent.com/64525827/107520001-33f4d980-6bb1-11eb-8690-249c3723710c.png)

On peut changer ici le nom d'utilisateur et le mot de passe par défaut et aussi désactiver l'auth avec localhost
#### Authentification   (Outils/Option/interface web)
<img width="662" alt="auth qbittorrent" src="https://user-images.githubusercontent.com/64525827/149655235-21ce21aa-1b30-414d-8307-01ae51514dce.png">


#### Téléchargement   (Outils/Option/Téléchargements)
![enregistrement](https://user-images.githubusercontent.com/64525827/107518518-63a2e200-6baf-11eb-828b-2891a6c16588.png)


## Optimisations   


#### Réglages:   (Outils/Option/Avancé/Section libtorrent)
il faut désactiver l'utilisation du cache ainsi que d'autres changement (comparer avec l'image)

<img width="675" alt="reglage qbittorrent" src="https://user-images.githubusercontent.com/64525827/149655285-0102f79a-691d-4e9c-a213-4b9fc8a4de6c.png">


#### Connexions  (Outils/Option/Connexion)   
![connexions](https://user-images.githubusercontent.com/64525827/107518883-d2803b00-6baf-11eb-97da-bc94d2bc2baf.png)


#### Priorisation   (Outils/Option/BitTorrent)   

![priorisation](https://user-images.githubusercontent.com/64525827/107518996-f774ae00-6baf-11eb-9a90-31e456974b22.png)

### Ajout de Qbittorrent dans Radarr et Sonarr (Download client - Remote Path Mappings )

<img width="1171" alt="radarr et sonarr remote" src="https://user-images.githubusercontent.com/64525827/149655523-da7b2ce7-f9b5-400d-a334-f3d7579393e6.png">

> Attention il faut adapter le chemin selon vos réglages, perso j'utilise les catégories pour déplacer à la fin le contenu dans un dossier préci, aussi je préfère indiquer le chemin complet mais ça fonctionne aussi avec `/home/$USER/local` 



