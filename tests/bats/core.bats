#!/usr/bin/env bats
# Tests unitaires des fonctions pures de includes/functions.sh
# Lancement : bats tests/bats/core.bats

setup() {
  TESTDIR="$(mktemp -d)"
  export SETTINGS_STORAGE="$TESTDIR"
  export SETTINGS_SOURCE="$BATS_TEST_DIRNAME/../.."
  mkdir -p "$TESTDIR/conf" "$TESTDIR/bin" "$TESTDIR/vars"

  # faux docker : ne répond qu'à l'inventaire par label
  cat >"$TESTDIR/bin/docker" <<'EOF'
#!/bin/bash
case "$*" in
  *"label=ssdv2.app="*) printf 'app\nlabelonly\n' ;;
  *) : ;;
esac
EOF
  chmod +x "$TESTDIR/bin/docker"
  export PATH="$TESTDIR/bin:$PATH"

  # shellcheck disable=SC1090
  source "$SETTINGS_SOURCE/includes/functions.sh"
}

teardown() {
  rm -rf "$TESTDIR"
}

@test "json_array_from_lines: liste vide" {
  result="$(json_array_from_lines)"
  [ "$result" = "[]" ]
}

@test "json_array_from_lines: un element" {
  result="$(json_array_from_lines wings)"
  [ "$result" = '["wings"]' ]
}

@test "json_array_from_lines: plusieurs elements dedupliques" {
  result="$(json_array_from_lines collabora office collabora)"
  [ "$result" = '["collabora","office"]' ]
}

@test "json_array_from_lines: ignore les lignes vides" {
  result="$(json_array_from_lines a '' b)"
  [ "$result" = '["a","b"]' ]
}

@test "collect_app_containers: union label + registre + conventions" {
  printf 'db-app\napp\n' >"$SETTINGS_STORAGE/conf/app.containers"
  result="$(collect_app_containers app)"
  expected="$(printf '%s\n' app db-app labelonly memcached-app redis-app | sort)"
  [ "$result" = "$expected" ]
}

@test "collect_app_containers: registre absent -> label + conventions" {
  result="$(collect_app_containers app)"
  expected="$(printf '%s\n' app db-app labelonly memcached-app redis-app | sort)"
  [ "$result" = "$expected" ]
}

@test "account_cache_file: chemin sous SETTINGS_STORAGE" {
  result="$(account_cache_file)"
  [ "$result" = "$SETTINGS_STORAGE/.account.cache.json" ]
}
