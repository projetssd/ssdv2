---
layout: default
title: ssdv2
---
UFW, ou Uncomplicated Firewall, est une interface vers + iptables + qui est conçue pour simplifier le processus de configuration d’un pare-feu.

#### 1 - Installation :

Pour l'activer il faut se rendre dans le menu 3)Gestion, 2)Utilitaires, 8) Bloquer les ports non vitaux avec UFW.

Par defaut, il sera installé avec les ports ouverts suivant : 

	- http (80)
    - https (443)
    - plex  (32400)
    - ssh (22 si vous avez laissé la valeur par défaut)

![mobaxterm-kfkusnrm4l](https://user-images.githubusercontent.com/64525827/105354525-f70c7700-5bf0-11eb-83ae-27aec32d5a72.png)


#### 2 - Conseil important :

Une fois l'installation terminée, ne surtout pas fermer votre terminal. En ouvrir un second et essayer de vous connecter en SSH.

#### 3 - Commandes UFW utiles :

ci joint une liste non exhaustive des commandes pour UFW

Pour connaitre la liste des ports et le status sur votre serveur

	ufw status verbose
    


	Status: active 
	To                         Action      From
	--                         ------      ----
	8398                       ALLOW       Anywhere
	Anywhere                   ALLOW       176.189.55.227
	Anywhere                   ALLOW       172.16.0.0/12
	Anywhere                   ALLOW       127.0.0.1
	80                         ALLOW       Anywhere
	443                        ALLOW       Anywhere
	8080                       ALLOW       Anywhere
	45000                      ALLOW       Anywhere
	plexmediaserver-all        ALLOW       Anywhere
	Anywhere                   ALLOW       182.122.87.111
	8398 (v6)                  ALLOW       Anywhere (v6)
	80 (v6)                    ALLOW       Anywhere (v6)
	443 (v6)                   ALLOW       Anywhere (v6)
	8080 (v6)                  ALLOW       Anywhere (v6)
	45000 (v6)                 ALLOW       Anywhere (v6)
	plexmediaserver-all (v6)   ALLOW       Anywhere (v6)
    
    
#### 4 - Ajout de ports et/ou d'IP

Si vous avez besoin d'ajouter un port particulier et/ou une adresse Ip qui ne sera pas affecté par le filtrage d'UFW, il faut éditer le fichier suivant :  /opt/seedbox/conf/ufw.yml
et ajouter des lignes supplémentaires. Il ne faut pas modifier les lignes existantes.

	hosts: localhost
 	gather_facts: true
  	vars:
     opened_ports:
      - 80
      - 443
      - 8080
      - 45000
      # Ajoutez les ports nécessaires ici :
      # - 25 # smtp
     allow_ips:
      - 172.17.0.1/12 # réseau docker, ne pas supprimer !
      - 127.0.0.1
      - 188.13.87.111
      # ajoutez des ip ou des plages supplémentaires ici
      # - 123.456.789.123
      # - fe20:abcd::