#!/usr/bin/env bats

setup() {
  TESTDIR="$(mktemp -d)"
  export SETTINGS_STORAGE="$TESTDIR/storage"
  export SETTINGS_SOURCE="$TESTDIR/source"
  mkdir -p "$SETTINGS_STORAGE/vars" "$SETTINGS_SOURCE/includes/dockerapps/vars"
  source "$BATS_TEST_DIRNAME/../../includes/functions.sh"
  log_write() { :; }
  get_from_account_yml() {
    case "$1" in
      *.auth) printf '%s\n' "${TEST_AUTH:-notfound}" ;;
      *) printf '%s\n' existing ;;
    esac
  }
  manage_account_yml() { printf 'saved %s=%s\n' "$1" "$2"; }
  auth_unitaire() { printf 'asked %s\n' "$1"; }
  ansible-playbook() { :; }
}

teardown() {
  rm -rf "$TESTDIR"
}

@test "middleware sans authentification : aucun choix demandé et compte synchronisé" {
  printf "traefik_middleware_override: 'chain-no-auth@file'\n" > "$SETTINGS_SOURCE/includes/dockerapps/vars/app.yml"
  run launch_service app
  [ "$status" -eq 0 ]
  [[ "$output" == *'saved sub.app.auth=aucune'* ]]
  [[ "$output" != *'asked app'* ]]
}

@test "middleware forcé : une ancienne valeur est corrigée" {
  printf 'traefik_middleware_override: chain-no-auth@file\n' > "$SETTINGS_SOURCE/includes/dockerapps/vars/app.yml"
  TEST_AUTH=basique
  run launch_service app
  [ "$status" -eq 0 ]
  [[ "$output" == *'saved sub.app.auth=aucune'* ]]
  [[ "$output" != *'asked app'* ]]
}

@test "fichier personnalisé prioritaire sans middleware forcé : choix demandé" {
  printf "traefik_middleware_override: 'chain-no-auth@file'\n" > "$SETTINGS_SOURCE/includes/dockerapps/vars/app.yml"
  printf 'pgrole: app\n' > "$SETTINGS_STORAGE/vars/app.yml"
  run launch_service app
  [ "$status" -eq 0 ]
  [[ "$output" == *'asked app'* ]]
  [[ "$output" != *'saved sub.app.auth=aucune'* ]]
}
