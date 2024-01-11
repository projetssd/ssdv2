---
layout: default
title: ssdv2
---
![](https://grafana.com/api/dashboards/9558/images/5968/image)
<br>
#### Quelques explications

Lors de l'installation de Varken, seront également installés Grafana et Telegraf.

* **Varken**: utilitaire autonome pour agréger les données de l'écosystème Plex dans InfluxDB.
* **Grafana**: application web nous permettant d’afficher des graphiques selon des métriques enregistré dans une base de donnée sous le moteur Influxdb.
* **Telegraf**: agent qui s’installe sur les serveurs et qui récupèrent des métriques selon les « inputs » définis dans ses fichiers de configurations. Il renvoie les différentes métriques vers les « outputs », les sorties définies dans la configuration de même.
* **Monitorr**: application Web PHP auto-hébergée qui surveille l'état des services réseau, des sites Web, des applications locales et distantes.

#### 1. Maxmind  
#### Comment obtenir une clé de licence

1ère étape [créer un compte (gratuit) chez MaxMind](https://www.maxmind.com/en/geolite2/signup)  

Une fois le compte créé, il sera possible de générer une clé de licence.  
<br>
![](https://100son.net/wp-content/uploads/2020/01/maxmind-com-license-key-2020-01-02.jpg)  
<br>
Répondez non à la question ci-dessous et n'oubliez pas de **copier votre key** l'étape après avoir confirmé:
![](https://nextcloud.teamsyno.com/s/K3YLH99tAZqdSPL/preview)
<br> 

Maintenant on va lancer le script et coller la KEY:

![](https://nextcloud.teamsyno.com/s/Q8RgfkbACgSXDSm/preview)

Valider par **Enter**, le script poursuit son travail.

#### 2. Grafana  
![](https://i.stack.imgur.com/F5YMp.png)  
user: admin  
Pass: grafana

#### Configuration influxdb  
Aller sur data sources  
![](https://wiki.cajun.pro/uploads/images/gallery/2019-05-May/tizFzcFxa5xbGpf9-firefox_mvqEuEQvW9.png)  
<br>
Cliquer sur Add data source  
![](https://wiki.cajun.pro/uploads/images/gallery/2019-05-May/wznBc1XcoHpadRYj-firefox_O7f9LaAwpO.png)  
<br>
Choisir Influxdb  
![](https://wiki.cajun.pro/uploads/images/gallery/2019-05-May/ZY6yozj0FSD13LWW-firefox_Nv62HqpleL.png)  
<br>
Configurer comme ci dessous  
![](https://wiki.cajun.pro/uploads/images/gallery/2019-05-May/scaled-840-0/dNUOg1UMRxG6hLwy-firefox_xuRCHdLEQB.png)  
<br>  
Recréer une 2ème base de donnée sur le même shéma que précédemment en changeant varken par telegraf, ce qui fait qu'au final vous disposerez de 2 bases de données influxdb: varken et telegraf  
<br>
Pour terminer vous importez le [dashboard unofficial de plex](https://grafana.com/grafana/dashboards/9558) avec le n° id '9558'
![](https://grafana.com/static/img/docs/v50/import_step1.png)  
<br>[Complément d'information sur la configuration](https://wiki.cajun.pro/books/varken/page/breakdown)  
#### 3. Monitorr  
Une fois monitorr installé à partir du script, assurez vous vous qu'il est fonctionnel en tapant:  
```https:/monitorr.domain.com/assets/php/phpinfo.php```  
vous devriez tomber sur cette page  
<br>
![](https://camo.githubusercontent.com/f70a9b7570bffc43562dd8d6f9a5930a28272fe0/68747470733a2f2f692e696d6775722e636f6d2f347568767730572e706e67)  
<br>
Accédez à https://monitorr.domain.com Vous verrez un avertissement indiquant "Répertoire de données NON détecté. Cliquer sur Monitorr setting  
<br>
![](https://camo.githubusercontent.com/4c0efdb48e174b366d0ec03d43cd3a5dcfb125c0/68747470733a2f2f692e696d6775722e636f6d2f3237466c5633552e706e67)  
<br>
Cliquer sur Monitorr registration  
<br>
![](https://camo.githubusercontent.com/74ae70a67cba5edc55ba092960ae89ba9fc21f9a/68747470733a2f2f692e696d6775722e636f6d2f4b43504d7070552e706e67)  
<br>
Ensuite créer vos identifiants de connexion  
<br>
![](https://camo.githubusercontent.com/7e81a59a2190857157628348cbee57a0b8261309/68747470733a2f2f692e696d6775722e636f6d2f43764356354e6a2e706e67)  
<br>
Vous devriez obtenir ceci  
<br>
![](https://camo.githubusercontent.com/407c7a568e294728b88be617eda021bf74208263/68747470733a2f2f692e696d6775722e636f6d2f347549685364372e706e67)  
<br>
Et enfin  
<br>
![](https://camo.githubusercontent.com/9fe47abd0e3c527d398ed69a1ed20908b69ea847/68747470733a2f2f692e696d6775722e636f6d2f77704939756f4b2e706e67)  
<br>
Plus qu'à configurer, c’est très simple de rajouter des applis, suivez le modele de celles déjà présentes  
Sources: https://github.com/Monitorr/Monitorr/wiki/01-Config:--Initial-configuration  
<br>
#### 4. Intégration Monitorr avec la Home page d'Organizr  
A ajouter dans Éditeur/Éléments de la page d’accueil/CustomHTML-1  
<br>
```
<div style="overflow:hidden;  height:255px">    
        <embed style="height:100%" width='100%' src='https://yourdomain.com/monitorr/index.min.php'/>
</div>
<br>
```
<br>  
Vous pouvez régler (height:255px) pour ne pas avoir d’ascenseur dans la Home page, rafraichissez, vous obtenez  

![Imgur Image](https://i.imgur.com/uQ7iZ7I.png)  
<br>
Copier le script HTML ci dessous dans Éditeur/Éléments de la page d’accueil/CustomHTML-1 dessous le code précédemment intégré de monitorr  
<br>
```
 <style>
.flex {
    display: flex;
    flex-wrap: wrap;
    flex-direction: row;
    align-items: center;
    background: transparent;
    box-shadow: none !important;
    transition: all .4s ease-in-out;
    cursor: pointer
}

/* -------------------Small widget------------------- */
.flex-child { padding: 3px; flex-grow: 1; flex-basis: 0;}
#grafanadwidget { position: relative; height: calc(80px); width: calc(100%);}
/* -------------------Small widget------------------- */

/* -------------------Big widget------------------- */
.flex-child-big { padding: 3px; flex-grow: 1; flex-basis: 0;}
#grafanadwidget-big { position: relative; height: calc(250px); width: calc(100%);}
/* -------------------Big widget------------------- */

/* -------------------iFrame Link------------------- */
.iframe-link { z-index:1; position:absolute; height: calc(80px); width: calc(100%); background-color: transparent; cursor: pointer}
/* -------------------iFrame Link------------------- */

#announcementRow { background-color:transparent !important;}
#announcementRow>h4 {
    padding-left: 15px;
    font-family: Rubik,sans-serif;
    margin: 10px 0;
    font-weight: 300 !important;
    line-height: 22px;
    font-size: 18px;
    color: #dce2ec;
}
.overflowhider { height: 100%; overflow: hidden;}
@media only screen and (max-width: 650px) {.flex-child-big {flex-basis: auto;min-width: auto !important;}}
@media only screen and (max-width: 1125px) {.flex-child-big {flex-basis: auto;min-width: 600px;flex-basis: fit-content;}}
@media only screen and (max-width: 1649px) {.flex-child {flex-basis: auto;}}
</style>

<!-- -------------------ADD TITLE HERE------------------- -->
<div id="announcementRow" class="row"><h4 class="pull-left">
    <span>Grafana</span></h4><hr class="hidden-xs"></div>

<!-- -------------------SMALL WIDGET START------------------- -->
    <div class="content-box flex">
    <!-- -------------------WIDGET------------------- -->
    <div class="flex-child" id="flex-grafanadwidget">
    <div class="overflowhider">
    <iframe class="iframe" id="grafanadwidget" 
    frameborder="0" src="ADD-URL-TO-GRAFANA-PANEL-HERE"></iframe>
    </div></div>
    <!-- -------------------WIDGET------------------- --> 
    <div class="flex-child" id="flex-grafanadwidget">
    <div class="overflowhider">
    <iframe class="iframe" id="grafanadwidget" 
    frameborder="0" src="ADD-URL-TO-GRAFANA-PANEL-HERE"></iframe>
    </div></div>
    <!-- -------------------WIDGET------------------- -->     
    <div class="flex-child" id="flex-grafanadwidget">
    <div class="overflowhider">
    <iframe class="iframe" id="grafanadwidget" 
    frameborder="0" src="ADD-URL-TO-GRAFANA-PANEL-HERE"></iframe>
    </div></div>
    <!-- -------------------WIDGET------------------- --> 
    <div class="flex-child" id="flex-grafanadwidget">
    <div class="overflowhider">
    <iframe class="iframe" id="grafanadwidget" 
    frameborder="0" src="ADD-URL-TO-GRAFANA-PANEL-HERE"></iframe>
    </div></div>
    <!-- -------------------WIDGET------------------- -->     
    <div class="flex-child" id="flex-grafanadwidget">
    <div class="overflowhider">
    <iframe class="iframe" id="grafanadwidget" 
    frameborder="0" src="ADD-URL-TO-GRAFANA-PANEL-HERE"></iframe>
    </div></div>
    <!-- -------------------WIDGET------------------- -->     
    <div class="flex-child" id="flex-grafanadwidget">
    <div class="overflowhider">
    <iframe class="flex" id="grafanadwidget" 
    frameborder="0" src="ADD-URL-TO-GRAFANA-PANEL-HERE"></iframe>
    </div></div>
</div>
<!-- -------------------SMALL WIDGET END------------------- -->

<!-- -------------------BIG WIDGET START------------------- -->   
<div class="content-box flex">
    <!-- -------------------BIG WIDGET------------------- -->        
    <div class="flex-child-big" id="flex-grafanadwidget-big">
    <div class="overflowhider">
    <iframe class="flex" id="grafanadwidget-big" frameborder="0" 
    frameborder="0" src="ADD-URL-TO-GRAFANA-PANEL-HERE"></iframe>
    </div></div>
    <!-- -------------------BIG WIDGET------------------- -->     
    <div class="flex-child-big" id="flex-grafanadwidget-big">
    <div class="overflowhider">
    <iframe class="iframe" id="grafanadwidget-big" frameborder="0" 
    frameborder="0" src="ADD-URL-TO-GRAFANA-PANEL-HERE"></iframe>
    </div></div>
    <!-- -------------------BIG WIDGET------------------- -->     
    <div class="flex-child-big" id="flex-grafanadwidget-big">
    <div class="overflowhider">
    <iframe class="iframe" id="grafanadwidget-big" frameborder="0" 
    frameborder="0" src="ADD-URL-TO-GRAFANA-PANEL-HERE"></iframe>
    </div></div>   
</div>
<!-- -------------------BIG WIDGET END------------------- --> 
```
<br>
Comme vous pouvez le constater, 6 blocs sont réserves pour des petits widgets et 3 pour des plus gros. L'idée est de modifier les emplacements  
<br>  

``` 
ADD-URL-TO-GRAFANA-PANEL-HERE  
```
En mettant l'adresse du panel récupéré dans Grafana ainsi que  
```
TAB-NAME-HERE  
```
Par le nom de la table créée dans Oganizr.  
<br>
Par défaut on utilise l'adresse suivante  
```
src='https://grafana.domain.com/d-solo/bj0JnBMmz/org-dash?refresh=5s&orgId=1&panelId=22'/>  
``` 
Pour 
```
ADD-URL-TO-GRAFANA-PANEL-HERE  
```  
<br>
<br>
On modifie simplement le numéro de panelId par celui correspondant au panel que nous souhaitons afficher. Pour récupérer le numéro du panel on clique sur la petite flèche du panel puis Share/Embed on obtient ça:  
<br>  
  
![](https://technicalramblings.com/wp-content/uploads/2019/01/share.png)  
<br>  

Ce qui nous intéresse c est le numéro 38 que l'on remplace dans  
```
src='https://grafana.domain.com/d-solo/bj0JnBMmz/org-dash?refresh=5s&orgId=1&panelId=38'/>  
``` 
<br>  
Voilà mon Dashboard mais vous pouvez construire ce que vous voulez intégrant des metrics avec telegraf ou bien des données de Netdata    
<br>  

![Imgur Image](https://i.imgur.com/S8QsuWg.png)  
<br>

#### Ajouter des onglets à Monitorr

Rendez-vous sur Services configuration de Monitorr: https://monitorr.ndd.tld/settings.php#services-configuration

![](https://nextcloud.teamsyno.com/s/QEzQ7YJNSHw4QGJ/preview)

* **Add Service**: ajouter un service
* **Remove Service**: supprimer le service 
* **Move Up**: monter un service dans l'ordre d'apparence
* **Move Down**: descendre un service dans l'ordre d'apparence
* **Clear**: supprimer les données déjà entrées dans le service
* **Images**: sélectionner et/ou ajouter l'icône d'un service

![](https://nextcloud.teamsyno.com/s/qPr4ckPrWogz6fD/preview)

* **Service title**: Rutorrent
* **Enabled**: oui, on l'active
* **Service image**: un grand choix d'icônes est présent, (il suffira de copier le code de l'image), mais vous pouvez aussi en ajouter.
* **Check type**: standard
* **Ping RT**:
* **Link Enabled**: si vous voulez que l'icône soit cliquable et mène à la page web correspondante
* **Check URL**: https://rutorrent.VOTRE_DOMAINE.tld:443
* **Service URL**: https://rutorrent.VOTRE_DOMAINE.tld:443

#### Corriger l'erreur grafana-worldmap-panel

`rm -rf /opt/seedbox/docker/tjmm/grafana/plugins/grafana-worldmap-panel`

`wget https://github.com/grafana/worldmap-panel/releases/download/v0.3.0/grafana-worldmap-panel-0.3.0.zip`

Mais vérifier s’il n’y a pas une nouvelle version [ici](https://github.com/grafana/worldmap-panel/releases/).

`unzip grafana-worldmap-panel-0.3.0.zip`

`rm -rf grafana-worldmap-panel-0.3.0.zip`

`chown -R 472:472 grafana-worldmap-panel`

`docker restart grafana`