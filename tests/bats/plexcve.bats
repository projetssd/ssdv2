#!/usr/bin/env bats
# Tests du backend Plex2Shell (CVE-2026-96652 / 96654 / 96655 / 96656).

setup() {
  SETTINGS_SOURCE="$BATS_TEST_DIRNAME/../.."
  PLEXCVE="$SETTINGS_SOURCE/includes/config/scripts/plexcve.py"
  FIXTURE="$(mktemp -d)"
  make_fixture
}

teardown() {
  rm -rf "$FIXTURE"
}

make_fixture() {
  mkdir -p "$FIXTURE/Logs" "$FIXTURE/Codecs/a336ba9-deadbeef-linux-aarch64"
  cat >"$FIXTURE/container.json" <<EOF
{
  "Id": "abc",
  "Image": "sha256:abc",
  "State": {"Running": true},
  "Config": {
    "Image": "lscr.io/linuxserver/plex:latest",
    "Env": ["PUID=1002", "TZ=Europe/Paris"],
    "Labels": {
      "org.opencontainers.image.version": "1.43.5.11029",
      "traefik.http.routers.plex-rtr.middlewares": "chain-no-auth@file"
    },
    "ExposedPorts": {"32400/tcp": {}}
  },
  "HostConfig": {
    "PortBindings": {"32400/tcp": [{"HostIp": "0.0.0.0", "HostPort": "32400"}]},
    "Binds": ["$HOME:$HOME:rw", "/tmp:/tmp:rw", "/dev/shm:/dev/shm:rw"],
    "SecurityOpt": null,
    "CapDrop": null,
    "ReadonlyRootfs": false,
    "Privileged": false,
    "ShmSize": 67108864
  },
  "Mounts": [
    {"Type": "bind", "Source": "$HOME", "Destination": "$HOME", "RW": true},
    {"Type": "bind", "Source": "/tmp", "Destination": "/tmp", "RW": true},
    {"Type": "bind", "Source": "/dev/shm", "Destination": "/dev/shm", "RW": true}
  ],
  "NetworkSettings": {"Networks": {"traefik_proxy": {"IPAddress": "172.18.0.19"}}}
}
EOF
  printf '<Preferences />\n' >"$FIXTURE/Preferences.xml"
  printf 'id\n' >"$FIXTURE/Codecs/.device-id"
  printf 'x' >"$FIXTURE/Codecs/a336ba9-deadbeef-linux-aarch64/libh264_decoder.so"
  mkdir -p "$FIXTURE/Medias"
  ln -s /mnt/fake/root/film.mkv "$FIXTURE/Medias/film.mkv"
  cat >"$FIXTURE/Logs/Plex Media Server.log" <<'EOF'
Oct 24, 2026 16:55:10.151 [1] DEBUG - Request: [91.92.40.202:43822 (WAN)] GET /player/timeline/subscribe?protocol=http%3A%2F%2F127.0.0.1%3A32400%2Fsystem%2Fagents%2Fz%2FsearchOne HTTP/1.1
Oct 24, 2026 16:55:10.152 [2] DEBUG - Completed: [91.92.40.202:43822] 400 GET /player/timeline/subscribe (1 live)
EOF
  : >"$FIXTURE/traefik.log"
  cat >"$FIXTURE/host.json" <<'EOF'
{"ufw":"inactive","docker_user":"empty","docker_user_rules":0,"published_ports":[],"watchtower":{"present":false,"cleanup":false,"schedule":null}}
EOF
}

@test "plexcve: selftest" {
  run python3 "$PLEXCVE" selftest
  [ "$status" -eq 0 ]
  [[ "$output" == *"selftest: ok"* ]]
}

@test "plexcve: patch, doc et menu presents" {
  [ -f "$SETTINGS_SOURCE/patches/20261025_plex2shell" ]
  [ -f "$SETTINGS_SOURCE/docs/plex2shell.md" ]
  [ -f "$SETTINGS_SOURCE/docs/verification-32400-443.md" ]
  [ -f "$SETTINGS_SOURCE/includes/menus-plexcve.sh" ]
}

@test "ssdv2ctl: la commande security plex-cve est declaree" {
  run python3 "$SETTINGS_SOURCE/ssdv2ctl" security plex-cve --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"plex-cve"* ]]
}

@test "plexcve: scan fixture detecte 32400 direct, sans succes" {
  run python3 "$PLEXCVE" scan --fixture "$FIXTURE" --json
  [ "$status" -eq 1 ]
  [ "$(printf '%s' "$output" | jq -r '.attack_path')" = "direct_32400" ]
  [ "$(printf '%s' "$output" | jq -r '.container.version_status')" = "patched" ]
  [ "$(printf '%s' "$output" | jq -r '.container.logs.attempts')" = "1" ]
  [ "$(printf '%s' "$output" | jq -r '.container.logs.blocked')" = "1" ]
  [ "$(printf '%s' "$output" | jq -r '.container.logs.success')" = "0" ]
  [ "$(printf '%s' "$output" | jq -r '.summary.status')" = "hardening_required" ]
}

@test "plexcve: scan fixture detecte 443 quand Traefik voit la requete" {
  cat >"$FIXTURE/traefik.log" <<'EOF'
{"ClientHost":"91.92.40.202","RequestHost":"plex.kesurof.eu","RequestPath":"/player/timeline/subscribe","DownstreamStatus":400}
EOF
  run python3 "$PLEXCVE" scan --fixture "$FIXTURE" --json
  [ "$status" -eq 1 ]
  [ "$(printf '%s' "$output" | jq -r '.attack_path')" = "traefik_443" ]
}

@test "plexcve: scan fixture detecte un zz*.so" {
  printf '\177ELF' >"$FIXTURE/Codecs/zz123.so"
  run python3 "$PLEXCVE" scan --fixture "$FIXTURE" --json
  [ "$status" -eq 1 ]
  [ "$(printf '%s' "$output" | jq -r '.container.codecs.has_zz')" = "true" ]
  [ "$(printf '%s' "$output" | jq -r '.summary.status')" = "compromised" ]
}

@test "plexcve: close-port dry-run affiche DOCKER-USER" {
  run python3 "$PLEXCVE" close-port --dry-run --ports 32400
  [ "$status" -eq 0 ]
  [[ "$output" == *"DOCKER-USER"* ]]
  [[ "$output" == *"32400"* ]]
}

@test "plexcve: le menu lit le cache sans lancer de scan" {
  export SETTINGS_STORAGE="$FIXTURE/state"
  mkdir -p "$SETTINGS_STORAGE/conf"
  python3 "$PLEXCVE" scan --fixture "$FIXTURE" --json >"$SETTINGS_STORAGE/conf/plexcve-status.json" || true
  cat >"$FIXTURE/fake-plexcve.py" <<'PY'
import sys
print("SHOULD_NOT_RUN", file=sys.stderr)
sys.exit(99)
PY
  run bash -c 'source "$1"; PLEXCVE_SCRIPT="$2"; plexcve_status_json' _ \
    "$SETTINGS_SOURCE/includes/menus-plexcve.sh" "$FIXTURE/fake-plexcve.py"
  [ "$status" -eq 0 ]
  [[ "$output" != *"SHOULD_NOT_RUN"* ]]
  [ "$(printf '%s' "$output" | jq -r '.summary.status')" = "hardening_required" ]
}

@test "plexcve: report --input ne relance pas de scan" {
  python3 "$PLEXCVE" scan --fixture "$FIXTURE" --json >"$FIXTURE/scan.json" || true
  run python3 "$PLEXCVE" report --input "$FIXTURE/scan.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"PLEX2SHELL"* ]]
  [[ "$output" == *"direct_32400"* ]]
}

@test "plexcve: logs --input ne relance pas de scan" {
  python3 "$PLEXCVE" scan --fixture "$FIXTURE" --json >"$FIXTURE/scan.json" || true
  run python3 "$PLEXCVE" logs --input "$FIXTURE/scan.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Analyse des logs"* ]]
  [[ "$output" == *"direct_32400"* ]]
}

@test "plexcve: fix-plex --use-cache exige un cache" {
  export SETTINGS_STORAGE="$FIXTURE/empty"
  mkdir -p "$SETTINGS_STORAGE"
  run python3 "$PLEXCVE" fix-plex --use-cache --apply
  [ "$status" -eq 1 ]
  [[ "$output" == *"Aucun audit en cache"* ]]
}

@test "plexcve: les confirmations affichent o/n" {
  run bash -c 'source "$1"; printf "o\n" | plexcve_confirm test "Question ?" "n"' _ \
    "$SETTINGS_SOURCE/includes/menus-plexcve.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"(o/n)"* ]]
}

@test "plexcve: detecte une cible de symlink non montee" {
  run python3 "$PLEXCVE" scan --fixture "$FIXTURE" --json
  [ "$status" -eq 1 ]
  [ "$(printf '%s' "$output" | jq -r '.container.symlink_targets.unmounted[0]')" = "/mnt/fake/root" ]
  [ "$(printf '%s' "$output" | jq -r '[.summary.issues[] | select(.code == "symlink_target_not_mounted")] | length')" -ge 1 ]
}

@test "plexcve: report --input affiche les recommandations" {
  python3 "$PLEXCVE" scan --fixture "$FIXTURE" --json >"$FIXTURE/scan.json" || true
  run python3 "$PLEXCVE" report --input "$FIXTURE/scan.json"
  [[ "$output" == *"Recommandations"* ]]
}

@test "plexcve: detecte un fallback d'acces distant non conforme" {
  cat >"$FIXTURE/Preferences.xml" <<'EOF'
<Preferences customConnections="https://plex.example.com:443,http://1.2.3.4:32400" ManualPortMappingMode="1" ManualPortMappingPort="32400" />
EOF
  run python3 "$PLEXCVE" scan --fixture "$FIXTURE" --json
  [ "$status" -eq 1 ]
  [ "$(printf '%s' "$output" | jq -r '[.summary.issues[] | select(.code == "remote_access_insecure_fallback")] | length')" -ge 1 ]
  [ "$(printf '%s' "$output" | jq -r '[.summary.issues[] | select(.code == "remote_access_manual_32400")] | length')" -ge 1 ]
}

@test "ssdv2ctl: la commande security plex-cve fix-remote est declaree" {
  run python3 "$SETTINGS_SOURCE/ssdv2ctl" security plex-cve fix-remote --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"fix-remote"* ]]
}
