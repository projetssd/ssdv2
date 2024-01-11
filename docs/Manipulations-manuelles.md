---
layout: default
title: ssdv2
---
Pour toute opération, assurez vous de ne pas être root.

Charger l'environnement : 
```
cd /opt/seedbox-compose
source profile.sh
```

Après cela, vous devriez voir (venv) devant l'invite de commande.


# Afficher dans le shell tout le contenu du account.yml
```
get_from_account_yml
```

# Manipuler le account.yml

Les clés sont séparées par des points. Par exemple
```
user
  domain: mydomain.net
```

La clé sera user.domain, et sa valeur sera mydomain.net

## Ecrire une clé
Cela va créer la clé si elle n'existe pas, ou l'écraser si elle existe

```
manage_account_yml cle valeur
```
Par exemple
```
manage_account_yml user.domain mondomaine.com
```

## Effacer une clé
Cela va effacer la clé ainsi que toutes les sous clés associées

```
manage_account_yml cle " "
```
Par exemple
```
manage_account_yml user.domain " "
```

## Obtenir la valeur d'une clé

```
get_from_account_yml cle
```
Par exemple
```
get_from_account_yml user.domain
```
va retourner
```
mondomaine.com
```
Si la valeur n'est pas trouvé, cela retourne "notfound"

On peut également retourner une clé et toutes ses sous clés : 
```
get_from_account_yml user
```
va retourner
```
domain: mondomaine.com group: null groupid: 1001 htpwd: seed:xxxxxxxxxxxxxx mail: moi@mondomaine.com name: seed pass: xxxxxxxxxxxxxx userid: 1001
```

# Installer/Lancer une application sans passer par le menu

```
launch_service nomduservice
```
# Désinstaller une application sans passer par le menu
```
suppression_appli nomduservice
```
# Quitter l'environnement de manipulation

Lancer la commande
```
deactivate
```