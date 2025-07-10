#!/bin/bash

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

[ "$QUIET" -eq 1 ] && exec > /dev/null 2>&1

# ─────── RÉCUPÉRATION DES VARIABLES ────────────────────────────
[ -f /tmp/ssd.env ] && source /tmp/ssd.env

MAKEFILE_DIR="$HOME/ssd-bootstrap"
BASHRC="$HOME/.bashrc"
ALIAS_MARKER="# >>> ssd aliases >>>"

# ─────── AJOUT DES ALIAS S'ILS N'EXISTENT PAS ──────────────────
if grep -q "$ALIAS_MARKER" "$BASHRC"; then
  log "ℹ️  Alias déjà présents dans $BASHRC."
else
  log "🔗 Ajout des alias dans $BASHRC..."
  {
    echo -e "\n$ALIAS_MARKER"
    echo "alias ssd:setup='make -C $MAKEFILE_DIR setup'"
    echo "alias ssd:install='make -C $MAKEFILE_DIR install'"
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

# ─────── CHARGEMENT & NETTOYAGE ────────────────────────────────
log "✅ Aliases ajoutés. Rechargement de .bashrc..."
source "$BASHRC"

log "🧹 Suppression du fichier temporaire contenant les secrets..."
rm -f /tmp/ssd.env

log "✅ Setup des alias terminé."

exit 0
