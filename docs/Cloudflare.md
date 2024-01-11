---
layout: post
title: ssdv2
---
### Présentation
Plus que des services de CDN, les clients font confiance au réseau mondial de Cloudflare pour améliorer la sécurité, la performance et la fiabilité de tout ce qui est connecté à Internet.

Cloudflare est conçu pour être configuré facilement. Toute personne possédant un site web et un domaine personnel peut utiliser Cloudflare, indépendamment de son choix de plate-forme. Cloudflare ne requiert aucun critère matériel, logiciel ni changement de code particuliers.

> Voilà pour la présentation officiel

### Les étapes sont à réaliser dans l'ordre suivant :
* Créez un compte Cloudflare et ajoutez un site web
* Transférez la gestion des DNS à cloudflare
* Récupérer l'API global de cloudflare
* Passer le mode SSL/TLS sur type complet

### Étape 1. Créez un compte Cloudflare ou connectez vous.

Rendez-vous ici: [https://href.li/?https://dash.cloudflare.com/sign-up](https://dash.cloudflare.com/sign-up):

- Entrez votre adresse email et votre mot de passe

- Cliquez sur **Create Account** (Créer un compte)

- cliquer ensuite sur le bouton bleu ``ajouter un site``


Entrez le domaine racine pour votre site web puis cliquez sur **Add Site**. Par exemple, si votre site est www.exemple.com, entrez exemple.com.

Cloudflare tente d’identifier automatiquement vos enregistrements DNS. Cela prendra environ 60 secondes.

- Cliquez sur **Next** (Suivant).

- Choisissez un niveau d’offre, la gratuite, et cliquez sur **Confirmer l'offre**:

- Cliquez sur Continuer

- Copiez les 2 serveurs de noms Cloudflare affichés puis cliquez sur: **Terminé, vérifier les serveurs de noms**.

***

### Étape 2. Changer les serveurs de noms de votre domaine pour Cloudflare 

Dans cet exemple je vais utiliser OVH qui est relativement fréquent. 

Si vous avez un provider différent, nous vous invitons sur Discord afin de vous aiguiller.

On va se rendre sur la console d'administration d'OVH:

[https://href.li/?https://www.ovh.com/manager/web/#/configuration/domains](https://www.ovh.com/manager/web/#/configuration/domains)

Cliquez sur votre domaine et rendez-vous dans la partie: **Serveurs DNS**.

- Cliquez sur Modifier les serveurs DNS
- Indiquez les DNS copiés précédemment dans Cloudflare

- Cliquez sur **Appliquer la configuration** 

Maintenant il va falloir patienter un peu que la propagation des DNS se fassent (jusqu'à 24H).

##### Vous recevrez un email de confirmation.

***

### Étape 3. Récupérer L'API global Cloudflare

- Rendez-vous sur votre compte Clouflare et cliquez sur ``Aperçu`` sur le côté gauche de l'écran.

- En bas sur la droite ``Obtenir votre jeton d’API``

- Puis l'onglet ``jeton API``

- Cliquer sur ``affichage``en face de la ligne ``Global API Key``

- Récupérez votre jeton et **gardez le pour l'installation du script**

***

### Étape 4. Modification du mode de chiffrement SSL/TLS 

![Cloudflare - SSL:TLS](https://user-images.githubusercontent.com/64525827/105042745-e5966400-5a64-11eb-9dd9-aa4bed5bd8b7.png)

