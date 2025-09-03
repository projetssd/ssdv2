#!/bin/bash
set -euo pipefail
trap 'echo "❌ Erreur à la ligne $LINENO"; exit 1' ERR

# ─────── MODE VERBEUX / SILENCIEUX ────────────────
QUIET=0
for arg in "$@"; do
  case $arg in
    --silent) QUIET=1 ;;
    --verbose) QUIET=0 ;;
  esac
done
log() { [ "$QUIET" -eq 0 ] && echo "$@"; }

# ─────── VARIABLES DE BASE ───────────────────────
source "$HOME/seedbox-compose/profile.sh"

domain=$(get_from_account_yml user.domain)
email=$(get_from_account_yml cloudflare.login)
cloudflare_api_key=$(get_from_account_yml cloudflare.api)
IP=$(curl -4 -s ifconfig.me)

USERNAME=$(id -un)
PROJECT_DIR="$HOME/seedbox/docker/$USERNAME/projet-ssd"
SSD_DIR="$PROJECT_DIR/ssd-backend"
SSD_FRONTEND_DIR="$PROJECT_DIR/ssd-frontend"
SAISON_FRONTEND_DIR="$PROJECT_DIR/saison-frontend"
mkdir -p "$PROJECT_DIR"

# ─────── ENVIRONNEMENT NODE / PM2 ────────────────
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  . "$NVM_DIR/nvm.sh"
  nvm use default >/dev/null || true
fi

export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"

if ! command -v pm2 >/dev/null 2>&1; then
  log "❌ pm2 introuvable."
  log "➡️  Lance 'make install-system' puis recharge ton shell avec : source ~/.bashrc"
  exit 1
fi

# ─────── DNS CLOUDFLARE ─────────────────────────
log "🌐 Vérification DNS Cloudflare..."
zone_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$domain" \
  -H "X-Auth-Email: $email" \
  -H "X-Auth-Key: $cloudflare_api_key" \
  -H "Content-Type: application/json" | jq -r '.result[0].id')

[ -z "$zone_id" ] || [ "$zone_id" = "null" ] && {
  log "❌ Zone ID introuvable pour $domain"
  exit 1
}

check_or_create_dns() {
  sub="$1"
  full_name=$([ -n "$sub" ] && echo "$sub.$domain" || echo "$domain")

  existing=$(curl -s -X GET \
    "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?name=$full_name" \
    -H "X-Auth-Email: $email" -H "X-Auth-Key: $cloudflare_api_key" \
    -H "Content-Type: application/json" | jq -r '.result[0].id')

  if [ -z "$existing" ] || [ "$existing" = "null" ]; then
    log "➕ Ajout DNS $full_name"
    curl -s -X POST \
      "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
      -H "X-Auth-Email: $email" \
      -H "X-Auth-Key: $cloudflare_api_key" \
      -H "Content-Type: application/json" \
      --data "{
        \"type\": \"A\",
        \"name\": \"$full_name\",
        \"content\": \"$IP\",
        \"ttl\": 120,
        \"proxied\": true
      }" | jq -r '.success'
  else
    log "✅ DNS $full_name déjà existant."
  fi
}

check_or_create_dns "ssdv2"

# ─────── DEPLOIEMENT DES APPS ───────────────────
pm2 stop all &> /dev/null || true
pm2 delete all &> /dev/null || true

log "♻️ Clonage dépôts..."
rm -rf "$SSD_DIR" "$SSD_FRONTEND_DIR" "$SAISON_FRONTEND_DIR"
git clone https://github.com/laster13/ssd-backend.git "$SSD_DIR"
git clone https://github.com/laster13/ssd-frontend.git "$SSD_FRONTEND_DIR"
git clone https://github.com/laster13/saison-frontend.git "$SAISON_FRONTEND_DIR"

# .env fichiers
cat <<EOT > "$SSD_FRONTEND_DIR/.env"
VITE_BACKEND_URL_HTTPS=https://ssdv2.$domain
VITE_API_BASE_URL=https://ssdv2.$domain/api/v1
EOT

cat <<EOT > "$SSD_DIR/.env"
DEBUG=False
COOKIE_SECURE=True
COOKIE_DOMAIN=ssdv2.$domain
JWT_SECRET_KEY=$(openssl rand -hex 32)
JWT_ALGORITHM=HS256
EOT

cat <<EOT > "$SAISON_FRONTEND_DIR/.env"
DATABASE_URL=local.db
VITE_API_BASE_URL=https://ssdv2.$domain/api/v1
VITE_BACKEND_URL_HTTPS=https://ssdv2.$domain
EOT

# Backend
log "♻️ Installation backend..."
cd "$SSD_DIR"
pip3 install poetry &> /dev/null || true
poetry env use python3.11 || true
poetry install &> /dev/null

log "🚀 Lancement backend avec PM2..."
pm2 start "poetry run bash start.sh" --name backend --cwd "$SSD_DIR"

# Frontend
log "♻️ Compilation frontend..."
cd "$SSD_FRONTEND_DIR"
pnpm install &> /dev/null
pnpm run build &> /dev/null
pm2 start "ORIGIN=https://ssdv2.$domain node build" \
  --name frontend --cwd "$SSD_FRONTEND_DIR"

# Saison-frontend
log "♻️ Compilation saison-frontend..."
cd "$SAISON_FRONTEND_DIR"
pnpm install &> /dev/null
pnpm run build &> /dev/null
PORT=8001 pm2 start "node build" \
  --name saison-frontend --cwd "$SAISON_FRONTEND_DIR"

log "✅ Déploiement terminé."
