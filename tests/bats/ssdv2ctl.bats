#!/usr/bin/env bats
# Tests des règles non interactives de ssdv2ctl (sous-domaine / réinstallation).

setup() {
  SETTINGS_SOURCE="$BATS_TEST_DIRNAME/../.."
}

@test "ssdv2ctl: sous-domaine non requis pour une app sans Traefik (warp)" {
  run python3 - "$SETTINGS_SOURCE" <<'PY'
import importlib.machinery
import importlib.util
import pathlib
import sys
import tempfile

source = pathlib.Path(sys.argv[1])
loader = importlib.machinery.SourceFileLoader("ssdv2ctl_test", str(source / "ssdv2ctl"))
spec = importlib.util.spec_from_loader(loader.name, loader)
module = importlib.util.module_from_spec(spec)
loader.exec_module(module)

with tempfile.TemporaryDirectory() as tmp:
    storage = pathlib.Path(tmp)
    assert module.app_requires_subdomain(source, storage, "warp") is False
    assert module.app_requires_subdomain(source, storage, "prowlarr") is True
    assert module.app_requires_subdomain(source, storage, "webui") is True
    assert module.app_requires_subdomain(source, storage, "prestashop") is True
    assert module.app_requires_subdomain(source, storage, "inconnue") is True

    (storage / "vars").mkdir()
    (storage / "vars" / "prowlarr.yml").write_text(
        "traefik_labels_enabled: false\n", encoding="utf-8"
    )
    assert module.app_requires_subdomain(source, storage, "prowlarr") is False

    (storage / "vars" / "custom.yml").write_text(
        "traefik_labels_enabled: false\nlabels:\n  a: b\n", encoding="utf-8"
    )
    assert module.app_requires_subdomain(source, storage, "custom") is True

print("ok")
PY
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "ssdv2ctl: reinstall warp ne reclame pas de sous-domaine" {
  run python3 - "$SETTINGS_SOURCE" <<'PY'
import importlib.machinery
import importlib.util
import pathlib
import sys
import tempfile
import types

source = pathlib.Path(sys.argv[1])
loader = importlib.machinery.SourceFileLoader("ssdv2ctl_test", str(source / "ssdv2ctl"))
spec = importlib.util.spec_from_loader(loader.name, loader)
module = importlib.util.module_from_spec(spec)
loader.exec_module(module)

with tempfile.TemporaryDirectory() as tmp:
    storage = pathlib.Path(tmp)
    module.require_app = lambda *args, **kwargs: None
    module.is_installed = lambda *args, **kwargs: True
    module.read_account_value = lambda src, st, key: None
    module.run_bash_function = lambda *args, **kwargs: types.SimpleNamespace(returncode=0)
    module.write_account_value = lambda *args, **kwargs: None
    module.mutation_payload = lambda app, action, result: {"ok": True, "action": action}

    assert module.command_app_reinstall(source, storage, "warp")["ok"] is True

    try:
        module.command_app_reinstall(source, storage, "prowlarr")
    except module.CtlError as exc:
        assert "sub.prowlarr.prowlarr" in exc.message, exc.message
        assert "sub.prowlarr.auth" in exc.message, exc.message
    else:
        raise AssertionError("prowlarr doit exiger un sous-domaine et une auth")

print("ok")
PY
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}
