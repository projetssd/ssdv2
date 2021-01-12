Tous les tests sont à faire sur 

- ubuntu 20.04
- Debian 10

(Debian 9 et Ubuntu 18.04 ne sont plus concernés)

Prérequis : 
- une vm/vps avec connection internet, si possible avec une ip publique (les vm sur un poste de travail risquent de ne pas pouvoir faire tous les tests)
- un user "normal" (non root), qui puisse faire du sudo. 
- si possible une vm neuve (non pourrie pas des tests/installs précédentes)
- git installé (apt install git)


Cloner le dépot :

```
sudo git clone https://github.com/projetssd/ssdv2.git /opt/seedbox-compose
sudo chown -R ${USER}: /opt/seedbox-compose  
```

puis avec le user
```
cd /opt/seedbox-compose
sudo ./prerequis.sh
```
Rebooter le serveur ! (ça devrait être le dernier reboot obligatoire)
```
./seedbox.sh
```

et se laisser guider

## Tests à faire :

- Lancer seedbox.sh, puis installer la gui (choix 999 caché) et vérifier que tout est ok.
- Faire une install silentieuse de la gui
```
cp autoinstall.ini.sample autoinstall.ini
```
Editer le fichier autoinstall.ini avec les informations demandées
```
./seedbox.sh --action install_gui
```


