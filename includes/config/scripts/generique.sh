#!/bin/bash
###########################################################
# permet juste de lancer la fonction laubash depuis python
# python ne permet pas de lancer des fonctions bash
############################################################
# Utilisation :
# generique.sh <nom fonction> <arguments>
# ex:
# generique.sh launch_service rutorrent
############################################################

source "${SETTINGS_SOURCE}/includes/variables.sh"
source "${SETTINGS_SOURCE}/includes/menus.sh"
source "${SETTINGS_SOURCE}/includes/functions.sh"

# Toute action de gestion lancée via ce wrapper (WebUI et scripts Python)
# applique d'abord les patchs SSDV2 en attente. Idempotent : sans effet si
# rien n'est en attente. Un échec ne doit jamais bloquer l'action demandée.
apply_patches || true

"$@"
