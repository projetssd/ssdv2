---
layout: default
title: ssdv2
---
Pour supprimer le dossier install  
```
docker exec -ti prestashop bash
rm -rf install
mv admin toto
```  
  
Pour forcer le SSL sur toutes les pages du site  
```
docker exec -ti db-prestashop bash
mysql -u root -p
use prestashop
SELECT NAME, VALUE FROM ps_configuration WHERE NAME IN ('PS_SSL_ENABLED', 'PS_SSL_ENABLED_EVERYWHERE');
UPDATE ps_configuration SET VALUE = '1' WHERE NAME IN ('PS_SSL_ENABLED', 'PS_SSL_ENABLED_EVERYWHERE');
SELECT NAME, VALUE FROM ps_configuration WHERE NAME IN ('PS_SSL_ENABLED', 'PS_SSL_ENABLED_EVERYWHERE');
```