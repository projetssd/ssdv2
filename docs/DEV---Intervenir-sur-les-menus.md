---
layout: default
title: ssdv2
---
## Principes de base

Les menus sont stockés dans une base sqlite3 à la racine du projet (fichier menu), qui comprend une seule table (menu)

### Structure de la table 

```
CREATE TABLE menu 
(id integer primary key AUTOINCREMENT,
texte text,
parent_id integer,
ordre integer,
action text);
```

## Voir les menus existants

Une fois l'environnement, chargé, utiliser la fonction debug_menu

```
(venv) seed@seedop:/opt/seedbox-compose$ debug_menu 
 ==> 1-1) Ajout/Suppression d'applis | 
 ==>  ==> 3-1) Ajout d'application | 
 ==>  ==>  ==> 13-1) Applications Seedbox | ajout_app_seedbox
 ==>  ==>  ==> 14-2) Autres Applications | ajout_app_autres
 ==>  ==> 4-2) Suppression d'application | menu_suppression_application
 ==>  ==> 5-3) Réinitialisation container | menu_reinit_container
 ==> 2-2) Gestion | 
 ==>  ==> 6-1) Sécurisation système | 
 ==>  ==>  ==> 15-1) Sécuriser Traefik avec Google OAuth2 | menu_secu_system_oauth2
 ==>  ==>  ==> 16-2) Sécuriser avec Authentification Classique | menu_secu_system_auth_classique
 ==>  ==>  ==> 17-3) Ajout / Supression adresses mail autorisées pour Google OAuth2 | menu_secu_system_ajout_adresse_oauth2
 ==>  ==>  ==> 18-4) Modification port SSH, mise à jour fail2ban, installation Iptables | menu_secu_systeme_iptables
[ ... ]
 ==>  ==> 12-7) Installation Rclone vfs && Plexdrive | 
 ==>  ==>  ==> 52-1) Installation rclone vfs | menu_install_rclone_vfs
 ==>  ==>  ==> 53-2) Installation plexdrive | menu_install_plexdrive
 ==>  ==>  ==> 54-3) Installation plexdrive + rclone vfs | menu_install_vfs_plexdrive
```

Le premier chiffre est l'id du menu, le second son ordre. 

## Insertion d'un nouveau menu

Première étape, repérer l'id du parent grace à la fonction debug_menu (voir ci-dessus)

Entrer en sql

```
sqlite3 menu
```

Puis
```
insert into menu (texte,parent_id,ordre,action) values ('<nom menu>',<parent_id>,<ordre>,'<fonction>');
```
Avec
- nom menu: le nom qui sera affiché. Si le nom contient des apostrophes, il faut les doubler. Exemple : ajout d''application
- parent_id: l'id du parent (si menu racine, il faut mettre NULL)
- ordre: ordre d'affichage dans le menu
- fonction (optionnel): nom de la fonction qui sera exécutée quand on choisira ce menu. Si pas de fonction,  mettre NULL

La fonction peut être soit un script, soit une fonction définie dans functions.sh ou menu.sh

Une fois fait, ne pas oublier de commiter le fichier menu pour le pousser sur le git.

## Edition d'un menu existant

```
update menu set texte='<nom menu>',parent_id=<parent_id>,ordre=<ordre>,action='<fonction>' where id = <id>;
```

Une fois fait, ne pas oublier de commiter le fichier menu pour le pousser sur le git.

