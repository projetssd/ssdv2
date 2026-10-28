#!/usr/bin/env bats
# Tests statiques des applications Silo, Silo patché (silosffs) et sffs.

setup() {
  SETTINGS_SOURCE="$BATS_TEST_DIRNAME/../.."
}

@test "catalogue: silo, silosffs et sffs sont declares" {
  run grep -q '^silo - ' "$SETTINGS_SOURCE/includes/config/services-available"
  [ "$status" -eq 0 ]
  run grep -q '^silosffs - ' "$SETTINGS_SOURCE/includes/config/services-available"
  [ "$status" -eq 0 ]
  run grep -q '^sffs - ' "$SETTINGS_SOURCE/includes/config/services-available"
  [ "$status" -eq 0 ]
}

@test "silosffs: instance locale independante de silo" {
  run grep -q "^pgrole: 'silosffs'" "$SETTINGS_SOURCE/includes/dockerapps/vars/silosffs.yml"
  [ "$status" -eq 0 ]
  run grep -q "^image: 'localhost/silo-sffs:latest'" "$SETTINGS_SOURCE/includes/dockerapps/vars/silosffs.yml"
  [ "$status" -eq 0 ]
  run grep -q "^pull_image: false" "$SETTINGS_SOURCE/includes/dockerapps/vars/silosffs.yml"
  [ "$status" -eq 0 ]
  run grep -q "SILO_SF_ROOT: '/mnt/sffs'" "$SETTINGS_SOURCE/includes/dockerapps/vars/silosffs.yml"
  [ "$status" -eq 0 ]
}

@test "sffs: cible silosffs et ne patche pas silo" {
  run grep -q "SFFS_SILO_URL: 'http://silosffs:8080'" "$SETTINGS_SOURCE/includes/dockerapps/vars/sffs.yml"
  [ "$status" -eq 0 ]
  run grep -q "launch_service" "$SETTINGS_SOURCE/includes/dockerapps/pretasks/sffs.yml"
  [ "$status" -ne 0 ]
  run grep -q "vars/silo.yml" "$SETTINGS_SOURCE/includes/dockerapps/pretasks/sffs.yml"
  [ "$status" -ne 0 ]
  run grep -q "launch_service" "$SETTINGS_SOURCE/includes/dockerapps/posttasks/sffs.yml"
  [ "$status" -ne 0 ]
}

@test "sffs: depend de silosffs avant installation" {
  run grep -q "name='silosffs'" "$SETTINGS_SOURCE/includes/dockerapps/pretasks/sffs.yml"
  [ "$status" -eq 0 ]
  run grep -q "L'application silosffs" "$SETTINGS_SOURCE/includes/dockerapps/pretasks/sffs.yml"
  [ "$status" -eq 0 ]
}

@test "sffs: cache TMDB persistant hors dossier applicatif" {
  run grep -q '^sffs_cache_dir:' "$SETTINGS_SOURCE/includes/dockerapps/vars/sffs.yml"
  [ "$status" -eq 0 ]
  run grep -q "SFFS_TMDB_CACHE: '/cache/tmdb-tv.json'" "$SETTINGS_SOURCE/includes/dockerapps/vars/sffs.yml"
  [ "$status" -eq 0 ]
  run grep -q "SFFS_KNOWN_CACHE: '/cache/known-cached.json'" "$SETTINGS_SOURCE/includes/dockerapps/vars/sffs.yml"
  [ "$status" -eq 0 ]
  run grep -q '{{ sffs_cache_dir }}:/cache' "$SETTINGS_SOURCE/includes/dockerapps/vars/sffs.yml"
  [ "$status" -eq 0 ]
  run grep -q 'Migrer les anciens caches sffs' "$SETTINGS_SOURCE/includes/dockerapps/pretasks/sffs.yml"
  [ "$status" -eq 0 ]
}

@test "suppression: volumes et cache retirés en mode complet" {
  run grep -q 'db-silo-data' "$SETTINGS_SOURCE/includes/functions.sh"
  [ "$status" -eq 0 ]
  run grep -q 'db-silosffs-data' "$SETTINGS_SOURCE/includes/functions.sh"
  [ "$status" -eq 0 ]
  run grep -q 'sffs-cache' "$SETTINGS_SOURCE/includes/functions.sh"
  [ "$status" -eq 0 ]
}

@test "suppression: nettoyage sffs et silosffs" {
  run grep -q '^  sffs)' "$SETTINGS_SOURCE/includes/functions.sh"
  [ "$status" -eq 0 ]
  run grep -q '^  silosffs)' "$SETTINGS_SOURCE/includes/functions.sh"
  [ "$status" -eq 0 ]
  run grep -q 'DROP OWNED BY' "$SETTINGS_SOURCE/includes/functions.sh"
  [ "$status" -eq 0 ]
  run grep -q "delete from api_keys where label = 'sffs'" "$SETTINGS_SOURCE/includes/functions.sh"
  [ "$status" -eq 0 ]
  run grep -q 'Supprimer d.abord l.application sffs' "$SETTINGS_SOURCE/includes/functions.sh"
  [ "$status" -eq 0 ]
}

@test "silosffs: utilise la pile Silo commune" {
  run grep -q 'templates/generique/silo_stack.yml' "$SETTINGS_SOURCE/includes/dockerapps/pretasks/silosffs.yml"
  [ "$status" -eq 0 ]
  run grep -q 'templates/generique/silo_post.yml' "$SETTINGS_SOURCE/includes/dockerapps/posttasks/silosffs.yml"
  [ "$status" -eq 0 ]
}

@test "silosffs: cache des images désactivé à l'installation" {
  run grep -q '^silo_cache_images:' "$SETTINGS_SOURCE/includes/dockerapps/vars/silosffs.yml"
  [ "$status" -eq 0 ]
  run grep -q 'metadata.cache_images' "$SETTINGS_SOURCE/includes/dockerapps/posttasks/silosffs.yml"
  [ "$status" -eq 0 ]
  run grep -q 'If-Match: \*' "$SETTINGS_SOURCE/includes/dockerapps/posttasks/silosffs.yml"
  [ "$status" -eq 0 ]
  run grep -q 'ssdv2-silosffs-image-cache' "$SETTINGS_SOURCE/includes/dockerapps/posttasks/silosffs.yml"
  [ "$status" -eq 0 ]
}
