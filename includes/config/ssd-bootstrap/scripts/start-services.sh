#!/bin/bash
set -e
trap 'echo "❌ Erreur à la ligne $LINENO"' ERR

# ─────── MODE VERBEUX / SILENCIEUX ─────────────────────────────
QUIET=0
for arg in "$@"; do
  case $arg in
    --silent) QUIET=1 ;;
    --verbose) QUIET=0 ;;
  esac
done

log() {
  [ "$QUIET" -eq 0 ] && echo "$@"
}

# ─────── CHARGEMENT DES VARIABLES & VENV ──────────────────────
log "🐍 Activation du venv et récupération des variables..."
source "$HOME/seedbox-compose/profile.sh"

domain=$(get_from_account_yml user.domain)
email=$(get_from_account_yml cloudflare.login)
cloudflare_api_key=$(get_from_account_yml cloudflare.api)
IP=$(curl -s ifconfig.me)

PROJECT_DIR="$HOME/projet-ssd"
SSD_DIR="$PROJECT_DIR/ssd-backend"
SSD_FRONTEND_DIR="$PROJECT_DIR/ssd-frontend"

# ─────── PM2 INSTALLATION & PATCH PERMANENT ───────────────────
log "🔍 Vérification de pm2..."

export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"
export NVM_DIR="$HOME/.nvm"

if [ -s "$NVM_DIR/nvm.sh" ]; then
  . "$NVM_DIR/nvm.sh"
  nvm use default > /dev/null
fi

NODE_VER=$(node -v 2>/dev/null | sed 's/^v//')
if [ -z "$NODE_VER" ]; then
  echo "❌ Node.js n'est pas disponible. Assurez-vous qu'une version est installée via NVM."
  exit 1
fi

NVM_BIN="$HOME/.nvm/versions/node/v$NODE_VER/bin"
export PATH="$NVM_BIN:$PATH"

npm install -g pm2 &> /dev/null

# Vérifie que pm2 est bien accessible
if ! command -v pm2 &>/dev/null; then
  echo "❌ pm2 non détecté dans le PATH"
  exit 1
fi

# Ajoute le PATH dans .bashrc si absent
LINE="export PATH=\"$NVM_BIN:\$PATH\""
if ! grep -Fxq "$LINE" "$HOME/.bashrc"; then
  echo "$LINE" >> "$HOME/.bashrc"
  log "✅ PM2 sera accessible dans les prochaines sessions"
fi

# ─────── SUPPRESSION PM2 EXISTANT & CLONAGE ───────────────────
pm2 stop all &> /dev/null || true
pm2 delete all &> /dev/null || true

log "♻️ Suppression et re-clonage des dépôts..."
rm -rf "$SSD_DIR" "$SSD_FRONTEND_DIR"
git clone https://github.com/laster13/ssd-backend.git "$SSD_DIR" &> /dev/null
git clone https://github.com/laster13/ssd-frontend.git "$SSD_FRONTEND_DIR" &> /dev/null

# Fichier .env pour le frontend
cat <<EOT > "$SSD_FRONTEND_DIR/.env"
VITE_BACKEND_URL_HTTP=http://$IP:8080
VITE_BACKEND_URL_HTTPS=https://ssdv2.$domain
EOT

# ─────── INSTALLATION DES PROJETS ──────────────────────────────
log "♻️ Installation poetry"
cd "$SSD_DIR"
pip3.11 install poetry &> /dev/null
poetry env use python3.11 &> /dev/null
poetry install &> /dev/null

log "♻️ Compilation du frontend"
cd "$SSD_FRONTEND_DIR"
pnpm install &> /dev/null
pnpm run build &> /dev/null

# ─────── DNS CLOUDFLARE ────────────────────────────────────────
log "🌐 Récupération du Zone ID..."
zone_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$domain" \
  -H "X-Auth-Email: $email" \
  -H "X-Auth-Key: $cloudflare_api_key" \
  -H "Content-Type: application/json" | jq -r '.result[0].id')

[ -z "$zone_id" ] || [ "$zone_id" = "null" ] && {
  log "❌ Zone ID introuvable. Vérifiez vos credentials Cloudflare."
  exit 1
}

check_or_create_dns() {
  sub="$1"
  existing=$(curl -s -X GET \
    "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?name=$sub.$domain" \
    -H "X-Auth-Email: $email" -H "X-Auth-Key: $cloudflare_api_key" \
    -H "Content-Type: application/json" | jq -r '.result[0].id')

  if [ -z "$existing" ] || [ "$existing" = "null" ]; then
    curl -s -X POST \
      "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
      -H "X-Auth-Email: $email" -H "X-Auth-Key: $cloudflare_api_key" \
      -H "Content-Type: application/json" \
      --data "{
        \"type\": \"A\",
        \"name\": \"$sub.$domain\",
        \"content\": \"$IP\",
        \"ttl\": 120,
        \"proxied\": true
      }" > /dev/null
    log "✅ DNS $sub.$domain ajouté."
  else
    log "✅ DNS $sub.$domain déjà existant."
  fi
}

check_or_create_dns "ssdv2"
check_or_create_dns "traefik"

# ─────── LANCEMENT DES SERVICES PM2 ────────────────────────────
log "🚀 Lancement du backend avec PM2..."
cd "$SSD_DIR"
pm2 start "poetry run bash start.sh" --name backend --cwd "$SSD_DIR" &> /dev/null

log "🚀 Lancement du frontend avec PM2..."
cd "$SSD_FRONTEND_DIR"
pm2 start "ORIGIN=https://ssdv2.$domain VITE_BACKEND_URL_HTTPS=https://ssdv2.$domain node build" \
  --name frontend --cwd "$SSD_FRONTEND_DIR" &> /dev/null

log "✅ Services backend et frontend lancés avec PM2"

# Appliquer les modifs bashrc à la session actuelle
source "$HOME/.bashrc"

exit 0
