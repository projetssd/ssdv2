# Mécanismes SSDV2

Ce document décrit les mécanismes internes introduits pour rendre l'installation,
la réinstallation et la suppression des applications fiables et réversibles.

## Cycle de vie d'une application

1. Le menu lit `includes/config/services-available` et écrit la sélection.
2. `launch_service <app>` résout le fichier `vars/<app>.yml` (version
   personnalisée dans `~/seedbox/vars/` prioritaire sur la version source).
3. `includes/dockerapps/vars/generique.yml` exécute : pretasks → labels/DNS →
   déploiement du conteneur principal → posttasks → registres → SQLite.
4. `suppression_appli <app>` retire conteneurs, volumes, DNS et entrée SQLite.

## Marqueur `SSDV2_PROMPT`

Les applications SSDV2 sont lancées de **deux façons** :

- depuis le **menu CLI** (terminal) ;
- depuis l'**interface Web**, qui exécute `launch_service`/`relance_container` dans un
  terminal interne et doit savoir **quelle question poser** et **comment** la poser.

Sans indication, l'interface **devine** l'invite d'après le texte : c'est fragile (un libellé
modifié casse la détection) et elle ne peut pas savoir qu'un champ est **secret**.

Le marqueur `SSDV2_PROMPT` résout ça :

- **détection fiable** (identifiant stable, pas de devinette) ;
- **type de saisie** : texte, mot de passe, oui/non, choix ;
- **masquage des secrets** : le champ est masqué **et la valeur est retirée des journaux**.

### Format

Une **ligne** émise juste avant de lire :

```text
SSDV2_PROMPT {"id":"ygege.password","label":"Mot de passe YGG","kind":"secret","secret":true}
```

| Champ | Rôle |
|---|---|
| `id` (obligatoire) | Identifiant stable et unique, de préférence `app.champ` (ex. `ygege.username`) |
| `label` | Texte court affiché à l'utilisateur |
| `kind` | `text` (défaut), `secret`, `confirm` (oui/non ou Entrée), `choice` |
| `secret` | `true` pour mot de passe/token/clé → champ masqué + valeur redactée |
| `options` | Pour `choice` : `["openvpn","wireguard"]` ou `[{"value":"5","label":"oauth2-proxy"}]` |

L'interface affiche la question dans un panneau « Action requise » et renvoie la réponse ; la
ligne du marqueur est **filtrée des logs**.

### Utilisation

#### Ansible (`pause:`)

Le marqueur va en **première ligne** du `prompt` (bloc `|`). Pour un secret : `echo: no` **et**
`no_log: true`.

```yaml
- name: Demander le mot de passe YGG
  ansible.builtin.pause:
    prompt: |
      SSDV2_PROMPT {"id":"ygege.password","label":"Mot de passe YGG","kind":"secret","secret":true}
      Enter value for YGG_PASSWORD (your YGG account password)
    echo: no
  register: ygg_password
  no_log: true
```

#### Bash (`read`)

Émettre le marqueur sur **stderr** juste avant la lecture ; `read -s` pour un secret.

```bash
printf 'SSDV2_PROMPT %s\n' '{"id":"plex.login","label":"Login Plex","kind":"text","secret":false}' >&2
printf 'Votre login Plex : ' >&2
read -r PLEX_LOGIN

printf 'SSDV2_PROMPT %s\n' '{"id":"plex.password","label":"Mot de passe Plex","kind":"secret","secret":true}' >&2
printf 'Votre mot de passe Plex : ' >&2
read -rs PLEX_PASSWORD
```

### Erreurs à ne pas faire

- **Ne pas marquer une question.** L'interface repasse en heuristique : ça marche parfois, mais
  casse au moindre changement de libellé (constaté sur `alfred`, `ygege`).
- **`echo: yes` sur un secret.** La valeur est échotée dans les logs. Toujours `echo: no`
  (+ `no_log: true` en Ansible, `read -s` en bash).
- **Mauvais `secret`.** Un mot de passe/token/clé doit être `secret: true` ; sinon il s'affiche
  en clair. Inversement, ne pas tout marquer secret (un chemin, un email restent `text`).
- **Placer une saisie obligatoire derrière `pause()`.** `pause()` est un simple « appuyer sur
  Entrée », **sauté en contexte non interactif** ; il ne doit jamais servir à recueillir une
  information.
- **`id` instable, générique ou dupliqué.** Utiliser `app.champ` ; éviter `login`, `password`
  seuls (risque de collision/ambiguïté).
- **JSON invalide.** Guillemets doubles autour des clés/valeurs ; une ligne, pas de retour à la
  ligne dans le JSON.
- **Marqueur mal placé.** Il doit précéder **immédiatement** la lecture ; sinon l'interface peut
  l'associer à la mauvaise étape.
- **`options` inadaptées.** Pour `choice`, `options` doit contenir **les valeurs attendues par
  le script** (`"1".."5"`), pas seulement un libellé — d'où la forme
  `{"value":"5","label":"oauth2-proxy"}`.
- **Cacher le marqueur.** Ne pas l'enfermer dans un `no_log` global : l'interface doit pouvoir
  le lire (le `no_log` se met sur la tâche de lecture, pas sur le marqueur).
- **Confondre avec une pause de courtoisie.** Un simple « press Enter » n'a pas besoin de
  marqueur ; ne pas le transformer en question.

### À retenir

- Toute **question réelle** → un marqueur `SSDV2_PROMPT` juste avant la lecture.
- Toute **donnée sensible** → `secret: true` + écho coupé.
- Le comportement reste **identique au menu CLI** : le marqueur n'est qu'une information en plus
  lue par l'interface Web.

## Label `ssdv2.app`

À partir de la version courante, tout conteneur géré par SSDV2 porte le label
Docker `ssdv2.app=<pgrole>` (conteneur principal **et** compagnons). Il sert à
retrouver de façon fiable tous les conteneurs d'une application, y compris ceux
dont le nom ne suit pas les conventions.

```
docker ps -a --filter label=ssdv2.app=wordpress
```

Le label est posé par `generique.yml` (principal) et par les templates/posttasks
compagnons.

## Registres par application

Dans `~/seedbox/conf/` :

| Fichier | Contenu |
|---|---|
| `<app>.containers` | noms des conteneurs de l'app (principal + compagnons) |
| `<app>.volumes` | noms des volumes Docker créés pour l'app |
| `<app>.dns` | sous-domaines enregistrés sur Cloudflare (principal + additionnels) |

Ils sont écrits à l'installation par `generique.yml` et par le rôle Cloudflare.
La suppression lit ces registres pour tout nettoyer, puis les supprime.

La suppression combine : **label `ssdv2.app`** + **registres** + **conventions de
nommage** (`db-`, `redis-`, `memcached-`) + **fallback historique** (cas
particuliers codés).

## Cache `account.yml`

`account.yml` (chiffré par Ansible Vault) est déchiffré **une fois par session**
dans `~/seedbox/.account.cache.json` (permissions `0600`), puis lu en mémoire.

- invalidé automatiquement après chaque écriture (`manage_account_yml`) ;
- supprimé en sortie (trap) et purgé au démarrage (résidu si arrêt brutal) ;
- accès par `get_from_account_yml` / `manage_account_yml`.

Gain constaté : ~50× sur les lectures répétées.

## Patch de backfill

`patches/20260916_backfill_registries` reconstruit les registres manquants des
applications installées avant l'introduction du mécanisme. Il est appliqué une
seule fois (`apply_patches`), de façon idempotente.

## Sécurité — points d'attention

- **Ports hôte exposés (`SEC-01`)** : certaines applications publient un port sur
  l'hôte alors que Traefik est actif (`radarr` 7878, `sonarr` 8989, `kasm` 3000,
  `emby` 8096, `jellyfin` 7359/udp, `syncthing`, clients torrent, `wireguard`…).
  Ces accès directs **contournent l'authentification Traefik**. À réserver aux
  usages LAN ou à supprimer de `specific_docker_info.ports` si non désirés.
- **`dashdot` (`SEC-02`)** : conteneur `privileged` avec montage de
  `/var/run/docker.sock` (nécessaire à ses métriques). À installer en
  connaissance de cause ; il donne un accès équivalent root à l'hôte.

## Rechargement automatique après une mise à jour

Les fonctions interactives (`suppression_appli`, `launch_service`, …) sont
chargées dans le shell au login via `profile.sh`. Après un `git pull`, un shell
**déjà ouvert** garderait l'ancienne version en mémoire (un script exécuté ne
peut pas modifier le shell parent).

`profile.sh` installe donc un contrôle léger dans `PROMPT_COMMAND` : à chaque
invite, il compare une **empreinte `stat`** (mtime + taille) de
`includes/{variables,functions,menus}.sh` et de `profile.sh`. Si elle change, il
recharge automatiquement et affiche `[SSDV2] fonctions rechargées (commit X)`.

- Aucune action nécessaire après un `git pull` (au prompt suivant).
- L'enregistrement dans `PROMPT_COMMAND` est idempotent et préserve un
  `PROMPT_COMMAND` existant.
- Portée : **bash interactif** uniquement (zsh non géré).
- **Premier déploiement** : un shell déjà ouvert avant l'ajout de ce mécanisme
  doit être rechargé **une fois** (`source ~/seedbox-compose/profile.sh`) ou
  reconnecté ; ensuite, c'est automatique.

## Tests

- `bats tests/bats` : tests unitaires des fonctions pures.
- `python3 includes/config/scripts/validate_catalogue.py` : cohérence du
  catalogue (fichiers `vars`, casse, références pre/posttasks).
- CI : `.github/workflows/lint.yml` (shellcheck, catalogue, bats, py_compile,
  syntax-check Ansible, YAML, ansible-lint informatif).
