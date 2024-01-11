---
layout: default
title: ssdv2
---
**1. SSL/TLS Options**  
<br>
Activer **Full SSL mode**  
<br>
![68747470733a2f2f77696b692e73637269707473656564626f78646f636b65722e636f6d2f75706c6f6164732f696d616765732f67616c6c6572792f323032302d31312f7363616c65642d313638302d2f73736c2d746c732e706e67](https://user-images.githubusercontent.com/64525827/105626452-ebf35a00-5e2f-11eb-991f-a491e98fd1b5.png)
 
### Puis dans l'onglet Certificats de périphérie  

![](https://user-images.githubusercontent.com/64525827/105626484-3543a980-5e30-11eb-8d2d-37657b581a0a.png)
 
Always Use HTTPS: **ON**  ==> Redirige automatiquement toutes les demandes http vers https.  

HTTP Strict Transport Security (HSTS): **Enable**  
(Attention). HSTS améliore le niveau de sécurité. Cependant activez cette option avec précaution. Tout problème / changement de certificat (par exemple, la suspension de Cloudflare) peut vous empêcher d'accéder à vos services (vous pouvez toujours y accéder localement avec IP: port). Je recommande donc de ne l'activer qu'après vérification que tout fonctionne parfaitement.   
<br>
Minimum TLS Version: **1.2**  
Seules les connexions avec la version TLS 1.2 ou ultérieure seront autorisées pour une sécurité améliorée.  
<br>
Opportunistic Encryption: **ON**  
Le chiffrement opportuniste permet aux navigateurs de bénéficier des performances améliorées de HTTP / 2 en leur faisant savoir que votre site est disponible via une connexion chiffrée.  
<br>
TLS 1.3: **ON**  
TLS 1.3 est la version la plus récente, la plus rapide et la plus sécurisée du protocole TLS. Activez-le.  
<br>
Automatic HTTPS Rewrites: **ON**  
Cette option corrige l'avertissement de contenu mixte des navigateurs en réécrivant automatiquement les requêtes HTTP en HTTPS.  
<br>
Certificate Transparency Monitoring: **ON**  
Cloudflare envoie un e-mail lorsqu'une autorité de certification émet un certificat pour votre domaine. Ainsi, lorsque votre certificat LetsEncrypt est renouvelé, vous recevrez un email.  
<br>
**2. Firewall**  
<br>
**Firewall Rules**  
Sous Règles de pare-feu, le plan gratuit vous permet de créer jusqu'à 5 règles.

En utilisant cette fonction, vous pouvez bloquer certains types de trafic. Par exemple, je bloque toutes les demandes en provenance de Chine. Vous pouvez également choisir d'autoriser l'accès uniquement à partir des pays dont vous savez que vous accéderez à vos applications et de bloquer le reste.  
<br>
![cloudflare-firewall-rules-740x335](https://user-images.githubusercontent.com/64525827/105626846-f5ca8c80-5e32-11eb-94a7-663d277006a4.png)


#### Firewall Tools
Vous pouvez également utiliser la section Outils pour mettre en place certains blocs ou autorisations. Vous pouvez même définir une règle pour le trafic entrant.

Dans l'exemple ci-dessous, je mets en liste blanche le trafic provenant de l'adresse IP WAN de mon domicile afin que toutes les demandes provenant de mon adresse IP domestique soient autorisées et non bloquées ou contestées.  

![cloudflare_ip_whitelist-740x309](https://user-images.githubusercontent.com/64525827/105626853-febb5e00-5e32-11eb-8322-8bb965180b13.png)


#### Firewall Settings

#### Security Level: **High**  
Blocage de tous les visiteurs qui ont montré un comportement menaçant au cours des 14 derniers jours.  

* Bot Fight Mode: **ON**  
Gestion des demandes correspondantes aux modèles de bots connus avant qu'ils ne puissent accéder à votre site.  

* Challenge Passage: **30 Minutes**  
Spécifiez la durée pendant laquelle un visiteur, qui a réussi un Captcha ou JavaScript, peut accéder à votre site Web.  

* Browser Integrity Check: **ON**  
Évaluez les en-têtes HTTP du navigateur de votre visiteur pour les menaces. Si une menace est détectée, une page de blocage sera envoyée.  

* 3. Vitesse 
Ceci concerne les serveur à fort traffic notamment pour un site web, peu d impact sur nos sedbox  

* Auto Minify: **OFF**  
Réduisez la taille du fichier du code source sur votre site Web. Mais si cela n'est pas fait correctement, cela peut avoir un  impact sur Javascript et CSS, et provoquer un comportement inattendu.  

* Brotli: **ON**  
Accélère les temps de chargement des pages pour le trafic HTTPS en appliquant la compression Brotli  

* Rocket Loader: **OFF**  


![](https://user-images.githubusercontent.com/64525827/105626862-14c91e80-5e33-11eb-866e-87f642d14ef1.png)

* 4. Caching

Caching Level: **Standard**  
Déterminez la quantité de contenu statique de votre site Web que Cloudflare doit mettre en cache.  

Browser Cache TTL: **1 hour**  
Pendant cette période, le navigateur charge les fichiers à partir de son cache local, accélérant ainsi le chargement des pages. Mettre une durée trop importante peut vous forcer à vider le cache de votre navigateur pour voir les changements.  

Always Online: **OFF**  
Si votre serveur tombe en panne, Cloudflare servira les pages "statiques" de votre application Web à partir du cache  

**5. Page Rules**  
Ensuite, nous passons à l'un des paramètres Cloudflare les plus importants pour Docker et Traefik. Ceci est essentiel, en particulier, si vous exécutez des serveurs de médias (par exemple Plex, Emby, Jellyfin, etc.).

Les règles de page offrent un contrôle plus fin et basé sur les URL des paramètres de Cloudflare. Certaines pages de notre configuration doivent contourner les ressources de Cloudflare. Dans mon cas, je voulais éviter les applications suivantes d'utiliser le cache Cloudflare: plex, Emby, Jellyfin  

![](https://camo.githubusercontent.com/cda7414ca78e8e8d5ea5754390e57c0681fce71b/68747470733a2f2f692e696d6775722e636f6d2f513433304c6b7a2e706e67)  

![](https://camo.githubusercontent.com/c2cb6903c9a1279b99daeddf09430589bfe29913/68747470733a2f2f692e696d6775722e636f6d2f706c57456c6b662e706e67)  

C'est important pour se conformer aux conditions générales de Cloudflare pour le plan gratuit. Sinon vous pourriez être banni par Cloudflare pour avoir enfreint leur TOS.