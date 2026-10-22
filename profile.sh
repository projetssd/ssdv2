#!/bin/bash


# Active le venv SSDV2 uniquement s'il est exploitable. Le venv est construit
# sur l'hôte avec un shebang vers /usr/bin/python3 ; dans le conteneur WebUI ce
# binaire n'existe pas, et l'activer casserait ansible-vault/ansible-playbook
# (utilisés par manage_account_yml). On laisse alors le PATH ambiant (ansible
# système fourni par l'image).
_ssdv2_activate_venv() {
  "${SETTINGS_SOURCE}/venv/bin/python" -c 'import sys' >/dev/null 2>&1 || return 1
  # shellcheck disable=SC1091
  source "${SETTINGS_SOURCE}/venv/bin/activate"
  return 0
}

# Si le fichier n'existe pas, on ne fait rien
if [ -f "${HOME}/.config/ssd/env" ]; then
  source "${HOME}/.config/ssd/env"
  export PATH="$HOME/.local/bin:$PATH"
  # On rentre dans le venv
  _ssdv2_activate_venv
  # On charge les variables
  source ${SETTINGS_SOURCE}/includes/variables.sh
  # On charge les fonctions
  source ${SETTINGS_SOURCE}/includes/functions.sh
  # On garantit la commande ssdv2ctl dans ~/.local/bin
  "${SETTINGS_SOURCE}/includes/config/scripts/ensure_ssdv2ctl_wrapper.sh" >/dev/null 2>&1 || true
  # On charge les fonctions qui sont lancées par le menu
  source ${SETTINGS_SOURCE}/includes/menus.sh

  # PYTHONPATH n'est renseigné que si le venv est exploitable (sinon il
  # fausserait l'ansible système du conteneur WebUI).
  if _ssdv2_activate_venv; then
    PYTHONPATH=${SETTINGS_SOURCE}/venv/lib/$(ls ${SETTINGS_SOURCE}/venv/lib)/site-packages
    export PYTHONPATH
  fi

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
