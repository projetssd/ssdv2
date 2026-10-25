# shellcheck shell=bash
# Menu de gestion Plex2Shell (CVE-2026-96652 / 96654 / 96655 / 96656).
# Ce fichier est source par includes/menus.sh (voir le patch
# 20261025_plex2shell).
#
# Le menu travaille sur le dernier audit en cache. Seule l'option 1 lance un
# scan ; les autres actions ne relancent pas de scan implicite.

PLEXCVE_SCRIPT="${SETTINGS_SOURCE}/includes/config/scripts/plexcve.py"

plexcve_cache_file() {
  printf '%s' "${SETTINGS_STORAGE%/}/conf/plexcve-status.json"
}

plexcve_status_json() {
  local cache
  cache="$(plexcve_cache_file)"
  if [ -s "${cache}" ] && jq -e '.summary and .container' "${cache}" >/dev/null 2>&1; then
    cat "${cache}"
  else
    echo '{}'
  fi
}

plexcve_run() {
  python3 "${PLEXCVE_SCRIPT}" "$@"
}

plexcve_confirm() {
  local id="$1" label="$2" default="$3" answer prompt_label
  prompt_label="${label} (o/n)"
  printf 'SSDV2_PROMPT %s\n' "{\"id\":\"${id}\",\"label\":\"${prompt_label}\",\"kind\":\"confirm\",\"secret\":false}" >&2
  printf '%s [%s] : ' "${prompt_label}" "${default}" >&2
  read -r answer
  answer="${answer:-${default}}"
  case "${answer,,}" in
    o|oui|y|yes) return 0 ;;
    *) return 1 ;;
  esac
}

plexcve_ports_to_close() {
  local status="$1"
  printf '%s' "${status}" | jq -r '
    ([32400] + [(.other_exposed_ports[]?.host_port)]) | unique | map(tostring) | join(",")
  ' 2>/dev/null
}

plexcve_require_cache() {
  local cache
  cache="$(plexcve_cache_file)"
  if [ -s "${cache}" ] && jq -e '.summary and .container' "${cache}" >/dev/null 2>&1; then
    return 0
  fi
  echo -e "${YELLOW}Aucun audit en cache. Lancer l'option 1 (Audit complet).${NC}"
  return 1
}

plexcve_scan_to_cache() {
  local cache tmp
  cache="$(plexcve_cache_file)"
  mkdir -p "$(dirname "${cache}")" 2>/dev/null || true
  tmp="$(mktemp)"
  plexcve_run scan --json >"${tmp}" 2>/dev/null || true
  if ! jq -e '.summary and .container' "${tmp}" >/dev/null 2>&1; then
    echo -e "${RED}Scan en echec.${NC}"
    cat "${tmp}" 2>/dev/null
    rm -f "${tmp}"
    return 1
  fi
  chmod 600 "${tmp}" 2>/dev/null || true
  mv "${tmp}" "${cache}"
  return 0
}

menu_plexcve() {
  local status summary_status version version_status version_env attack_path
  local attempts blocked success middleware port_public issues_count
  local last_audit has_status choice ports cache plex_conform recommendation recommendation2
  cache="$(plexcve_cache_file)"

  while true; do
    clear
    logo
    status="$(plexcve_status_json)"

    has_status="$(printf '%s' "${status}" | jq -r 'if .summary.status then "oui" else "non" end' 2>/dev/null)"
    summary_status="$(printf '%s' "${status}" | jq -r '.summary.status // "aucun audit"' 2>/dev/null)"
    version="$(printf '%s' "${status}" | jq -r '.container.version // "?"' 2>/dev/null)"
    version_status="$(printf '%s' "${status}" | jq -r '.container.version_status // "inconnu"' 2>/dev/null)"
    version_env="$(printf '%s' "${status}" | jq -r 'if .container.version_env then .container.version_env else "absent" end' 2>/dev/null)"
    attack_path="$(printf '%s' "${status}" | jq -r '.attack_path // "inconnu"' 2>/dev/null)"
    attempts="$(printf '%s' "${status}" | jq -r '.container.logs.attempts // 0' 2>/dev/null)"
    blocked="$(printf '%s' "${status}" | jq -r '.container.logs.blocked // 0' 2>/dev/null)"
    success="$(printf '%s' "${status}" | jq -r '.container.logs.success // 0' 2>/dev/null)"
    middleware="$(printf '%s' "${status}" | jq -r '.container.traefik.middlewares // "ABSENT"' 2>/dev/null)"
    port_public="$(printf '%s' "${status}" | jq -r 'if ([.container.ports[]? | select(.host_ip == "0.0.0.0" or .host_ip == "::" or .host_ip == "")] | length) > 0 then "PUBLIE" else "ferme" end' 2>/dev/null)"
    issues_count="$(printf '%s' "${status}" | jq -r '.summary.issue_count // 0' 2>/dev/null)"
    last_audit="$(printf '%s' "${status}" | jq -r '.generated_at // "jamais"' 2>/dev/null)"
    plex_conform="$(printf '%s' "${status}" | jq -r 'if .summary.plex_conform then "oui" else "non" end' 2>/dev/null)"
    recommendation="$(printf '%s' "${status}" | jq -r '.summary.recommendations[0] // empty' 2>/dev/null)"
    recommendation2="$(printf '%s' "${status}" | jq -r '.summary.recommendations[1] // empty' 2>/dev/null)"

    echo -e "${CRED}---------------------------------------------------------------${CEND}"
    echo -e "${CCYAN}     AUDIT PLEX2SHELL (CVE-2026-96652 / 96654 / 96655 / 96656)${CEND}"
    echo -e "${CRED}---------------------------------------------------------------${CEND}"
    echo -e " ${BWHITE}Statut${CEND} : ${summary_status} | Plex ${version} (${version_status}) | VERSION ${version_env}"
    if [ "${has_status}" = "oui" ]; then
      echo -e " ${BWHITE}Plex conforme${CEND} : ${plex_conform}"
    fi
    echo -e " ${BWHITE}Dernier audit${CEND} : ${last_audit}"
    echo -e " ${BWHITE}Chemin d'attaque${CEND} : ${attack_path}"
    echo -e " ${BWHITE}Tentatives${CEND} : ${attempts} (${blocked} bloquees, ${success} succes)"
    echo -e " ${BWHITE}Middleware 443${CEND} : ${middleware} | 32400 : ${port_public}"
    echo -e " ${BWHITE}Problemes${CEND} : ${issues_count}"
    if [ -n "${recommendation}" ]; then
      echo -e " ${BWHITE}Recommandation${CEND} : ${recommendation}"
      if [ -n "${recommendation2}" ]; then
        echo "                   ${recommendation2}"
      fi
    fi
    if [ "${has_status}" = "non" ]; then
      echo -e " ${YELLOW}Aucun audit recent. Choisir 1 pour scanner (seul scan du menu).${NC}"
    elif [ "${summary_status}" = "compromised" ]; then
      echo -e " ${RED}IoC detecte : ne pas nettoyer a l'aveugle, isoler et rotation.${NC}"
    elif [ "${summary_status}" = "hardening_required" ]; then
      if [ "${plex_conform}" = "oui" ]; then
        echo -e " ${CGREEN}Plex est conforme. Reste : ports publies / Watchtower (voir recommandation).${NC}"
      else
        echo -e " ${YELLOW}Pas de compromission prouvee, mais durcissement requis.${NC}"
      fi
    elif [ "${summary_status}" = "ok" ]; then
      echo -e " ${CGREEN}Configuration conforme.${NC}"
    fi
    echo -e "${CRED}---------------------------------------------------------------${CEND}"
    echo -e " ${CGREEN}1)${CEND} Audit complet Plex (scan + cache)"
    echo -e " ${CGREEN}2)${CEND} Corriger Plex (VERSION, 32400, middleware, montages)"
    echo -e " ${CGREEN}3)${CEND} Fermer les ports exposes"
    echo -e " ${CGREEN}4)${CEND} Analyser les logs d'exploitation (cache)"
    echo -e " ${CGREEN}5)${CEND} Isoler/arreter Plex"
    echo -e " ${CGREEN}6)${CEND} Rapport detaille (cache)"
    echo -e " ${CGREEN}7)${CEND} Aide / CVE Plex2Shell"
    echo -e " ${CGREEN}8)${CEND} Retour"
    echo -e "${CRED}---------------------------------------------------------------${CEND}"

    printf 'SSDV2_PROMPT %s\n' '{"id":"plexcve.action","label":"Choix plex2shell","kind":"choice","options":["1","2","3","4","5","6","7","8"]}' >&2
    read -rp "Votre choix : " choice

    case "${choice}" in
      1)
        clear
        logo
        if plexcve_scan_to_cache; then
          plexcve_run report --input "${cache}"
        fi
        pause
        ;;
      2)
        if ! plexcve_require_cache; then
          pause
          continue
        fi
        echo -e "${YELLOW}La correction va :"
        echo -e "  - ajouter VERSION=latest ;"
        echo -e "  - ajouter le middleware chain-no-auth@file sur 443 ;"
        echo -e "  - retirer la publication 0.0.0.0:32400 ;"
        echo -e "  - retirer \$HOME, /tmp et /dev/shm ;"
        echo -e "  - configurer customConnections HTTPS et desactiver le port manuel 32400 ;"
        echo -e "  - detecter les medias et monter /mnt en lecture seule (rslave) ;"
        echo -e "    (mode strict possible en CLI : --media-mode strict) ;"
        echo -e "  - recréer Plex avec sauvegarde et rollback.${NC}"
        if plexcve_confirm "plexcve.fix" "Appliquer la correction maintenant ?" "n"; then
          if plexcve_run fix-plex --apply --use-cache --media-mode generic; then
            rm -f "${cache}"
            echo -e " ${CGREEN}Correction appliquee. Relancer l'audit (option 1) pour actualiser.${NC}"
          fi
        fi
        pause
        ;;
      3)
        ports="$(plexcve_ports_to_close "${status}")"
        echo -e "${YELLOW}Ports proposes : ${ports}${NC}"
        if [ "${has_status}" = "non" ]; then
          echo -e "${YELLOW}Liste partielle : lancer l'option 1 pour inclure les autres ports.${NC}"
        fi
        echo -e "${YELLOW}Oracle bloque peut-etre deja l'externe, mais ces ports restent publies localement.${NC}"
        if plexcve_confirm "plexcve.close_ports" "Fermer ces ports via DOCKER-USER ?" "n"; then
          if plexcve_run close-port --apply --ports "${ports}"; then
            rm -f "${cache}"
            echo -e " ${CGREEN}Ports fermes. Relancer l'audit (option 1) pour actualiser.${NC}"
          fi
        fi
        pause
        ;;
      4)
        if ! plexcve_require_cache; then
          pause
          continue
        fi
        clear
        logo
        plexcve_run logs --input "${cache}"
        pause
        ;;
      5)
        echo -e "${RED}La quarantaine arrete Plex et le retire de Traefik. Aucune donnee n'est supprimee.${NC}"
        if plexcve_confirm "plexcve.quarantine" "Isoler Plex maintenant ?" "n"; then
          if plexcve_run quarantine --apply; then
            rm -f "${cache}"
            echo -e " ${CGREEN}Plex isole. Relancer l'audit (option 1) pour actualiser.${NC}"
          fi
        fi
        pause
        ;;
      6)
        if ! plexcve_require_cache; then
          pause
          continue
        fi
        clear
        logo
        plexcve_run report --input "${cache}"
        echo -e " ${CGREEN}JSON : ${cache}${CEND}"
        pause
        ;;
      7)
        clear
        cat <<'EOF'
PLEX2SHELL — CVE-2026-96652 / 96654 / 96655 / 96656

1. La chaine
   SSRF /player/timeline -> vol du PlexOnlineToken -> SSRF transcoder ->
   ecriture .so via TranscoderH264Options=dump-yuv -> chargement dans Codecs.

2. Versions
   Corrige dans Plex 1.43.3.10861 (recommande 1.43.5+).
   Sans VERSION, l'image LinuxServer ne met pas PMS a jour.

3. 32400 ou 443 ?
   Les logs Plex seuls ne donnent pas le port de destination.
   Le script correle avec le log d'acces Traefik :
   - Plex seul -> 32400 direct ;
   - Plex + Traefik -> 443 (ou les deux).

4. IoC
   Codecs/zz*.so, .so hors bundle, TranscoderH264Options avec dump-yuv/stats,
   tentatives /player/timeline/subscribe avec searchOne/sslip.io.

5. Scans
   Seule l'option 1 lance un scan. Les options 2, 4 et 6 utilisent le cache
   ${SETTINGS_STORAGE}/conf/plexcve-status.json.
   Apres une correction, le cache est invalide : relancer l'option 1.

6. Commandes
   ssdv2ctl security plex-cve scan --json
   ssdv2ctl security plex-cve report --input <fichier>
   ssdv2ctl security plex-cve logs --input <fichier>
   ssdv2ctl security plex-cve fix-plex --apply --use-cache
   ssdv2ctl security plex-cve fix-plex --apply --use-cache --media-mode strict
   ssdv2ctl security plex-cve fix-remote --apply
   ssdv2ctl security plex-cve close-port --apply --ports 32400
   ssdv2ctl security plex-cve quarantine --apply

7. Limites
   Aucune suppression de volume ou de media.
   En cas d'IoC, le script refuse fix-plex et propose la quarantaine.
EOF
        pause
        ;;
      8|"")
        return 0
        ;;
      *)
        echo -e "${RED}Choix invalide.${NC}"
        pause
        ;;
    esac
  done
}
