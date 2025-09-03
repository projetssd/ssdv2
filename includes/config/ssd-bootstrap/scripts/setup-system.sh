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

# ─────── SUDO OU ROOT ────────────────────────────
if command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
else
  if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Ce script doit être exécuté en root ou avec sudo"
    exit 1
  fi
  SUDO=""
fi

USERNAME=$(id -un)
BASE_DIR="$HOME/seedbox/docker/$USERNAME/projet-ssd"
mkdir -p "$BASE_DIR"

PROFILE="$HOME/.bashrc"

# ─────── CONFIG .BASHRC ──────────────────────────
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

# ─────── ENV DIRECTEMENT ACTIF ───────────────────
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"

export PM2_HOME="$BASE_DIR/.pm2"

# ─────── PAQUETS SYSTÈME ─────────────────────────
log "🔧 Mise à jour des paquets..."
$SUDO DEBIAN_FRONTEND=noninteractive apt-get update -qq || true

log "📦 Installation des paquets système..."
$SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y \
  software-properties-common curl git jq apache2-utils inotify-tools || true

# ─────── PYTHON ──────────────────────────────────
if ! command -v python3.11 >/dev/null; then
  log "🐍 Installation de Python 3.11..."
  if command -v add-apt-repository >/dev/null; then
    $SUDO add-apt-repository -y ppa:deadsnakes/ppa
    $SUDO apt-get update -qq
    $SUDO apt-get install -y python3.11 python3.11-venv python3.11-dev lm-sensors
  else
    log "⚠️ Pas de add-apt-repository, utilisation du python3 par défaut."
  fi
fi

if command -v python3.11 >/dev/null; then
  curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11
fi

# ─────── NODE + PNPM ─────────────────────────────
log "🟢 Installation de Node.js via NVM..."
if [ ! -s "$NVM_DIR/nvm.sh" ]; then
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
  . "$NVM_DIR/nvm.sh"
fi

nvm install --lts
nvm alias default 'lts/*'
nvm use default

log "📦 Installation de PNPM..."
curl -fsSL https://get.pnpm.io/install.sh | sh -s -- > /dev/null

# ─────── INSTALLATION PM2 ─────────────────────────
log "📦 Installation de pm2..."
npm install -g pm2 >/dev/null

if ! command -v pm2 >/dev/null; then
  log "❌ pm2 non détecté après installation."
  exit 1
fi
log "✅ pm2 installé : $(pm2 -v)"

# ─────── SUDOERS ─────────────────────────────────
log "🔐 Ajout de $USERNAME dans les sudoers si nécessaire..."
if command -v sudo >/dev/null 2>&1; then
  if ! sudo grep -q "^$USERNAME ALL=(ALL) NOPASSWD:ALL" /etc/sudoers; then
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers > /dev/null
  fi
fi

log "✅ Setup système terminé."
