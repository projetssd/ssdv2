#!/bin/bash
set -euo pipefail
trap 'echo "❌ Erreur à la ligne $LINENO"; exit 1' ERR

QUIET=0
for arg in "$@"; do
  case $arg in
    --silent) QUIET=1 ;;
    --verbose) QUIET=0 ;;
  esac
done
log() { [ "$QUIET" -eq 0 ] && echo "$@"; }

source "$HOME/seedbox-compose/profile.sh"

domain=$(get_from_account_yml user.domain)
STORAGE_PATH="$HOME/seedbox"
ssdv2_file="${STORAGE_PATH}/docker/traefik/rules/ssdv2.toml"

if [ ! -f "$ssdv2_file" ]; then
  log "📄 Création $ssdv2_file"
  mkdir -p "$(dirname "$ssdv2_file")"
  cat <<EOF > "$ssdv2_file"
[http.routers]
  [http.routers.ssdv2-rtr]
    entryPoints = ["https"]
    rule = "Host(\`ssdv2.${domain}\`)"
    service = "ssdv2-svc"
    [http.routers.ssdv2-rtr.tls]
      certresolver = "letsencrypt"

  [http.routers.api-rtr]
    entryPoints = ["https"]
    rule = "Host(\`ssdv2.${domain}\`) && PathPrefix(\`/api/v1\`)"
    service = "api-svc"
    [http.routers.api-rtr.tls]
      certresolver = "letsencrypt"

  [http.routers.season-rtr]
    entryPoints = ["https"]
    rule = "Host(\`ssdv2.${domain}\`) && PathPrefix(\`/season\`)"
    service = "season-svc"
    middlewares = ["season-fallback"]
    [http.routers.season-rtr.tls]
      certresolver = "letsencrypt"

[http.services]
  [http.services.season-svc.loadBalancer]
    [[http.services.season-svc.loadBalancer.servers]]
      url = "http://172.17.0.1:8001"

  [http.services.ssdv2-svc.loadBalancer]
    [[http.services.ssdv2-svc.loadBalancer.servers]]
      url = "http://172.17.0.1:3000"

  [http.services.api-svc.loadBalancer]
    [[http.services.api-svc.loadBalancer.servers]]
      url = "http://172.17.0.1:8080"

[http.middlewares]
  [http.middlewares.season-fallback.redirectRegex]
    regex = "^/season/(.*)$"
    replacement = "/season/index.html"
    permanent = false
EOF
else
  log "✅ $ssdv2_file déjà présent."
fi

log "✅ Traefik configuré."
