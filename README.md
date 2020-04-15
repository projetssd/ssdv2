
[![](https://img.shields.io/github/repo-size/laster13/patxav.svg?style=flat)](https://github.com/laster13/patxav)

--- 
# Introduction

Mise à jour avec Ansible le 10/07/2019

# Pré-requis

1. Un serveur Ubuntu 18.04/Debian 10
2. Un nom de domaine
3. Connaissances en Linux
4. Connaissances en Docker
5. Un compte Google Drive si la seedbox est orienté PlexDrive

# Installation en root

1. Mise à jour des paquets :
```
apt update && apt upgrade -y
```

2. Installation de Git :
```
apt install git
```

3. Clonage du script : 

```
git clone https://github.com/laster13/patxav.git /opt/seedbox-compose
```

4. Pour rentrer là ou le script est installé :

```
cd /opt/seedbox-compose 
```

5. Lancer le script : 

```
./seedbox.sh
```
Ce script est proposé à des fins d'expérimentation uniquement, le téléchargement d’oeuvre copyrightées est illégal.
Merci de vous conformer à la législation en vigueur en fonction de vos pays respectifs en faisant vos tests sur des fichiers libres de droits
