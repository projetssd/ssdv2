#!/usr/bin/env bats
# Le catalogue utilise "nom - description" ; un nom peut contenir un tiret.

setup() {
  SETTINGS_SOURCE="$BATS_TEST_DIRNAME/../.."
}

@test "catalogue: un nom avec tiret n'est pas tronqué" {
  run python3 - "$SETTINGS_SOURCE" <<'PY'
import importlib.util
import pathlib
import sys

source = pathlib.Path(sys.argv[1])
script = source / "includes/config/scripts/validate_catalogue.py"
spec = importlib.util.spec_from_file_location("validate_catalogue", script)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

entries = module.catalog_entries()
assert "ssdv2-relay" in entries, entries
assert "ssdv2" not in entries, entries
print("ok")
PY
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}
