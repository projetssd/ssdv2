# Cache gate Decypharr (Sonarr v5+)

Passerelle interne SSDV2 entre **Sonarr v5+** et une instance **decypharr**.
Elle transforme les rejets decypharr en `409 Conflict` pour que Sonarr skippe
la release sans creer de pending ni de blocklist.

## Pourquoi

Avec `download_uncached=false`, decypharr refuse les torrents non caches
(`404 torrent_not_cached`) ou renvoie une erreur provider (`502 provider_error`,
`503`). Sonarr **v5** transforme un echec d'ajout au client en
`DownloadClientUnavailableException` : la release part en pending et bloque la
recherche.

Sonarr v4 et Radarr v6 classent deja ces erreurs generiques en `Skipped` :
ils n'ont pas besoin de la gate.

## Portee

| Arr | Gate necessaire ? |
|---|---|
| Sonarr v5+ | Oui |
| Sonarr4k v5+ | Oui |
| Sonarr v4 | Non (deja skippe) |
| Radarr / Radarr4k v6 | Non (deja skippe) |
| qbittorrent / rdtclient | Non concerne |

Une gate est installee **par upstream decypharr utilise par au moins un
Sonarr v5+**. Plusieurs instances decypharr = plusieurs gates.

## Fonctionnement

```text
Sonarr v5+
  |  POST /api/v2/torrents/add
  v
decypharrgate-<instance> (OpenResty + Lua)
  |  inspection du corps JSON
  v
decypharr:8282 / decypharrsonarr:8282
  |
  +- 404 torrent_not_cached / torrent_not_found -> 409 Conflict
  +- 502 provider_error                         -> 409 Conflict
  +- 503 traffic_exceeded / hoster_unavailable  -> 409 Conflict
  +- 509 too_many_active_downloads              -> 509 (pending)
  +- 502 autre (vraie panne)                   -> 502 (pending)
  +- 200 / autre                                -> renvoye tel quel
```

Le client qBittorrent de Sonarr v5 convertit `409` en
`DownloadClientRejectedReleaseException` : la release est skippee, sans pending,
sans file, sans blocklist. Elle reste eligible pour un prochain RSS si elle
devient cachee.

Le corps JSON de decypharr est inspecte : une vraie panne 502 (sans
`provider_error`) et le 509 restent des indisponibilites temporaires (pending).

## Installation

Menu :

```text
Gestion -> Utilitaires -> Cache gate Decypharr (Sonarr v5+)
```

- **1) Installer/mettre a jour les gates manquantes** : cree une gate pour
  chaque upstream decypharr utilise par un Sonarr v5+.
- **2) Configurer les Sonarr v5+ eligibles** : pointe leur download client vers
  la gate.
- **3) Restaurer** : remet les Sonarr vers leur upstream.
- **4) Cache** : augmente le cache DFS d'une instance decypharr (independant).
- **5) Desinstaller une gate** : apres restauration des Sonarr concernes.

Le catalogue propose aussi `decypharrgate` pour la gate par defaut. Les gates
supplementaires sont creees par le menu (`decypharrgate-<instance>`).

### Detection de l'upstream

La pretask :
- detecte les conteneurs decypharr (`cy01/blackhole`, labels `ssdv2.app=decypharr*`,
  hors `decypharrseed` et `decypharrgate*`) ;
- utilise l'upstream fourni par les vars d'une gate custom ;
- sinon lit l'etat `conf/<gate>.upstream` ;
- sinon reprend l'upstream de la gate existante (migration) ;
- sinon selectionne l'unique instance, ou demande laquelle choisir.

La configuration nginx est generee dans
`docker/<user>/<gate>/default.conf` et montee dans le conteneur.

## Questions / reponses

### La gate est-elle utile pour moi ?

- Sonarr v5+ + decypharr + entrees `downloadClientUnavailable` : oui.
- Radarr v6 / Sonarr v4 : non, ces versions skippent deja.
- qbittorrent / rdtclient : non.

### Pourquoi pas Radarr ?

Radarr v6 ne transforme pas un echec generique d'ajout en client indisponible :
`ProcessDownloadDecisions` le classe en `Skipped`. Une gate sur Radarr serait
redondante.

### Plusieurs instances de decypharr ?

Une gate par upstream utilise par un Sonarr v5+ :
- gate legacy : `decypharrgate` ;
- gates additionnelles : `decypharrgate-<instance>`.

Chaque gate a son etat `conf/<gate>.upstream` et sa config
`docker/<user>/<gate>/default.conf`.

### Configurer Sonarr automatiquement ?

Oui : le host du download client est remplace par le nom de la gate
(`decypharrgate` ou `decypharrgate-<instance>`). Le mot de passe utilise l'API
key de l'Arr.

### Et l'ancienne gate manuelle `decypharrsonarr-gate` ?

La pretask de `decypharrgate` lit l'upstream de la gate existante et le
conserve. Si necessaire, changer le host manuellement dans Sonarr.

### Le cache DFS ?

Action separee, applicable a n'importe quelle instance decypharr (y compris
celle utilisee uniquement par Radarr) :
- backup de `config.json` ;
- `disk_cache_size` 500 Mo -> 20 Go ;
- restart de l'instance ;
- verifier l'espace libre.

### Est-ce que ca blocklist ?

Non. `404`, `502 provider_error` et `503` provider sont convertis en `409` ;
Sonarr skippe sans blocklist. Le `509` et une vraie panne `502` restent des
pending.

### Est-ce que ca change `download_uncached` ?

Non.

### Comment desinstaller ?

1. Menu -> `Restaurer` pour les Sonarr de la gate.
2. Menu -> `Desinstaller une gate`.
3. Pour une gate custom, le menu retire aussi `conf/<gate>.upstream` et
   `vars/<gate>.yml`.

Ne pas supprimer l'application via le menu generique avant d'avoir restaure
les Sonarr : ils pointeraient vers un conteneur absent.

La suppression generique SSDV2 tente aussi de retirer un enregistrement DNS
`<gate>`, qui n'existe pas (aucune gate n'en cree) : le message est sans effet.

### Mise a jour

Apres une mise a jour via le menu, la posttask fait `nginx -t` puis
`nginx -s reload`. La config generee est conservee.

## Resume

- Gate interne, sans port publie, sans DNS, sans label Traefik.
- Sonarr v5+ : releases rejetees skippees, 0 pending, 0 blocklist.
- Radarr v6 et Sonarr v4 : non concernes.
- Une gate par upstream decypharr utilise par Sonarr v5+.
- Cache DFS : action separee, reversible via backup.
- Aucune migration de base, aucun fichier media touche.

## Fichiers

```text
patches/20261021_decypharr_cache_gate
patches/20261022_decypharrgate_generic
includes/dockerapps/vars/decypharrgate.yml
includes/dockerapps/pretasks/decypharrgate.yml
includes/dockerapps/posttasks/decypharrgate.yml
includes/dockerapps/templates/decypharrgate/default.conf.j2
includes/config/scripts/decypharrgate.py
includes/menus-decypharrgate.sh
docs/decypharrgate.md
```
