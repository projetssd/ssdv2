#!/usr/bin/env bats

setup() {
  TESTDIR="$(mktemp -d)"
  export SETTINGS_SOURCE="$TESTDIR/source"
  export SETTINGS_STORAGE="$TESTDIR/storage"
  export FORCE_PATCH=20261115_crowdsec_etherremix
  mkdir -p "$SETTINGS_SOURCE/patches" "$SETTINGS_STORAGE/conf"
  source "$BATS_TEST_DIRNAME/../../includes/functions.sh"
  cat > "$SETTINGS_SOURCE/patches/$FORCE_PATCH" <<'EOF'
#!/bin/bash
echo run >> "$SETTINGS_STORAGE/runs"
[ ! -f "$SETTINGS_STORAGE/fail" ]
EOF
}

teardown() {
  rm -rf "$TESTDIR"
}

@test "patch : première application enregistrée et non répétée" {
  unset FORCE_PATCH
  run apply_patches
  [ "$status" -eq 0 ]
  grep -qx 20261115_crowdsec_etherremix "$SETTINGS_STORAGE/conf/.ssdv2-patches"
  run apply_patches
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$SETTINGS_STORAGE/runs")" -eq 1 ]
}

@test "FORCE_PATCH : rejoue seulement le patch demandé" {
  printf '%s\n' "$FORCE_PATCH" > "$SETTINGS_STORAGE/conf/.ssdv2-patches"
  printf 'exit 99\n' > "$SETTINGS_SOURCE/patches/another_patch"
  run apply_patches
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$SETTINGS_STORAGE/runs")" -eq 1 ]
  [ "$(wc -l < "$SETTINGS_STORAGE/conf/.ssdv2-patches")" -eq 1 ]
}

@test "patch en échec : pas de marqueur et nouvel essai possible" {
  touch "$SETTINGS_STORAGE/fail"
  run apply_patches
  [ "$status" -eq 1 ]
  ! grep -qx "$FORCE_PATCH" "$SETTINGS_STORAGE/conf/.ssdv2-patches"
  rm "$SETTINGS_STORAGE/fail"
  run apply_patches
  [ "$status" -eq 0 ]
  grep -qx "$FORCE_PATCH" "$SETTINGS_STORAGE/conf/.ssdv2-patches"
}

@test "FORCE_PATCH en échec : erreur remontée et journal disponible" {
  printf '%s\n' "$FORCE_PATCH" > "$SETTINGS_STORAGE/conf/.ssdv2-patches"
  touch "$SETTINGS_STORAGE/fail"
  run apply_patches
  [ "$status" -eq 1 ]
  [ -f "$SETTINGS_STORAGE/conf/$FORCE_PATCH.log" ]
}
