# Plex public HTTPS (opt-in)

Ce mode expose **uniquement Plex** sur `https://plex.<domaine>` en direct
(port 443, certificat Let's Encrypt, sans port dans l'URL). Les autres
applications restent accessibles via Cloudflare ; l'accès direct public à ces
applications renvoie `403`.

Il est **désactivé par défaut**. Les installations existantes conservent leur
comportement tant que `plex.public_https` n'est pas activé.

## Pourquoi

Le proxy Cloudflare peut limiter le débit et ajouter de la latence sur les
flux Plex. Le mode public HTTPS fait passer les clients Plex **directement**
par Traefik sur le VPS, tout en gardant les autres applications derrière
Cloudflare.

## Modèle de sécurité

| Élément | Configuration |
|---|---|
| DNS Plex | `A` **DNS-only** (gris), pas de proxy Cloudflare |
| Oracle | ingress `443` depuis `0.0.0.0/0` ; `32400` fermé |
| Traefik Plex | entrypoint `https` uniquement |
| Middleware Plex | `chain-plex@file` = CrowdSec + rate-limit + secure-headers, **sans allowlist** |
| Backend Plex | `scheme=https`, `serverstransport=plex-transport@file`, port `32400` |
| `plex-transport` | `insecureSkipVerify=true` (certificat `plex.direct`) |
| Autres applications | `middlewares-allowlist@file` ajouté aux chaînes non-Plex |
| Allowlist | **Cloudflare IPv4/IPv6 uniquement** (aucun réseau privé/Tailscale) |
| 32400 | publication `127.0.0.1:32400` uniquement, jamais `0.0.0.0` |
| Plex Relay | désactivé |
| Plex Remote Access | `secureConnections=0` (Required), `PublishServerOnPlexOnlineKey=1`, `customConnections=https://plex.<domaine>` |
| CrowdSec | whitelist `local/plex-clients-whitelist` limitée au routeur Plex et aux chemins de lecture |

> L'allowlist utilise l'adresse source directe de la connexion. Derrière
> Cloudflare, la source est une IP Cloudflare (autorisée) ; depuis Internet en
> direct, la source est publique (refusée, `403`). Les réseaux privés et
> Tailscale ne sont volontairement **pas** ajoutés : aucun client n'accède aux
> applications via Traefik en direct sur ces réseaux.

## Prérequis

1. Plex ≥ `1.43.3.10861` (recommandé `1.43.5+`), `VERSION=latest`.
2. Cloudflare configuré dans SSDV2 (pour le DNS et le certificat DNS-01).
3. Oracle : ingress `443` ouvert, `32400` fermé.
4. Le sous-domaine Plex existe (`sub.plex.plex` dans `account.yml`).

## Activation

> Si `~/seedbox/vars/plex.yml` existe (personnalisation), `ssdv2ctl app
> reinstall plex` utilise cet override à la place du playbook du dépôt.
> L'option de menu 9 n'est pas concernée (elle recrée le conteneur), mais
> l'override doit être mis à jour ou supprimé pour que la réinstallation
> applique les labels conditionnels.

### Menu

**Gestion → Sécurisation système → Audit Plex (plex2shell) → 9) Activer Plex
public HTTPS**.

Le menu affiche les conséquences, demande confirmation, puis :

1. écrit `plex.public_https: true` dans `account.yml` ;
2. régénère les règles Traefik (allowlist + `chain-plex` + `plex-transport`) ;
3. passe le DNS Plex en DNS-only ;
4. recrée Plex avec `chain-plex@file`, backend HTTPS et `127.0.0.1:32400` ;
5. applique les préférences Plex via l'API HTTPS locale ;
6. vérifie `/identity`, `/web`, le port loopback et les préférences ;
7. installe la whitelist CrowdSec `local/plex-clients-whitelist` et recharge
   CrowdSec (évite les bans en boucle d'Infuse/Plex Web).

### CLI

```bash
ssdv2ctl security plex-cve public-https --dry-run
ssdv2ctl security plex-cve public-https --apply
```

`fix-plex --apply --public-https` ne recrée que le conteneur Plex (labels,
port, prefs) : il ne modifie ni le DNS ni `plex.public_https`. Pour le mode
complet, utiliser `public-https --apply`.

> Les applications compagnon sont réalignées à leur prochain déploiement
> (`ssdv2ctl app reinstall tautulli` / `plexautolanguages`) : Tautulli passe
> sur `https://plex:32400` (`verify_ssl_cert=0`) et `plexautolanguages` sur
> `https://plex.<domaine>`. En mode public, `plex.token` doit être un token
> valide (le token serveur `PlexOnlineToken` convient).

Désactivation :

```bash
ssdv2ctl security plex-cve public-https --disable --apply
```

Rollback complet depuis une sauvegarde :

```bash
ssdv2ctl security plex-cve rollback --backup ~/seedbox/backup/plexsec/<date> --apply
```

Le rollback restaure `Preferences.xml`, les règles Traefik, le flag
`plex.public_https`, le DNS Plex et le conteneur Plex (inspect sauvegardé).

## Préférences Plex

| Préférence | Valeur | Rôle |
|---|---|---|
| `customConnections` | `https://plex.<domaine>` | URL publiée aux clients, sans `:443` |
| `ManualPortMappingMode` | `0` | pas de mappage manuel |
| `ManualPortMappingPort` | `0` | port manuel neutralisé |
| `secureConnections` | `0` | Required |
| `RelayEnabled` | `0` | pas de relais Plex |
| `PublishServerOnPlexOnlineKey` | `1` | publication sur plex.tv |

`secureConnections=Required` peut refuser l'API Plex en HTTP local. Le script
utilise donc `https://127.0.0.1:32400/:/prefs` avec vérification du certificat
désactivée (certificat `plex.direct`).

## Vérifications

Depuis un réseau extérieur (4G) :

```bash
curl -sI https://plex.<domaine>/identity          # 200, certificat valide
curl -sI https://plex.<domaine>/web               # 302
curl -r 0-1023 https://plex.<domaine>/library/parts/<id>/file.mkv  # 206
```

Depuis le VPS :

```bash
docker port plex
# attendu : 127.0.0.1:32400 uniquement

curl -k -s -o /dev/null -w '%{http_code}\n' \
  --resolve plex.<domaine>:443:127.0.0.1 https://plex.<domaine>/identity
# 200 (Plex n'utilise pas l'allowlist)
```

Depuis une machine externe **hors Cloudflare** (ou avec une IP publique non
autorisée) :

```bash
curl -k -s -o /dev/null -w '%{http_code}\n' https://sonarr.<domaine>/
# 403 attendu (allowlist non-Plex)
```

Vérifier aussi :

- `ssdv2ctl security plex-cve scan --json` : `public_https=true`, aucune
  alerte `traefik_allowlist_missing`, `plex_loopback_port_missing`, etc. ;
- `cscli decisions list` : aucune décision sur l'IP du foyer ;
- `cscli parsers list | grep plex-clients-whitelist` : whitelist active ;
- `grep -i 'x-plex-token=' ~/seedbox/docker/traefik/logs/access.log` :
  aucun token en clair (voir la section Sécurité).

## Faux négatif « Remote Access »

Plex teste le port public **32400** pour afficher le voyant vert. Comme 32400
est fermé, le statut peut rester **jaune/indisponible** même si l'accès via
`https://plex.<domaine>` fonctionne. C'est attendu.

- Ne pas rouvrir 32400 pour obtenir le voyant vert.
- Se fier à `customConnections` et à un test réel depuis la 4G.
- Le NAT hairpin du VPS peut également fausser le test depuis le serveur.

## Pièges connus

- **Traefik doit utiliser `plex-transport`** : le certificat Plex est un
  certificat `plex.direct`, pas le certificat Let's Encrypt du domaine.
- **32400 doit rester loopback** : une publication `0.0.0.0:32400` réintroduit
  l'exposition publique.
- **Une seule liste Cloudflare** : `traefik_cloudflare_ips` dans
  `includes/dockerapps/vars/traefik.yml` alimente `forwardedHeaders` et
  l'allowlist.
- **Ordre de génération Traefik** : les middlewares sont écrits avant les
  chaînes pour éviter l'erreur transitoire
  `middleware "middlewares-allowlist@file" does not exist`.
- **Allowlist** : les autres applications ne sont plus joignables en direct
  depuis une IP publique. C'est le comportement voulu ; **seul Cloudflare**
  est autorisé (pas de réseau privé/Tailscale).
- **CrowdSec** : Plex Web et Infuse parcourent la bibliothèque et provoquent
  des `404` de vignettes/composites. Sans whitelist, les scénarios
  `http-probing` et `http-crawl-non_statics` bannissent l'IP du foyer, ce qui
  coupe **toutes** les apps (la décision est par IP, pas par host). La
  whitelist `local/plex-clients-whitelist` limite l'exemption au routeur
  `plex-rtr` et aux chemins de lecture (`/library/`, `/hubs/`, `/playlists/`,
  `/video/:/`, `/photo/:/`, `/web/`). Les scans (`/wp-admin`, `/.env`, CVE)
  restent détectés.
- **Journal Traefik** : `accessLog` ne conserve que les codes `400-599`.
  Journaliser les `2xx/206` ajoutait une ligne par segment vidéo (plusieurs
  Go par semaine) et exposait les tokens Plex.
- **Applications compagnon** : `secureConnections=Required` casse les accès
  HTTP internes. `tautulli` est réaligné sur `https://plex:32400`
  (`verify_ssl_cert=0`) et `plexautolanguages` sur
  `https://plex.<domaine>` (certificat Let's Encrypt valide, l'app ne sait pas
  ignorer un certificat auto-signé).
  ⚠️ `plex.token` doit être un **token de compte** (login Plex), jamais le
  `PlexOnlineToken` du serveur : python-plexapi ré-enregistre alors le serveur
  comme `provides="controller"` sur plex.tv, et les clients Plex ne le voient
  plus (accueil vide). Le posttask arrête automatiquement
  `plexautolanguages` dans ce cas.
- **Plex Web sur Safari** : Safari ne décode pas le HEVC dans un conteneur
  MPEG-TS. Plex « copie » la vidéo HEVC pour Safari, ce qui donne un écran
  noir avec du son. Contournement côté client : forcer un débit inférieur à
  la source dans *Réglages → Plex Web → Lecteur → Qualité vidéo* (par ex.
  `1080p 8 Mbps`), ou utiliser Chrome/Edge, l'app Plex ou Infuse.

## Sécurité Plex

- Appliquer les correctifs Plex2Shell : `VERSION=latest`, Plex ≥ 1.43.3.10861.
- Activer la 2FA sur le compte Plex.
- Ne pas exposer 32400.
- Surveiller les tokens Plex dans `access.log` : privilégier l'en-tête
  `X-Plex-Token` (les clients Plex le font) plutôt que la query string.
  Le log Traefik est en `0600` et rotationné ; en cas de fuite, changer le
  token Plex et vérifier les sessions.
- En cas d'IoC (`Codecs/zz*.so`, `TranscoderH264Options` suspect), utiliser
  la quarantaine et la rotation des secrets, pas un simple redémarrage.

## Fichiers concernés

- `includes/dockerapps/vars/traefik.yml`
- `includes/dockerapps/templates/traefik/traefik.yml.j2`
- `includes/dockerapps/templates/traefik/middlewares.toml.j2`
- `includes/dockerapps/templates/traefik/middlewares-chains.toml.j2`
- `includes/config/roles/cloudflare/tasks/main.yml`
- `includes/dockerapps/templates/plex/defaults/main.yml`
- `includes/dockerapps/vars/plex.yml`
- `includes/config/playbooks/plex_dns.yml`
- `includes/config/scripts/plexcve.py`
- `includes/config/files/crowdsec/plex-clients-whitelist.yaml`
- `includes/dockerapps/posttasks/crowdsec.yml`
- `includes/dockerapps/posttasks/tautulli.yml`
- `includes/dockerapps/posttasks/plexautolanguages.yml`
- `includes/dockerapps/vars/plexautolanguages.yml`
- `includes/config/scripts/recreate_app_container.py`
- `includes/menus-plexcve.sh`
- `ssdv2ctl`
