---
layout: default
title: ssdv2
---
Information Essentielles, nécessaires à la configuration du mailserver de @hardware
https://github.com/hardware/mailserver

#### Configuration des DNS

Par défaut, si vous avez confié la gestion de vos DNS à Cloudflare, **Le script va automatiquement créer les enregistrements décrits ci dessous dans la partie DNS de votre Domaine**. Dans le cas contraire vous devez rentrer manuellement ces enregistrements auprès de votre Registrar (Gandi, Ovh , etc ..)  

Très important, et çà le script ne le fait pas, penser à configurer le PTR au niveau de votre serveur Hetzner --> **Reverse DNS entry** --> mail.domain.tld

<br>

HOSTNAME| CLASS | TYPE | PRIORITY | VALUE
|-------|:-----:|:----:|:--------:|------:
| mail  |  IN 	|A/AAAA|  any     |1.2.3.4
| spam 	|  IN 	| CNAME|  any 	  |mail.domain.tld.
| webmail| IN   |CNAME |any 	  |mail.domain.tld.
postfixadmin| 	IN| 	CNAME| 	any| 	mail.domain.tld.
@|	IN| 	MX| 	10| 	mail.domain.tld.
@ |	IN |	TXT |	any |	"v=spf1 a mx ip4:SERVER_IPV4 ~all"
mail._domainkey |	IN |	TXT |	any |	"v=DKIM1; k=rsa; p=YOUR DKIM Public Key"
_dmarc| 	IN| 	TXT| 	any| 	"v=DMARC1; p=reject; rua=mailto:postmaster@domain.tld; ruf=mailto:admin@domain.tld; fo=0; adkim=s; aspf=s; pct=100; rf=afrf; sp=reject"

La clé public key DKIM est disponible après lancement:
```
/mnt/docker/mail/dkim/domain.tld/public.key
```

#### Configuration Postfixadmin

1. Allez sur la page de configuration https://postfixadmin.domain.tld/setup.php  
2. Definir le setup password  
3. Recuperer le hash  
```
docker exec -ti postfixadmin setup

> Postfixadmin setup hash : ffdeb741c58db70d060ddb170af4623a:54e0ac9a55d69c5e53d214c7ad7f1e3df40a3caa
Setup done.
```
4. Créer le compte Admin
5. Aller sur la page https://postfixadmin.your-domain.tld/
6. Vous pouvez maintenant creer vos mailboxes, Alias, etc ..  
<br>

![](https://camo.githubusercontent.com/b16f7a3ca44d1a89791014d35522d718098e9006/687474703a2f2f692e696d6775722e636f6d2f344237554d4b692e706e67)


![](https://camo.githubusercontent.com/03c6094f15bf963a6669a1b5c2d3e81e4278284b/687474703a2f2f692e696d6775722e636f6d2f4a686f79354f6e2e706e67)

#### Configuration Rainloop
Pour configurer Rainloop il faut se rendre sur la panneau d'administration, https://webmail.domain.tld/?admin  
Login par défaut: **admin** password **12345**
Vous d'abord configurer votre domaine
![](https://camo.githubusercontent.com/a6f4ad35c115c988e4258dc857f22705b9edf0db/687474703a2f2f692e696d6775722e636f6d2f52624d56686b7a2e706e67)

![](https://camo.githubusercontent.com/fa9bf6188e34b4170cc9a8d8cfeba718f930dfb2/687474703a2f2f692e696d6775722e636f6d2f474662624a7a732e706e67)

![](https://camo.githubusercontent.com/013beb92422e527c513d0daa12fb1ecc3f352904/687474703a2f2f692e696d6775722e636f6d2f6572764b7472472e706e67)

![](https://camo.githubusercontent.com/0ecf409c5e5585e9c58de4a0533d5bdce6055ab9/687474703a2f2f692e696d6775722e636f6d2f38593070704c622e706e67)

#### Liste des web services:

 Service|	URI
|-------|----------:
| Rspamd  dashboard |	https://spam.domain.tld/
| Administration |	https://postfixadmin.domain.tld/
| Webmail |	https://webmail.domain.tld/

Vous pouvez enfin tester l'authenticité de vos mail  

* https://www.mail-tester.com/  
* https://www.hardenize.com/  
* https://observatory.mozilla.org/  
* https://www.emailprivacytester.com/  
<br>

![](https://i.imgur.com/xbufE6H.png)