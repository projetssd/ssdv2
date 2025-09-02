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

if [ "$QUIET" -eq 1 ]; then
  exec > /dev/null 2>&1
fi

log() {
  [ "$QUIET" -eq 0 ] && echo "$@"
}

# ─────── CHEMIN D’INSTALLATION ────────────────────────────────
USERNAME=$(id -un)
BASE_DIR="$HOME/seedbox/docker/$USERNAME/projet-ssd"
mkdir -p "$BASE_DIR"

# Variables d'environnement permanentes (évite doublons)
PROFILE="$HOME/.bashrc"
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
    echo "export PM2_HOME=\"$BASE_DIR/.pm2\""
    echo "# <<< Fin config >>>"
  } >> "$PROFILE"
fi

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

# ─────── NODE + PNPM ───────────────────────────────────────────
log "🟢 Installation de Node.js via NVM..."
export NVM_DIR="$HOME/.nvm"

if [ ! -s "$NVM_DIR/nvm.sh" ]; then
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
fi

# Charger NVM
# shellcheck disable=SC1090
. "$NVM_DIR/nvm.sh"

nvm install --lts
nvm alias default 'lts/*'
nvm use default

log "📦 Installation de PNPM..."
curl -fsSL https://get.pnpm.io/install.sh | sh -s -- > /dev/null

export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"

# ─────── SUDOERS ───────────────────────────────────────────────
log "🔐 Ajout de $USERNAME dans les sudoers si nécessaire..."
if ! sudo grep -q "^$USERNAME ALL=(ALL) NOPASSWD:ALL" /etc/sudoers; then
  echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers > /dev/null
fi

log "✅ Setup système terminé."
log "ℹ️ Recharge ton shell avec : source ~/.bashrc"
