#!/usr/bin/env bats
# Tests du backend PHP2Shell (CVE-2026-109618 / CVE-2026-109619).

setup() {
  SETTINGS_SOURCE="$BATS_TEST_DIRNAME/../.."
  PHPCVE="$SETTINGS_SOURCE/includes/config/scripts/phpcve.py"
}

@test "phpcve: selftest des comparaisons de versions" {
  run python3 "$PHPCVE" selftest
  [ "$status" -eq 0 ]
  [[ "$output" == *"selftest: ok"* ]]
}

@test "phpcve: le patch et la documentation sont presents" {
  [ -f "$SETTINGS_SOURCE/patches/20261022_php2shell" ]
  [ -f "$SETTINGS_SOURCE/docs/php2shell.md" ]
  [ -f "$SETTINGS_SOURCE/includes/menus-phpcve.sh" ]
}

@test "ssdv2ctl: la commande security php-cve est declaree" {
  run python3 "$SETTINGS_SOURCE/ssdv2ctl" security php-cve --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"php-cve"* ]]
}

@test "phpcve: le menu lit le cache sans lancer de scan" {
  local state
  state="$(mktemp -d)"
  mkdir -p "$state/conf"
  cat >"$state/conf/phpcve-status.json" <<'EOF'
{"host":{"status":"patched"},"containers":[],"ssdv2":{},"summary":{"vulnerable":0,"patched":1,"unknown":0,"not_php":0}}
EOF
  cat >"$state/fake.py" <<'PY'
import sys
print("SHOULD_NOT_RUN", file=sys.stderr)
sys.exit(99)
PY
  run bash -c 'export SETTINGS_STORAGE="$1"; source "$2"; PHPCVE_SCRIPT="$3"; phpcve_status_json' _ \
    "$state" "$SETTINGS_SOURCE/includes/menus-phpcve.sh" "$state/fake.py"
  [ "$status" -eq 0 ]
  [[ "$output" != *"SHOULD_NOT_RUN"* ]]
  [ "$(printf '%s' "$output" | jq -r '.host.status')" = "patched" ]
  rm -rf "$state"
}

@test "phpcve: report --input ne relance pas de scan" {
  local tmp
  tmp="$(mktemp -d)"
  cat >"$tmp/scan.json" <<'EOF'
{"host":{"status":"patched"},"containers":[],"ssdv2":{},"summary":{"vulnerable":0,"patched":1,"unknown":0,"not_php":0}}
EOF
  run python3 "$PHPCVE" report --input "$tmp/scan.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PHP2SHELL"* ]]
  rm -rf "$tmp"
}

@test "phpcve: les confirmations affichent o/n" {
  run bash -c 'source "$1"; printf "o\n" | phpcve_confirm test "Question ?" "n"' _ \
    "$SETTINGS_SOURCE/includes/menus-phpcve.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"(o/n)"* ]]
}
