# OAuth2 Proxy — intégration Traefik

OAuth2 Proxy protège les applications SSDV2 via le mode **ForwardAuth** de
Traefik. Google est le fournisseur d'identité.

## Deux chaînes, deux usages

Le middleware `errors` de Traefik transforme un 401 en page de connexion. Placé
avant le ForwardAuth, il capture **aussi** les 401/403 du backend : une
application dont la session propre a expiré renvoie alors la page OAuth2 alors
que la session Google est valide, ce qui provoque une boucle de réauthentification.

La chaîne OAuth2 est donc scindée :

| Chaîne | Usage | Contenu |
|---|---|---|
| `chain-oauth2-proxy@file` | navigation HTML | `errors` (401 uniquement) + ForwardAuth |
| `chain-oauth2-proxy-api@file` | API, SSE, CLI | ForwardAuth seul, sans `errors` |

Le template générique (`templates/generique/traefik_labels.yml.j2`) génère deux
routeurs pour les applications protégées par OAuth2 :

- `<app>-rtr` : `Host(...) && HeaderRegexp(`Accept`, `(?i)text/html`)`,
  priorité 20, chaîne HTML ;
- `<app>-api-rtr` : `Host(...)`, priorité 10, chaîne API/SSE.

Les 403 applicatifs (CSRF, permissions) ne sont plus interceptés : `errors` ne
traite que les 401.

## Configuration OAuth2 Proxy

Le template `templates/traefik/oauth2-proxy.yml` déploie une version **≥ 7.15.2**
(correctif CVE-2026-40575) avec :

- `--reverse-proxy=true` et `--trusted-proxy-ip` : seuls les réseaux Docker
  déclarés peuvent fournir `X-Forwarded-*` ;
- pas de `--skip-auth-route` : les endpoints `/oauth2/*` sont servis par un
  routeur Traefik dédié, sans ForwardAuth ;
- `--cookie-csrf-per-request=true` et `--cookie-csrf-expire=10m` : connexions
  parallèles (plusieurs onglets) sans collision de cookie CSRF ;
- `--cookie-domain` et `--whitelist-domain` sur le domaine parent pour le
  ForwardAuth multi-sous-domaines.

Le middleware ForwardAuth doit aussi recopier le cookie de session rafraîchi
vers le navigateur :

```toml
[http.middlewares.middlewares-oauth2-proxy.forwardAuth]
  addAuthCookiesToResponse = ["_oauth2_proxy"]
```

Adapter la liste si `--cookie-name` est modifié. Sans cette option, Traefik ne
renvoie pas le `Set-Cookie` de `/oauth2/auth` : le navigateur conserve l'ancien
cookie et oauth2-proxy rejoue un rafraîchissement Google à **chaque** requête
(rafales observées : plus de 100 en une seconde).

Le routeur `oauth2-proxy-path@file` a une priorité de 1000 afin de ne jamais
être éclipsé par un routeur applicatif.

## Pages personnalisées

Les pages `sign_in.html` et `error.html` sont versionnées dans
`includes/dockerapps/templates/traefik/oauth2-proxy-templates/`. Le template
Ansible les copie dans `/etc/oauth2_proxy/templates` (mode 0644) et le conteneur
les monte en lecture seule avec
`--custom-templates-dir=/etc/oauth2_proxy/templates`.

Ce sont des templates Go (`{{define "sign_in.html"}}` /
`{{define "error.html"}}`) compatibles OAuth2 Proxy ≥ 7.15.2. Le formulaire de
connexion doit conserver :

- `action="{{.ProxyPrefix}}/start"` et le champ caché `rd` (destination) ;
- les variables `.StatusCode`, `.SignInMessage`, `.CustomLogin` et `.Footer`.

La page d'erreur couvre 401, 403, 404 et les autres statuts ; le 403 est utilisé
notamment lorsqu'un compte Google n'est pas dans `authenticated-emails-file`.

Après modification, recréer le conteneur `oauth2-proxy` : le dossier est copié
au déploiement, puis monté en lecture seule.

## Déploiement

Les nouvelles règles Traefik sont rechargées à chaud (`providers.file.watch`).
En revanche, les **labels Docker des applications déjà installées** ne changent
qu'à la recréation du conteneur : après mise à jour des templates, recréer les
applications protégées par OAuth2 pour obtenir le routeur API/SSE.

## Application et réparation

L'application sur une installation existante est automatisée par un backend
unique, idempotent : `includes/config/scripts/oauth2_repair.py`.

### Menu

**Sécurisation système → Sécuriser Traefik avec OAuth2 Proxy** :

- **Diagnostic OAuth2 Proxy** : lecture seule ;
- **Réparer / mettre à jour OAuth2 Proxy** : confirmation puis application.

### Terminal

```bash
ssdv2ctl security oauth2 status            # diagnostic JSON
ssdv2ctl security oauth2 repair            # dry-run
ssdv2ctl security oauth2 repair --apply    # applique
ssdv2ctl security oauth2 rollback          # restaure la dernière sauvegarde
```

Le backend peut aussi être appelé directement :

```bash
python3 includes/config/scripts/oauth2_repair.py status
python3 includes/config/scripts/oauth2_repair.py repair --apply
```

### Ce que fait `repair --apply`

1. sauvegarde des règles Traefik dans `~/backup/oauth2-repair/<date>/` ;
2. correction idempotente de `middlewares.toml` et `middlewares-chains.toml` ;
3. installation des pages dans `/etc/oauth2_proxy/templates` ;
4. recréation de `oauth2-proxy` en v7.15.6 si nécessaire, avec test préalable
   sur un port local et sauvegarde `oauth2-proxy-pre-repair` ;
5. génération des routeurs API/SSE de transition pour les applications déjà
   installées, sans recréer leurs conteneurs ;
6. vérification de `/ping`, de la page de connexion et du rendu des erreurs.

Si tout est déjà à jour, le script ne redémarre rien. Les routeurs de transition
peuvent être supprimés après recréation des applications avec les nouveaux
labels (`--no-bridges` ou suppression de `oauth2-api-bridges.toml`).

## Vérification

```bash
# API sans session : 401 non-HTML
curl -sS -o /dev/null -w '%{http_code} %{content_type}\n' \
  https://app.example.tld/api/version

# Navigation sans session : page de connexion OAuth2
curl -sS -o /dev/null -w '%{http_code} %{content_type}\n' \
  -H 'Accept: text/html' https://app.example.tld/

# OAuth2 Proxy
curl -sS -o /dev/null -w '%{http_code}\n' https://oauth2-proxy.example.tld/ping
```

Un `401` avec `content-type: text/html` sur une route API indique que le
routeur API/SSE n'est pas appliqué (conteneur non recréé ou routeur éclipsé).

## WebUI SSDV2

Par défaut la WebUI conserve son authentification interne et n'est pas placée
derrière OAuth2 Proxy. Le mode `proxy` (`WEBUI_AUTH_MODE=proxy`,
`WEBUI_TRUSTED_PROXIES`, `WEBUI_PROXY_IDENTITY_HEADER=X-Auth-Request-Email`)
permet une authentification Google unique ; il exige que le routeur de la WebUI
utilise une chaîne OAuth2 et que les en-têtes `X-Auth-Request-*` soient écrasés
par Traefik (`authResponseHeaders`).
