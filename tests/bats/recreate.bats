#!/usr/bin/env bats
# Tests de la recréation « image seule » (doublon de mount point, réseau).

setup() {
  SETTINGS_SOURCE="$BATS_TEST_DIRNAME/../.."
  HELPER="$SETTINGS_SOURCE/includes/config/scripts/recreate_app_container.py"
}

@test "recreate: selftest interne (mounts, binds, reseau)" {
  run python3 "$HELPER" --selftest
  [ "$status" -eq 0 ]
  [[ "$output" == *"selftest: ok"* ]]
}

@test "recreate: le conteneur reste obligatoire hors selftest" {
  run python3 "$HELPER"
  [ "$status" -ne 0 ]
  [[ "$output" == *"le nom du conteneur est requis"* ]]
}
