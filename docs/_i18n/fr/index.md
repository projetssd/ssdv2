# Kubeseed, c'est quoi ? 

Kubeseed est un projet de seedbox et autres outils tournant sur un moteur Kubernetes. L'implémentation qui a été choisie est [k3s](https://k3s.io/)

# Puis-je l'utiliser ?

Ce projet est destiné à simplifier l'installation et l'usage des outils nécessaires à une seedbox. Toutefois, l'utilisation de kubernetes n'est pas forcément simple.
Il est recommandé d'avoir des bases en administration système linux, et de ne pas avoir peur de mettre les mains dans le cambouis.

De plus, le projet est en cours de développement actif, et il y aura certainement des adaptations à faire au fil de l'eau.

Si vous cherchez un projet plus simple à utiliser, je recommande [ssdv2](https://github.com/projetssd/ssdv2) des mêmes auteurs, qui tourne en docker.

# Comment l'installer 

Vous avez besoin : 
- d'un serveur en debian 11 ou 12 fraîchement installé (Théoriquement compatible ubuntu 22.04 mais non testé)
- d'un nom de domaine

Non obligatoire mais conseillé : l'utilisation de cloudflare. Cela permet les enregistrements automatiques des sous domaines.

Si vous utilisez [rclone](https://rclone.org/), vous aurez besoin d'un rclone.conf déjà configuré.

A minima, les ports 80 et 443 doivent être accessibles. Certaines autres ports devront être accessibles selon les outils installés :
- 32400 pour plex
- 30000 pour rutorrent
- etc...

Avec ces outils, connectez vous avec un user qui a les droits sudo (pas en root !), puis : 

```
git clone https://github.com/projetssd/kubeseed.git
cd kubeseed
./seedbox.sh
```

et laissez vous guider...

## Installation avec kickstart et variables d'environnements.

### Variables d'environnement

Plusieurs variables d'environnement peuvent être déclarées avant installation, pour éviter des saisies manuelles. La liste des variables possibles se trouve dans le fichier ***kickstart.sample***

### Fichier kickstart

Vous pouvez aussi copier le fichier **kickstart.sample** en **kickstart**, modifier son contenu selon votre convenance, et il sera pris en compte lors de l'installation.

## Migration depuis ssdv2

Dans le cas ou vous faites une migration depuis ssdV2, [suivez ce guide](migration_ssdv2.html)