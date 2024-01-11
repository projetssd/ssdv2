---
layout: post
title: ssdv2
---
#### Faire pointer son nom de domaine vers Wordpress


Par défaut votre installation sera installée en sous domaine: https://wordpres.ndd.tld

Il se peut que vous ayez envie/besoin d'avoir votre site qui pointe directement sur votre domaine: https://ndd.tld

Il suffi d'éditer le fichier **wordpress.yml** et de modifier les deux lignes comme dans le cadre noir:

`nano /opt/seedbox/conf/wordpress.yml`

![](https://nextcloud.teamsyno.com/s/eDd89bxJWjTkpFf/preview)

`traefik.frontend.rule: 'Host:{{domain.stdout}}'`

`traefik.frontend.headers.SSLHost: '{{domain.stdout}}'`

Une fois terminé, réinitialiser le conteneur et par mesure de précaution, vider le cache de votre explorateur.

Vous avez dorénavant accès à votre site directement par l'url de votre domaine et non en sous domaine.


&nbsp;


#### Augmenter la taille d'upload dans Wordpress (très) facilement

De base, la limitation de la taille d'upload peut poser un problème.

Voici comment y remédier:

* Commencer par éditer le .htaccess: `nano /opt/seedbox/docker/TON_USER/wordpress/.htaccess`
* Ajouter ces lignes: 

`php_value upload_max_filesize 128M`

`php_value post_max_size 128M`

`php_value max_execution_time 300`

`php_value max_input_time 300`

Cela ressemblera à ça une fois terminé:

![](https://nextcloud.teamsyno.com/s/Q3Y9dXe55bktf7z/preview)

Par principe de précaution toujours, vider le cache de votre explorateur et recharger la page sur votre domaine, à savoir, https://ndd.tld.