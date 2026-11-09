#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../../includes/functions.sh"
}

@test "P2: réseau absent, vide et occupé sans déconnexion étrangère" {
  docker() {
    case "$*" in
      'network inspect absent --format '*) return 1 ;;
      'network inspect empty --format '*) echo 0 ;;
      'network inspect occupied --format '*) echo 1 ;;
      'network rm empty') echo removed >&2 ;;
      *) echo "unexpected:$*" >&2; return 1 ;;
    esac
  }
  run cleanup_app_network absent
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run cleanup_app_network empty
  [ "$status" -eq 0 ]
  run cleanup_app_network occupied
  [ "$status" -eq 0 ]
  [[ "$output" == *"conservé"* ]]
  [[ "$output" != *"unexpected"* ]]
}

@test "P2: aucun affichage du QR en contexte WebUI ou non interactif" {
  docker() { echo 'SECRET-QR-MUST-NOT-APPEAR'; return 1; }
  export SSDV2_NON_INTERACTIVE=1
  run display_wireguard_qr
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  export SSDV2_NON_INTERACTIVE=0
  run display_wireguard_qr
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "P2: la suppression Jitsi conserve sa configuration en mode partiel" {
  export SETTINGS_STORAGE="$BATS_TEST_TMPDIR/storage"
  mkdir -p "$SETTINGS_STORAGE/conf" "$SETTINGS_STORAGE/vars" "$SETTINGS_STORAGE/docker/$USER/.jitsi-meet-cfg"
  touch "$SETTINGS_STORAGE/docker/$USER/.jitsi-meet-cfg/keep"
  get_from_account_yml() { echo jitsi; }
  manage_account_yml() { :; }
  collect_app_containers() { :; }
  log_write() { :; }
  checking_errors() { :; }
  ansible-playbook() { :; }
  sqlite3() { cat >/dev/null; }
  docker() { :; }
  sudo() { "$@"; }
  run suppression_appli jitsi 0
  [ "$status" -eq 0 ]
  [ -f "$SETTINGS_STORAGE/docker/$USER/.jitsi-meet-cfg/keep" ]
  run suppression_appli jitsi 1
  [ "$status" -eq 0 ]
  [ ! -e "$SETTINGS_STORAGE/docker/$USER/.jitsi-meet-cfg" ]
}
