---
layout: default
title: ssdv2
---
## Création des remotes pour utiliser le stockage Google sur votre serveur.  

> ce guide est uniquement pour MacOS (autres version : [Pour Windows](Cr%C3%A9ation-remote-rclone-(Windows)) | [Pour Linux](Cr%C3%A9ation-remote-rclone-(Linux)))  

#### pré-requis 👍🏻 
1. Installation de Homebrew
2. Installation de rclone
3. Création d'un projet API Google drive (disponible [ici](Cr%C3%A9ation-API-Google))
4. Un navigateur en session privée connecté sur votre compte Google (celui avec le projet API Google)


### Installation de Homebrew

Rendez vous sur la page de [Homebrew](https://brew.sh/index_fr) pour copier/coller la commande d'installation  

<img width="821" alt="brew" src="https://user-images.githubusercontent.com/64525827/165914239-8aa4b0c1-2f84-4c41-b741-f8cfc55206e3.png">

### Installation de rclone

`brew install rclone`

## Pour la suite, vous devez avoir réalisé les étapes 3 et 4

### création du premier remote Gdrive

##### Connectez vous à votre serveur en ssh

- depuis votre shell, taper `rclone config` puis Enter
- Taper **n** for **New remote** puis Enter 
- Puis pour **name**, taper **teamdrive** par exemple 

<img width="245" alt="remote" src="https://user-images.githubusercontent.com/64525827/165921230-78874568-a36a-4747-b6d8-cc3b2e2ec650.png">


- Pour **Type of storage**, taper le **chiffre** correspondant à **Google Drive \ (drive)** 
   
- Pour **Google Application Client ID**, **coller le Client ID** correspondant à votre projet **drive** et appuyer sur Enter.  

- Pour **Google Application Client Secret**, **coller le Client Secret** et appuyer sur Enter.   

- Appuyer sur Enter   

- Pour **ID du dossier racine**, laissez **vide** et appuyez sur Enter   

- Pour **Chemin du fichier JSON**, laissez **vide** et appuyez sur Enter   

- Pour **Edit advanced config**, taper n appuyer sur Enter    

- Pour **Utiliser la configuration automatique?**, Tapez **y** puis appuyer sur Enter  

<img width="1081" alt="autoconfig" src="https://user-images.githubusercontent.com/64525827/165916281-69016e9d-835f-4032-8323-4fe2817ed34f.png">

- Copier la ligne **http://127.0.0.1:53682/auth?state=0vK_dA1aQDIOIryBIIGYaw** et coller dans votre **session privée**.  

![Quickstart](https://user-images.githubusercontent.com/64525827/165916532-55dbf3f8-b23b-442c-a440-32fab590bf8f.png)

- cliquer sur **autoriser** puis retourner sur votre shell  

- Pour "Configure this as a Shared Drive (Team Drive)?", taper **y** appuyer sur Enter  

<img width="463" alt="teamdrive" src="https://user-images.githubusercontent.com/64525827/165917258-092af5a8-bd1e-4e0e-8706-e109bee3603f.png">

- Pour **Choose a number from below**, taper le **numéro** correspondant à votre stockage puis Enter  

### taper **y** puis entrer pour valider la création du remote


***


## Création du remote crypt

- Taper **n** for **New remote** puis Enter 

- Écrire le **même nom** que le remote précédent puis _crypt (exemple : teamdrive_crypt)

- Taper le **numéro** correspondant à **Encrypt/Decrypt a remote \ (crypt)** puis enter

<img width="510" alt="remote" src="https://user-images.githubusercontent.com/64525827/165918249-9dac9604-ec2b-4f74-981c-cfd8323f2cf7.png">

- vous devez taper le **nom du remote** puis :Medias (exemple : teamdrive:Medias)

- Taper **1** puis continuer comme ci-dessous 

<img width="452" alt="encrypt" src="https://user-images.githubusercontent.com/64525827/165918546-ca1aa9c4-1056-4149-982e-62ece7ee58c1.png">

- Taper **1** puis continuer comme ci-dessous 

<img width="557" alt="option_directory" src="https://user-images.githubusercontent.com/64525827/165918699-a875a00a-2127-4218-ab61-a9746c4068bd.png">

- Pour "Option password." choisir **g**
- Pour "Password strength in bits." choisir **128**

<img width="525" alt="passowrd1" src="https://user-images.githubusercontent.com/64525827/165918864-e916b56d-c3a8-48b9-84ec-22c065b513c7.png">

- Puis taper **Enter**

- Pour "Option password2" choisir **g**
- Pour "Password strength in bits" choisir **128**

<img width="490" alt="password2" src="https://user-images.githubusercontent.com/64525827/165919231-721017ba-1a2d-440f-8d2f-aaa8fe7b2612.png">

- Puis taper **Enter**

- Pour **Edit advanced config?** choisir **n** puis enter

#### taper **y** puis enter pour valider la création du remote puis **q** pour quitter

- Taper **rclone config file** puis copier le chemin (exemple : /Users/kesurof/.config/rclone/rclone.conf)

- Taper la commande suivante `cat /Users/kesurof/.config/rclone/rclone.conf` 

## Copier le contenu et surtout conserver le précieusement à VIE !!!





