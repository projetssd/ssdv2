# Audit d'alignement des applications SSDV2

Ce dossier contient un contrôle statique de chaque application du catalogue SSDV2
confrontée au contrat du skill `add-app` : variables, hooks, invites, Traefik,
persistance, permissions, cycle de vie et minimalisme.

Le moteur est en lecture seule : il n'installe, ne supprime et ne modifie aucune
application, aucun conteneur et aucune variable du dépôt.

## Usage

```bash
# Depuis la racine du dépôt
python3 scripts/audit/apps_alignment.py

# Auditer une autre branche ou un autre worktree
python3 scripts/audit/apps_alignment.py --repo /chemin/vers/worktree

# Comparer avec l'audit d'une autre branche
python3 scripts/audit/apps_alignment.py \
  --repo /chemin/worktree --out /tmp/audit-feature \
  --compare docs/audits/apps-alignment.json
```

Options :

| Option | Défaut | Rôle |
|---|---|---|
| `--repo` | `.` | racine du dépôt à auditer |
| `--out` | `docs/audits` | répertoire des livrables (ignoré par Git) |
| `--curated` | `scripts/audit/curated_findings.yml` | constats relus manuellement |
| `--compare` | aucun | JSON d'une autre branche à différencier |
| `--json` | aucun | copie du résumé à un emplacement absolu |

## Sorties

| Fichier | Contenu |
|---|---|
| `apps-alignment.json` | données brutes : constats, questions, états par axe, obsolètes |
| `apps-alignment.csv` | une ligne par application, neuf axes, preuves et remèdes |
| `apps-alignment.md` | synthèse, constats détaillés, chantiers transverses, comparaison |
| `apps-alignment-backlog.md` | lots de correction P0 → P3 |

`docs/audits/` est ignoré par Git : les rapports sont des artefacts dérivés,
régénérables à la demande. Le moteur et le fichier curaté sont versionnés.

## Axes contrôlés

| Axe | Contrôles |
|---|---|
| `catalogue` | `pgrole` = fichier = identifiant, entrée manquante, fichier hors catalogue |
| `deploiement` | image, `docker_deploy_enabled`, `pull_image`, options à la racine |
| `assistance` | marqueur `SSDV2_PROMPT`, pauses de courtoisie, étapes manuelles |
| `secrets` | `docker_no_log`, `no_log`, `echo: no`, secrets fixes, `debug` bavard |
| `traefik` | `intport`, labels bruts, port Web publié, routers, auth |
| `persistance` | `settings.storage`, racine applicative, volumes |
| `permissions` | sous-dossiers UID, `0777`, fichiers de secrets |
| `cycle` | `rm -rf` non gardé, suppressions croisées, réseaux, `wait_for` |
| `minimalisme` | hooks dupliqués, variables mortes |

## Fichier curaté

`curated_findings.yml` a trois sections :

| Section | Rôle |
|---|---|
| `findings` | constats confirmés après relecture humaine, avec `needle` |
| `checks` | points à vérifier, sans conclusion automatique |
| `acknowledged` | écarts volontaires et justifiés, exclus des compteurs |

Chaque entrée `findings` porte un `needle` : si le motif disparaît du fichier
ciblé, l'entrée est classée `stale_curated` dans le JSON au lieu d'être comptée.
Un audit lancé sur une autre branche ne peut donc pas hériter silencieusement de
constats périmés. Une entrée `acknowledged` exige `app`, `code`, `target` et
`reason`, et son application est tracée dans `acknowledged_seen`.

Les familles purement structurelles (`GENLOG`, `FIXEDSECRET`, `PROMPTECHO`, `TZ`,
`NETWORKCLEAN`, `PARTIALDELETE`, `CROSSAPPDELETE`, `WEBHOSTPORT`, etc.) sont
calculées par le script : ne pas les dupliquer dans le fichier curaté.

## Preuve et certitude

Chaque famille de constats porte dans le rapport un déclencheur, un impact et un
niveau de certitude (`confirmé (code)` ou `dépend de l'exécution`). Les hypothèses
testées puis écartées sont listées dans le rapport et documentées dans le code
(`REJECTED`) pour ne pas être rejouées.

## Preuve avant conclusion

Les suppressions croisées ne sont jamais déduites d'un nom (`mariadb`, `redis`,
`mysql`). Le moteur exige une preuve de propriété :

- `CROSSAPPDELETE` : au moins une autre application monte réellement le dossier
  supprimé (`.../docker/<user>/<dossier>`) ; la preuve `fichier:ligne` est citée.
- `OTHERAPPDELETE` : une autre application crée le conteneur supprimé, et
  l'application auditée ne le crée pas elle-même.
- Un conteneur créé par deux applications devient un point à vérifier
  (« définition partagée »), pas une suppression croisée.
- Un dossier supprimé sans propriétaire identifiable devient un point à vérifier.

Deux applications peuvent nommer un conteneur `redis` sans partager le moindre
dossier : le nom seul ne prouve rien.

## Ajouter un contrôle

1. Créer une méthode `check_<famille>` dans la classe `Audit`.
2. Appeler `self.add(app, CODE, axe, sévérité, chemin, ligne, détail)`.
3. Déclarer `CODE` dans `FIXES` (remède), `RULES` (règle du skill) et, si un
   correctif unique ferme la famille, dans `SYSTEMIC`.
4. Documenter le cas dans ce README et relancer pour vérifier l'absence de
   doublon et la stabilité des compteurs.

## Ce que l'audit ne fait pas

Il ne télécharge ni ne démarre aucune image : il ne peut pas certifier le port
réellement écouté, les volumes anonymes implicites, les versions amont, les CVE,
les migrations de base, le DNS, TLS ou les clients machine. Une application sans
constat n'est pas « testée » : elle est seulement conforme aux contrôles
statiques disponibles.
