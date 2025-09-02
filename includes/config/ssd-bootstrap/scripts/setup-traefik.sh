#!/bin/bash

# ─────── MODE VERBEUX / SILENCIEUX ─────────────────
QUIET=0
for arg in "$@"; do
  case $arg in
    --silent) QUIET=1 ;;
    --verbose) QUIET=0 ;;
  esac
done

log() { [ "$QUIET" -eq 0 ] && echo "$@"; }
slog() { "$@" > /dev/null 2>&1; }

# ─────── VARIABLES ─────────────────────────────────
log "🐍 Activation du venv et récuperation variables"
source $HOME/seedbox-compose/profile.sh

domain=$(get_from_account_yml user.domain)

STORAGE_PATH="$HOME/seedbox"
IP=$(curl -s ifconfig.me)
ssdv2_file="${STORAGE_PATH}/docker/traefik/rules/ssdv2.toml"

# ─────── SSDV2.TOML ────────────────────────────────
if [ ! -f "$ssdv2_file" ]; then
  log "📄 Création ssdv2.toml"
  cat <<EOF > "$ssdv2_file"
[http.routers]
  [http.routers.ssdv2-rtr]
    entryPoints = ["https"]
    rule = "Host(\`ssdv2.${domain}\`)"
    service = "ssdv2-svc"
    priority = 10
    [http.routers.ssdv2-rtr.tls]
      certresolver = "letsencrypt"

  [http.routers.api-rtr]
    entryPoints = ["https"]
    rule = "Host(\`ssdv2.${domain}\`) && PathPrefix(\`/api/v1\`)"
    service = "api-svc"
    priority = 200
    [http.routers.api-rtr.tls]
      certresolver = "letsencrypt"

  [http.routers.season-rtr]
    entryPoints = ["https"]
    rule = "Host(\`ssdv2.${domain}\`) && PathPrefix(\`/season\`)"
    service = "season-svc"
    priority = 200
    middlewares = ["season-fallback"]
    [http.routers.season-rtr.tls]
      certresolver = "letsencrypt"

[http.services]
  [http.services.season-svc.loadBalancer]
    passHostHeader = true
    [[http.services.season-svc.loadBalancer.servers]]
      url = "http://172.17.0.1:8001"

  [http.services.ssdv2-svc.loadBalancer]
    passHostHeader = true
    [[http.services.ssdv2-svc.loadBalancer.servers]]
      url = "http://172.17.0.1:3000"

  [http.services.api-svc.loadBalancer]
    passHostHeader = true
    [[http.services.api-svc.loadBalancer.servers]]
      url = "http://172.17.0.1:8080"

[http.middlewares]
  [http.middlewares.sse-headers.headers]
    customResponseHeaders.Content-Type = "text/event-stream"
    customResponseHeaders.Cache-Control = "no-cache"
    customResponseHeaders.Connection = "keep-alive"
    customResponseHeaders.X-Accel-Buffering = "no"

  [http.middlewares.season-fallback.redirectRegex]
    regex = "^/season/(.*)$"
    replacement = "/season/index.html"
    permanent = false
EOF

else
  log "✅ ssdv2.toml déjà présent."
fi

exit 0
