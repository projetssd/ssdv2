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
fi


