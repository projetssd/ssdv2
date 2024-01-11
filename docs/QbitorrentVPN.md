---
layout: default
title: ssdv2
---
> > Dépôt : https://hub.docker.com/r/dyonr/qbittorrentvpn

## Installation de Qbitorrent VPN

Variables d'environnement à remplir au moment de l'installation :

| Variable     | Required | Function                                                     | Example       | Default |
|--------------|----------|--------------------------------------------------------------|---------------|---------|
| VPN_ENABLED  | Yes      | Enable VPN (yes/no)?                                         | yes           | yes     |
| VPN_TYPE     | Yes      | WireGuard or OpenVPN (wireguard/openvpn)?                    | wireguard     | openvpn |
| VPN_USERNAME | No       |                                                              | username      |         |
| VPN_PASSWORD | No       |                                                              | password      |         |
| LAN_NETWORK  | Yes      | Réseaux locaux délimités par des virgules avec notation CIDR | 172.18.0.0/24 |         |

Attention -> pour le moment non fonctionnel avec wireguard.


## Réglages Qbitorrent

Par défaut il faut utiliser comme identifant (admin/adminadmin)

### Chemin d'enregistrement des fichiers

source des données : /home/user/local/qbitorrent/downloads/...

> Depuis l'interface, il faut commencer par downloads/...

On va commencer par sécuriser et mettre en Français l'interface 

#### Language   (Outils/Option/interface web)
![francais](https://user-images.githubusercontent.com/64525827/107520001-33f4d980-6bb1-11eb-8690-249c3723710c.png)

#### Authentification   (Outils/Option/interface web)
![auth](https://user-images.githubusercontent.com/64525827/107520003-348d7000-6bb1-11eb-9693-c6499659648d.png)


#### Téléchargement   (Outils/Option/Téléchargements)
![enregistrement](https://user-images.githubusercontent.com/64525827/107518518-63a2e200-6baf-11eb-828b-2891a6c16588.png)


## Optimisations   


#### Gestion du cache   (Outils/Option/Avancé/Section libtorrent)
il faut désactiver l'utilisation du cache 

![cache](https://user-images.githubusercontent.com/64525827/107519416-8aade380-6bb0-11eb-82bb-15065cacc821.png)


#### Connexions  (Outils/Option/Connexion)   
![connexions](https://user-images.githubusercontent.com/64525827/107518883-d2803b00-6baf-11eb-97da-bc94d2bc2baf.png)


#### Priorisation   (Outils/Option/BitTorrent)   

![priorisation](https://user-images.githubusercontent.com/64525827/107518996-f774ae00-6baf-11eb-9a90-31e456974b22.png)

