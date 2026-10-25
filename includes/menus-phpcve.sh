# shellcheck shell=bash
# Menu de gestion des CVE PHP2Shell (CVE-2026-109618 / CVE-2026-109619).
# Ce fichier est source par includes/menus.sh (voir le patch
# 20261022_php2shell).
#
# Le menu travaille sur le dernier audit en cache. Seule l'option 1 lance un
# scan ; les autres actions ne relancent pas de scan implicite.

PHPCVE_SCRIPT="${SETTINGS_SOURCE}/includes/config/scripts/phpcve.py"

phpcve_cache_file() {
  printf '%s' "${SETTINGS_STORAGE%/}/conf/phpcve-status.json"
}

phpcve_status_json() {
  local cache
  cache="$(phpcve_cache_file)"
  if [ -s "${cache}" ] && jq -e '.summary and .host' "${cache}" >/dev/null 2>&1; then
    cat "${cache}"
  else
    echo '{}'
  fi
}

phpcve_run() {
  python3 "${PHPCVE_SCRIPT}" "$@"
}

phpcve_confirm() {
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

phpcve_vulnerable_apps() {
  local status="$1"
  printf '%s' "${status}" | jq -r '
    .containers[]?
    | select(.is_php == true and .status == "vulnerable" and .app != null)
    | .app' 2>/dev/null | sort -u
}

phpcve_vulnerable_containers() {
  local status="$1"
  printf '%s' "${status}" | jq -r '
    .containers[]?
    | select(.is_php == true and .status == "vulnerable")
    | [.name, (.app // "hors SSDV2"), (.php_version // "?")] | @tsv' 2>/dev/null
}

phpcve_require_cache() {
  local cache
  cache="$(phpcve_cache_file)"
  if [ -s "${cache}" ] && jq -e '.summary and .host' "${cache}" >/dev/null 2>&1; then
    return 0
  fi
  echo -e "${YELLOW}Aucun audit en cache. Lancer l'option 1 (Audit complet).${NC}"
  return 1
}

phpcve_scan_to_cache() {
  local cache tmp
  cache="$(phpcve_cache_file)"
  mkdir -p "$(dirname "${cache}")" 2>/dev/null || true
  tmp="$(mktemp)"
  phpcve_run scan --json >"${tmp}" 2>/dev/null || true
  if ! jq -e '.summary and .host' "${tmp}" >/dev/null 2>&1; then
    echo -e "${RED}Scan en echec.${NC}"
    cat "${tmp}" 2>/dev/null
    rm -f "${tmp}"
    return 1
  fi
  chmod 600 "${tmp}" 2>/dev/null || true
  mv "${tmp}" "${cache}"
  return 0
}

menu_phpcve() {
  local status host_status host_php host_pkg host_exposure host_fix
  local summary_vuln summary_patched summary_unknown summary_php
  local last_audit has_status choice answer app name cache recommendation recommendation2
  local -a apps=() lines=() names=()
  cache="$(phpcve_cache_file)"

  while true; do
    clear
    logo
    status="$(phpcve_status_json)"

    has_status="$(printf '%s' "${status}" | jq -r 'if .summary then "oui" else "non" end' 2>/dev/null)"
    host_status="$(printf '%s' "${status}" | jq -r '.host.status // "inconnu"' 2>/dev/null)"
    host_php="$(printf '%s' "${status}" | jq -r '.host.php.version // "absent"' 2>/dev/null)"
    host_pkg="$(printf '%s' "${status}" | jq -r '.host.candidate // "n/a"' 2>/dev/null)"
    host_exposure="$(printf '%s' "${status}" | jq -r '.host.exposure // "inconnue"' 2>/dev/null)"
    host_fix="$(printf '%s' "${status}" | jq -r 'if .host.status == "patched" then "deja patche" elif .host.fix_available == true then "disponible" else "non disponible" end' 2>/dev/null)"
    summary_vuln="$(printf '%s' "${status}" | jq -r '.summary.vulnerable // 0' 2>/dev/null)"
    summary_patched="$(printf '%s' "${status}" | jq -r '.summary.patched // 0' 2>/dev/null)"
    summary_unknown="$(printf '%s' "${status}" | jq -r '.summary.unknown // 0' 2>/dev/null)"
    summary_php="$(printf '%s' "${status}" | jq -r '.summary.php_containers // 0' 2>/dev/null)"
    last_audit="$(printf '%s' "${status}" | jq -r '.generated_at // "jamais"' 2>/dev/null)"
    recommendation="$(printf '%s' "${status}" | jq -r '.summary.recommendations[0] // empty' 2>/dev/null)"
    recommendation2="$(printf '%s' "${status}" | jq -r '.summary.recommendations[1] // empty' 2>/dev/null)"

    echo -e "${CRED}---------------------------------------------------------------${CEND}"
    echo -e "${CCYAN}     AUDIT PHP2SHELL (CVE-2026-109618 / CVE-2026-109619)${CEND}"
    echo -e "${CRED}---------------------------------------------------------------${CEND}"
    echo -e " ${BWHITE}Hote${CEND} : ${host_status} | PHP ${host_php} | exposition ${host_exposure}"
    echo -e " ${BWHITE}Correctif hote${CEND} : ${host_fix} (candidat apt ${host_pkg})"
    echo -e " ${BWHITE}Dernier audit${CEND} : ${last_audit}"
    echo -e " ${BWHITE}Resume${CEND} : ${summary_vuln} vulnerable(s), ${summary_patched} patche(s), ${summary_unknown} inconnu(s)"
    echo -e " ${BWHITE}Conteneurs PHP${CEND} : ${summary_php}"
    if [ -n "${recommendation}" ]; then
      echo -e " ${BWHITE}Recommandation${CEND} : ${recommendation}"
      if [ -n "${recommendation2}" ]; then
        echo "                   ${recommendation2}"
      fi
    fi
    if [ "${has_status}" = "non" ]; then
      echo -e " ${YELLOW}Aucun audit recent. Choisir 1 pour scanner (seul scan du menu).${NC}"
    elif [ "${summary_vuln}" -gt 0 ]; then
      echo -e " ${YELLOW}Action requise : patcher PHP sans attendre.${NC}"
    else
      echo -e " ${CGREEN}Aucun element vulnerable detecte.${NC}"
    fi
    echo -e "${CRED}---------------------------------------------------------------${CEND}"
    echo -e " ${CGREEN}1)${CEND} Audit complet (hote + SSDV2 + conteneurs) (scan + cache)"
    echo -e " ${CGREEN}2)${CEND} Corriger le serveur (paquets PHP)"
    echo -e " ${CGREEN}3)${CEND} Mettre a jour les conteneurs PHP geres par SSDV2"
    echo -e " ${CGREEN}4)${CEND} Appliquer les mitigations partielles (hote)"
    echo -e " ${CGREEN}5)${CEND} Isoler/arreter un conteneur vulnerable"
    echo -e " ${CGREEN}6)${CEND} Rapport detaille (cache)"
    echo -e " ${CGREEN}7)${CEND} Aide / CVE php2shell"
    echo -e " ${CGREEN}8)${CEND} Retour"
    echo -e "${CRED}---------------------------------------------------------------${CEND}"

    printf 'SSDV2_PROMPT %s\n' '{"id":"phpcve.action","label":"Choix php2shell","kind":"choice","options":["1","2","3","4","5","6","7","8"]}' >&2
    read -rp "Votre choix : " choice

    case "${choice}" in
      1)
        clear
        logo
        if phpcve_scan_to_cache; then
          phpcve_run report --input "${cache}"
        fi
        pause
        ;;
      2)
        if phpcve_confirm "phpcve.fix_host" "Corriger les paquets PHP de l'hote ?" "o"; then
          if phpcve_run fix-host; then
            rm -f "${cache}"
            echo -e " ${CGREEN}Correctif applique. Relancer l'audit (option 1) pour actualiser.${NC}"
          fi
        fi
        pause
        ;;
      3)
        if ! phpcve_require_cache; then
          pause
          continue
        fi
        apps=()
        mapfile -t apps < <(phpcve_vulnerable_apps "${status}")
        if [ "${#apps[@]}" -eq 0 ]; then
          echo -e "${YELLOW}Aucun conteneur PHP vulnerable gere par SSDV2.${NC}"
          pause
          continue
        fi
        echo -e " ${BWHITE}Applications concernees :${CEND}"
        printf '   - %s\n' "${apps[@]}"
        if phpcve_confirm "phpcve.fix_apps" "Mettre a jour ces applications ?" "o"; then
          for app in "${apps[@]}"; do
            [ -n "${app}" ] || continue
            echo -e "${BLUE}--- ${app} ---${NC}"
            phpcve_run fix-app "${app}"
          done
          rm -f "${cache}"
          echo -e " ${CGREEN}Mises a jour faites. Relancer l'audit (option 1) pour actualiser.${NC}"
        fi
        pause
        ;;
      4)
        echo -e "${YELLOW}Mitigations partielles : session.upload_progress=0"
        echo -e "et fatal_error_backtraces=0 (PHP 8.5). Le patch reste obligatoire.${NC}"
        if phpcve_confirm "phpcve.harden_host" "Appliquer les mitigations sur l'hote ?" "n"; then
          if phpcve_run harden-host; then
            rm -f "${cache}"
            echo -e " ${CGREEN}Mitigations appliquees. Relancer l'audit (option 1) pour actualiser.${NC}"
          fi
        fi
        pause
        ;;
      5)
        if ! phpcve_require_cache; then
          pause
          continue
        fi
        lines=()
        names=()
        mapfile -t lines < <(phpcve_vulnerable_containers "${status}")
        if [ "${#lines[@]}" -eq 0 ]; then
          echo -e "${YELLOW}Aucun conteneur PHP vulnerable detecte.${NC}"
          pause
          continue
        fi
        echo -e " ${BWHITE}Conteneurs vulnerables :${CEND}"
        local i=0 line
        for line in "${lines[@]}"; do
          i=$((i + 1))
          names+=("$(printf '%s' "${line}" | cut -f1)")
          printf '   %s) %s [%s] PHP %s\n' "${i}" \
            "$(printf '%s' "${line}" | cut -f1)" \
            "$(printf '%s' "${line}" | cut -f2)" \
            "$(printf '%s' "${line}" | cut -f3)"
        done
        printf 'SSDV2_PROMPT %s\n' '{"id":"phpcve.stop_container","label":"Conteneur a arreter","kind":"text","secret":false}' >&2
        read -rp "Numero ou nom du conteneur : " answer
        if [[ "${answer}" =~ ^[0-9]+$ ]] && [ "${answer}" -ge 1 ] && [ "${answer}" -le "${#names[@]}" ]; then
          name="${names[$((answer - 1))]}"
        else
          name="${answer}"
        fi
        if [ -z "${name}" ]; then
          pause
          continue
        fi
        if ! printf '%s\n' "${names[@]}" | grep -qxF -- "${name}"; then
          echo -e "${RED}Conteneur inconnu dans la liste.${NC}"
          pause
          continue
        fi
        if phpcve_confirm "phpcve.stop_confirm" "Arreter ${name} ?" "n"; then
          if phpcve_run stop "${name}"; then
            rm -f "${cache}"
            echo -e " ${CGREEN}Conteneur arrete. Relancer l'audit (option 1) pour actualiser.${NC}"
          fi
        fi
        pause
        ;;
      6)
        if ! phpcve_require_cache; then
          pause
          continue
        fi
        clear
        logo
        phpcve_run report --input "${cache}"
        echo -e " ${CGREEN}JSON : ${cache}${CEND}"
        pause
        ;;
      7)
        clear
        cat <<'EOF'
PHP2SHELL — CVE-2026-109618 / CVE-2026-109619

1. Pourquoi ?
   Deux vulnerabilites critiques du coeur de PHP permettent une execution
   de code a distance non authentifiee. Les versions corrigees sont
   PHP 8.2.35, 8.3.36, 8.4.27 et 8.5.12.

2. Qui est concerne ?
   Tout PHP qui traite des requetes HTTP : Apache mod_php, PHP-FPM, CGI,
   FrankenPHP, LiteSpeed, ainsi que les applications PHP embarquees dans
   les conteneurs (Nextcloud, Bookstack, WordPress, etc.).

3. L'hote
   Le script compare la version du paquet de la distribution, pas seulement
   `php -v`. Sur Ubuntu 24.04, le correctif est
   php8.3 8.3.6-0ubuntu0.24.04.13.

4. Les conteneurs
   Les conteneurs geres par SSDV2 sont mis a jour par pull + recreation,
   sans suppression des volumes. Les images epinglees ou non gerees sont
   signalees : un pull ne suffit pas toujours.

5. Mitigations
   session.upload_progress=0 et fatal_error_backtraces=0 (PHP 8.5)
   reduisent l'exposition mais ne remplacent pas le patch. memory_limit=-1
   n'est pas applique automatiquement (risque d'OOM serveur).

6. Scans
   Seule l'option 1 lance un scan. Les options 3, 5 et 6 utilisent le cache
   ${SETTINGS_STORAGE}/conf/phpcve-status.json.
   Apres une correction, le cache est invalide : relancer l'option 1.

7. Commandes
   ssdv2ctl security php-cve scan --json
   ssdv2ctl security php-cve report --input <fichier>
   ssdv2ctl security php-cve fix-host
   ssdv2ctl security php-cve fix-app <app>

RESUME
- Le patch PHP est la seule correction complete.
- Aucune suppression de volume ni de donnee.
- Les conteneurs hors SSDV2 ne sont pas modifies automatiquement.
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
