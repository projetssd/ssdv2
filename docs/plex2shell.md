# Plex2Shell — CVE-2026-96652 / 96654 / 96655 / 96656

Quatre vulnérabilités chainables de Plex Media Server, corrigées dans
**Plex 1.43.3.10861**. La chaine complète permet à un attaquant non authentifié
d'obtenir le jeton propriétaire, d'écrire un `.so` dans `Codecs/` puis de
l'exécuter au démarrage du serveur.

## Chaine d'exploitation

1. **CVE-2026-96652** — SSRF non authentifiée via `/player/timeline`.
2. **CVE-2026-96654** — vol du `PlexOnlineToken`.
3. **CVE-2026-96655** — SSRF du transcoder.
4. **CVE-2026-96656** — écriture arbitraire via
   `TranscoderH264Options=dump-yuv`, chargée depuis `Codecs/`.

Impact : exécution de code, persistance, mineur XMRig, proxy, flood UDP.

## Versions

| Élément | Valeur |
|---|---|
| Version corrigée | `1.43.3.10861` |
| Recommandée | `1.43.5+` |
| Image sans `VERSION` | PMS reste figé à la version de l'image |

## Ce que fait SSDV2

`ssdv2ctl security plex-cve` et le menu **Gestion → Sécurisation système →
Audit Plex (plex2shell)** couvrent :

1. **Version** et variable `VERSION`.
2. **Ports** : 32400 publié sur `0.0.0.0`.
3. **Montages** : `$HOME`, `/tmp`, `/dev/shm`, `/mnt` en écriture.
4. **Sécurité** : `no-new-privileges`, `cap_drop`, rootfs.
5. **Traefik** : middleware `chain-no-auth@file`.
6. **Preferences.xml** : `TranscoderH264Options`.
7. **Codecs/** : `zz*.so`, `.so` hors bundle, queue ELF uniforme.
8. **Logs Plex** : tentatives, codes, IP sources.
9. **Corrélation Traefik** : 32400 direct ou 443.
10. **Autres ports publiés** et Watchtower.

## Menu et cache

Le menu **Gestion → Sécurisation système → Audit Plex (plex2shell)** travaille
sur le dernier audit en cache (`${SETTINGS_STORAGE}/conf/plexcve-status.json`).

- **Option 1** : seul scan du menu ; écrit le cache puis affiche le rapport.
- **Options 2, 4 et 6** : utilisent le cache, sans relancer de scan.
- **Option 2** : `fix-plex --apply --use-cache` ; le cache est supprimé après
  correction, il faut relancer l'option 1 pour actualiser.
- **Options 3 et 5** : ne scannent pas ; elles invalident aussi le cache après
  action.
- Le menu reste ouvert après chaque action ; seul **8** revient au menu parent.
- Les confirmations affichent explicitement `(o/n)`.
- L'entête et le rapport affichent une **recommandation prioritaire** (fermer
  les ports, traiter Watchtower, etc.).

## Accès distant Plex

Plex teste le port public **32400** pour afficher « disponible en dehors du
réseau local ». Comme 32400 est fermé, ce statut peut rester **indisponible**
même si l'accès via le domaine fonctionne.

Configuration correcte :

- `customConnections = https://plex.<domaine>:443` **uniquement** ;
- `ManualPortMappingMode = 0` ;
- `ManualPortMappingPort = 0` ;
- pas de fallback `http://<ip>:32400` ;
- Plex Relay possible en secours, avec bande passante limitée.

```bash
ssdv2ctl security plex-cve fix-remote --apply
```

Le statut Plex peut rester « non disponible » : il teste 32400. Les clients
utilisent `customConnections` sur 443. Tester depuis la 4G avec l'application
Plex. Ne pas rouvrir 32400 pour obtenir le voyant vert.

## Montages médias et symlinks

Les bibliothèques Plex contiennent souvent des symlinks vers `/mnt`
(FUSE decypharr, rclone, etc.). Ces chemins sont propres à chaque utilisateur :
il ne faut pas les coder en dur.

- **Mode générique (défaut)** : `/mnt:/mnt:ro,rslave`. Compatible avec tous
  les sous-chemins `/mnt`, en lecture seule, sans exposer `$HOME`.
- **Mode strict** : montage uniquement des cibles de symlinks détectées, en
  `:ro` (ex. `/mnt/decypharr/alldebrid`). Plus restrictif, mais dépend des
  chemins détectés.
- `~/Medias` et `~/local` restent montés en `:ro`.
- Les transcodes restent sur `/transcode:rw`.
- Le scan détecte `symlink_target_not_mounted` et recommande le mode adapté.

```bash
ssdv2ctl security plex-cve fix-plex --apply --use-cache --media-mode generic
ssdv2ctl security plex-cve fix-plex --apply --use-cache --media-mode strict
```

## Commandes

```bash
ssdv2ctl security plex-cve scan --json
ssdv2ctl security plex-cve report
ssdv2ctl security plex-cve logs
ssdv2ctl security plex-cve fix-plex --dry-run
ssdv2ctl security plex-cve fix-plex --apply
ssdv2ctl security plex-cve close-port --dry-run --ports 32400
ssdv2ctl security plex-cve close-port --apply --ports 32400
ssdv2ctl security plex-cve quarantine --apply
ssdv2ctl security plex-cve selftest
```

## 32400 ou 443 ?

Les logs Plex ne donnent pas le port de destination. Le script corrèle avec le
log d'accès Traefik :

- tentatives Plex **sans** trace Traefik → `direct_32400` ;
- tentatives Plex **avec** trace Traefik → `traefik_443` ;
- les deux → `both`.

Voir `docs/verification-32400-443.md`.

## Correctif manuel

1. Plex ≥ 1.43.3.10861, `VERSION=latest`.
2. Aucun `published_ports` pour 32400 (ou `127.0.0.1:32400:32400`).
3. `chain-no-auth@file` sur la route Plex 443.
4. Retirer `$HOME`, `/tmp`, `/dev/shm` ; monter les médias en `:ro`.
5. `no-new-privileges:true`, `cap_drop: ALL` + `cap_add: CHOWN, DAC_OVERRIDE,
   FOWNER, SETGID, SETUID` (s6/Plex), tmpfs `/tmp`.
6. Vérifier `Codecs/zz*.so` et `TranscoderH264Options`.
7. En cas d'IoC : arrêter, isoler, rotation des secrets, restauration.

## Limites

- Le script ne supprime aucun volume ni média.
- En cas d'IoC, `fix-plex` refuse et propose `quarantine`.
- Les mitigations ne remplacent pas le patch.
- Le log Traefik est volumineux : la corrélation peut prendre quelques secondes.
- Oracle n'est pas inspectable depuis l'hôte : vérifier la console.

## Références

- CVE-2026-96652 / 96654 / 96655 / 96656.
- CISA KEV — Plex2Shell.
- LinuxServer.io — image Plex, variable `VERSION`.
