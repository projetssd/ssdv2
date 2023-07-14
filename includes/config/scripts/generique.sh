#!/bin/bash
###########################################################
# permet juste de lancer la fonction laubash depuis python
# python ne permet pas de lancer des fonctions bash
############################################################
# Utilisation :
# generique.sh <nom fonction> <arguments>
# ex:
# generique.sh ks_launch_service rutorrent
############################################################


source "${SETTINGS_SOURCE}/includes/functions.sh"
source "${SETTINGS_SOURCE}/includes/variables.sh"
"$@"