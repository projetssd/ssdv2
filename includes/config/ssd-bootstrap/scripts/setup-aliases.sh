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
log "ℹ️ Recharge ton shell avec : source ~/.bashrc"
