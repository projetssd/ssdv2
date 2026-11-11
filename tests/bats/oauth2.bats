#!/usr/bin/env bats
# Tests de l'outillage OAuth2 (ssdv2ctl + menu).

setup() {
  SETTINGS_SOURCE="$BATS_TEST_DIRNAME/../.."
}

@test "oauth2: commandes ssdv2ctl disponibles" {
  run python3 "$SETTINGS_SOURCE/ssdv2ctl" security oauth2 status --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--text"* ]]
  run python3 "$SETTINGS_SOURCE/ssdv2ctl" security oauth2 --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"status"* ]]
  [[ "$output" == *"repair"* ]]
  [[ "$output" == *"rollback"* ]]
}

@test "oauth2: entrées de menu présentes" {
  run sqlite3 "$SETTINGS_SOURCE/menu" \
    "select action from menu where parent_id=96 order by ordre;"
  [ "$status" -eq 0 ]
  [[ "$output" == *"menu_secu_system_oauth2_status"* ]]
  [[ "$output" == *"menu_secu_system_oauth2_repair"* ]]
}

@test "oauth2: backend de réparation présent" {
  [ -f "$SETTINGS_SOURCE/includes/config/scripts/oauth2_repair.py" ]
}
