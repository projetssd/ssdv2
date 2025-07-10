#!/bin/bash

# ─────── MODE VERBEUX / SILENCIEUX ─────────────────────────────
QUIET=0

for arg in "$@"; do
  case $arg in
    --silent) QUIET=1 ;;
    --verbose) QUIET=0 ;;
  esac
done

# Si en mode silencieux, on coupe toutes les sorties
if [ "$QUIET" -eq 1 ]; then
  exec > /dev/null 2>&1
fi

log() {
  [ "$QUIET" -eq 0 ] && echo "$@"
}

# ─────── MISE À JOUR SYSTÈME ───────────────────────────────────
log "🔧 Mise à jour des paquets..."
sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq > /dev/null 2>&1

log "📦 Installation des paquets système..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  software-properties-common curl git jq apache2-utils \
  > /dev/null 2>&1

# ─────── PYTHON 3.11 + pip ─────────────────────────────────────
log "🐍 Installation de Python 3.11..."
sudo add-apt-repository -y ppa:deadsnakes/ppa > /dev/null 2>&1
sudo apt-get update -qq > /dev/null 2>&1
sudo apt-get install -y python3.11 python3.11-venv python3.11-dev > /dev/null 2>&1

log "📥 Installation de pip..."
curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11 > /dev/null 2>&1

# ─────── NODE + PNPM ───────────────────────────────────────────
log "🟢 Installation de Node.js via NVM..."
if [ ! -d "$HOME/.nvm" ]; then
  curl -s -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash > /dev/null 2>&1
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

nvm install --lts > /dev/null 2>&1
nvm use --lts > /dev/null 2>&1

log "📦 Installation de PNPM..."
curl -fsSL https://get.pnpm.io/install.sh | sh -s -- > /dev/null

export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"

# ─────── DOCKER ────────────────────────────────────────────────
log "🐳 Installation de Docker si nécessaire..."
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh > /dev/null 2>&1
  rm get-docker.sh
  sudo usermod -aG docker "$USER"
fi

# ─────── SUDOERS ───────────────────────────────────────────────
log "🔐 Ajout de $USER dans les sudoers si nécessaire..."
if ! sudo grep -q "^$USER ALL=(ALL) NOPASSWD:ALL" /etc/sudoers; then
  echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers > /dev/null
fi

log "✅ Setup système terminé."
exit 0
