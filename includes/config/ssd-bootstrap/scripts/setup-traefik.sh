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
email=$(get_from_account_yml cloudflare.login)
htpsswd=$(get_from_account_yml user.htpwd)

STORAGE_PATH="$HOME/seedbox"
IP=$(curl -s ifconfig.me)
middlewares_file="${STORAGE_PATH}/docker/traefik/rules/middlewares.toml"
middlewares_chains_file="${STORAGE_PATH}/docker/traefik/rules/middlewares-chains.toml"
ssdv2_file="${STORAGE_PATH}/docker/traefik/rules/ssdv2.toml"

# ─────── TRAEFIK ───────────────────────────────────
if docker ps --format '{{.Names}}' | grep -qw traefik; then
  log "⚠️  Traefik déjà en cours d'exécution. Ignoré."
else
  log "🚀 Lancement de Traefik..."

  mkdir -p "$STORAGE_PATH/docker/traefik/acme" \
           "$STORAGE_PATH/docker/traefik/rules" \
           "$STORAGE_PATH/docker/traefik/logs"

  sudo touch "$STORAGE_PATH/docker/traefik/acme/acme.json"
  sudo chmod 600 "$STORAGE_PATH/docker/traefik/acme/acme.json"
  sudo touch "$STORAGE_PATH/docker/traefik/logs/access.log"

  if ! docker network ls | grep -q traefik_proxy; then
    slog docker network create traefik_proxy
  fi

  docker run -d \
    --name traefik \
    --network traefik_proxy \
    --restart unless-stopped \
    -p 80:80 -p 443:443 \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    -v "${STORAGE_PATH}/docker/traefik/acme/acme.json:/acme.json" \
    -v "${STORAGE_PATH}/docker/traefik/rules:/rules" \
    -v "${STORAGE_PATH}/docker/traefik/logs:/logs" \
    -e CF_API_EMAIL=$email \
    -e CF_API_KEY=$cloudflare_api_key \
    --label "traefik.enable=true" \
    --label "traefik.http.middlewares.redirect-to-https.redirectscheme.scheme=https" \
    --label "traefik.http.routers.http-catchall.entrypoints=http" \
    --label "traefik.http.routers.http-catchall.middlewares=redirect-to-https" \
    --label "traefik.http.routers.http-catchall.rule=HostRegexp(\`{host:.+}\`)" \
    --label "traefik.http.routers.traefik-rtr.entrypoints=http,https" \
    --label "traefik.http.routers.traefik-rtr.middlewares=chain-basic-auth@file" \
    --label "traefik.http.routers.traefik-rtr.rule=Host(\`traefik.$domain\`)" \
    --label "traefik.http.routers.traefik-rtr.service=api@internal" \
    --label "traefik.http.routers.traefik-rtr.tls=true" \
    --label "traefik.http.routers.traefik-rtr.tls.certresolver=letsencrypt" \
    --label "traefik.http.routers.traefik-rtr.tls.domains[0].main=$domain" \
    --label "traefik.http.routers.traefik-rtr.tls.domains[0].sans=*.$domain" \
    --label "traefik.http.routers.fastapi.entrypoints=https" \
    --label "traefik.http.routers.fastapi.rule=Host(\`ssdv2.lastharo.fr\`) && PathPrefix(\`/api/v1\`)" \
    --label "traefik.http.routers.fastapi.tls=true" \
    --label "traefik.http.routers.fastapi.tls.certresolver=letsencrypt" \
    --label "traefik.http.services.fastapi.loadbalancer.server.url=http://172.17.0.1:8080" \
    traefik:v3.0 \
    --global.checkNewVersion=true \
    --global.sendAnonymousUsage=true \
    --entrypoints.http.address=:80 \
    --entrypoints.https.address=:443 \
    --entrypoints.web.http.redirections.entrypoint.to=https \
    --entrypoints.web.http.redirections.entrypoint.scheme=https \
    --entrypoints.web.http.redirections.entrypoint.permanent=true \
    --api=true \
    --api.dashboard=true \
    --entrypoints.https.forwardedHeaders.trustedIPs=173.245.48.0/20,103.21.244.0/22,103.22.200.0/22,103.31.4.0/22,141.101.64.0/18,108.162.192.0/18,190.93.240.0/20,188.114.96.0/20,197.234.240.0/22,198.41.128.0/17,162.158.0.0/15,104.16.0.0/12,172.64.0.0/13,131.0.72.0/22 \
    --log=true \
    --log.filePath=/logs/traefik.log \
    --log.level=DEBUG \
    --accessLog=true \
    --accessLog.bufferingSize=100 \
    --accessLog.filters.statusCodes=204-299,400-499,500-599 \
    --providers.docker=true \
    --providers.docker.exposedByDefault=false \
    --providers.docker.network=traefik_proxy \
    --entrypoints.https.http.tls=true \
    --entrypoints.https.http.tls.certresolver=letsencrypt \
    --providers.file.directory=/rules \
    --providers.file.watch=true \
    --certificatesResolvers.letsencrypt.acme.email=$email \
    --certificatesResolvers.letsencrypt.acme.storage=/acme.json \
    --certificatesResolvers.letsencrypt.acme.dnsChallenge.provider=cloudflare \
    --certificatesResolvers.letsencrypt.acme.dnsChallenge.resolvers=1.1.1.1:53,1.0.0.1:53 \
    --certificatesResolvers.letsencrypt.acme.dnsChallenge.delayBeforeCheck=90
fi

# ─────── MIDDLEWARES.TOML ──────────────────────────
if [ ! -f "$middlewares_file" ]; then
  log "📄 Création middlewares.toml"
  cat <<EOL > "$middlewares_file"
[http.middlewares.middlewares-basic-auth]
  [http.middlewares.middlewares-basic-auth.basicAuth]
    users = [
      "${htpasswd}",
    ]

  [http.middlewares.middlewares-rate-limit]
    [http.middlewares.middlewares-rate-limit.rateLimit]
      average = 100
      burst = 50

  [http.middlewares.middlewares-secure-headers]
    [http.middlewares.middlewares-secure-headers.headers]
      accessControlAllowMethods= ["GET", "OPTIONS", "PUT"]
      accessControlMaxAge = 100
      hostsProxyHeaders = ["X-Forwarded-Host"]
      sslRedirect = true
      stsSeconds = 63072000
      stsIncludeSubdomains = true
      stsPreload = true
      forceSTSHeader = true
      customFrameOptionsValue = "SAMEORIGIN"
      contentTypeNosniff = true 
      browserXssFilter = true 
      referrerPolicy = "same-origin" 
      featurePolicy = "camera 'none'; geolocation 'none'; microphone 'none'; payment 'none'; usb 'none'; vr 'none';" 
      [http.middlewares.middlewares-secure-headers.headers.customResponseHeaders]
        X-Robots-Tag = "none,noarchive,nosnippet,notranslate,noimageindex,"
        server = ""

  [http.middlewares.middlewares-oauth]
    [http.middlewares.middlewares-oauth.forwardAuth]
      address = "http://oauth:4181"
      trustForwardHeader = true
      authResponseHeaders = ["X-Forwarded-User"]

  [http.middlewares.middlewares-authelia]
    [http.middlewares.middlewares-authelia.forwardAuth]
      address = "http://authelia:9091/api/verify?rd=https://authelia.$domain"
      trustForwardHeader = true
      authResponseHeaders = ["Remote-User", "Remote-Groups"]
EOL
else
  log "✅ middlewares.toml déjà présent."
fi

# ─────── CHAINS.TOML ───────────────────────────────
if [ ! -f "$middlewares_chains_file" ]; then
  log "📄 Création middlewares-chains.toml"
  cat <<EOL > "$middlewares_chains_file"
[http.middlewares]
  [http.middlewares.chain-no-auth]
    [http.middlewares.chain-no-auth.chain]
      middlewares = [ "middlewares-rate-limit", "middlewares-secure-headers"]

  [http.middlewares.chain-basic-auth]
    [http.middlewares.chain-basic-auth.chain]
      middlewares = [ "middlewares-rate-limit", "middlewares-secure-headers", "middlewares-basic-auth"]

  [http.middlewares.chain-oauth]
    [http.middlewares.chain-oauth.chain]
      middlewares = [ "middlewares-rate-limit", "middlewares-secure-headers", "middlewares-oauth"]

  [http.middlewares.chain-authelia]
    [http.middlewares.chain-authelia.chain]
      middlewares = [ "middlewares-rate-limit", "middlewares-secure-headers", "middlewares-authelia"]
EOL
else
  log "✅ middlewares-chains.toml déjà présent."
fi

# ─────── SSDV2.TOML ────────────────────────────────
if [ ! -f "$ssdv2_file" ]; then
  log "📄 Création ssdv2.toml"
  cat <<EOL > "$ssdv2_file"
[http.routers]
  [http.routers.ssdv2-rtr]
      entryPoints = ["https"]
      rule = "Host(\`ssdv2.$domain\`)"
      service = "ssdv2-svc"
      [http.routers.ssdv2-rtr.tls]
        certresolver = "letsencrypt"

  [http.routers.api-rtr]
      entryPoints = ["https"]
      rule = "Host(\`ssdv2.$domain\`) && PathPrefix(\`/api/v1/scripts\`)"
      service = "api-svc"
      [http.routers.api-rtr.tls]
        certresolver = "letsencrypt"

[http.services]
  [http.services.ssdv2-svc]
    [http.services.ssdv2-svc.loadBalancer]
      passHostHeader = true
      [[http.services.ssdv2-svc.loadBalancer.servers]]
        url = "http://$IP:3000"

  [http.services.api-svc]
    [http.services.api-svc.loadBalancer]
      passHostHeader = true
      [[http.services.api-svc.loadBalancer.servers]]
        url = "http://$IP:8080"
EOL
else
  log "✅ ssdv2.toml déjà présent."
fi

log "🎉 Traefik déployé pour $domain"

exit 0
