# StreamFusion

L'installation demande la clé TMDB, la clé d'administration (32 caractères minimum),
l'adresse de l'API AllDebrid et, facultativement, un proxy. L'adresse recommandée
est `https://api.alldebrid.com`. SSD Relay reste utilisable avec son URL propre ;
il n'est pas une dépendance obligatoire.

Les quatre réglages sont conservés dans
`$SETTINGS_STORAGE/docker/$USER/streamfusion-secrets`, avec les autres secrets
StreamFusion (dossier en 0700, fichiers en 0600). Aucun de ces paramètres n'est
écrit dans `seedbox/conf`. Les registres Docker génériques restent inchangés.
Lors du premier passage d'une ancienne installation, les valeurs manquantes
sont récupérées depuis `stream-fusion`, sans lire le YAML personnalisé.

À la réinstallation, « Modifier les réglages mémorisés ? » propose **non** par
défaut. Oui repose les quatre questions. Entrée conserve une valeur existante ;
`-` désactive le proxy. Les secrets internes et les données PostgreSQL sont conservés.

Pour automatiser l'installation, fournir les variables Ansible
`streamfusion_tmdb_api_key`, `streamfusion_admin_secret_key`,
`streamfusion_ad_base_url` et `streamfusion_proxy_url` (chaîne vide sans proxy).
`streamfusion_reconfigure: false` conserve les réglages sans question de
confirmation. Une valeur explicitement fournie remplace la valeur mémorisée.
Sans saisie interactive, les valeurs existantes sont réutilisées ; une clé
obligatoire manquante arrête l'installation avant le déploiement.

## Changer le proxy

Depuis un terminal SSDV2 :

```bash
streamfusion_proxy                # saisie masquée, conseillée avec des identifiants
streamfusion_proxy 'http://proxy:1080'
streamfusion_proxy --disable
```

La commande mémorise le proxy et recrée `stream-fusion` et `taskiq-worker` avec
leurs images actuelles, volumes, labels et autres paramètres. Elle ne rejoue
pas le playbook. Elle conserve `AD_BASE_URL` : choisir un proxy capable de
joindre cette adresse, en particulier si elle désigne un relais privé.

Si l'une des recréations échoue, la commande renvoie une erreur et indique le
conteneur concerné, sans afficher le proxy. La valeur reste mémorisée ; relancer
la même commande pour terminer l'application. Les deux conteneurs doivent être
présents avant toute modification.

La commande ne modifie pas un éventuel YAML personnalisé. Celui-ci garde la
priorité habituelle SSDV2 lors des prochains déploiements ; utiliser les
variables de l'intégration publique pour reprendre les réglages mémorisés.
