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

## Déploiement

Les nouvelles règles Traefik sont rechargées à chaud (`providers.file.watch`).
En revanche, les **labels Docker des applications déjà installées** ne changent
qu'à la recréation du conteneur : après mise à jour des templates, recréer les
applications protégées par OAuth2 pour obtenir le routeur API/SSE.

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
