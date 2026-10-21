# Cache gate Decypharr (Sonarr v5)

Utilitaire optionnel SSDV2 : une passerelle nginx interne entre Sonarr v5 et
decypharr, qui transforme le refus `404 torrent_not_cached` en `409 Conflict`.

## Pourquoi

Avec `download_uncached=false`, decypharr refuse les torrents non cachés.
Sonarr v5 interprete ce `404` comme un client de telechargement indisponible et
cree une entree `downloadClientUnavailable` dans Activity -> Queue. La release
reste bloquee en pending, alors qu'elle n'a jamais ete telechargee.

Sonarr v4 n'avait pas ce comportement : le refus etait skippe. La gate restaure
ce comportement sans downgrade.

## Fonctionnement

```text
Sonarr v5
  |  POST /api/v2/torrents/add
  v
decypharrgate (OpenResty + Lua)
  |  inspection du corps JSON
  v
decypharrsonarr:8282
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

La gate lit le corps JSON de decypharr et ne convertit que les vrais rejets :
torrent non cache, `provider_error` (ex. « no peer ») et erreurs provider 503.
Une vraie panne 502 (sans `provider_error`) et le 509 « trop de telechargements
actifs » restent des indisponibilites temporaires : Sonarr les garde en pending
et reessaiera, sans blocklist.

Apres une mise a jour via le menu, la posttask recharge nginx automatiquement
(`nginx -t` puis `nginx -s reload`).

## Installation

1. `Gestion -> Utilitaires -> Cache gate Decypharr (Sonarr v5)`
   ou `Ajout/Suppression -> Installer Application -> decypharrgate`.
2. Choisir les options dans les questions.
3. Verifier : `curl http://decypharrgate:8282/api/v2/app/version` depuis Sonarr.

La gate est interne : aucun port publie, aucun DNS, aucun label Traefik.

## Questions / reponses

### La gate est-elle utile pour moi ?

- Sonarr v5 + decypharr + entrees `downloadClientUnavailable` : oui.
- Sonarr v4 : non, v4 skippe deja.
- Pas de decypharr : non.

### Configurer Sonarr automatiquement ?

- Oui (defaut) : le host du download client passe a `decypharrgate:8282`.
- Non : la gate est installee, Sonarr reste inchange ; configuration manuelle
  dans Settings -> Download Clients.
- Si le host actuel est `decypharrsonarr-gate` (ancienne gate manuelle), la
  configuration automatique refuse : changer le host a la main vers
  `decypharrgate` (ou d'abord vers `decypharrsonarr`).

### Radarr ?

Non pris en charge dans cette version. Perimetre Sonarr.

### Passer le cache DFS a 20 Go ?

- Optionnel, refus par defaut.
- Backup de `config.json`, `disk_cache_size` 500 Mo -> 20 Go, restart de
  `decypharrsonarr`.
- Recommande si les logs contiennent `disk limit reached`.
- Verifier l'espace libre du disque.

### Est-ce que ca blocklist ?

Non. Les rejets `404` (non cache), `502 provider_error` et `503` provider sont
convertis en `409` ; Sonarr skippe sans blocklist. Le `509` et une vraie panne
`502` restent des pending (client indisponible/occupe).

### Est-ce que ca change `download_uncached` ?

Non.

### Comment desinstaller ?

1. Menu -> `Restaurer Sonarr` (host -> `decypharrsonarr`).
2. Menu -> `Desinstaller la gate`.

Ne pas supprimer l'application via le menu generique avant d'avoir restaure
Sonarr : Sonarr pointerait vers un conteneur absent.

La suppression generique SSDV2 tente aussi de retirer un enregistrement DNS
`decypharrgate`, qui n'existe pas (la gate n'en cree pas) : le message est sans
effet.

## Resume

- Gate nginx interne, sans port ni DNS.
- Releases non cachees skippees : 0 pending, 0 file, 0 blocklist.
- Changements Sonarr et cache DFS optionnels, detectes et reversibles.
- Aucune migration de base, aucun fichier media touche.
- Rollback : `Restaurer Sonarr` puis `Desinstaller la gate`.

## Fichiers

```text
patches/20261021_decypharr_cache_gate
includes/dockerapps/vars/decypharrgate.yml
includes/dockerapps/posttasks/decypharrgate.yml
includes/dockerapps/templates/decypharrgate/default.conf
includes/config/scripts/decypharrgate.py
includes/menus-decypharrgate.sh
docs/decypharrgate.md
```
