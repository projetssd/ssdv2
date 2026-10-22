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
