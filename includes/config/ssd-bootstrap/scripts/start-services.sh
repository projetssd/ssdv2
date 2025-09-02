#!/bin/bash
set -euo pipefail
trap 'echo "❌ Erreur à la ligne $LINENO"; exit 1' ERR

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

# ─────── CHARGEMENT VARIABLES ──────────────────────────────────
log "🐍 Activation du venv et récupération des variables..."
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

PROFILE="$HOME/.bashrc"

# ─────── CONFIG ENV PERMANENTE ─────────────────────────────────
if ! grep -q "Config Node/npm/pm2 personnalisée" "$PROFILE"; then
  {
    echo ""
    echo "# >>> Config Node/npm/pm2 personnalisée >>>"
    echo "export NVM_DIR=\"\$HOME/.nvm\""
    echo "[ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\""
    echo ""
    echo "export PNPM_HOME=\"\$HOME/.local/share/pnpm\""
    echo "export PATH=\"\$PNPM_HOME:\$PATH\""
    echo ""
    echo "export PM2_HOME=\"$PROJECT_DIR/.pm2\""
    echo "# <<< Fin config >>>"
  } >> "$PROFILE"
fi

export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"
export PM2_HOME="$PROJECT_DIR/.pm2"

# ─────── MISE À JOUR SYSTÈME ───────────────────────────────────
log "🔧 Mise à jour des paquets..."
sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq

log "📦 Installation des paquets système..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  software-properties-common curl git jq apache2-utils inotify-tools

# ─────── PYTHON 3.11 + pip ─────────────────────────────────────
log "🐍 Installation de Python 3.11..."
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt-get update -qq
sudo apt-get install -y python3.11 python3.11-venv python3.11-dev lm-sensors

log "📥 Installation de pip..."
curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11

#!/usr/bin/env bash

# ─────── DNS CLOUDFLARE ────────────────────────────────────────

log() {
  echo -e "$1"
}

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
  full_name=$([ -n "$sub" ] && echo "$sub.$domain" || echo "$domain")

  existing=$(curl -s -X GET \
    "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?name=$full_name" \
    -H "X-Auth-Email: $email" -H "X-Auth-Key: $cloudflare_api_key" \
    -H "Content-Type: application/json" | jq -r '.result[0].id')

  if [ -z "$existing" ] || [ "$existing" = "null" ]; then
    create_result=$(curl -s -X POST \
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
      }")

    if echo "$create_result" | jq -e '.success' | grep -q true; then
      log "✅ DNS $full_name ajouté."
    else
      log "❌ Erreur lors de l’ajout de $full_name : $(echo "$create_result" | jq -c '.errors')"
    fi
  else
    log "✅ DNS $full_name déjà existant."
  fi
}

# Exemple d’appel
check_or_create_dns "ssdv2"

# ─────── NODE + PNPM ───────────────────────────────────────────
log "🟢 Installation de Node.js via NVM..."
export NVM_DIR="$HOME/.nvm"

if [ ! -s "$NVM_DIR/nvm.sh" ]; then
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
fi

# shellcheck disable=SC1090
. "$NVM_DIR/nvm.sh"

nvm install --lts
nvm alias default 'lts/*'
nvm use default

log "📦 Installation de PNPM..."
curl -fsSL https://get.pnpm.io/install.sh | sh -s -- > /dev/null

# ─────── INSTALLATION PM2 ──────────────────────────────────────
log "📦 Installation de pm2..."
npm install -g pm2 >/dev/null

if ! command -v pm2 >/dev/null; then
  echo "❌ pm2 non détecté"
  exit 1
fi
log "✅ pm2 installé : $(pm2 -v)"

# ─────── SUDOERS ───────────────────────────────────────────────
log "🔐 Ajout de $USERNAME dans les sudoers si nécessaire..."
if ! sudo grep -q "^$USERNAME ALL=(ALL) NOPASSWD:ALL" /etc/sudoers; then
  echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers > /dev/null
fi

# ─────── DEPLOIEMENT APPS ──────────────────────────────────────
pm2 stop all &> /dev/null || true
pm2 delete all &> /dev/null || true

log "♻️ Suppression et re-clonage des dépôts..."
rm -rf "$SSD_DIR" "$SSD_FRONTEND_DIR" "$SAISON_FRONTEND_DIR"
git clone https://github.com/laster13/ssd-backend.git "$SSD_DIR" &> /dev/null
git clone https://github.com/laster13/ssd-frontend.git "$SSD_FRONTEND_DIR" &> /dev/null
git clone https://github.com/laster13/saison-frontend.git "$SAISON_FRONTEND_DIR" &> /dev/null

# Fichiers .env
cat <<EOT > "$SSD_FRONTEND_DIR/.env"
VITE_BACKEND_URL_HTTPS=https://ssdv2.$domain
VITE_API_BASE_URL=https://ssdv2.$domain/api/v1
EOT

cat <<EOT > "$SSD_DIR/.env"
DEBUG=False
COOKIE_SECURE=True
COOKIE_DOMAIN=ssdv2.$domain

JWT_SECRET_KEY=ton_secret_super_long
JWT_ALGORITHM=HS256
EOT

cat <<EOT > "$SAISON_FRONTEND_DIR/.env"
DATABASE_URL=local.db
VITE_API_BASE_URL=https://ssdv2.$domain/api/v1
VITE_BACKEND_URL_HTTPS=https://ssdv2.$domain
EOT

# Backend
log "♻️ Installation poetry"
cd "$SSD_DIR"
pip3.11 install poetry &> /dev/null
poetry env use python3.11 &> /dev/null
poetry install &> /dev/null

log "🚀 Lancement du backend avec PM2..."
pm2 start "poetry run bash start.sh" --name backend --cwd "$SSD_DIR" &> /dev/null

sleep 5

# Frontend
log "♻️ Compilation du frontend"
cd "$SSD_FRONTEND_DIR"
pnpm install &> /dev/null
pnpm run build &> /dev/null

log "🚀 Lancement du frontend avec PM2..."
pm2 start "ORIGIN=https://ssdv2.$domain VITE_BACKEND_URL_HTTPS=https://ssdv2.$domain node build" \
  --name frontend --cwd "$SSD_FRONTEND_DIR" &> /dev/null

# Saison-frontend
log "♻️ Compilation du saison-frontend"
cd "$SAISON_FRONTEND_DIR"
pnpm install &> /dev/null
pnpm run build &> /dev/null

log "🚀 Lancement du saison-frontend avec PM2..."
PORT=8001 pm2 start "ORIGIN=https://ssdv2.$domain VITE_BACKEND_URL_HTTPS=https://ssdv2.$domain node build" \
  --name saison-frontend --cwd "$SAISON_FRONTEND_DIR" &> /dev/null

# ─────── FIN ───────────────────────────────────────────────────
log "✅ Setup + déploiement terminé."
log "ℹ️ Recharge ton shell avec : source ~/.bashrc"
