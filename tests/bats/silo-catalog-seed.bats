#!/usr/bin/env bats
# Tests du générateur de seed de catalogue Silo.

setup() {
  SETTINGS_SOURCE="$BATS_TEST_DIRNAME/../.."
  TESTDIR="$(mktemp -d)"
  FILMS="$TESTDIR/films"
  SERIES="$TESTDIR/series"
  mkdir -p "$FILMS/Alpha (2020) {tmdb-101}/Extras" \
    "$FILMS/Alpha Remaster (2020) {tmdb-101}" \
    "$FILMS/Trailer Park Boys (2001) {tmdb-303}" \
    "$SERIES/Beta (2021) {tmdb-202}/Season 01" \
    "$SERIES/Beta (2021) {tmdb-202}/Season 02"

  printf 'video' >"$FILMS/Alpha (2020) {tmdb-101}/Alpha.2020.2160p.HDR.x265.mkv"
  printf 'video' >"$FILMS/Alpha (2020) {tmdb-101}/Alpha.2020.1080p.x264.mkv"
  printf 'video' >"$FILMS/Alpha (2020) {tmdb-101}/Alpha.2020.720p.mkv"
  printf 'video' >"$FILMS/Alpha (2020) {tmdb-101}/Alpha.2020.480p.mkv"
  printf 'extra' >"$FILMS/Alpha (2020) {tmdb-101}/Alpha.2020.Trailer.mkv"
  printf 'extra' >"$FILMS/Alpha (2020) {tmdb-101}/sample.mkv"
  printf 'extra' >"$FILMS/Alpha (2020) {tmdb-101}/Extras/Featurette.mkv"
  printf 'video' >"$FILMS/Alpha Remaster (2020) {tmdb-101}/Alpha.Remaster.2020.2160p.mkv"
  printf 'video' >"$FILMS/Trailer Park Boys (2001) {tmdb-303}/Trailer.Park.Boys.2001.1080p.mkv"
  printf 'video' >"$SERIES/Beta (2021) {tmdb-202}/Season 01/Beta - S01E01 - 2160p.HDR.mkv"
  printf 'video' >"$SERIES/Beta (2021) {tmdb-202}/Season 01/Beta - S01E01 - 1080p.mkv"
  printf 'video' >"$SERIES/Beta (2021) {tmdb-202}/Season 01/Beta - S01E01 - 720p.mkv"
  printf 'extra' >"$SERIES/Beta (2021) {tmdb-202}/Season 01/Beta - S01E01 - Featurette.mkv"
  printf 'video' >"$SERIES/Beta (2021) {tmdb-202}/Season 02/Beta - S02E01 - 1080p.mkv"
}

teardown() {
  rm -rf "$TESTDIR"
}

@test "seed: toutes les versions, 4K inclus, extras exclus" {
  run python3 "$SETTINGS_SOURCE/includes/config/scripts/silo_catalog_seed.py" \
    --films-dir "$FILMS" --series-dir "$SERIES" --output "$TESTDIR/seed.json.gz"
  [ "$status" -eq 0 ]

  run python3 -c '
import gzip, json, sys
with gzip.open(sys.argv[1], "rt", encoding="utf-8") as handle:
    data = json.load(handle)
assert len(data["libraries"]) == 2, data["libraries"]
assert len(data["items"]) == 3, data["items"]
assert len(data["files"]) == 10, data["files"]
assert len(data["seasons"]) == 2, data["seasons"]
assert len(data["episodes"]) == 2, data["episodes"]
alpha_items = [i for i in data["items"] if i["content_id"] == "movie-tmdb-101"]
assert len(alpha_items) == 1, alpha_items
alpha_files = [f for f in data["files"] if f["content_id"] == "movie-tmdb-101"]
assert len(alpha_files) == 5, alpha_files
assert {f["resolution"] for f in data["files"]} >= {"2160p", "1080p", "720p", "480p"}
assert any(f["hdr"] for f in data["files"])
assert any(f["codec_video"] == "hevc" for f in data["files"])
paths = [f["file_path"] for f in data["files"]]
assert any("Trailer.Park.Boys.2001.1080p.mkv" in p for p in paths), paths
assert not any("Alpha.2020.Trailer" in p for p in paths), paths
assert not any(p.endswith("sample.mkv") for p in paths), paths
assert not any("Featurette" in p or "/Extras/" in p for p in paths), paths
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
assert [item["content_id"] for item in data["items"]] == ["movie-tmdb-303", "series-tmdb-202"], data["items"]
assert len(data["files"]) == 5, data["files"]
' "$TESTDIR/seed.json.gz"
  [ "$status" -eq 0 ]
}

@test "sffs: import asynchrone du seed et pas de création concurrente des bibliothèques" {
  run grep -q 'silo_catalog_seed.py' "$SETTINGS_SOURCE/includes/dockerapps/posttasks/sffs.yml"
  [ "$status" -eq 0 ]
  run grep -q 'api/v2/admin/catalog/import-jobs' "$SETTINGS_SOURCE/includes/dockerapps/posttasks/sffs.yml"
  [ "$status" -eq 0 ]
  run grep -q 'api/v2/admin/jobs/' "$SETTINGS_SOURCE/includes/dockerapps/posttasks/sffs.yml"
  [ "$status" -eq 0 ]
  run grep -q 'refresh-metadata' "$SETTINGS_SOURCE/includes/dockerapps/posttasks/sffs.yml"
  [ "$status" -eq 0 ]
  run grep -q "SFFS_SILO_LIBRARIES: \"{{ '0' if sffs_catalog_seed | bool else '1' }}\"" \
    "$SETTINGS_SOURCE/includes/dockerapps/vars/sffs.yml"
  [ "$status" -eq 0 ]
  run grep -q '^sffs_catalog_seed:' "$SETTINGS_SOURCE/includes/dockerapps/vars/sffs.yml"
  [ "$status" -eq 0 ]
}
