# Vérifier si les attaques Plex passent par 32400 ou 443

## Méthode

Les logs Plex donnent l'IP source et le chemin, pas le port de destination. Il
faut corréler avec le log d'accès Traefik.

```bash
PLEX_CONFIG="/home/<user>/seedbox/docker/<user>/plex/config/Library/Application Support/Plex Media Server"
TRAEFIK_LOG="/home/<user>/seedbox/docker/traefik/logs/access.log"

grep -RhiE 'poc_|searchOne|sslip\.io|/player/timeline/subscribe' "$PLEX_CONFIG/Logs" | tail -30
grep -aE '91\.92\.40\.202|154\.53\.48\.251|85\.11\.167\.7|/player/timeline/subscribe|searchOne|sslip\.io' "$TRAEFIK_LOG" | tail -30
```

Traefik journalise les codes 400–599. Une tentative bloquée en 400 doit y
apparaître si elle est passée par 443.

## Interprétation

| Logs Plex | Log Traefik | Conclusion |
|---|---|---|
| présents | absents | **32400 direct** |
| présents | présents | **443 via Traefik** (ou les deux) |
| absents | présents | 443 seul |

## Résultat constaté le 25/10/2026

- `91.92.40.202` : présent dans Plex, **absent** de Traefik.
- `154.53.48.251` : présent dans Plex, **absent** de Traefik.
- `85.11.167.7` : présent dans Plex ; dans Traefik uniquement pour d'anciens
  scans sur le port 80, pas la requête Plex.
- `/player/timeline/subscribe` : 12 occurrences dans Plex, **0** dans Traefik.

**Conclusion : attaques directes sur 32400.** La fermeture de 32400 est la
bonne action. 443 reste exposé sans middleware : ajouter
`chain-no-auth@file` sur la route Plex.

## Après fermeture de 32400

1. Vérifier depuis l'extérieur (4G, port checker) que 32400 est fermé.
2. Vérifier la console Oracle : seuls 80/443.
3. Surveiller les logs Plex : si de nouvelles tentatives apparaissent, elles
   passent par 443.
4. Vérifier Traefik pour `/player/timeline/subscribe`, `searchOne`, `sslip.io`.
5. Ajouter le middleware 443.

## Automatisation

`ssdv2ctl security plex-cve scan` calcule `attack_path` et affiche les preuves :

```bash
ssdv2ctl security plex-cve scan --json | jq '.attack_path, .evidence'
```

## Limites

- Le log Traefik est volumineux et peut être roté.
- Les logs Plex peuvent être en heure locale ; la corrélation par IP + chemin +
  hôte est plus fiable qu'une corrélation temporelle stricte.
- Oracle n'est pas inspectable depuis l'hôte.
