import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "includes" / "config" / "scripts" / "oauth2_repair.py"
spec = importlib.util.spec_from_file_location("oauth2_repair", SCRIPT)
oauth2_repair = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(oauth2_repair)


MIDDLEWARES = '''
[http.middlewares.middlewares-basic-auth]
  [http.middlewares.middlewares-basic-auth.basicAuth]
    users = ["x"]


[http.middlewares.middlewares-oauth2-errors.errors]
  status = ["401-403"]
  service = "oauth2proxy-svc@docker"
  query = "/oauth2/sign_in?rd={url}"


[http.routers.oauth2-proxy-path]
  rule = "HostRegexp(`^[a-z0-9-]+[.]example.tld$`) && PathPrefix(`/oauth2/`)"
  entryPoints = ["https"]
  service = "oauth2proxy-svc@docker"
  middlewares = ["chain-no-auth@file"]
  [http.routers.oauth2-proxy-path.tls]
    certResolver = "letsencrypt"


[http.middlewares.middlewares-oauth2-proxy]
  [http.middlewares.middlewares-oauth2-proxy.forwardAuth]
    address = "http://oauth2-proxy:4180/oauth2/auth"
    trustForwardHeader = true
    authResponseHeaders = ["X-Auth-Request-User"]
'''


def test_patch_middlewares():
    patched, changes = oauth2_repair.patch_middlewares(MIDDLEWARES)
    assert 'status = ["401"]' in patched
    assert 'status = ["401-403"]' not in patched
    assert "trustForwardHeader" not in patched
    assert 'addAuthCookiesToResponse = ["_oauth2_proxy"]' in patched
    assert "priority = 1000" in patched
    assert changes
    again, changes_again = oauth2_repair.patch_middlewares(patched)
    assert again == patched
    assert changes_again == []


def test_patch_middlewares_keeps_other_trust_forward_header():
    text = MIDDLEWARES.replace(
        "[http.middlewares.middlewares-oauth2-proxy]",
        "[http.middlewares.middlewares-authelia]\n"
        "  [http.middlewares.middlewares-authelia.forwardAuth]\n"
        "    trustForwardHeader = true\n\n"
        "[http.middlewares.middlewares-oauth2-proxy]",
    )
    patched, _ = oauth2_repair.patch_middlewares(text)
    assert patched.count("trustForwardHeader = true") == 1
    assert "[http.middlewares.middlewares-authelia]" in patched


CHAINS = '''
[http.middlewares.chain-no-auth.chain]
  middlewares = [
    "crowdsec@file",
    "middlewares-rate-limit@file",
    "middlewares-secure-headers@file"
  ]


[http.middlewares.chain-oauth2-proxy.chain]
  middlewares = [
    "crowdsec@file",
    "middlewares-rate-limit@file",
    "middlewares-secure-headers@file",
    "middlewares-allowlist@file",
    "middlewares-oauth2-errors@file",
    "middlewares-oauth2-proxy@file"
  ]
'''


def test_patch_chains():
    patched, changes = oauth2_repair.patch_chains(CHAINS)
    assert "[http.middlewares.chain-oauth2-proxy-api.chain]" in patched
    assert "middlewares-allowlist@file" in patched
    assert patched.count("middlewares-oauth2-errors@file") == 1
    assert changes
    again, changes_again = oauth2_repair.patch_chains(patched)
    assert again == patched
    assert changes_again == []


def test_build_managed_command():
    old = [
        "--provider=google",
        "--client-secret=secret-value",
        "--reverse-proxy=true",
        "--skip-auth-route=^/oauth2/",
        "--trusted-proxy-ip=172.18.0.0/16",
        "--cookie-secret=cookie-value",
        "--cookie-csrf-per-request=true",
        "--cookie-csrf-expire=5m",
        "--custom-templates-dir=/old",
        "--http-address=0.0.0.0:4180",
    ]
    new = oauth2_repair.build_managed_command(old)
    assert "--skip-auth-route=^/oauth2/" not in new
    assert "--trusted-proxy-ip=172.18.0.0/16" in new
    assert "--cookie-csrf-expire=5m" in new
    assert "--custom-templates-dir=/etc/oauth2_proxy/templates" in new
    assert "--client-secret=secret-value" in new
    assert "--cookie-secret=cookie-value" in new
    assert len([a for a in new if a.startswith("--trusted-proxy-ip=")]) == 1
    assert len([a for a in new if a.startswith("--cookie-csrf-per-request=")]) == 1


def test_render_bridges():
    blocks = [
        {
            "name": "app-rtr-oauth2-api",
            "rule": "(Host(`app.example.tld`)) && !HeaderRegexp(`Accept`, `(?i)text/html`)",
            "priority": 11,
            "service": "app-svc@docker",
        }
    ]
    text = oauth2_repair.render_bridges(blocks)
    assert "[http.routers.app-rtr-oauth2-api]" in text
    assert "priority = 11" in text
    assert 'service = "app-svc@docker"' in text
    assert 'middlewares = ["chain-oauth2-proxy-api@file"]' in text
    assert oauth2_repair.render_bridges([]) == ""


def test_container_is_current():
    inspect = {
        "Config": {
            "Image": oauth2_repair.OAUTH2_IMAGE,
            "Cmd": [
                "--provider=google",
                "--reverse-proxy=true",
                "--trusted-proxy-ip=172.16.0.0/12",
                "--cookie-csrf-per-request=true",
                "--cookie-csrf-expire=10m",
                "--custom-templates-dir=/etc/oauth2_proxy/templates",
            ],
        },
        "HostConfig": {
            "Binds": ["/etc/oauth2_proxy/templates:/etc/oauth2_proxy/templates:ro"]
        },
    }
    assert oauth2_repair._container_is_current(inspect)
    inspect["Config"]["Cmd"].append("--skip-auth-route=/oauth2/")
    assert not oauth2_repair._container_is_current(inspect)


def test_restore_files():
    import tempfile

    with tempfile.TemporaryDirectory() as tmp:
        storage = Path(tmp)
        rules = storage / oauth2_repair.RULES_RELATIVE
        rules.mkdir(parents=True)
        backup = storage / "backup"
        backup.mkdir()
        (rules / oauth2_repair.MIDDLEWARES).write_text("new-mw", encoding="utf-8")
        (rules / oauth2_repair.CHAINS).write_text("new-ch", encoding="utf-8")
        (rules / oauth2_repair.BRIDGES).write_text("new-bridge", encoding="utf-8")
        (backup / oauth2_repair.MIDDLEWARES).write_text("old-mw", encoding="utf-8")
        (backup / oauth2_repair.CHAINS).write_text("old-ch", encoding="utf-8")
        restored = oauth2_repair._restore_files(storage, backup)
        assert (rules / oauth2_repair.MIDDLEWARES).read_text(encoding="utf-8") == "old-mw"
        assert (rules / oauth2_repair.CHAINS).read_text(encoding="utf-8") == "old-ch"
        assert not (rules / oauth2_repair.BRIDGES).exists()
        assert oauth2_repair.BRIDGES + " (supprimé)" in restored


def test_print_status_summary():
    import contextlib
    import io

    payload = {
        "ok": False,
        "image": "quay.io/oauth2-proxy/oauth2-proxy:v7.6.0",
        "expected_image": oauth2_repair.OAUTH2_IMAGE,
        "summary": {
            "container_update": True,
            "templates_missing": 2,
            "traefik_corrections": 5,
            "bridges_missing": 11,
        },
        "refresh_count_10m": 0,
        "next_action": "ssdv2ctl security oauth2 repair --apply",
        "checks": [{"ok": False, "detail": "status 401-403 au lieu de 401"}],
    }
    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        oauth2_repair._print_status(payload)
    text = output.getvalue()
    assert "réparation requise" in text
    assert "v7.6.0" in text
    assert "2 fichier(s) à installer" in text
    assert "5 correction(s)" in text
    assert "11 pont(s) API à créer" in text
    assert "ssdv2ctl security oauth2 repair --apply" in text
