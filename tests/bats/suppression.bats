#!/usr/bin/env bats
# Contrat de suppression : une suppression partielle (DELETE=0, utilisée par la
# réinstallation) conserve les données, et une application ne retire jamais les
# ressources d'une autre. Aucun Docker réel : `docker` et `sudo` sont simulés.

setup() {
  TESTDIR="$(mktemp -d)"
  export SETTINGS_STORAGE="$TESTDIR"
  export SETTINGS_SOURCE="$BATS_TEST_DIRNAME/../.."
  export USER="fixture"
  export DOCKER_LOG="$TESTDIR/docker.log"
  export REMOVED_LOG="$TESTDIR/removed.log"
  : >"$REMOVED_LOG"
  mkdir -p "$TESTDIR/conf" "$TESTDIR/bin" "$TESTDIR/vars" "$TESTDIR/docker/$USER"

  cat >"$TESTDIR/bin/docker" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$DOCKER_LOG"
case "$1" in
  rm)
    shift
    # Journalise un nom par ligne pour des assertions exactes.
    for arg in "$@"; do
      case "$arg" in -*) continue ;; esac
      printf '%s\n' "$arg" >>"$REMOVED_LOG"
    done
    ;;
esac
case "$*" in
  *"label=ssdv2.app="*) ;;
  *inspect*) exit 1 ;;
esac
exit 0
EOF
  chmod +x "$TESTDIR/bin/docker"

  cat >"$TESTDIR/bin/sudo" <<'EOF'
#!/bin/bash
exec "$@"
EOF
  chmod +x "$TESTDIR/bin/sudo"

  cat >"$TESTDIR/bin/findmnt" <<'EOF'
#!/bin/bash
exit 1
EOF
  chmod +x "$TESTDIR/bin/findmnt"

  # Aucun accès réseau ni base réelle : DNS (Ansible) et SQLite sont neutralisés.
  cat >"$TESTDIR/bin/ansible-playbook" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"${ANSIBLE_LOG:-/dev/null}"
exit 0
EOF
  chmod +x "$TESTDIR/bin/ansible-playbook"

  cat >"$TESTDIR/bin/sqlite3" <<'EOF'
#!/bin/bash
# Répond uniquement à la requête de statut utilisée par suppression_appli.
query="$*"
cat >/dev/null 2>&1
case "$query" in
  *"applications where name="*)
    name=$(printf '%s' "$query" | sed -n "s/.*name='\([^']*\)'.*/\1/p")
    if [ -n "$name" ] && [ -f "${INSTALLED_APPS:-/dev/null}" ] && grep -qxF "$name" "$INSTALLED_APPS"; then
      printf '2\n'
    fi
    ;;
esac
exit 0
EOF
  chmod +x "$TESTDIR/bin/sqlite3"

  export ANSIBLE_LOG="$TESTDIR/ansible.log"
  export INSTALLED_APPS="$TESTDIR/installed-apps"
  : >"$INSTALLED_APPS"

  export PATH="$TESTDIR/bin:$PATH"

  # shellcheck disable=SC1090
  source "$SETTINGS_SOURCE/includes/functions.sh"

  # Effets de bord hors périmètre du test.
  manage_account_yml() { :; }
  get_from_account_yml() { :; }
  log_write() { :; }
}

teardown() {
  rm -rf "$TESTDIR"
}

make_data() {
  for name in "$@"; do
    mkdir -p "$SETTINGS_STORAGE/docker/$USER/$name"
    printf 'donnee-%s\n' "$name" >"$SETTINGS_STORAGE/docker/$USER/$name/keep"
  done
}

assert_exists() {
  [ -f "$SETTINGS_STORAGE/docker/$USER/$1/keep" ] || {
    echo "donnée $1 absente" >&2
    return 1
  }
}

assert_absent() {
  [ ! -e "$SETTINGS_STORAGE/docker/$USER/$1" ] || {
    echo "donnée $1 encore présente" >&2
    return 1
  }
}

@test "suppression partielle paperless : données conservées" {
  make_data paperless mariadb redis
  run suppression_appli paperless 0
  [ "$status" -eq 0 ]
  assert_exists paperless
  assert_exists mariadb
  assert_exists redis
}

@test "suppression complète paperless : données retirées" {
  make_data paperless mariadb redis
  run suppression_appli paperless 1
  [ "$status" -eq 0 ]
  assert_absent paperless
  assert_absent mariadb
  assert_absent redis
}

@test "suppression partielle espocrm : base mysql conservée" {
  make_data espocrm mysql
  run suppression_appli espocrm 0
  [ "$status" -eq 0 ]
  assert_exists espocrm
  assert_exists mysql
  run grep -qxF "espocrm" "$REMOVED_LOG"
  [ "$status" -eq 0 ]
}

@test "suppression partielle nextcloud : coturn conservé" {
  make_data coturn
  run suppression_appli nextcloud 0
  [ "$status" -eq 0 ]
  assert_exists coturn
}

@test "suppression partielle jitsi : configuration conservée" {
  make_data .jitsi-meet-cfg
  run suppression_appli jitsi 0
  [ "$status" -eq 0 ]
  assert_exists .jitsi-meet-cfg
}

@test "suppression partielle zurg : données conservées" {
  make_data zurg
  run suppression_appli zurg 0
  [ "$status" -eq 0 ]
  assert_exists zurg
}

@test "suppression partielle piped : données conservées" {
  make_data piped
  run suppression_appli piped 0
  [ "$status" -eq 0 ]
  assert_exists piped
}

@test "suppression partielle jellygrail : fichiers conservés" {
  mkdir -p "$SETTINGS_STORAGE/docker/$USER/jellygrail/Video_Library"
  printf 'media\n' >"$SETTINGS_STORAGE/docker/$USER/jellygrail/Video_Library/keep"
  run suppression_appli jellygrail 0
  [ "$status" -eq 0 ]
  [ -f "$SETTINGS_STORAGE/docker/$USER/jellygrail/Video_Library/keep" ]
}

@test "streamfusion ne supprime pas le conteneur warp des autres applications" {
  run suppression_appli streamfusion 1
  [ "$status" -eq 0 ]
  run grep -qxF "warp" "$REMOVED_LOG"
  [ "$status" -ne 0 ]
  run grep -qxF "streamfusion" "$REMOVED_LOG"
  [ "$status" -eq 0 ]
}

@test "sffs conserve son cache persistant en suppression partielle" {
  make_data sffs-cache sffs-secrets
  run suppression_appli sffs 0
  [ "$status" -eq 0 ]
  assert_exists sffs-cache
  assert_absent sffs-secrets
}

@test "une application dépendante sans statut en base protège son conteneur" {
  printf 'stremio-postgres\n' >"$SETTINGS_STORAGE/conf/sftorznab.containers"
  # Aucune entrée en base : l'application peut être arrêtée, en échec ou
  # réinstallée, elle dépend toujours de la ressource.
  : >"$INSTALLED_APPS"
  run remove_app_containers streamfusion stremio-postgres streamfusion
  [ "$status" -eq 0 ]
  run grep -qxF "stremio-postgres" "$REMOVED_LOG"
  [ "$status" -ne 0 ]
  grep -qxF "streamfusion" "$REMOVED_LOG"
}

@test "streamfusion puis sftorznab : chacun protège la pile de l'autre" {
  printf 'stremio-postgres\nstremio-redis\n' >"$SETTINGS_STORAGE/conf/sftorznab.containers"
  run remove_app_containers streamfusion stremio-postgres stremio-redis
  [ "$status" -eq 0 ]
  run grep -qxF "stremio-postgres" "$REMOVED_LOG"
  [ "$status" -ne 0 ]

  : >"$REMOVED_LOG"
  printf 'streamfusion\nstremio-postgres\nstremio-redis\n' >"$SETTINGS_STORAGE/conf/streamfusion.containers"
  run remove_app_containers sftorznab stremio-postgres stremio-redis
  [ "$status" -eq 0 ]
  run grep -qxF "stremio-postgres" "$REMOVED_LOG"
  [ "$status" -ne 0 ]
}

@test "le dernier utilisateur d'un conteneur partagé peut le retirer" {
  printf 'mariadb\n' >"$SETTINGS_STORAGE/conf/otherapp.containers"
  run remove_app_containers paperless mariadb
  [ "$status" -eq 0 ]
  run grep -qxF "mariadb" "$REMOVED_LOG"
  [ "$status" -ne 0 ]

  : >"$REMOVED_LOG"
  rm -f "$SETTINGS_STORAGE/conf/otherapp.containers"
  run remove_app_containers paperless mariadb
  [ "$status" -eq 0 ]
  grep -qxF "mariadb" "$REMOVED_LOG"
}

@test "registre absent : la déclaration dans les hooks suffit" {
  rm -f "$SETTINGS_STORAGE/conf"/*.containers
  run remove_app_containers paperless mariadb
  [ "$status" -eq 0 ]
  grep -qxF "mariadb" "$REMOVED_LOG"
}

@test "propriété inconnue : ressource conservée avec un message explicite" {
  run remove_app_containers paperless ressource-inconnue
  [ "$status" -eq 0 ]
  local message="$output"
  run grep -qxF "ressource-inconnue" "$REMOVED_LOG"
  [ "$status" -ne 0 ]
  [[ "$message" == *"Ressource conservée (paperless)"* ]]
  [[ "$message" == *"propriété non établie"* ]]
}

@test "la liste générique ne garde que les conteneurs possédés" {
  printf 'shared-db\n' >"$SETTINGS_STORAGE/conf/paperless.containers"
  printf 'shared-db\n' >"$SETTINGS_STORAGE/conf/otherapp.containers"
  output="$(printf 'shared-db\ndb-paperless\n' | filter_owned_containers paperless)"
  [[ "$output" == *"db-paperless"* ]]
  [[ "$output" != "shared-db"* ]]
  [[ "$output" == *"Ressource conservée (paperless)"* ]]
}

@test "dossier partagé : conservé tant qu'une autre application le référence" {
  mkdir -p "$SETTINGS_STORAGE/vars"
  printf 'pgrole: otherapp\npg_volumes:\n  - "{{ settings.storage }}/docker/{{ lookup('"'"'env'"'"','"'"'USER'"'"') }}/mariadb:/data"\n' \
    >"$SETTINGS_STORAGE/vars/otherapp.yml"
  make_data mariadb
  run remove_app_dir paperless mariadb
  [ "$status" -eq 0 ]
  assert_exists mariadb
  [[ "$output" == *"Ressource conservée (paperless)"* ]]

  rm -f "$SETTINGS_STORAGE/vars/otherapp.yml"
  run remove_app_dir paperless mariadb
  [ "$status" -eq 0 ]
  assert_absent mariadb
}

@test "volume partagé : conservé, puis retiré pour le dernier utilisateur" {
  printf 'shared-vol\n' >"$SETTINGS_STORAGE/conf/paperless.volumes"
  printf 'shared-vol\n' >"$SETTINGS_STORAGE/conf/otherapp.volumes"
  run remove_app_volumes paperless
  [ "$status" -eq 0 ]
  local message="$output"
  run grep -q "volume rm -f shared-vol" "$DOCKER_LOG"
  [ "$status" -ne 0 ]
  [[ "$message" == *"Ressource conservée (paperless) : volume shared-vol"* ]]

  rm -f "$SETTINGS_STORAGE/conf/otherapp.volumes"
  run remove_app_volumes paperless
  [ "$status" -eq 0 ]
  grep -q "volume rm -f shared-vol" "$DOCKER_LOG"
}

@test "un nom conventionnel revendiqué par une autre application est conservé" {
  # `<app>` et `db-<app>` sont des indices, pas une preuve : si une autre
  # application enregistre ce nom, la ressource n'est pas retirée.
  printf 'paperless\n' >"$SETTINGS_STORAGE/conf/otherapp.containers"
  run remove_app_containers paperless paperless
  [ "$status" -eq 0 ]
  local message="$output"
  run grep -qxF "paperless" "$REMOVED_LOG"
  [ "$status" -ne 0 ]
  [[ "$message" == *"Ressource conservée (paperless)"* ]]
}
