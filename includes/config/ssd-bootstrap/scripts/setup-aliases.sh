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

# ─────── VARIABLES ───────────────────────────────
MAKEFILE_DIR="$HOME/ssd-bootstrap"
BASHRC="$HOME/.bashrc"
ALIAS_MARKER="# >>> ssd aliases >>>"

# ─────── AJOUT DES ALIAS ─────────────────────────
if grep -q "$ALIAS_MARKER" "$BASHRC"; then
  log "ℹ️  Alias déjà présents dans $BASHRC."
else
  log "🔗 Ajout des alias dans $BASHRC..."
  {
    echo -e "\n$ALIAS_MARKER"
    echo "alias ssd:setup='make -C $MAKEFILE_DIR setup-all'"
    echo "alias ssd:install='make -C $MAKEFILE_DIR install-system'"
    echo "alias ssd:start='make -C $MAKEFILE_DIR start'"
    echo "alias ssd:stop='make -C $MAKEFILE_DIR stop'"
    echo "alias ssd:restart='make -C $MAKEFILE_DIR restart'"
    echo "alias ssd:status='make -C $MAKEFILE_DIR status'"
    echo "alias ssd:logs='pm2 logs'"
    echo "alias ssd:logs:backend='pm2 logs backend'"
    echo "alias ssd:logs:frontend='pm2 logs frontend'"
    echo "# <<< ssd aliases <<<"
  } >> "$BASHRC"
fi

log "✅ Aliases ajoutés."

# ─────── fd ──────────────────────────────────

# Mise à jour et installation de fd-find
echo "🔄 Mise à jour des paquets..."
sudo apt update -y
sudo apt install -y fd-find

# Vérification du lien symbolique
if [ -L /usr/local/bin/fd ]; then
    echo "✅ Le lien symbolique /usr/local/bin/fd existe déjà."
elif [ -f /usr/local/bin/fd ]; then
    echo "⚠️ Un fichier normal existe déjà à /usr/local/bin/fd — pas de lien créé."
else
    echo "🔗 Création du lien symbolique /usr/local/bin/fd → $(which fdfind)"
    sudo ln -s "$(which fdfind)" /usr/local/bin/fd
    echo "✅ Lien créé avec succès."
fi

# ─────────────────────────────────────────────


echo "🧹 Désinstallation de pnpm, pm2 et nvm..."

# ─────── PNPM ─────────────────────────────────────
echo "➖ Suppression de pnpm..."
rm -rf ~/.local/share/pnpm ~/.pnpm-store 2>/dev/null || true
sed -i '/PNPM_HOME/d' ~/.bashrc
sed -i '/pnpm/d' ~/.bashrc

# ─────── PM2 ──────────────────────────────────────
echo "➖ Suppression de pm2..."
if command -v pm2 >/dev/null 2>&1; then
  echo "⏹ Arrêt des processus PM2..."
  pm2 stop all || true
  pm2 delete all || true
  pm2 save --force || true

  echo "🛑 Arrêt complet du démon PM2..."
  pm2 kill || true

  echo "❌ Désinstallation de pm2 (npm)..."
  npm uninstall -g pm2 || true
fi
rm -rf ~/.pm2 2>/dev/null || true
sed -i '/PM2_HOME/d' ~/.bashrc
sed -i '/pm2/d' ~/.bashrc

# ─────── NVM ──────────────────────────────────────
echo "➖ Suppression de nvm..."
rm -rf ~/.nvm 2>/dev/null || true
sed -i '/NVM_DIR/d' ~/.bashrc
sed -i '/nvm.sh/d' ~/.bashrc

# ─────── SUPPRESSION DOSSIER ──────────────────────
TARGET_DIR="$HOME/seedbox/docker/$USER/projet-ssd"
if [[ -d "$TARGET_DIR" ]]; then
  echo "➖ Suppression du dossier $TARGET_DIR..."
  rm -rf "$TARGET_DIR"
fi

# ─────── VÉRIFICATION PROCESS PM2 ─────────────────
echo "🔍 Vérification que PM2 ne tourne plus..."
if pgrep -fa pm2 >/dev/null; then
  echo "⚠️ Attention : il reste des processus PM2 actifs :"
  pgrep -fa pm2
else
  echo "✅ Aucun processus PM2 détecté."
fi

# ─────── VÉRIFICATION PORTS ───────────────────────
echo "🔍 Vérification des ports 8080, 8001 et 3000..."
for PORT in 8080 8001 3000; do
  if ss -ltnp 2>/dev/null | grep -q ":$PORT "; then
    echo "⚠️ Le port $PORT est encore occupé :"
    ss -ltnp | grep ":$PORT "
  else
    echo "✅ Le port $PORT est libre."
  fi
done

# ─────── FIN ──────────────────────────────────────
echo "✅ Désinstallation terminée."
