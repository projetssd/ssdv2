---
layout: default
title: ssdv2
---
# Différences entre ajout, suppression et réinitialiser

## 1) Ajout application

- Permet de faire une installation complète d’application
- Permet d’appliquer les modifications faites sur le fichier .yml local (commencer par supprimer le container `docker rm -f appli`)

## 2) Suppression d’application

- Permet de supprimer le .yml local ainsi que les données sous `opt/seedbox/docker/${USER}` et les informations
d’authentification et de sous domaines dans le fichier account

## 3) Réinitialisation container

- Permet de restaurer le fichier .yml d’origine et d’appliquer les changements
pas de suppression des données utilisateurs ni des données contenu dans le fichier account

## 4) Relance container

- Permet d'arrêter/relancer un container sans suppression des parametres personnalisés. A utiliser si vous avez modifié le .yml d'origine de l'application.
pas de suppression des données utilisateurs ni des données contenu dans le fichier account

## Astuces

Il est possible d'utiliser des commandes rapide à la condition d'être dans le venv

``suppression_appli app`` : supprimes le container, les infos dans account et le yml local  
``suppression_appli app 1`` : supprimes le container, les infos dans account, le yml local ainsi que les données sous opt  
``launch_service app`` : installation de l'application demandé  