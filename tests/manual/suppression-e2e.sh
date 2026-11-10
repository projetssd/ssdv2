#!/usr/bin/env bash
# Essai de bout en bout de la suppression SSDV2 sur un démon Docker JETABLE.
#
# Ce script n'est PAS exécuté par la CI et ne doit jamais viser l'installation
# réelle : il refuse de démarrer si DOCKER_HOST pointe sur le socket de l'hôte.
#
# Prérequis :
#   - un démon Docker dédié (VM jetable, ou hôte de test), accessible via
#     DOCKER_HOST (ex. tcp://127.0.0.1:2375) ou un contexte Docker dédié ;
#   - bash, docker, sqlite3, curl.
#
# Lancement :
#   DOCKER_HOST=tcp://127.0.0.1:2375 ./tests/manual/suppression-e2e.sh
#
# Ce qu'il vérifie :
#   1. installation de deux applications factices partageant un conteneur ;
#   2. suppression partielle (DELETE=0) : conteneur partagé et données conservés ;
#   3. suppression complète de la première : l'application restante fonctionne ;
#   4. suppression de la dernière : la ressource partagée est retirée ;
#   5. ressource de propriété inconnue conservée avec un message explicatif.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# ---------------------------------------------------------------------------
# Garde-fou : jamais le démon de l'hôte.
# ---------------------------------------------------------------------------
DOCKER_HOST_VALUE="${DOCKER_HOST:-unix:///var/run/docker.sock}"
case "$DOCKER_HOST_VALUE" in
  unix:///var/run/docker.sock|unix:///run/docker.sock)
    cat >&2 <<'MSG'
Refus : DOCKER_HOST pointe sur le démon Docker de l'hôte.
Ce test crée et supprime des conteneurs, des volumes et des réseaux.
Utilisez une VM ou un démon jetable, par exemple :
  DOCKER_HOST=tcp://127.0.0.1:2375 ./tests/manual/suppression-e2e.sh
MSG
    exit 2
    ;;
esac

command -v docker >/dev/null || { echo "docker requis" >&2; exit 2; }
docker info >/dev/null 2>&1 || { echo "démon Docker injoignable : $DOCKER_HOST_VALUE" >&2; exit 2; }

WORKDIR="$(mktemp -d)"
export SETTINGS_STORAGE="$WORKDIR/seedbox"
export SETTINGS_SOURCE="$REPO_ROOT"
export USER="fixture-e2e"
export APP_A="e2e-alpha"
export APP_B="e2e-beta"
export SHARED_NAME="e2e-shared-db"

cleanup() {
  docker rm -f "$APP_A" "$APP_B" "$SHARED_NAME" >/dev/null 2>&1 || true
  docker volume rm -f "e2e-shared-vol" >/dev/null 2>&1 || true
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

mkdir -p "$SETTINGS_STORAGE/conf" "$SETTINGS_STORAGE/vars" "$SETTINGS_STORAGE/docker/$USER"

notes() { printf '\n== %s\n' "$1"; }
fail() { printf 'ÉCHEC : %s\n' "$1" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Fixtures : deux applications qui déclarent le même conteneur partagé.
# ---------------------------------------------------------------------------
cat >"$SETTINGS_STORAGE/vars/$APP_A.yml" <<EOF
pgrole: '$APP_A'
shared_container: '$SHARED_NAME'
EOF
cat >"$SETTINGS_STORAGE/vars/$APP_B.yml" <<EOF
pgrole: '$APP_B'
shared_container: '$SHARED_NAME'
EOF
printf '%s\n' "$SHARED_NAME" "$APP_A" >"$SETTINGS_STORAGE/conf/$APP_A.containers"
printf '%s\n' "$SHARED_NAME" "$APP_B" >"$SETTINGS_STORAGE/conf/$APP_B.containers"
printf 'e2e-shared-vol\n' >"$SETTINGS_STORAGE/conf/$APP_A.volumes"
printf 'e2e-shared-vol\n' >"$SETTINGS_STORAGE/conf/$APP_B.volumes"

# Base minimale utilisée par suppression_appli.
sqlite3 "$SETTINGS_SOURCE/ssddb" "create table if not exists applications(name varchar(50) primary key, status integer, subdomain varchar(50), port integer);" 2>/dev/null || true

# shellcheck disable=SC1090
source "$SETTINGS_SOURCE/includes/functions.sh"

# Neutralise les effets hors périmètre (coffre, DNS, logs).
manage_account_yml() { :; }
get_from_account_yml() { :; }
log_write() { :; }

notes "1. Installation de deux applications partageant $SHARED_NAME"
docker run -d --name "$SHARED_NAME" --label "ssdv2.app=$APP_A" \
  -v "e2e-shared-vol:/data" alpine:3.20 sh -c 'mkdir -p /data && echo partage >/data/marker && sleep 3600' >/dev/null
docker run -d --name "$APP_A" --label "ssdv2.app=$APP_A" alpine:3.20 sleep 3600 >/dev/null
docker run -d --name "$APP_B" --label "ssdv2.app=$APP_B" alpine:3.20 sleep 3600 >/dev/null
mkdir -p "$SETTINGS_STORAGE/docker/$USER/$APP_A" "$SETTINGS_STORAGE/docker/$USER/$APP_B"
echo "donnee-alpha" >"$SETTINGS_STORAGE/docker/$USER/$APP_A/keep"
echo "donnee-beta" >"$SETTINGS_STORAGE/docker/$USER/$APP_B/keep"

notes "2. Suppression partielle de $APP_A (DELETE=0)"
suppression_appli "$APP_A" 0 >/dev/null
docker inspect "$SHARED_NAME" >/dev/null 2>&1 || fail "conteneur partagé supprimé en mode partiel"
[ -f "$SETTINGS_STORAGE/docker/$USER/$APP_A/keep" ] || fail "données de $APP_A perdues en mode partiel"
printf 'OK : partagé et données conservés\n'

notes "3. Suppression complète de $APP_A alors que $APP_B est installée"
suppression_appli "$APP_A" 1 >/dev/null
docker inspect "$SHARED_NAME" >/dev/null 2>&1 || fail "conteneur partagé supprimé alors que $APP_B l'utilise"
docker inspect "$APP_B" >/dev/null 2>&1 || fail "conteneur de $APP_B supprimé"
docker run --rm -v "e2e-shared-vol:/data" alpine:3.20 cat /data/marker | grep -q partage \
  || fail "volume partagé vidé"
printf 'OK : application restante et volume intacts\n'

notes "4. Suppression de la dernière utilisatrice ($APP_B)"
suppression_appli "$APP_B" 1 >/dev/null
if docker inspect "$SHARED_NAME" >/dev/null 2>&1; then
  fail "conteneur partagé conservé sans utilisateur restant"
fi
printf 'OK : ressource partagée retirée avec le dernier utilisateur\n'

notes "5. Ressource de propriété inconnue"
output="$(remove_app_containers "$APP_A" conteneur-inconnu 2>&1)"
case "$output" in
  *"Ressource conservée"*"propriété non établie"*) printf 'OK : message explicatif\n' ;;
  *) fail "aucun message explicatif pour une ressource inconnue" ;;
esac

printf '\nEssai terminé.\n'
