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
- l'IP publique de sortie réelle, découverte via `https://api.ipify.org` si
  elle diffère (serveur derrière un VPN, changement d'adresse) ;
- les réseaux Tailscale/CGNAT (`100.64.0.0/10`), IPv6 ULA (`fc00::/7`) et
  link-local (`fe80::/10`) ;
- tous les 404/403 des domaines média Polyfin/Jellyfin/Silo/Stremfin/
  StreamFusion/Plex : ces faux positifs ne dépendent plus de l'IP du client ;
- les 404 normaux du WebUI SSDV2 sur son sous-domaine (`/api/v1/`) ;
- la racine `www.<domaine>` en 404 ;
- les chemins de flux opaques de StreamFusion (`/gAAAA...`) ;
- la navigation légitime des applis média (200/206/304) si `media_crawl` est
  actif.

Après déploiement, la posttask supprime une seule fois toutes les décisions
locales existantes. Un fichier marqueur évite de répéter cette opération.

## Mise à jour d'une installation existante

Les anciennes installations peuvent avoir un conteneur CrowdSec avec des ports
malformés (`7422/tcp/tcp`) ou un ancien binding `0.0.0.0:8080`. La pretask
supprime désormais ce conteneur et le recrée proprement. Les données CrowdSec
sont conservées dans les bind mounts.

Procédure unique pour tous les serveurs :

```sh
cd ~/seedbox-compose
git pull
ssdv2ctl app recreate crowdsec
```

Aucune IP personnelle n'est à saisir. Le patch :

- recrée le conteneur CrowdSec avec les bons ports ;
- déploie la whitelist ;
- débloque les décisions locales existantes ;
- vérifie que `whitelist-ssdv2` est bien chargée.

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

La migration initiale de la posttask supprime une fois toutes les décisions
locales. Pour une urgence sur n'importe quel serveur, sans connaître l'IP :

```sh
docker exec crowdsec cscli decisions delete --all
```

## Vérifier

```sh
docker exec crowdsec cscli parsers list | grep whitelist-ssdv2
docker exec crowdsec cscli decisions list
docker exec crowdsec cscli explain --type traefik --log '<ligne de log>'
```

`cscli explain` indique `ignored by whitelist` lorsqu'une requête correspond à
une exclusion.

## Dépannage

- **`Bind for 0.0.0.0:8080 failed: port is already allocated`** : ancien
  conteneur CrowdSec. La pretask le supprime désormais automatiquement.
- **Port LAPI** : Docker publie le LAPI sur un port libre choisi
  automatiquement sur `127.0.0.1`. Aucun conflit avec un autre service ; la
  posttask configure le firewall bouncer avec le port réellement attribué.
- **Whitelist absente** : la posttask vérifie désormais `cscli parsers list` et
  échoue clairement si `whitelist-ssdv2` n'est pas chargée.

## Limites

- Les 404/403 sur les domaines média sont volontairement ignorés : un scanner
  qui probe ces domaines ne sera pas banni. Les applications sont
  authentifiées ; c'est le compromis pour éviter les faux positifs des clients.
- Une whitelist locale empêche CrowdSec de créer de nouvelles décisions, mais
  ne neutralise pas forcément une décision reçue de la blocklist CAPI. Le
  nettoyage de la posttask supprime les décisions présentes au moment de la
  relance ; une décision CAPI peut réapparaître ensuite.
- L'exclusion `media_crawl` est volontairement large pour les applications
  média. La passer à `false` dans `whitelist.yml` restaure un contrôle plus
  strict, au prix de possibles faux positifs.
- Les IP publiques dynamiques doivent être mises à jour dans `whitelist.yml`.
