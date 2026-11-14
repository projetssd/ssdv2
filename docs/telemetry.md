# Statistiques communautaires de SSDV2

SSDV2 propose un **inventaire pseudonyme automatique** et non bloquant pour mesurer le nombre d'installations, les applications populaires, leurs versions et les changements observés au fil du temps.

## Données transmises

Une fois par jour environ, un petit snapshot HTTPS contient uniquement :
- Un UUIDv4 aléatoire propre à l'installation (fichier local `~/.config/ssd/telemetry-id`, mode 0600). Il ne provient ni de l'IP, ni de la MAC, ni du matériel.
- La branche du dépôt (`master`, `dev` ou `unknown`) et une révision Git courte.
- Les noms des applications installées figurant dans le catalogue SSDV2 et leur tag Docker (`unknown` si absent).

**Jamais envoyés :** IP, MAC, hostname, domaine, noms de conteneurs, images ou registres Docker, URL, secrets, identifiants de compte, paramètres, journaux, environnement ou fichiers de configuration. Le module lit SQLite et les labels Docker, sans accès aux secrets `account.yml`.

L'URL de réception est fournie une seule fois **par le mainteneur** via `includes/config/telemetry-endpoint.txt`. Si elle n'est pas configurée, aucune requête n'est envoyée.

## Confidentialité, limites et conservation

Le Worker ne stocke jamais l'UUID brut : il enregistre son HMAC-SHA256 calculé avec un secret serveur. Les données par installation (HMAC et snapshot courant) sont supprimées après **120 jours d'inactivité**. Les séries historiques ne contiennent que des totaux agrégés. Cloudflare peut techniquement voir les IP de connexion ; l'application ne les enregistre pas, et la rétention des journaux Cloudflare doit être configurée séparément.

Un UUID persistant, même protégé par HMAC, et une combinaison rare d'applications constituent une **pseudonymisation, pas une anonymisation**. Le dashboard est privé. Les statistiques sont indicatives, pas une mesure exhaustive ni une preuve cryptographique d'installation.

Un tag Docker `latest` ne permet pas d'identifier exactement la version de l'application ; une mise à jour avec un tag inchangé peut ne pas être détectée. Les statistiques de mises à jour mesurent des **changements d'inventaire observés**, et non le succès technique des commandes.

## Désactivation

Aucune action supplémentaire n'est requise lors de l'installation. L'utilisateur peut désactiver la collecte immédiatement :

```bash
python3 ~/seedbox-compose/includes/config/scripts/telemetry.py disable
```

Pour réactiver ou supprimer l'identifiant local :

```bash
python3 ~/seedbox-compose/includes/config/scripts/telemetry.py enable
python3 ~/seedbox-compose/includes/config/scripts/telemetry.py forget
```

`forget` désactive la collecte et supprime l'UUID local ; les données individualisées déjà reçues expirent selon la politique de conservation, les agrégats historiques restent. Une demande d'effacement anticipé peut être adressée au mainteneur.

Autre moyen : configurer `SSDV2_TELEMETRY=off` dans l'environnement du service, ou créer `~/.config/ssd/telemetry.disabled`.

## Exécution

Le collecteur utilise uniquement la bibliothèque standard Python, avec un timer systemd quotidien. Une indisponibilité de Cloudflare, de Docker ou du réseau n'interrompt **jamais** SSDV2. En cas de défaillance de Docker ou de SQLite, aucun snapshot incomplet n'est envoyé.

L'API et le dashboard sont dans le dépôt privé `projetssd/ssdv2-analytics`.

**Avant l'activation publique :** informer les utilisateurs dès l'installation, documenter la politique de confidentialité, régler la rétention des logs Cloudflare et vérifier la base légale applicable au titre du RGPD / des recommandations CNIL.
