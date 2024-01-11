---
layout: default
title: ssdv2
---
## 1er Étape : la création d'un Groupe Google

Nécessaire uniquement pour le transfert d'un gdrive vers un sharedrive.

Rendez vous à l'adresse suivante et **connecté vous avec votre Gsuite** : [groups.google.com](https://groups.google.com/my-groups)

- Cliquer sur Créer un groupe

puis dans la nouvelle fenêtre :
- choisir le nom du groupe
- définir un préfixe d'email et ``sélectionner @mondomaine.tld``
- suivant puis suivant et enfin ``Créer un groupe``

<img width="542" alt="groupsgoogle" src="https://user-images.githubusercontent.com/64525827/95431227-26062200-094d-11eb-80eb-cc0226b4891a.png" style="max-width:100%;">

## 2eme Étape : création des comptes de service

Naviguer dans le menu du script :
- 3) Outils
- 5) Comptes de Service 
- 1) Création des SA avec sa-gen

Entrer pour continuer, Souhaitez-vous continuer ? [O/n] –> répondre O

Attendre la fin de l’installation jusqu’à : You must log in to continue. Would you like to log in (Y/n)? –> répondre Y

Copier le lien dans votre navigateur et connecter vous avec le compte sur lequel vous avez créer le @googlegroups.com

Puis entrer : - Le verification code - Sélectionner le nom du projet que vous avez créé en tapant le chiffre

- Le nom du groupe (cela va créer 2 projet API exemple account484- va créer account484-1 et account484-2)
- et le préfixe de l’email (cela va servir en tant que préfixe email SA exemple service498442)

> à partir de la, vous pouvez aller prendre un café et revenir plus tard. Pendant ce temps, Gen-SA va créer pour vous 200 Account service.

Attendez de voir ce message : */! COMPTES DE SERVICE INSTALLES AVEC SUCCES /!*

Une fois terminé on passe à l’étape suivante

## Ajouter les SA en tant que membre du Groupe Google

Récupérer le fichier allmembers.csv présent dans `/opt/sa`

Rendez vous à l’adresse suivante https://groups.google.com/my-groups

- Cliquer sur le groupe
- En bas à gauche “membres”
- puis en haut cliquer sur ajouter membres

Dans la fenêtre qui s’ouvre coller les 100 premieres adresse email présente dans le fichier allmembers.csv

et cliquer sur “Ajouter des membres”

## Cas d'un shared drive

Si vous utiliser un shared drive, il faut aller sur l'interface de google drive, faire un clic droit sur le shared drive, et aller dans "membres". De là, il faudra ajouter le groupe créé dans les membres du shared drive, sinon les uploads ne vont pas marcher
