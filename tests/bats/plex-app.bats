#!/usr/bin/env bats
# Tests du role Ansible Plex.

setup() {
  SETTINGS_SOURCE="$BATS_TEST_DIRNAME/../.."
  ROLE="$SETTINGS_SOURCE/includes/dockerapps/vars/plex.yml"
}

@test "plex: le role utilise capabilities, pas cap_add" {
  run grep -nE '^[[:space:]]+cap_add:' "$ROLE"
  [ "$status" -ne 0 ]
  run grep -nE '^[[:space:]]+capabilities:' "$ROLE"
  [ "$status" -eq 0 ]
}
