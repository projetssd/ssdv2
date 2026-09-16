#!/bin/bash


# Si le fichier n'existe pas, on ne fait rien
if [ -f "${HOME}/.config/ssd/env" ]; then
  source "${HOME}/.config/ssd/env"
  export PATH="$HOME/.local/bin:$PATH"
  # On rentre dans le venv
  source ${SETTINGS_SOURCE}/venv/bin/activate
  # On charge les variables
  source ${SETTINGS_SOURCE}/includes/variables.sh
  # On charge les fonctions
  source ${SETTINGS_SOURCE}/includes/functions.sh
  # On charge les fonctions qui sont lancées par le menu
  source ${SETTINGS_SOURCE}/includes/menus.sh

  PYTHONPATH=${SETTINGS_SOURCE}/venv/lib/$(ls ${SETTINGS_SOURCE}/venv/lib)/site-packages
  export PYTHONPATH
  # le fonction nous a probablement fait sortir du venv, on le recharge
  source ${SETTINGS_SOURCE}/venv/bin/activate

  # ------------------------------------------------------------------
  # Rechargement automatique après une mise à jour (git pull)
  # ------------------------------------------------------------------
  # Le shell surveille les fichiers de fonctions ; s'ils changent, il se
  # recharge tout seul au prompt suivant. Bash interactif uniquement.
  # Empreinte basée sur stat (mtime + taille), très légère.

  _ssdv2_fingerprint() {
    local src="${SETTINGS_SOURCE:-$HOME/seedbox-compose}"
    stat -c '%Y%s' \
      "${src}/includes/variables.sh" \
      "${src}/includes/functions.sh" \
      "${src}/includes/menus.sh" \
      "${src}/profile.sh" 2>/dev/null | tr '\n' ':'
  }

  _ssdv2_autoreload() {
    local fp short
    fp="$(_ssdv2_fingerprint)"
    [ -z "$fp" ] && return 0
    if [ "$fp" != "${__SSDV2_FP:-}" ]; then
      # Mise à jour de l'empreinte AVANT de re-sourcer (évite toute boucle).
      __SSDV2_FP="$fp"
      source "${SETTINGS_SOURCE}/profile.sh"
      short=""
      command -v git >/dev/null 2>&1 && short="$(git -C "${SETTINGS_SOURCE}" rev-parse --short HEAD 2>/dev/null)"
      printf '\033[0;36m[SSDV2]\033[0m fonctions rechargées%s\n' "${short:+ (commit ${short})}"
    fi
  }

  # Enregistrement idempotent dans PROMPT_COMMAND, en préservant l'existant.
  if [[ $- == *i* ]]; then
    case ";${PROMPT_COMMAND:-};" in
      *";_ssdv2_autoreload;"*) : ;;
      *) PROMPT_COMMAND="_ssdv2_autoreload${PROMPT_COMMAND:+; ${PROMPT_COMMAND}}" ;;
    esac
  fi

  # Empreinte initiale (pas de faux rechargement au premier prompt).
  __SSDV2_FP="$(_ssdv2_fingerprint)"
fi
