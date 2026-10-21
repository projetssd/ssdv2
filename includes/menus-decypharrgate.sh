# shellcheck shell=bash
# Menu de gestion des gates decypharr (Sonarr v5+).
# Ce fichier est source par includes/menus.sh (voir le patch
# 20261021_decypharr_cache_gate).

DECYPHARRGATE_SCRIPT="${SETTINGS_SOURCE}/includes/config/scripts/decypharrgate.py"

decypharrgate_status_json() {
  if [ -f "${DECYPHARRGATE_SCRIPT}" ]; then
    python3 "${DECYPHARRGATE_SCRIPT}" menu-status 2>/dev/null || echo '{}'
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

decypharrgate_default_container_exists() {
  docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx 'decypharrgate'
}

menu_decypharrgate() {
  clear
  logo

  local status choice answer gate upstream name
  status="$(decypharrgate_status_json)"

  echo -e "${CRED}---------------------------------------------------------------${CEND}"
  echo -e "${CCYAN}     CACHE GATE DECYPHARR (SONARR V5+)${CEND}"
  echo -e "${CRED}---------------------------------------------------------------${CEND}"
  echo -e " ${BWHITE}Instances decypharr :${CEND}"
  printf '%s' "${status}" | jq -r '.instances[]? | "   - \(.name) [\(.upstream)] gate=\(.gate // "aucune") cache=\(.cache_size // "?")"' 2>/dev/null
  echo -e " ${BWHITE}Gates :${CEND}"
  printf '%s' "${status}" | jq -r '.gates[]? | "   - \(.name) -> \(.upstream // "inconnu") (\(.health // "?"))"' 2>/dev/null
  echo -e " ${BWHITE}Sonarr v5+ :${CEND}"
  printf '%s' "${status}" | jq -r '.sonarrs[]? | "   - \(.name) \(.version) : \(.client_host) [\(.state)]"' 2>/dev/null
  echo -e " ${BWHITE}Non concernes :${CEND}"
  printf '%s' "${status}" | jq -r '.skipped[]? | "   - \(.name) \(.version // "") : \(.reason)"' 2>/dev/null
  echo -e "${CRED}---------------------------------------------------------------${CEND}"
  echo -e " ${CGREEN}1)${CEND} Installer/mettre a jour les gates manquantes"
  echo -e " ${CGREEN}2)${CEND} Configurer les Sonarr v5+ eligibles"
  echo -e " ${CGREEN}3)${CEND} Restaurer les Sonarr v5+"
  echo -e " ${CGREEN}4)${CEND} Augmenter le cache d'une instance decypharr"
  echo -e " ${CGREEN}5)${CEND} Desinstaller une gate"
  echo -e " ${CGREEN}6)${CEND} Aide / questions-reponses"
  echo -e " ${CGREEN}7)${CEND} Retour"
  echo -e "${CRED}---------------------------------------------------------------${CEND}"

  printf 'SSDV2_PROMPT %s\n' '{"id":"decypharrgate.action","label":"Choix decypharrgate","kind":"choice","options":["1","2","3","4","5","6","7"]}' >&2
  read -rp "Votre choix : " choice

  case "${choice}" in
    1)
      local missing=0
      while IFS=$'\t' read -r name upstream; do
        [ -n "${name}" ] || continue
        [ -n "${upstream}" ] || continue
        missing=1
        if ! decypharrgate_default_container_exists; then
          gate="decypharrgate"
          mkdir -p "${SETTINGS_STORAGE}/conf"
          printf '%s\n' "${upstream}" >"${SETTINGS_STORAGE}/conf/${gate}.upstream"
          echo -e "${BLUE}Installation de ${gate} pour ${upstream}...${NC}"
          launch_service "${gate}"
        else
          gate="decypharrgate-${name}"
          python3 "${DECYPHARRGATE_SCRIPT}" write-gate-vars --gate "${gate}" --upstream "${upstream}"
          echo -e "${BLUE}Installation de ${gate} pour ${upstream}...${NC}"
          launch_service "${gate}"
        fi
      done < <(printf '%s' "${status}" | jq -r '.instances[]? | select(.used_by_sonarr == true and .gate == null) | [.name, .upstream] | @tsv' 2>/dev/null)
      if [ "${missing}" -eq 0 ]; then
        echo -e "${YELLOW}Aucune gate manquante pour les Sonarr v5+ detectes.${NC}"
      fi
      pause
      ;;
    2)
      if decypharrgate_confirm "decypharrgate.configure_sonarr" "Configurer les Sonarr v5+ eligibles ?" "o"; then
        while IFS= read -r gate; do
          [ -n "${gate}" ] || continue
          echo -e "${BLUE}--- ${gate} ---${NC}"
          python3 "${DECYPHARRGATE_SCRIPT}" configure --gate "${gate}"
        done < <(printf '%s' "${status}" | jq -r '.gates[]? | select(.upstream != null and .upstream != "") | .name' 2>/dev/null)
      fi
      pause
      ;;
    3)
      if decypharrgate_confirm "decypharrgate.restore_sonarr" "Restaurer les Sonarr v5+ vers leur upstream ?" "o"; then
        while IFS= read -r gate; do
          [ -n "${gate}" ] || continue
          echo -e "${BLUE}--- ${gate} ---${NC}"
          python3 "${DECYPHARRGATE_SCRIPT}" restore --gate "${gate}"
        done < <(printf '%s' "${status}" | jq -r '.gates[]? | select(.upstream != null and .upstream != "") | .name' 2>/dev/null)
      fi
      pause
      ;;
    4)
      local -a inst_names=() inst_lines=()
      mapfile -t inst_lines < <(printf '%s' "${status}" | jq -r '.instances[]? | "\(.name)\t\(.cache_size // "inconnu")"' 2>/dev/null)
      if [ "${#inst_lines[@]}" -eq 0 ]; then
        echo -e "${YELLOW}Aucune instance decypharr detectee.${NC}"
        pause
        return 0
      fi
      local i=0
      for line in "${inst_lines[@]}"; do
        i=$((i + 1))
        inst_names+=("$(printf '%s' "${line}" | cut -f1)")
        echo -e " ${CGREEN}${i})${CEND} $(printf '%s' "${line}" | cut -f1) (cache: $(printf '%s' "${line}" | cut -f2))"
      done
      printf 'SSDV2_PROMPT %s\n' '{"id":"decypharrgate.cache_choice","label":"Instance decypharr pour le cache","kind":"text","secret":false}' >&2
      read -rp "Numero ou nom de l'instance : " answer
      if [[ "${answer}" =~ ^[0-9]+$ ]] && [ "${answer}" -ge 1 ] && [ "${answer}" -le "${#inst_names[@]}" ]; then
        name="${inst_names[$((answer - 1))]}"
      else
        name="${answer}"
      fi
      if [ -n "${name}" ]; then
        python3 "${DECYPHARRGATE_SCRIPT}" increase-cache --upstream "${name}"
      else
        echo -e "${YELLOW}Aucune instance selectionnee.${NC}"
      fi
      pause
      ;;
    5)
      local -a gate_names=()
      mapfile -t gate_names < <(printf '%s' "${status}" | jq -r '.gates[]? | .name' 2>/dev/null)
      if [ "${#gate_names[@]}" -eq 0 ]; then
        echo -e "${YELLOW}Aucune gate installee.${NC}"
        pause
        return 0
      fi
      echo -e " ${BWHITE}Gates installees :${CEND}"
      printf ' %s\n' "${gate_names[@]}"
      printf 'SSDV2_PROMPT %s\n' '{"id":"decypharrgate.remove_gate","label":"Gate a desinstaller","kind":"text","secret":false}' >&2
      read -rp "Nom de la gate : " gate
      if [ -z "${gate}" ]; then
        pause
        return 0
      fi
      if ! printf '%s\n' "${gate_names[@]}" | grep -qxF -- "${gate}"; then
        echo -e "${RED}Gate inconnue.${NC}"
        pause
        return 0
      fi
      local configured
      configured="$(printf '%s' "${status}" | jq -r --arg g "${gate}" '.sonarrs[]? | select(.gate == $g) | .name' 2>/dev/null)"
      if [ -n "${configured}" ]; then
        echo -e "${YELLOW}Sonarr encore configure(s) sur ${gate} : ${configured}${NC}"
        echo -e "${YELLOW}Utilisez d'abord l'option 3 (Restaurer).${NC}"
      elif decypharrgate_confirm "decypharrgate.remove_gate_confirm" "Desinstaller ${gate} ?" "n"; then
        suppression_appli "${gate}" 1
        rm -f "${SETTINGS_STORAGE}/conf/${gate}.upstream"
        rm -f "${SETTINGS_STORAGE}/vars/${gate}.yml"
        echo -e "${CGREEN}Gate ${gate} desinstallee.${NC}"
      fi
      pause
      ;;
    6)
      clear
      cat <<'EOF'
CACHE GATE DECYPHARR — SONARR V5+

1. Pourquoi ?
   Sonarr v5 transforme un echec d'ajout au client de telechargement en
   "client indisponible" (pending). La gate transforme les rejets decypharr
   (non cache, provider_error, 503 provider) en 409 : Sonarr skippe sans
   pending et sans blocklist.

2. Qui est concerne ?
   - Sonarr v5+ (Sonarr, Sonarr4k) utilisant decypharr.
   - Radarr/Radarr4k v6 : deja skippe les erreurs generiques, pas besoin de gate.
   - Sonarr v4 : idem, pas besoin.
   - qbittorrent/rdtclient : non concerne.

3. Plusieurs instances decypharr ?
   Une gate par upstream utilise par un Sonarr v5+. Le menu cree les gates
   manquantes (decypharrgate ou decypharrgate-<instance>).

4. Cache DFS
   Action separee : 500 Mo -> 20 Go pour l'instance choisie, avec backup et
   restart. Utile meme si l'instance n'est pas derriere une gate.

5. Desinstallation
   Restaurer les Sonarr, puis Desinstaller la gate. Le cache et les Arrs ne
   sont pas modifies par la desinstallation.

RESUME
- Aucun port publie, aucun DNS, aucun label Traefik.
- Sonarr v5+ : file propre, pas de blocklist.
- Radarr v6 / Sonarr v4 : non concernes.
EOF
      pause
      ;;
    7|"")
      return 0
      ;;
    *)
      echo -e "${RED}Choix invalide.${NC}"
      pause
      ;;
  esac
}
