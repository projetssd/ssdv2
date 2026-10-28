#!/usr/bin/env bats
# Tests du générateur de seed de catalogue Silo.

setup() {
  SETTINGS_SOURCE="$BATS_TEST_DIRNAME/../.."
  TESTDIR="$(mktemp -d)"
  FILMS="$TESTDIR/films"
  SERIES="$TESTDIR/series"
  mkdir -p "$FILMS/Alpha (2020) {tmdb-101}" \
    "$SERIES/Beta (2021) {tmdb-202}/Season 01" \
    "$SERIES/Beta (2021) {tmdb-202}/Season 02"
  printf 'video' >"$FILMS/Alpha (2020) {tmdb-101}/Alpha.2020.1080p.mkv"
  printf 'video' >"$SERIES/Beta (2021) {tmdb-202}/Season 01/Beta - S01E01 - 1080p.mkv"
  printf 'video' >"$SERIES/Beta (2021) {tmdb-202}/Season 01/Beta - S01E01 - 720p.mkv"
  printf 'video' >"$SERIES/Beta (2021) {tmdb-202}/Season 02/Beta - S02E01 - 1080p.mkv"
  printf 'ignore' >"$FILMS/Alpha (2020) {tmdb-101}/movie.nfo"
}

teardown() {
  rm -rf "$TESTDIR"
}

@test "seed: films, séries, saisons, épisodes et meilleure version" {
  run python3 "$SETTINGS_SOURCE/includes/config/scripts/silo_catalog_seed.py" \
    --films-dir "$FILMS" --series-dir "$SERIES" --output "$TESTDIR/seed.json.gz"
  [ "$status" -eq 0 ]

  run python3 -c '
import gzip, json, sys
with gzip.open(sys.argv[1], "rt", encoding="utf-8") as handle:
    data = json.load(handle)
assert len(data["libraries"]) == 2, data["libraries"]
assert len(data["items"]) == 2, data["items"]
assert len(data["files"]) == 3, data["files"]
assert len(data["seasons"]) == 2, data["seasons"]
assert len(data["episodes"]) == 2, data["episodes"]
movie = [f for f in data["files"] if f["content_id"] == "movie-tmdb-101"]
episode = [f for f in data["files"] if f["episode_id"] == "episode-tmdb-202-1-1"]
assert movie and movie[0]["file_path"].endswith("1080p.mkv"), movie
assert episode and episode[0]["file_path"].endswith("1080p.mkv"), episode
assert data["libraries"][0]["name"] == "Films"
assert data["libraries"][1]["name"] == "Séries"
print("seed-ok")
' "$TESTDIR/seed.json.gz"
  [ "$status" -eq 0 ]
  [ "$output" = "seed-ok" ]
}

@test "seed: exclusion par content_id" {
  printf 'movie-tmdb-101\n' >"$TESTDIR/exclude.txt"
  run python3 "$SETTINGS_SOURCE/includes/config/scripts/silo_catalog_seed.py" \
    --films-dir "$FILMS" --series-dir "$SERIES" --exclude-file "$TESTDIR/exclude.txt" \
    --output "$TESTDIR/seed.json.gz"
  [ "$status" -eq 0 ]

  run python3 -c '
import gzip, json, sys
with gzip.open(sys.argv[1], "rt", encoding="utf-8") as handle:
    data = json.load(handle)
assert [item["content_id"] for item in data["items"]] == ["series-tmdb-202"], data["items"]
' "$TESTDIR/seed.json.gz"
  [ "$status" -eq 0 ]
}

@test "sffs: import du seed et pas de création concurrente des bibliothèques" {
  run grep -q 'silo_catalog_seed.py' "$SETTINGS_SOURCE/includes/dockerapps/posttasks/sffs.yml"
  [ "$status" -eq 0 ]
  run grep -q 'api/v2/admin/catalog/import' "$SETTINGS_SOURCE/includes/dockerapps/posttasks/sffs.yml"
  [ "$status" -eq 0 ]
  run grep -q 'refresh-metadata' "$SETTINGS_SOURCE/includes/dockerapps/posttasks/sffs.yml"
  [ "$status" -eq 0 ]
  run grep -q "SFFS_SILO_LIBRARIES: \"{{ '0' if sffs_catalog_seed | bool else '1' }}\"" \
    "$SETTINGS_SOURCE/includes/dockerapps/vars/sffs.yml"
  [ "$status" -eq 0 ]
  run grep -q '^sffs_catalog_seed:' "$SETTINGS_SOURCE/includes/dockerapps/vars/sffs.yml"
  [ "$status" -eq 0 ]
}
