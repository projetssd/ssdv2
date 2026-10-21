# shellcheck shell=bash
# Menu de gestion de la passerelle decypharrgate (Sonarr v5).
# Ce fichier est source par includes/menus.sh (voir le patch
# 20261021_decypharr_cache_gate).

DECYPHARRGATE_SCRIPT="${SETTINGS_SOURCE}/includes/config/scripts/decypharrgate.py"

decypharrgate_status_json() {
  if [ -f "${DECYPHARRGATE_SCRIPT}" ]; then
    python3 "${DECYPHARRGATE_SCRIPT}" status 2>/dev/null || echo '{}'
  else
    echo '{}'
  fi
}

decypharrgate_confirm() {
  local id="$1" label="$2" default="$3" answer
  printf 'SSDV2_PROMPT %s\n' "{\"id\":\"${id}\",\"label\":\"${label}\",\"kind\":\"confirm\",\"secret\":false}" >&2
  printf '%s [%s] : ' "${label}" "${default}" >&2
  read -r answer
  answer="${answer:-${default}}"
  case "${answer,,}" in
    o|oui|y|yes) return 0 ;;
    *) return 1 ;;
  esac
}

menu_decypharrgate() {
  clear
  logo

  local status gate host cache sonarr_installed choice answer
  status="$(decypharrgate_status_json)"
  gate="$(printf '%s' "${status}" | jq -r '.gate // "inconnu"' 2>/dev/null)"
  host="$(printf '%s' "${status}" | jq -r '.sonarr_host // "non detecte"' 2>/dev/null)"
  cache="$(printf '%s' "${status}" | jq -r '.cache_size // "inconnu"' 2>/dev/null)"
  sonarr_installed="$(printf '%s' "${status}" | jq -r '.sonarr_installed // false' 2>/dev/null)"

  echo -e "${CRED}---------------------------------------------------------------${CEND}"
  echo -e "${CCYAN}     CACHE GATE DECYPHARR (SONARR V5)${CEND}"
  echo -e "${CRED}---------------------------------------------------------------${CEND}"
  echo -e " ${BWHITE}Gate              :${CEND} ${gate}"
  echo -e " ${BWHITE}Sonarr installe   :${CEND} ${sonarr_installed}"
  echo -e " ${BWHITE}Host Sonarr       :${CEND} ${host}"
  echo -e " ${BWHITE}Cache DFS         :${CEND} ${cache}"
  echo -e "${CRED}---------------------------------------------------------------${CEND}"
  echo -e " ${CGREEN}1)${CEND} Installer / mettre a jour la gate"
  echo -e " ${CGREEN}2)${CEND} Configurer Sonarr (host -> decypharrgate)"
  echo -e " ${CGREEN}3)${CEND} Restaurer Sonarr (host -> decypharrsonarr)"
  echo -e " ${CGREEN}4)${CEND} Passer le cache DFS a 20 Go"
  echo -e " ${CGREEN}5)${CEND} Desinstaller la gate"
  echo -e " ${CGREEN}6)${CEND} Aide / questions-reponses"
  echo -e " ${CGREEN}7)${CEND} Retour"
  echo -e "${CRED}---------------------------------------------------------------${CEND}"

  printf 'SSDV2_PROMPT %s\n' '{"id":"decypharrgate.action","label":"Choix decypharrgate","kind":"choice","options":["1","2","3","4","5","6","7"]}' >&2
  read -rp "Votre choix : " choice

  case "${choice}" in
    1)
      launch_service decypharrgate
      echo ""
      echo -e "${CGREEN}Gate installee/mise a jour. La posttask a pu poser les questions de configuration.${CEND}"
      pause
      ;;
    2)
      if [ "${sonarr_installed}" != "true" ]; then
        echo -e "${YELLOW}Sonarr n'est pas installe : rien a configurer.${CEND}"
      elif decypharrgate_confirm "decypharrgate.confirm_sonarr" "Pointer Sonarr vers decypharrgate ?" "o"; then
        python3 "${DECYPHARRGATE_SCRIPT}" configure-sonarr
      fi
      pause
      ;;
    3)
      if decypharrgate_confirm "decypharrgate.confirm_restore" "Remettre Sonarr vers decypharrsonarr ?" "o"; then
        python3 "${DECYPHARRGATE_SCRIPT}" restore-sonarr
      fi
      pause
      ;;
    4)
      if decypharrgate_confirm "decypharrgate.confirm_cache" "Passer le cache DFS a 20 Go ? (backup + restart decypharrsonarr)" "n"; then
        python3 "${DECYPHARRGATE_SCRIPT}" increase-cache
      fi
      pause
      ;;
    5)
      if [ "${host}" = "decypharrgate" ]; then
        echo -e "${YELLOW}Sonarr pointe encore vers decypharrgate.${CEND}"
        echo -e "${YELLOW}Utilisez d'abord l'option 3 (Restaurer Sonarr).${CEND}"
      elif decypharrgate_confirm "decypharrgate.confirm_uninstall" "Desinstaller la gate ?" "n"; then
        # La gate ne stocke aucune donnee : suppression complete du dossier vide.
        suppression_appli decypharrgate 1
        echo -e "${CGREEN}Gate desinstallee.${CEND}"
      fi
      pause
      ;;
    6)
      clear
      cat <<'EOF'
CACHE GATE DECYPHARR — QUESTIONS / REPONSES

1. Est-ce utile pour moi ?
   - Sonarr v5 + decypharr + entrees "downloadClientUnavailable" dans la file : oui.
   - Sonarr v4 : non, v4 skippe deja les releases refusees.
   - Pas de decypharr : non.

2. Configurer Sonarr automatiquement ?
   - Oui : le host du download client passe a decypharrgate:8282.
   - Non : la gate est installee, Sonarr reste inchange.

3. Radarr ?
   - Non pris en charge dans cette version (perimetre Sonarr).

4. Passer le cache DFS a 20 Go ?
   - Oui : backup de config.json, disk_cache_size 500 Mo -> 20 Go, restart.
   - Recommande si les logs contiennent "disk limit reached".
   - Verifier l'espace libre du disque.

5. Est-ce que ca blocklist ?
   - Non. 404 -> 409, Sonarr skippe la release sans blocklist.

6. Est-ce que ca change download_uncached ?
   - Non.

7. Comment desinstaller ?
   - Option 3 (Restaurer Sonarr), puis option 5 (Desinstaller la gate).

RESUME
- Gate nginx interne : aucun port publie, aucun DNS, aucun label Traefik.
- Sonarr v5 : releases non cachees skippees, file propre, pas de blocklist.
- Changements Sonarr/cache : optionnels, detectes et reversibles.
EOF
      pause
      ;;
    7|"")
      return 0
      ;;
    *)
      echo -e "${RED}Choix invalide.${CEND}"
      pause
      ;;
  esac
}
