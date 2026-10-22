# shellcheck shell=bash
# Menu de gestion des CVE PHP2Shell (CVE-2026-109618 / CVE-2026-109619).
# Ce fichier est source par includes/menus.sh (voir le patch
# 20261022_php2shell).

PHPCVE_SCRIPT="${SETTINGS_SOURCE}/includes/config/scripts/phpcve.py"

phpcve_status_json() {
  if [ -f "${PHPCVE_SCRIPT}" ]; then
    python3 "${PHPCVE_SCRIPT}" status 2>/dev/null || echo '{}'
  else
    echo '{}'
  fi
}

phpcve_run() {
  python3 "${PHPCVE_SCRIPT}" "$@"
}

phpcve_confirm() {
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

menu_phpcve() {
  clear
  logo

  local status host_status host_php host_pkg host_exposure host_fix
  local summary_vuln summary_patched summary_unknown summary_php
  local choice answer app name
  status="$(phpcve_status_json)"

  host_status="$(printf '%s' "${status}" | jq -r '.host.status // "inconnu"' 2>/dev/null)"
  host_php="$(printf '%s' "${status}" | jq -r '.host.php.version // "absent"' 2>/dev/null)"
  host_pkg="$(printf '%s' "${status}" | jq -r '.host.candidate // "n/a"' 2>/dev/null)"
  host_exposure="$(printf '%s' "${status}" | jq -r '.host.exposure // "inconnue"' 2>/dev/null)"
  host_fix="$(printf '%s' "${status}" | jq -r 'if .host.status == "patched" then "deja patche" elif .host.fix_available == true then "disponible" else "non disponible" end' 2>/dev/null)"
  summary_vuln="$(printf '%s' "${status}" | jq -r '.summary.vulnerable // 0' 2>/dev/null)"
  summary_patched="$(printf '%s' "${status}" | jq -r '.summary.patched // 0' 2>/dev/null)"
  summary_unknown="$(printf '%s' "${status}" | jq -r '.summary.unknown // 0' 2>/dev/null)"
  summary_php="$(printf '%s' "${status}" | jq -r '.summary.php_containers // 0' 2>/dev/null)"

  echo -e "${CRED}---------------------------------------------------------------${CEND}"
  echo -e "${CCYAN}     AUDIT PHP2SHELL (CVE-2026-109618 / CVE-2026-109619)${CEND}"
  echo -e "${CRED}---------------------------------------------------------------${CEND}"
  echo -e " ${BWHITE}Hote${CEND} : ${host_status} | PHP ${host_php} | exposition ${host_exposure}"
  echo -e " ${BWHITE}Correctif hote${CEND} : ${host_fix} (candidat apt ${host_pkg})"
  echo -e " ${BWHITE}Resume${CEND} : ${summary_vuln} vulnerable(s), ${summary_patched} patche(s), ${summary_unknown} inconnu(s)"
  echo -e " ${BWHITE}Conteneurs PHP${CEND} : ${summary_php}"
  if [ "${summary_vuln}" -gt 0 ]; then
    echo -e " ${YELLOW}Action requise : patcher PHP sans attendre.${NC}"
  else
    echo -e " ${CGREEN}Aucun element vulnerable detecte.${NC}"
  fi
  echo -e "${CRED}---------------------------------------------------------------${CEND}"
  echo -e " ${CGREEN}1)${CEND} Audit complet (hote + SSDV2 + conteneurs)"
  echo -e " ${CGREEN}2)${CEND} Corriger le serveur (paquets PHP)"
  echo -e " ${CGREEN}3)${CEND} Mettre a jour les conteneurs PHP geres par SSDV2"
  echo -e " ${CGREEN}4)${CEND} Appliquer les mitigations partielles (hote)"
  echo -e " ${CGREEN}5)${CEND} Isoler/arreter un conteneur vulnerable"
  echo -e " ${CGREEN}6)${CEND} Rapport detaille / export JSON"
  echo -e " ${CGREEN}7)${CEND} Aide / CVE php2shell"
  echo -e " ${CGREEN}8)${CEND} Retour"
  echo -e "${CRED}---------------------------------------------------------------${CEND}"

  printf 'SSDV2_PROMPT %s\n' '{"id":"phpcve.action","label":"Choix php2shell","kind":"choice","options":["1","2","3","4","5","6","7","8"]}' >&2
  read -rp "Votre choix : " choice

  case "${choice}" in
    1)
      clear
      logo
      phpcve_run scan
      pause
      ;;
    2)
      if phpcve_confirm "phpcve.fix_host" "Corriger les paquets PHP de l'hote ?" "o"; then
        phpcve_run fix-host
      fi
      pause
      ;;
    3)
      local -a apps=()
      mapfile -t apps < <(phpcve_vulnerable_apps "${status}")
      if [ "${#apps[@]}" -eq 0 ]; then
        echo -e "${YELLOW}Aucun conteneur PHP vulnerable gere par SSDV2.${NC}"
        pause
        return 0
      fi
      echo -e " ${BWHITE}Applications concernees :${CEND}"
      printf '   - %s\n' "${apps[@]}"
      if phpcve_confirm "phpcve.fix_apps" "Mettre a jour ces applications ?" "o"; then
        for app in "${apps[@]}"; do
          [ -n "${app}" ] || continue
          echo -e "${BLUE}--- ${app} ---${NC}"
          phpcve_run fix-app "${app}"
        done
      fi
      pause
      ;;
    4)
      echo -e "${YELLOW}Mitigations partielles : session.upload_progress=0"
      echo -e "et fatal_error_backtraces=0 (PHP 8.5). Le patch reste obligatoire.${NC}"
      if phpcve_confirm "phpcve.harden_host" "Appliquer les mitigations sur l'hote ?" "n"; then
        phpcve_run harden-host
      fi
      pause
      ;;
    5)
      local -a lines=() names=()
      mapfile -t lines < <(phpcve_vulnerable_containers "${status}")
      if [ "${#lines[@]}" -eq 0 ]; then
        echo -e "${YELLOW}Aucun conteneur PHP vulnerable detecte.${NC}"
        pause
        return 0
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
        return 0
      fi
      if ! printf '%s\n' "${names[@]}" | grep -qxF -- "${name}"; then
        echo -e "${RED}Conteneur inconnu dans la liste.${NC}"
        pause
        return 0
      fi
      if phpcve_confirm "phpcve.stop_confirm" "Arreter ${name} ?" "n"; then
        phpcve_run stop "${name}"
      fi
      pause
      ;;
    6)
      clear
      logo
      phpcve_run report
      if phpcve_confirm "phpcve.export_json" "Ecrire aussi le rapport JSON ?" "n"; then
        local out="${SETTINGS_STORAGE}/conf/phpcve-status.json"
        mkdir -p "${SETTINGS_STORAGE}/conf" 2>/dev/null || true
        phpcve_run status >"${out}" 2>/dev/null || true
        echo -e " ${CGREEN}Rapport ecrit : ${out}${CEND}"
      fi
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

6. Commandes
   ssdv2ctl security php-cve scan --json
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
}
