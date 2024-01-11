---
layout: default
title: ssdv2
---
Parce que le port ssh est le plus exposé aux attaques, il est fortement conseillé à la fois d'atttribuer un autre port que le 22 par défault (ce que nous verrons plus bas) mais également de mettre en place une authentification par clés.  

#### Création des clés d'authentification  
#### 1. Windows  
##### Générer une paire de clés sous Windows  

La plupart des connexions SSH sous Windows sont initialisées avec le client Putty qui est simple et efficace. L'outil PuttyGen permet de générer facilement un jeu de clés qui nous permettra de nous authentifier sur un serveur en les utilisant. On doit donc commencer par télécharger PuttyGen sur la page de téléchargement de Putty : http://www.chiark.greenend.org.uk/~sgtatham/putty/download.html  
<br>
Une fois téléchargé, nous l’exécuterons en cliquant sur l’exécutable:  
<br>
![](https://www.it-connect.fr/wp-content-itc/uploads/2015/07/linux-ssh-cle-authentification-01.jpg)  
<br>
Il nous faut ensuite sélectionner le type de clé que nous voulons générer, “SSH-1 (RSA)” et “SSH-2-RSA” correspondent à la version du protocole pour des clés RSA et “SSH-2- DSA” pour la création d’une clé DSA.  
<br>
On peut également choisir le nombre de bits pour notre clé (au minimum 2048 !). On cliquera ensuite sur “Generate“. Il faudra alors bouger la souris pour générer de l’entropie et cela jusqu’à ce que la barre de chargement soit pleine:  
<br>
![](https://www.it-connect.fr/wp-content-itc/uploads/2015/07/linux-ssh-cle-authentification-02.jpg)  
<br>
Une fois terminé, nous aurons cet affichage:  
<br>
![](https://www.it-connect.fr/wp-content-itc/uploads/2015/07/linux-ssh-cle-authentification-03.jpg)  
<br>
On voit donc bien notre clé générée. On peut également, avant de l’enregistrer, ajouter un commentaire et une passphrase. La passphrase permet d’ajouter une couche de sécurité. C’est le même principe qu’un mot de passe. Si votre clé privée se retrouve dans les mains d’un attaquant, il lui faudra la passphrase pour l’utiliser. Il est possible de ne pas mettre de passphrase. Nous aurons alors un avertissement comme quoi il est préférable d’entrer une passphrase mais nous pourrons continuer. Il faut donc finir par cliquer sur “Save private key” et “Save public key”. Nous pourrons ensuite fermer PuttyGen.  

#### 2. Mettre la clé sur le serveur  
Il nous suffira alors simplement de copier le contenu de notre clé publique (par défaut ".ssh/id_rsa.pub") dans le fichier ".ssh/authorized_keys" de l'utilisateur du serveur visé.  
<br>
Nous supposons ici que nous voulons une connexion sur le compte "root" (c’est bien sûr déconseillé dans un cadre réel). Nous allons donc aller dans le dossier "root" de cet utilisateur et créer le dossier ".ssh" s'il n’existe pas déjà:  

> mkdir .ssh  

Le dossier ".ssh" est là où vont se situer les informations relatives aux comptes et aux connexions SSH de l’utilisateur. Nous y créerons le fichier "authorized_keys" s’il n’existe pas. Ce fichier contient toutes les clés publiques que permettent d’établir des connexions avec le serveur et l’utilisateur dans lequel il se trouve (selon le dossier "home" dans lequel il se trouve). Nous allons ensuite dans ce fichier mettre notre clé publique (éviter de mettre les "=== BEGIN===" et "===END===" générés automatiquement par PuttyGen).  
<br>
Il nous faudra ensuite donner les droits les plus restreints à ce fichier par sécurité et pour les exigences d’OpenSSH:  

> chmod 700 ~/.ssh -Rf

Notre clé est maintenant présente sur le serveur, il nous reste plus qu’à nous connecter pour tester!  
##### Authentification SSH par clé sous Windows  
Putty a maintenant besoin de savoir où se situe notre clé privée pour établir une communication valable avec le serveur. Après l’avoir lancé et avoir renseigné l’IP de notre serveur, nous nous rendrons dans la partie "Connexion" > "SSH" > "Auth" puis nous cliquerons sur "Browse" pour aller chercher notre clé privée à côté du champ "Private key file for authentication":  
<br>
![](http://www.it-connect.fr/wp-content-itc/uploads/2015/07/linux-ssh-cle-authentification-04.jpg)  
##### 2. Linux  
Pour générer des clés sur linux je vous invite à consulter ce lien à partir duquel je me suis plus qu'inspirer pour ce tuto ;)  
https://www.it-connect.fr/chapitres/authentification-ssh-par-cles/  
#### Changement du port SSH, installation fail2ban et iptables  
J'ai repris le travail de geerlingguy qui propose 2 roles ansibles déjà pré-configurés qui vont dans un 1er temps proposer le changement du port SSH, configurer fail2ban en conséquence et installer un iptables avec seulement le port SSH choisis d'ouvert.  
<br>
Tous les autres ports nécessaires au bon fonctionnement des applis sont gérés par docker qui interfère directement avec iptables.  
<br>
Pour les plus aguerris il est tout à fait possible de modifier les règles dans le fichier de config qui ressemble à çà:  
```firewall_state: started
firewall_enabled_at_boot: true

firewall_allowed_tcp_ports:
  - "{{ ssh.stdout }}"
firewall_allowed_udp_ports: []
firewall_forwarded_tcp_ports: []
firewall_forwarded_udp_ports: []
firewall_additional_rules: []
firewall_enable_ipv6: false
firewall_ip6_additional_rules: []
firewall_log_dropped_packets: true

# Set to true to ensure other firewall management software is disabled.
firewall_disable_firewalld: false
firewall_disable_ufw: false  
```

Plus d'infos:  
https://github.com/geerlingguy/ansible-role-firewall  
<br>
Même chose pour ssh, possibilité de personnaliser le fichier sshd_config
```security_ssh_port: "{{ ssh }}"
security_ssh_password_authentication: "yes"
security_ssh_permit_root_login: "yes"
security_ssh_usedns: "no"
security_ssh_permit_empty_password: "no"
security_ssh_challenge_response_auth: "no"
security_ssh_gss_api_authentication: "no"
security_ssh_x11_forwarding: "no"

security_sudoers_passwordless: []
security_sudoers_passworded: []

security_autoupdate_enabled: true
security_autoupdate_blacklist: []

# Autoupdate mail settings used on Debian/Ubuntu only.
security_autoupdate_reboot: "false"
security_autoupdate_reboot_time: "03:00"
security_autoupdate_mail_to: ""
security_autoupdate_mail_on_error: true

security_fail2ban_enabled: false
```
Plus d'infos:  
https://github.com/geerlingguy/ansible-role-security  
<br>
Par défault j'ai laissé l'options suivante à "yes"  

```security_ssh_password_authentication: "yes"
security_ssh_permit_root_login: "yes"
```
Mais on peut très bien imaginer une création de clés uniquement pour votre user, et désactiver l'authentification par mots de passe et root. Penser toujours à laisser une fenêtre ssh ouverte pendant vos tests pour ne pas risquer d'être bloqué.