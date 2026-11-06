# CrowdSec — exclusions SSDV2

CrowdSec protège Traefik et l'hôte, mais certaines requêtes légitimes des
applications média ressemblent à du probing :

- Polyfin, Jellyfin, Silo et Streamyfin demandent des routes absentes et
  reçoivent des 404 ou 403 normaux ;
- les clients média envoient des événements de lecture qui peuvent être
  refusés (403) sans qu'il s'agisse d'une attaque ;
- la navigation dans une bibliothèque déclenche plusieurs dizaines de requêtes
  en peu de temps et peut ressembler à un crawl agressif ;
- le serveur lui-même appelle ses propres services publics (Polyfin vers
  StreamFusion ou SSDV2 Proxy), avec l'IP publique du serveur comme source.

Sans exclusion, CrowdSec peut bannir l'IP du serveur ou les IP des utilisateurs.

## Ce que SSDV2 déploie

La posttask `includes/dockerapps/posttasks/crowdsec.yml` déploie :

`~/seedbox/docker/<utilisateur>/crowdsec/etc/parsers/s02-enrich/whitelist-ssdv2.yaml`

Cette whitelist contient par défaut :

- l'IP publique du serveur (`network.ipv4` dans `account.yml`) ;
- les réseaux Tailscale/CGNAT (`100.64.0.0/10`), IPv6 ULA (`fc00::/7`) et
  link-local (`fe80::/10`) ;
- les 404 normaux de Polyfin/Jellyfin/Silo (`/api/v2/favorites/`,
  `/api/v2/watchlist/`, `/admin/api/`) ;
- les 404 normaux du WebUI SSDV2 sur son sous-domaine (`/api/v1/`) ;
- la racine `www.<domaine>` en 404 ;
- les 403 normaux des clients média (`/api/v2/playback/`,
  `/Sessions/Capabilities/Full`, `/playback/`) ;
- les chemins de flux opaques de StreamFusion (`/gAAAA...`) ;
- la navigation légitime des applis média (`/Items/`, `/Users/`,
  `/stremfin/api/`, `/playback/`, `/gAAAA...`, `/api/v2/`) pour éviter
  `http-crawl-non_statics`.

Après déploiement, les décisions CrowdSec actives pour l'IP du serveur et les
IP/réseaux ajoutés par l'utilisateur sont supprimées.

## Ajouter une IP ou un réseau

Le fichier utilisateur est créé automatiquement :

`~/seedbox/docker/<utilisateur>/crowdsec/whitelist.yml`

```yaml
# IP exactes à ne jamais bannir
ips:
  - 89.82.54.117

# Réseaux CIDR à ne jamais bannir
cidrs:
  - 2001:861:20d2:bc00::/64

# Faux positifs de crawl des applis média
media_crawl: true
```

Utiliser une IP exacte ou un réseau étroit. Pour une box, un `/64` IPv6 est
adapté ; éviter les réseaux IPv4 trop larges. Les CIDR IPv4 plus larges que
`/24` et les CIDR IPv6 plus larges que `/48` sont refusés.

Le fichier est créé automatiquement s'il n'existe pas ; une réinstallation de
CrowdSec ne l'écrase pas.

Après modification, relancer CrowdSec depuis SSDV2 (menu de relance de
l'application `crowdsec`, ou `ssdv2ctl app recreate crowdsec`). La whitelist
est rendue à nouveau et CrowdSec redémarre si nécessaire.

## Débannir une IP

```sh
docker exec crowdsec cscli decisions delete --ip 1.2.3.4
docker exec crowdsec cscli decisions delete --range 2001:db8::/64 --contained
```

Une IP ajoutée à `whitelist.yml` puis une relance de CrowdSec déclenchent aussi
ce nettoyage.

## Vérifier

```sh
docker exec crowdsec cscli parsers list | grep whitelist-ssdv2
docker exec crowdsec cscli decisions list --ip 1.2.3.4
docker exec crowdsec cscli explain --type traefik --log '<ligne de log>'
```

`cscli explain` indique `ignored by whitelist` lorsqu'une requête correspond à
une exclusion.

## Limites

- Une whitelist locale empêche CrowdSec de créer de nouvelles décisions, mais
  ne neutralise pas forcément une décision reçue de la blocklist CAPI. Le
  nettoyage de la posttask supprime les décisions présentes au moment de la
  relance ; une décision CAPI peut réapparaître ensuite.
- Les exclusions 404 sur `/admin/api/` et sur la racine `www.<domaine>` sont
  volontairement larges : elles évitent les faux positifs des interfaces
  d'administration et des sites statiques, au prix d'une détection de probing
  réduite sur ces préfixes.
- L'exclusion `media_crawl` est volontairement large pour les applications
  média. La passer à `false` dans `whitelist.yml` restaure un contrôle plus
  strict, au prix de possibles faux positifs.
- Les IP publiques dynamiques doivent être mises à jour dans `whitelist.yml`.
