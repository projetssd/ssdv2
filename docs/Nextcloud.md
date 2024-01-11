---
layout: post
title: ssdv2
---
## Comment installer & configurer Nextcloud

#### À propos de mariadb et la base de données

⚠️ TON_USER = VOTRE user, en minuscule ⚠️

⚠️ ndd.tld = VOTRE domaine, en minuscule ⚠️

⚠️ Commenter c'est ajouter un # en début de ligne afin que le fichier config n'en tienne pas compte ⚠️



Afin d’éviter des erreurs ultérieures et d’optimiser votre installation, il vaut mieux opter pour une installation avec Mariadb et non SQLite !

Voici les informations nécessaires pour une installation avec Mariadb :

![505-828-max](https://user-images.githubusercontent.com/64525827/105355834-f2e15900-5bf2-11eb-9d55-19d4eb658830.jpg)

* Login: choisissez le vôtre et laissez toto tranquille :0)
* Password: choisissez un password **fort**!
* Répertoires des données : `/data `
* Utilisateur de la base de données : `nextcloud`
* Mot de passe de la base de données : `nextcloud`
* Nom de la base de données : `nextcloud`
* Hôte de la base de données : `db-nextcloud`

Clquer sur **Installer**, libre à vous de laisser coché les applications conseillées. Il est toujours possible de les installer par après.

#### Pensez à mettre votre Nextcloud à jour avant toute autre opération!! 
#### Ce tuto est valable pour la dernière version: 20.0.4


### Régler les alertes de sécurité

Après l’installation de Nextcloud il est nécessaire de régler les alertes de sécurité présentes dans : 

Paramètres / Vue d’ensemble / Avertissements de sécurité & configuration

https://nextcloud.ndd.tld/settings/admin/overview

![1582-500-max](https://user-images.githubusercontent.com/64525827/105355836-f379ef80-5bf2-11eb-95a0-1a166d368729.jpg)



Pour l’alerte: 
« L'en-tête HTTP "Strict-Transport-Security" n'est pas configurée à au moins "15552000" secondes. Pour renforcer la sécurité, nous recommandons d'activer HSTS comme décrit dans nos conseils de sécurisation ↗. »

`nano /opt/seedbox/docker/TON_USER/nextcloud/conf/nginx/site-confs/default`

Ajouter cette ligne : 
`add_header Strict-Transport-Security "max-age=63072000; includeSubdomains; preload";`

Comme ceci (par exemple):

![769-132-max](https://user-images.githubusercontent.com/64525827/105355840-f4128600-5bf2-11eb-8e64-a454f0ac9b9c.jpg)

Sauver le fchier édité.

On relance Nextcloud et sa base de données en faisant: 

`docker restart nextcloud db-nextcloud`



Pour l'alerte: La base de données a quelques index manquants. L'ajout d'index dans de grandes tables peut prendre un certain temps. Elles ne sont donc pas ajoutées automatiquement.

`docker exec -ti nextcloud bash`

`occ db:add-missing-indices`



Pour l'alerte: Certaines colonnes de la base de données n'ont pas été converties en big int. Changer le type de colonne dans de grandes tables peu prendre beaucoup de temps, elles n'ont donc pas été converties automatiquement. 

`docker exec -ti nextcloud bash`

`occ db:convert-filecache-bigint` Valider 

Following columns will be updated:

* federated_reshares.share_id
* share_external.id
* share_external.parent

This can take up to hours, depending on the number of files in your instance!
Continue with the conversion (y/n)? Choisir y, bien entendu!

Vous obtenez à nouveau votre **V** vert sacré ;)

![1575-187-max](https://user-images.githubusercontent.com/64525827/105355841-f4128600-5bf2-11eb-97c6-80a48fb09b02.jpg)

Pour l'alerte: 
> Votre installation n’a pas de préfixe de région par défaut. C’est nécessaire pour valider les numéros de téléphone dans les paramètres du profil sans code pays. Pour autoriser les numéros sans code pays, veuillez ajouter "default_phone_region" avec le code ISO 3166-1 respectif de la région dans votre fichier de configuration.

Il faut modifier le fichier config.php :
``` 
nano /opt/seedbox/docker/TON_USER/nextcloud/conf/www/nextcloud/config/config.php
``` 
ajouter à la derniere ligne 
``` 
'default_phoneregion' => 'FR',
``` 
exemple:
``` 
  'dbhost' => 'XXX',
  'dbport' => '',
  'dbtableprefix' => 'oc',
  'mysql.utf8mb4' => true,
  'dbuser' => 'XXX',
  'dbpassword' => 'XXX',
  'installed' => true,
  'default_phone_region' => 'FR',
``` 
Sauver le fchier édité.

On relance Nextcloud et sa base de données en faisant:

``` 
docker restart nextcloud db-nextcloud
``` 

### Ajouter un mode sombre à Nextcloud


Probablement l'application la plus suivie et la plus sympa pour un thème sombre.

https://apps.nextcloud.com/apps/breezedark


Cela fonctionne comme n'importe quelle autre application du magasin Nextcloud.

Voici un aperçu:

![screenshot](https://user-images.githubusercontent.com/64525827/105355843-f4ab1c80-5bf2-11eb-9c2c-f94ab3a3221c.png)

Dans la partie application de Nextcloud il vous suffira d'entrer **dark** comme mot-clé et l'installer.

Videz bien le cache et reload la page pour constater les effets!




### Monter le home dans Nextcloud

https://mondedie.fr/d/10779-docker-monter-le-home-dans-nextcloud

### Monter le home dans Nextcloud sans modifier de fichiers

C'est très simple, il suffi de vous rendre dans la partie **Applications** de votre installation Nextcloud.
De rechercher l'application **External storage support** et de l'installer.

Une fois installée, rendez-vous dans **Paramètres** puis dans la colonne de gauche dans **Stockages externes**:

Maintenant remplissez les paramètres demandés:

* Un nom de dossier: à votre convenance 
* Dans stockage externe: choisir... local :)
* Authentification: aucun
* Configuration: il faudra ici renseigner le chemin qui mène à votre home.

_Pour ceux qui utilisent Gdrive: /home/**TON_USER**/Medias/_

_Pour ceux qui n'utilisent **PAS** Gdrive: /home/**TON_USER**/local/_
* Disponible pour: à vous de voir, si non laisser par défaut s'il n'y a pas de restrictions

Pour que vous puissiez partager vos fichiers et/ou dossiers, veilliez à cliquer sur les **...**	comme indiqué sur le screenshot et cliquer sur **Permettre le partage**

Vérifier qu'un **V** vert soit présent comme sur le screenshot, vous avez fini!





### La double authentification | 2fa

Augmenter la sécurité de votre compte avec la double authentification (two-factor authentication ou encore 2fa)!

![](https://raw.githubusercontent.com/nextcloud/twofactor_totp/dd1e48deec73a250886f35f3924186f5357f4c5f/screenshots/enter_challenge.png)

Rendez-vous dans la partie Applications de votre Nextcloud.

Rechercher et installer: **Two-Factor TOTP Provider**
Se rendre dans **Paramètres**
Choisir **Sécurité** en haut à gauche ( https://ndd.tld/settings/user/security)

Il suffira à cette étape de lancer votre application préférée pour la double authentification et de scanner le QR Code.
Dans ce cas nous allons utiliser Google Authenticator, disponible ici: https://play.google.com/store/apps/details?id=com.google.android.apps.authenticator2&hl=fr

Maintenant que l'application est lancée, vous devriez voir ça:

Cliquer sur **Commencer**
Sélectionner **Scanner un code-barres**

Votre compte est ajouté! 

N'oubliez pas de rentrer le code renvoyé par Google Authenticator dans Nextcloud pour **vérifier** le tout:


***
# Nextcloud avec Talk
***


On commence par mettre à jour le script:

`cd /opt/seedbox-compose/`

`git pull` 


On installe Nextcloud:

`cd /opt/seedbox-compose/`

`./seedbox.sh`

Choisir l'option 2, ensuite l'option 1. Sélectionner Nextcloud dans la liste des applications avec la barre **Espace**, grâce à la touche TAB(ulation) de votre clavier, sélectionner **OK** et valider.


Rendez-vous dans Nextcloud et télécharger **Talk** dans la partie applications:

https://nextcloud.ndd.tld/settings/apps et taper dans recherche "**Talk**".


Une fois installé il faut se rendre à cette adresse, qui correspond à **Paramètres** / **Discussion** (en bas à gauche):

https://nextcloud.ndd.tld/settings/admin/talk

Remplissez les informations comme indiqué sur le screenshot:

* **Serveurs STUN**: l'IP de votre serveur suivi du port :3478
* **Serveurs TURN**: l'IP de votre serveur suivi du port :3478
* **Secret**: indiquer le code qui se trouve après **static-auth-secret** dans votre fichier turnserver.conf:

`nano /opt/seedbox/docker/VOTRE_USER/coturn/turnserver.conf`  

**Important**  
Penser à ouvrir le port 3478 dans iptables  

C'est fini, Talk est maintenant fonctionnel.


***
# Nextcloud avec Collabora
***

![](https://nextcloud.teamsyno.com/s/xmkMexGHMoxJkop/preview)

## Vous avez déjà Nextcloud d'installé avec le script (sans pertes de données)

On commence par mettre à jour le script:

`cd /opt/seedbox-compose/`

`git pull` 


&nbsp;


Maintenant on va copier le fichier nextcloud.yml:

`cp /opt/seedbox-compose/includes/dockerapps/nextcloud.yml /opt/seedbox/conf`


&nbsp;



On réinitialise Nextcloud:

`cd /opt/seedbox-compose/`

`./seedbox.sh`

Choisir l'option 2, ensuite l'option 3. Sélectionner Nextcloud dans la liste des applications avec la barre **Espace**, grâce à la touche TAB(ulation) de votre clavier, sélectionner **OK** et valider.


&nbsp;



Rendez-vous dans Nextcloud et télécharger **Collabora** dans la partie applications:

https://nextcloud.ndd.tld/settings/apps

Une fois installée, rendez-vous dans la partie configuration de **Collabora**:

https://nextcloud.ndd.tld/settings/admin/richdocuments

![](https://nextcloud.teamsyno.com/s/QeD2qzCBm5xXrM4/preview)

Indiquez comme indiqué sur le screenshot votre sous domaine: https://collabora.ndd.tld et valider par **Apply**.

## Vous n'avez pas encore Nextcloud d'installé



On commence par mettre à jour le script:

```cd /opt/seedbox-compose/ && git pull```


On installe Nextcloud:

```cd /opt/seedbox-compose/ && ./seedbox.sh```


Choisir l'option 2, ensuite l'option 1. Sélectionner Nextcloud dans la liste des applications avec la barre **Espace**, grâce à la touche TAB(tabulation) de votre clavier, sélectionner **OK** et valider.


Rendez-vous dans Nextcloud et télécharger **Collabora** dans la partie applications:

https://nextcloud.ndd.tld/settings/apps

Une fois installée, rendez-vous dans la partie configuration de **Collabora**:

https://nextcloud.ndd.tld/settings/admin/richdocuments

Indiquez comme indiqué sur le screenshot votre sous domaine: https://collabora.ndd.tld et valider par **Apply**.


### Unauthorized WOPI host

Il se peut que vous ayez un jour une erreur de ce type: "Unauthorized WOPI host".

Afin de régler cela, suivez cette procédure:

* Sortir le fichier: `docker cp collabora:/etc/loolwsd/loolwsd.xml /opt/loolwsd.xml`
* Ensuite éditez le fichier loolwsd.xml: `nano /opt/loolwsd.xml`

Mettez à jour la balise **storage** en ajoutant deux lignes, l'une pour l'IP de votre serveur, l'autre pour le domaine de votre instance Nextcloud :

```<host desc="Regex pattern of hostname to allow or deny." allow="true">1\.2\.3\.4</host>```

```<host desc="Regex pattern of hostname to allow or deny." allow="true">nextcloud.votredomaine.tld</host>```

* Réinjecter le fichier loolwsd.xl: ```docker cp /opt/loolwsd.xml collabora:/etc/loolwsd/loolwsd.xml```

C'est fini et fonctionnel :)
