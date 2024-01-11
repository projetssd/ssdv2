---
layout: default
title: ssdv2
---
## la création du projet Google
Vous aurez besoin de ces éléments pour créer un Sharedrive

> ATTENTION : Vous devez être sur et certains de vous connecter au bon compte Google.
Si vous en avez plusieurs, connectez-vous alors en fenêtre de navigation privée !

* Rendez vous à l'adresse suivante et connectez vous avec votre compte Gsuite :  
[Google Apps Script API](https://href.li/?https://console.cloud.google.com/cloud-resource-manager)

* ### Cliquez sur Créer un projet
![creer_un_projet](https://user-images.githubusercontent.com/64525827/119948392-14839000-bf99-11eb-96a0-c7509bde74e9.png)  
<br><br>
* ### Entrer le nom du projet ``teamdrive`` puis cliquer sur Créer  
![creation_projet](https://user-images.githubusercontent.com/64525827/119948566-3f6de400-bf99-11eb-8ddf-ce61d54a76b4.png)  
<br><br>
* ### Dans la notification en haut à droite, cliquer sur "sélectionner un projet"  
![notification](https://user-images.githubusercontent.com/64525827/119949044-c28f3a00-bf99-11eb-8c9f-3342f6c0649e.png)  

## Activer une API Google Workspace
* sur la gauche Cliquez sur "API et Services" puis sur "Bibliothèque"
* Dans le champ de recherche, saisissez le nom de l'API "drive" 
* cliquer sur le résultat => Google Drive API  
<br><br>
### Cliquez sur Activer 
![google drive api](https://user-images.githubusercontent.com/64525827/119950056-c66f8c00-bf9a-11eb-8ea7-ba4670048a77.png)  


### Après l'installation cliquer sur "identifiants"  
![identifiant](https://user-images.githubusercontent.com/64525827/119950352-0a629100-bf9b-11eb-923c-fd49240cc6e0.png)
<br><br>
Dans la nouvelel fenetre, cliquer sur "Créer des identifiants" puis sur "ID client OAuth"
![creation_identifiant](https://user-images.githubusercontent.com/64525827/119950515-33832180-bf9b-11eb-9e12-14995ab54f3c.png)  
<br><br>
Il y a une étape intermédiaire, cliquer sur "Configurer l'écran d'autorisation"  
![configurer oauth](https://user-images.githubusercontent.com/64525827/119950915-af7d6980-bf9b-11eb-9d4a-f51a90294427.png)  
<br><br>
puis sélectionner "externe" et Créer  
![externe](https://user-images.githubusercontent.com/64525827/119951092-dc318100-bf9b-11eb-8fb2-79b59052fecf.png)
<br><br>
Dans la nouvelle fenêtre, remplissez les champs : 
* Nom de l'application => ``identique au nom du projet``
* Adresse e-mail d'assistance utilisateur => ``sélectionner celle du compte google``
* Coordonnées du développeur (Adresse email) => ``Entrer votre email``  

### Sur chaque étapes, cliqurer en bas sur enregistrer  
![etapes](https://user-images.githubusercontent.com/64525827/119951704-8a3d2b00-bf9c-11eb-9632-8c3698a45e5d.png)
<br><br>
Une fois terminé, cliquer à nouveau sur "Identifiants" sur la gauche de l'écran  
Puis :
* Créer des identifiants
* ID client OAuth
* Type d'application  => ``Application de bureau``
* Nom => ``identique au nom du projet``  
![noms](https://user-images.githubusercontent.com/64525827/119952103-ef911c00-bf9c-11eb-8303-9b3a6c7f95cf.png)  
<br><br>


* ### Copier sur un bloc note le CLIENT ID et le CLIENT SECRET  
![google-apps-script-api-client-id-et-secret](https://user-images.githubusercontent.com/64525827/105181463-1ee5d700-5b2c-11eb-85b1-55a14668ea34.jpeg)

### Vous aurez besoin par la suite de ces identifiants.  


Si vous avez fermer la fenêtre avec vos identifiants, vous pouvez les retrouver dans la rubrique identifiant de projet drive. [Dashboard API](https://href.li/?https://console.developers.google.com).  

![projets-google-api-identifiants](https://user-images.githubusercontent.com/64525827/105181488-2907d580-5b2c-11eb-9b8b-cc39e3e2ed04.jpg)
