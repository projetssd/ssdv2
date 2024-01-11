---
layout: default
title: ssdv2
---
#### Qu'est-ce qu'Organizr?

Organizr vous permet de configurer des «onglets» qui seront tous chargés dans une seule page Web. 
Vous pouvez ensuite travailler sur votre serveur en toute simplicité et passer d'un service à l'autre très facilement!
C'est aussi ce que l'on nomme, un dashboard.

#### Petite parenthèse sur l'authentification 

Organizr possède sa propre page d'authentification, vous pouvez très bien désactiver l'Auth (la fenêtre ou vous devez entrer votre user et mdp créé pendant le script) si vous avez des comptes utilisateurs afin de ne pas divulguer votre compte administrateur. Voici la marche à suivre:

`nano /opt/seedbox/conf/organizr.yml`





On commente ces 4 lignes en ajoutant un # devant les lignes en question:

`#traefik.frontend.auth.basic: '{{ passwd.stdout if (not oauth_client.stat.exists) | default(false) else omit }}'`

`#traefik.frontend.auth.forward.address: 'http://oauth:4181'`

`#traefik.frontend.auth.forward.authResponseHeaders: 'X-Forwarded-User'`

`#traefik.frontend.auth.forward.trustForwardHeader: 'true'`





Une fois que c’est fait il faut réinitialiser le conteneur de la manière suivante pour valider tous les changements effectués :

`cd /opt/seedbox-compose/`

`./seedbox.sh`

Choisir l’option 2 ( Ajout/Suppression d’Applis )

Choisir l’option 3 ( Réinitialisation Container )

Choisir Organizr et valider par OK





#### À quoi peut ressembler Organizr une fois configuré et installé?

Tout dépend évidemment de la façon dont vous allez configurer votre dashboard, voici un exemple:

![](https://user-images.githubusercontent.com/16184466/53615856-35cc5a80-3b9d-11e9-8428-1f2ae05da2c9.png)

C'est une présentation classique d'Organizr. Il est possible d'inclure Grafana à la homepage. C'est [le sujet de ce tutoriel](Varken-Grafana-Influxdb).

Vous obtiendrez alors un mélange d'Organizr & Grafana:

![](https://nextcloud.teamsyno.com/s/HrTfHFBnpJWQnZk/preview)





#### Configurer Organizr: Partie 1

Vous arrivez sur cette page (https://organizr.ndd.tld), et vous devez choisir votre type d'installation. 

Il y a deux types d'installations:

![](https://nextcloud.teamsyno.com/s/yDJqT7QNJsznRzP/preview)

**Personnel** ou **Professionnel**

**Personnel** ne cache rien — sans restrictions

**Professionnel** cache des éléments média [Plex, Emby, etc.]

Choisir ce qui vous correspond et suivant vos besoins. 

Cliquer sur **next**.






**Infos de l'administrateur.**

![](https://nextcloud.teamsyno.com/s/KRFBgmDxw8YJFJ7/preview)

Indiquer votre **nom d'utilisateur**: ici: **Marcel**

Indiquer votre **email**: D'ailleurs à ce propos, il est conseillé d'utiliser celui lié à votre compte Emby ou Plex. 

Indiquer **votre mot de passe**: De préférence un mot de passe fort. [Vous pouvez en créer un ici!](https://www.motdepasse.xyz/)

Cliquer sur **Next**.






**Création de l'administrateur**

![](https://nextcloud.teamsyno.com/s/nCzafGiRXweDWQn/preview)

**Clé de hachage**: entre 2 et 30 caractères. Mettons 30 caractères, précisément. Le cadre doit-être vert, si vous dépassez les 30 caractères, il sera rouge, il faudra effacer les caractères en trop.

**Mot de passe de l'inscription**: remettre le même mot de passe créé à l'étape précédente.

**Clé API**: c'est déjà rempli, vous pouvez passer à l'étape suivante.

Cliquer sur **Next**






**Création de l'administrateur, seconde partie**

![](https://nextcloud.teamsyno.com/s/RX6GdQ4Bsr2wwyF/preview)

**Nom de la base de données**: choisisir un nom de base de données.

**Emplacement de la base de données**: comme indiqué sur le screenshot, il faut placer la base de données hors de la racine du dossier web. Vous pouvez copier/coller le premier exemple `/config/www/db`.

Cliquer sur **Test/Create Path**, vous devez avoir le message annonçant **Path is good to go**. 

On va à la page suivante en cliquant sur **Next**.





**Création de l'administrateur, troisième partie**

![](https://nextcloud.teamsyno.com/s/XSEKKtxqPpBnStx/preview)

Maintenant vous pouvez cliquer sur **Finish**!






Vous voilà sur la page d'authentification d'Organizr, suivant que vous ayez désactivé l'Auth ou pas, il faudra au préalable entrer vos identifiants créé lors du script si elle n'est pas désactivée.

![](https://nextcloud.teamsyno.com/s/9nwXYdtyyzzGJCn/preview)

Une fois que vous avez entré votre login et password, on clic sur **Connexion**.





Vous arrivez sur la page générale des **Paramètres d'Organizr**. C'est ici que tout commence réellement. 

![](https://nextcloud.teamsyno.com/s/8GdZereG9m8RnzT/preview)





#### Configurer Organizr: Partie 2

Vu les nombreuses possibilités qu'offrent Organizr, nous allons parcourir les bases pour que vous ayez un bon dashboard fonctionnel et nous vous invitons à nous rejoindre sur [Discord](https://discord.gg/v5dZHB5) si vous avez d'autres questions qui ne seront pas forcément abordées ici.

Par contre, le fait de suivre ces étapes vont vous familiariser avec l'interface qui n'est pas très compliquée et vous prendrez très vite la main :)





#### Créer des onglets

Certainement l'un des paramètres les plus importants d'Organizr! 

C'est grâce aux onglets que vous pourrez afficher les icônes des services correspondants.

**Je vous invite à activer Homepage avant toute chose** :)

![](https://nextcloud.teamsyno.com/s/ojcDJYa8JaPjpym/preview)





Dans la partie **Éditeurs d'onglets**, cliquer sur ![](https://nextcloud.teamsyno.com/s/jztJFy2dmXrzKwt/preview)

![](https://nextcloud.teamsyno.com/s/CJjtSsz8qa7MYHY/preview)





On va ajouter l'onglet ruTorrent par exemple.

![](https://nextcloud.teamsyno.com/s/rxA3SmmEc9p65yN/preview)

**Nom de l'onglet**: **ruTorrent** ou comme bon vous semble

**URL de l'onglet**: indiquer l'url de votre ruTorrent sous la forme https://rutorrent.ndd.tld

**Choisir l'image**: soit vous tapez dans la recherche rutorrent ou vous collez ceci directement dans **Image de l'onglet**:

 `plugins/images/tabs/rutorrent.png`

Valider par **Ajouter un onglet**.





Recharger votre page en faisant **F5**, vous pouvez constater l'apparition de votre premier onglet ruTorrent sur le côté gauche de votre Organizr. Bien joué!

![](https://nextcloud.teamsyno.com/s/icPzxfcMX9YMkTm/preview)




Ajoutons maintenant Plex!

On va ajouter l'onglet Plex de la même manière que ruTorrent. 

Dans la partie **Éditeurs d'onglets**, cliquer sur ![](https://nextcloud.teamsyno.com/s/jztJFy2dmXrzKwt/preview)

![](https://nextcloud.teamsyno.com/s/xep3rL4pNCpzTbp/preview)

**Nom de l'onglet**: **Plex** ou comme bon vous semble

**URL de l'onglet**: indiquer l'url de Plex sous la forme https://plex.ndd.tld

**Choisir l'image**: soit vous tapez dans la recherche **Plex** ou vous collez ceci directement dans **Image de l'onglet**:

`plugins/images/tabs/plex.png`

Valider par **Ajouter un onglet**.

Recharger votre page en faisant F5, vous pouvez constater l'apparition de votre second onglet **Plex** sur le côté gauche de votre Organizr. Yeah! 

Vous pouvez maintenant ajouter des onglets à votre guise, le principe étant toujours le même.


#### Organiser les onglets



Il est possible d'organiser l'ordre de vos onglets. 

![](https://nextcloud.teamsyno.com/s/dP2Rg4TbptMkKoi/preview)

En passant votre souris sur l'icône, vous allez voir trois petites lignes ![](https://nextcloud.teamsyno.com/s/mcATj2MCsM8yrsY/preview), saisissez l'onglet en maintenant appuyé le clic gauche de votre souris, montez ou descendez votre onglet.




#### Personnalisation

Comme tout bon dashboard qui se respecte, il y a moyen de personnaliser l'interface.

Voici la partie personnalisation:

![](https://nextcloud.teamsyno.com/s/E8ey8x3J3xsJaPE/preview)

**Top Bar**

Cette catégorie permet de modifier 3 éléments.

* **Logo**: permet de changer le logo Organizr OU laisser le titre ORGANIZR V2 (que vous pouvez modifier bien entendu, c'est l'étape d'après). 

Pour utiliser un logo à la place du titre il suffi de cocher **Utiliser le logo à la place du titre**.

* **Titre**: par défaut ORGANIZR V2, adaptez suivant vos besoins.
* **Meta Description**: le descriptif de cette partie informe que: Used to set the description for SEO meta tags.

Pour faire plus simple:

> L’optimisation pour les moteurs de recherche, appelé aussi SEO (de l’anglais Search Engine Optimization) est un ensemble de techniques visant à favoriser la compréhension de la thématique et du contenu d’une ou de l’ensemble des pages d’un site web par les moteurs de recherche». 




Dans cet exemple, nous allons personnaliser le dashboard avec un petit logo de **Script Seedbox Docker**.

Dans la partie **Logo** vous coller l'url de l'image souhaitée, cochez **Utiliser le logo à la place du titre** et on valide par **Enregistrer**:

![](https://nextcloud.teamsyno.com/s/2NGJ9RBB4MWem6r/preview)

Prenez soin de rafraîchir la page pour voir le logo apparaître dans le coin supérieur gauche.



Si vous voulez changer l'arrière plan de la page de connexion, toujours dans **Personnaliser**, partie **LoginPage**:

![](https://nextcloud.teamsyno.com/s/qzby3ePFnwBPwDD/preview)



Vous collez l'URL de votre image dans la partie **Arrière-plan de connexion**. Quand c'est fait, on se déconnecte de sa session Organizr et on admire le résultat.

![](https://nextcloud.teamsyno.com/s/Q2bJBWYHnWJtgND/preview)




Afficher les requêtes Ombi sur la Homepage d'Organizr:

![](https://nextcloud.teamsyno.com/s/aBEfJkPCP8kFDzA/preview)





Se rendre sur Ombi: https://ombi.ndd.tld/Settings/Ombi

On récupère l'**Api Key**:

![](https://nextcloud.teamsyno.com/s/Q7CR72Qny32jpam/preview)




On retourne sur Organizr: **Settings**, **Éditeurs d'onglets**, **Éléments de la page d'accueil**, on clic sur Ombi.

![](https://nextcloud.teamsyno.com/s/fiJ5FYYBbi2ie2D/preview)

On commence par cocher **Activer** dans le premier onglet.





Dans **Connexion** vous mettez l'URL de votre Ombi et coller l'API KEY précédemment copiée.

![](https://nextcloud.teamsyno.com/s/rsgscHqgjkXR4s2/preview)





Rendez-vous maintenant dans la partie Default Filter et vous cochez suivant vos besoins:

![](https://nextcloud.teamsyno.com/s/gJW72o7AaJz8dHd/preview)



Il ne reste plus qu'à enregistrer le tout et d'aller dans le dernier onglet, **Test Connection**, vérifier que tout fonctionne bien. 

Votre Homepage affiche maintenant les requêtes Ombi:

![](https://nextcloud.teamsyno.com/s/NBAwHcQjaGGWPKm/preview)


***
> ### Pour aller encore plus loin avec Oganizr, suivez ce tuto [Varken-Grafana-Influxdb](Varken-Grafana-Influxdb)

***
