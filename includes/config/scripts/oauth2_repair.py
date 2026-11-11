#!/usr/bin/env python3
"""OAuth2 Proxy — diagnostic, réparation et rollback pour SSDV2.

Ce backend est appelé par ``ssdv2ctl security oauth2 ...`` (JSON) et par le menu
SSDV2 (texte). Il est idempotent : si l'installation est déjà correcte, il ne
redémarre rien.

Commandes :

    oauth2_repair.py status [--json]
    oauth2_repair.py repair [--apply] [--no-bridges] [--json]
    oauth2_repair.py rollback [--backup DIR] [--apply] [--json]

Le script ne modifie ni account.yml, ni emails.txt, ni les conteneurs
applicatifs. Il ne renouvelle aucun secret.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime
from pathlib import Path

SCHEMA_VERSION = 1
OAUTH2_CONTAINER = "oauth2-proxy"
OAUTH2_BACKUP = "oauth2-proxy-pre-repair"
OAUTH2_SMOKE = "oauth2-proxy-repair-smoke"
OAUTH2_IMAGE = "quay.io/oauth2-proxy/oauth2-proxy:v7.15.6"
OAUTH2_COOKIE = "_oauth2_proxy"
TRUSTED_PROXY_DEFAULT = "172.16.0.0/12"
TEMPLATES_CONTAINER_DIR = "/etc/oauth2_proxy/templates"
TEMPLATES_RELATIVE = "includes/dockerapps/templates/traefik/oauth2-proxy-templates"
RULES_RELATIVE = "docker/traefik/rules"
MIDDLEWARES = "middlewares.toml"
CHAINS = "middlewares-chains.toml"
BRIDGES = "oauth2-api-bridges.toml"

ERRORS_SECTION = "[http.middlewares.middlewares-oauth2-errors.errors]"
FORWARD_SECTION = "[http.middlewares.middlewares-oauth2-proxy.forwardAuth]"
PATH_SECTION = "[http.routers.oauth2-proxy-path]"
CHAIN_NAME = "chain-oauth2-proxy"
CHAIN_API_NAME = "chain-oauth2-proxy-api"


class RepairError(RuntimeError):
    """Erreur fonctionnelle (message destiné à l'utilisateur)."""


# ---------------------------------------------------------------------------
# Utilitaires
# ---------------------------------------------------------------------------

def _now() -> str:
    return datetime.now().strftime("%Y%m%d-%H%M%S")


def _run(args: list[str], timeout: int = 120, check: bool = False) -> subprocess.CompletedProcess:
    try:
        result = subprocess.run(
            args,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise RepairError(f"commande impossible ({args[0]}): {exc}") from exc
    if check and result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        raise RepairError(f"échec de {args[0]}: {detail}")
    return result


def _run_sudo(args: list[str], timeout: int = 60) -> subprocess.CompletedProcess:
    if shutil.which("sudo") is None:
        raise RepairError("sudo est requis pour installer les templates dans /etc/oauth2_proxy")
    return _run(["sudo", "-n", *args], timeout=timeout, check=True)


def _mask(args: list[str]) -> list[str]:
    masked = []
    for arg in args:
        if arg.startswith(("--client-secret=", "--cookie-secret=")):
            masked.append(arg.split("=", 1)[0] + "=<MASKED>")
        else:
            masked.append(arg)
    return masked


def _docker_inspect(name: str) -> dict | None:
    result = _run(["docker", "inspect", name], timeout=30)
    if result.returncode != 0:
        return None
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError:
        return None
    return payload[0] if payload else None


def _http_get(port: int, path: str, timeout: float = 3.0) -> tuple[int | None, str]:
    url = f"http://127.0.0.1:{port}{path}"
    try:
        with urllib.request.urlopen(url, timeout=timeout) as response:
            return response.status, response.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read().decode("utf-8", "replace")
    except Exception:  # noqa: BLE001
        return None, ""


def _wait_ping(port: int, timeout: int = 20) -> bool:
    deadline = time.time() + timeout
    while time.time() < deadline:
        status, _ = _http_get(port, "/ping")
        if status == 200:
            return True
        time.sleep(1)
    return False


def _free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def _section_ranges(lines: list[str]) -> dict[str, tuple[int, int]]:
    ranges: dict[str, tuple[int, int]] = {}
    current: str | None = None
    start = 0
    for index, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            if current is not None:
                ranges[current] = (start, index)
            current = stripped
            start = index
    if current is not None:
        ranges[current] = (start, len(lines))
    return ranges


def _patch_section(lines: list[str], section: str, transform) -> list[str]:
    ranges = _section_ranges(lines)
    if section not in ranges:
        return lines
    start, end = ranges[section]
    block = transform(lines[start:end])
    return lines[:start] + block + lines[end:]


# ---------------------------------------------------------------------------
# Patches TOML idempotents
# ---------------------------------------------------------------------------

def patch_middlewares(text: str) -> tuple[str, list[str]]:
    """Corrige middlewares.toml sans perdre les commentaires existants."""
    lines = text.splitlines()
    changes: list[str] = []

    def errors_block(block: list[str]) -> list[str]:
        for index, line in enumerate(block):
            if re.match(r'\s*status\s*=\s*\["401-403"\]\s*$', line):
                block[index] = line.replace('["401-403"]', '["401"]')
                changes.append("errors: status 401-403 -> 401")
        return block

    def forward_block(block: list[str]) -> list[str]:
        filtered = [
            line for line in block
            if not re.match(r"\s*trustForwardHeader\s*=", line)
        ]
        if len(filtered) != len(block):
            changes.append("forwardAuth: trustForwardHeader supprimé")
        block = filtered
        has_cookie = any(
            re.match(r"\s*addAuthCookiesToResponse\s*=", line) for line in block
        )
        if not has_cookie:
            address = next(
                (index for index, line in enumerate(block) if re.match(r"\s*address\s*=", line)),
                None,
            )
            insert_at = (address + 1) if address is not None else 1
            block.insert(
                insert_at,
                f'    addAuthCookiesToResponse = ["{OAUTH2_COOKIE}"]',
            )
            changes.append("forwardAuth: addAuthCookiesToResponse ajouté")
        return block

    def path_block(block: list[str]) -> list[str]:
        if any(re.match(r"\s*priority\s*=\s*", line) for line in block):
            return block
        entry = next(
            (index for index, line in enumerate(block) if re.match(r"\s*entryPoints\s*=", line)),
            None,
        )
        insert_at = (entry + 1) if entry is not None else 1
        block.insert(insert_at, "  priority = 1000")
        changes.append("oauth2-proxy-path: priority 1000 ajoutée")
        return block

    lines = _patch_section(lines, ERRORS_SECTION, errors_block)
    lines = _patch_section(lines, FORWARD_SECTION, forward_block)
    lines = _patch_section(lines, PATH_SECTION, path_block)
    result = "\n".join(lines)
    if text.endswith("\n"):
        result += "\n"
    return result, changes


def _extract_chain_middlewares(text: str, name: str) -> list[str] | None:
    pattern = re.compile(
        r"\[http\.middlewares\." + re.escape(name) + r"\.chain\]\s*\n"
        r"\s*middlewares\s*=\s*\[(.*?)\]",
        re.S,
    )
    match = pattern.search(text)
    if not match:
        return None
    return re.findall(r'"([^"]+)"', match.group(1))


def _render_api_chain(middlewares: list[str]) -> str:
    lines = [
        "",
        "",
        "# ==============================",
        "# CHAIN OAUTH2 PROXY — API / SSE",
        "# Même authentification, sans middleware errors : les 401/403 du backend",
        "# et du ForwardAuth sont transmis tels quels (JSON, SSE, CLI).",
        "# ==============================",
        "",
        f"[http.middlewares.{CHAIN_API_NAME}.chain]",
        "  middlewares = [",
    ]
    for name in middlewares:
        lines.append(f'    "{name}",')
    lines.append("  ]")
    return "\n".join(lines)


def patch_chains(text: str) -> tuple[str, list[str]]:
    """Ajoute chain-oauth2-proxy-api en reprenant les middlewares de la chaîne HTML."""
    if re.search(rf"\[http\.middlewares\.{re.escape(CHAIN_API_NAME)}\.chain\]", text):
        return text, []
    middlewares = _extract_chain_middlewares(text, CHAIN_NAME)
    if middlewares is None:
        raise RepairError(f"chaîne {CHAIN_NAME} introuvable dans {CHAINS}")
    api = [name for name in middlewares if name != "middlewares-oauth2-errors@file"]
    if "middlewares-oauth2-proxy@file" not in api:
        raise RepairError(f"middlewares-oauth2-proxy@file absent de {CHAIN_NAME}")
    result = text.rstrip("\n") + _render_api_chain(api) + "\n"
    return result, [f"{CHAIN_API_NAME}: chaîne API/SSE ajoutée"]


def _validate_toml(path: Path) -> None:
    try:
        import tomllib
    except ImportError as exc:  # pragma: no cover - Python < 3.11
        raise RepairError("tomllib indisponible (Python 3.11+ requis)") from exc
    try:
        with path.open("rb") as handle:
            tomllib.load(handle)
    except Exception as exc:  # noqa: BLE001
        raise RepairError(f"TOML invalide après patch: {path}: {exc}") from exc


# ---------------------------------------------------------------------------
# Conteneur oauth2-proxy
# ---------------------------------------------------------------------------

def _container_binds(inspect: dict) -> list[str]:
    binds = list((inspect.get("HostConfig") or {}).get("Binds") or [])
    templates_mount = f"{TEMPLATES_CONTAINER_DIR}:{TEMPLATES_CONTAINER_DIR}:ro"
    if templates_mount not in binds:
        binds.append(templates_mount)
    return binds


def build_managed_command(old_cmd: list[str]) -> list[str]:
    """Nettoie et complète les flags OAuth2 Proxy sans toucher aux secrets."""
    managed = (
        "--skip-auth-route=",
        "--trusted-proxy-ip=",
        "--cookie-csrf-per-request=",
        "--cookie-csrf-expire=",
        "--custom-templates-dir=",
    )
    trusted = next(
        (arg.split("=", 1)[1] for arg in old_cmd if arg.startswith("--trusted-proxy-ip=")),
        TRUSTED_PROXY_DEFAULT,
    )
    csrf_expire = next(
        (arg.split("=", 1)[1] for arg in old_cmd if arg.startswith("--cookie-csrf-expire=")),
        "10m",
    )
    new_cmd = [arg for arg in old_cmd if not arg.startswith(managed)]
    new_cmd.extend(
        [
            f"--trusted-proxy-ip={trusted}",
            "--cookie-csrf-per-request=true",
            f"--cookie-csrf-expire={csrf_expire}",
            f"--custom-templates-dir={TEMPLATES_CONTAINER_DIR}",
        ]
    )
    return new_cmd


def _container_run_args(inspect: dict, name: str, hostname: str, image: str,
                        command: list[str], publish: tuple[int, int] | None,
                        labels: dict[str, str] | None) -> list[str]:
    host_config = inspect.get("HostConfig") or {}
    args = ["docker", "run", "-d", "--restart",
            (host_config.get("RestartPolicy") or {}).get("Name") or "unless-stopped"]
    for bind in _container_binds(inspect):
        args += ["-v", bind]
    if publish is not None:
        args += ["-p", f"127.0.0.1:{publish[0]}:{publish[1]}"]
    args += ["--name", name, "--hostname", hostname]
    network = host_config.get("NetworkMode")
    if network and network != "default":
        args += ["--network", network]
    for key, value in (labels or {}).items():
        args += ["--label", f"{key}={value}"]
    args.append(image)
    args.extend(command)
    return args


def _desired_container(inspect: dict) -> tuple[str, list[str], list[str]]:
    config = inspect.get("Config") or {}
    old_cmd = list(config.get("Cmd") or [])
    command = build_managed_command(old_cmd)
    binds = _container_binds(inspect)
    image = str(config.get("Image") or "")
    return image, command, binds


def _container_is_current(inspect: dict) -> bool:
    config = inspect.get("Config") or {}
    image = str(config.get("Image") or "")
    command = list(config.get("Cmd") or [])
    binds = list((inspect.get("HostConfig") or {}).get("Binds") or [])
    trusted = [
        arg.split("=", 1)[1]
        for arg in command
        if arg.startswith("--trusted-proxy-ip=")
    ]
    checks = [
        OAUTH2_IMAGE in image,
        "--reverse-proxy=true" in command,
        not any(arg.startswith("--skip-auth-route=") for arg in command),
        bool(trusted) and all(value not in ("0.0.0.0/0", "::/0") for value in trusted),
        "--cookie-csrf-per-request=true" in command,
        any(arg.startswith("--cookie-csrf-expire=") for arg in command),
        f"--custom-templates-dir={TEMPLATES_CONTAINER_DIR}" in command,
        any(TEMPLATES_CONTAINER_DIR in bind for bind in binds),
    ]
    return all(checks)


def _smoke_test(inspect: dict) -> tuple[bool, str]:
    port = _free_port()
    command = build_managed_command(list((inspect.get("Config") or {}).get("Cmd") or []))
    args = _container_run_args(
        inspect, OAUTH2_SMOKE, "oauth2-proxy-repair-smoke", OAUTH2_IMAGE,
        command, (port, 4180), None,
    )
    _run(["docker", "rm", "-f", OAUTH2_SMOKE], timeout=30)
    try:
        _run(args, timeout=60, check=True)
        if not _wait_ping(port):
            logs = _run(["docker", "logs", "--tail", "30", OAUTH2_SMOKE], timeout=30)
            detail = (logs.stdout + logs.stderr).strip()
            return False, f"/ping KO sur le conteneur de test: {detail[-1200:]}"
        status, body = _http_get(port, "/oauth2/sign_in")
        if status != 200 or "Continuer avec Google" not in body:
            return False, "page de connexion personnalisée non rendue"
        return True, ""
    finally:
        _run(["docker", "rm", "-f", OAUTH2_SMOKE], timeout=30)


def _recreate_container(inspect: dict) -> None:
    command = build_managed_command(list((inspect.get("Config") or {}).get("Cmd") or []))
    labels = (inspect.get("Config") or {}).get("Labels") or {}
    hostname = (inspect.get("Config") or {}).get("Hostname") or OAUTH2_CONTAINER
    args = _container_run_args(
        inspect, OAUTH2_CONTAINER, hostname, OAUTH2_IMAGE, command, (4180, 4180), labels,
    )
    _run(["docker", "rm", "-f", OAUTH2_BACKUP], timeout=30)
    _run(["docker", "stop", OAUTH2_CONTAINER], timeout=60, check=True)
    _run(["docker", "rename", OAUTH2_CONTAINER, OAUTH2_BACKUP], timeout=30, check=True)
    try:
        _run(args, timeout=60, check=True)
        if not _wait_ping(4180):
            raise RepairError("oauth2-proxy ne répond pas après recréation")
    except Exception:
        _run(["docker", "rm", "-f", OAUTH2_CONTAINER], timeout=30)
        _run(["docker", "rename", OAUTH2_BACKUP, OAUTH2_CONTAINER], timeout=30)
        _run(["docker", "start", OAUTH2_CONTAINER], timeout=60)
        raise


# ---------------------------------------------------------------------------
# Ponts API/SSE pour les applications existantes
# ---------------------------------------------------------------------------

def _router_labels(labels: dict[str, str]) -> dict[str, dict[str, str]]:
    routers: dict[str, dict[str, str]] = {}
    prefix = "traefik.http.routers."
    for key, value in labels.items():
        if not key.startswith(prefix):
            continue
        rest = key[len(prefix):]
        name, _, attr = rest.partition(".")
        routers.setdefault(name, {})[attr] = value
    return routers


def _bridge_blocks(source: Path) -> list[dict]:
    result = _run(["docker", "ps", "--format", "{{.Names}}"], timeout=30, check=True)
    names = sorted(result.stdout.split())
    blocks: list[dict] = []
    for name in names:
        if name in (OAUTH2_CONTAINER, OAUTH2_SMOKE, OAUTH2_BACKUP):
            continue
        inspect = _docker_inspect(name)
        if not inspect:
            continue
        labels = (inspect.get("Config") or {}).get("Labels") or {}
        routers = _router_labels(labels)
        for router_name, attrs in routers.items():
            middlewares = attrs.get("middlewares", "")
            if "chain-oauth2-proxy@file" not in middlewares:
                continue
            if "chain-oauth2-proxy-api@file" in middlewares or "-api" in router_name:
                continue
            rule = attrs.get("rule", "")
            service = attrs.get("service", "")
            if not rule or not service or service.endswith("@internal"):
                continue
            # Application déjà recréée avec les nouveaux labels : pas de pont.
            if any(other.endswith("-api-rtr") for other in routers):
                continue
            priority_raw = attrs.get("priority", "")
            priority = int(priority_raw) if priority_raw.isdigit() else len(rule)
            blocks.append(
                {
                    "name": f"{router_name}-oauth2-api",
                    "rule": f"({rule}) && !HeaderRegexp(`Accept`, `(?i)text/html`)",
                    "priority": priority + 1,
                    "service": f"{service}@docker",
                }
            )
    return blocks


def render_bridges(blocks: list[dict]) -> str:
    if not blocks:
        return ""
    lines = [
        "# GÉNÉRÉ — routeurs API/SSE de transition OAuth2.",
        "# Objectif : ne plus renvoyer la page de connexion OAuth2 sur un 401/403",
        "# applicatif, sans recréer les conteneurs existants.",
        "# Supprimer après recréation des applications avec les labels des templates.",
        "",
    ]
    for block in blocks:
        lines.extend(
            [
                f"[http.routers.{block['name']}]",
                f'  rule = "{block["rule"]}"',
                '  entryPoints = ["https"]',
                f"  priority = {block['priority']}",
                f'  service = "{block["service"]}"',
                '  middlewares = ["chain-oauth2-proxy-api@file"]',
                f"  [http.routers.{block['name']}.tls]",
                '    certResolver = "letsencrypt"',
                "",
            ]
        )
    return "\n".join(lines).rstrip("\n") + "\n"


# ---------------------------------------------------------------------------
# Diagnostic
# ---------------------------------------------------------------------------

def _template_updates(templates_repo: Path) -> list[str]:
    updates: list[str] = []
    for name in ("sign_in.html", "error.html"):
        source = templates_repo / name
        target = Path(TEMPLATES_CONTAINER_DIR) / name
        if not target.is_file() or target.read_bytes() != source.read_bytes():
            updates.append(name)
    return updates


def _check(name: str, ok: bool, detail: str = "") -> dict:
    return {"name": name, "ok": bool(ok), "detail": detail}


def collect_status(source: Path, storage: Path) -> dict:
    rules_dir = storage / RULES_RELATIVE
    templates_repo = source / TEMPLATES_RELATIVE
    checks: list[dict] = []
    repo_ok = (templates_repo / "sign_in.html").is_file() and (templates_repo / "error.html").is_file()
    checks.append(_check(
        "templates_repo",
        repo_ok,
        "templates présents" if repo_ok else f"templates absents : {templates_repo}",
    ))
    inspect = _docker_inspect(OAUTH2_CONTAINER)
    checks.append(_check(
        "container",
        inspect is not None,
        "conteneur présent" if inspect else "conteneur oauth2-proxy absent",
    ))
    current = False
    image = None
    if inspect:
        current = _container_is_current(inspect)
        checks.append(_check(
            "container_current",
            current,
            "à jour" if current else "à recréer (image, flags ou montage)",
        ))
        image = str((inspect.get("Config") or {}).get("Image") or "")
        checks.append(_check("image", OAUTH2_IMAGE in image, image or "image inconnue"))
    template_updates = _template_updates(templates_repo)
    checks.append(_check(
        "templates_host",
        not template_updates,
        "installés" if not template_updates
        else f"à installer : {', '.join(template_updates)}",
    ))

    middlewares_path = rules_dir / MIDDLEWARES
    chains_path = rules_dir / CHAINS
    mw_text = middlewares_path.read_text(encoding="utf-8") if middlewares_path.is_file() else ""
    ch_text = chains_path.read_text(encoding="utf-8") if chains_path.is_file() else ""

    errors_ok = 'status = ["401"]' in mw_text
    checks.append(_check(
        "errors_401", errors_ok,
        "OK" if errors_ok else "status 401-403 au lieu de 401",
    ))
    forward_match = re.search(
        r"\[http\.middlewares\.middlewares-oauth2-proxy\.forwardAuth\](.*?)(?=\n\[|\Z)",
        mw_text,
        re.S,
    )
    forward_block = forward_match.group(1) if forward_match else ""
    trust_ok = not re.search(r"(?m)^\s*trustForwardHeader\s*=", forward_block)
    checks.append(_check(
        "trust_forward_header", trust_ok,
        "OK" if trust_ok else "trustForwardHeader encore présent",
    ))
    cookie_ok = f'addAuthCookiesToResponse = ["{OAUTH2_COOKIE}"]' in mw_text
    checks.append(_check(
        "add_auth_cookies", cookie_ok,
        "OK" if cookie_ok else "addAuthCookiesToResponse absent",
    ))
    priority_ok = "priority = 1000" in mw_text
    checks.append(_check(
        "path_priority", priority_ok,
        "OK" if priority_ok else "priorité 1000 absente",
    ))
    api_ok = f"[http.middlewares.{CHAIN_API_NAME}.chain]" in ch_text
    checks.append(_check(
        "api_chain", api_ok,
        "OK" if api_ok else f"chaîne {CHAIN_API_NAME} absente",
    ))

    blocks = _bridge_blocks(source)
    bridge_path = rules_dir / BRIDGES
    bridge_text = bridge_path.read_text(encoding="utf-8") if bridge_path.is_file() else ""
    missing = [block["name"] for block in blocks if f"[http.routers.{block['name']}]" not in bridge_text]
    checks.append(_check(
        "bridges",
        not missing,
        "OK" if not missing else f"{len(missing)} pont(s) manquant(s)",
    ))

    refreshes = 0
    if inspect:
        logs = _run(["docker", "logs", "--since", "10m", OAUTH2_CONTAINER], timeout=30)
        refreshes = (logs.stdout + logs.stderr).count("Refreshing session")
    checks.append(_check("refresh_burst", refreshes <= 20, f"{refreshes} sur 10 min"))

    rule_checks = {"errors_401", "trust_forward_header", "add_auth_cookies",
                   "path_priority", "api_chain"}
    traefik_corrections = sum(
        1 for item in checks if item["name"] in rule_checks and not item["ok"]
    )
    ok = all(item["ok"] for item in checks)
    return {
        "schema": SCHEMA_VERSION,
        "action": "oauth2.status",
        "ok": ok,
        "status": "ok" if ok else "repair_required",
        "checks": checks,
        "summary": {
            "container_update": not current,
            "templates_missing": len(template_updates),
            "traefik_corrections": traefik_corrections,
            "bridges_missing": len(missing),
        },
        "next_action": None if ok else "ssdv2ctl security oauth2 repair --apply",
        "bridges": [block["name"] for block in blocks],
        "refresh_count_10m": refreshes,
        "image": image,
        "expected_image": OAUTH2_IMAGE,
    }


# ---------------------------------------------------------------------------
# Sauvegarde / restauration
# ---------------------------------------------------------------------------

def _backup_dir(storage: Path) -> Path:
    root = Path(os.environ.get("BACKUP_DIR") or (Path.home() / "backup"))
    path = root / "oauth2-repair" / _now()
    path.mkdir(parents=True, exist_ok=True)
    return path


def _backup_files(storage: Path, backup: Path) -> None:
    rules = storage / RULES_RELATIVE
    backup.mkdir(parents=True, exist_ok=True)
    for name in (MIDDLEWARES, CHAINS, BRIDGES):
        source = rules / name
        if source.is_file():
            shutil.copy2(source, backup / name)
    inspect = _docker_inspect(OAUTH2_CONTAINER)
    if inspect:
        summary = {
            "container": OAUTH2_CONTAINER,
            "image": (inspect.get("Config") or {}).get("Image"),
            "created": (inspect.get("Created")),
        }
        (backup / "manifest.json").write_text(
            json.dumps(summary, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )


def _restore_files(storage: Path, backup: Path) -> list[str]:
    rules = storage / RULES_RELATIVE
    restored: list[str] = []
    for name in (MIDDLEWARES, CHAINS, BRIDGES):
        source = backup / name
        target = rules / name
        if source.is_file():
            shutil.copy2(source, target)
            restored.append(name)
        elif target.is_file() and name == BRIDGES:
            target.unlink()
            restored.append(f"{name} (supprimé)")
    return restored


# ---------------------------------------------------------------------------
# Réparation
# ---------------------------------------------------------------------------

def _write_if_changed(path: Path, content: str) -> bool:
    if path.is_file() and path.read_text(encoding="utf-8") == content:
        return False
    path.write_text(content, encoding="utf-8")
    return True


def repair(source: Path, storage: Path, apply: bool, no_bridges: bool) -> dict:
    rules_dir = storage / RULES_RELATIVE
    templates_repo = source / TEMPLATES_RELATIVE
    changes: list[str] = []
    checks: list[dict] = []

    if not (templates_repo / "sign_in.html").is_file():
        raise RepairError(
            f"templates absents du dépôt: {templates_repo}. Mettre le dépôt à jour (git pull)."
        )
    inspect = _docker_inspect(OAUTH2_CONTAINER)
    if inspect is None:
        raise RepairError("conteneur oauth2-proxy introuvable : installer OAuth2 Proxy d'abord.")

    middlewares_path = rules_dir / MIDDLEWARES
    chains_path = rules_dir / CHAINS
    if not middlewares_path.is_file() or not chains_path.is_file():
        raise RepairError(f"règles Traefik introuvables dans {rules_dir}")

    existing_mw = middlewares_path.read_text(encoding="utf-8")
    existing_ch = chains_path.read_text(encoding="utf-8")
    new_mw, mw_changes = patch_middlewares(existing_mw)
    new_ch, ch_changes = patch_chains(existing_ch)
    changes.extend(mw_changes + ch_changes)

    templates_updates = _template_updates(templates_repo)
    blocks = [] if no_bridges else _bridge_blocks(source)
    new_bridges = render_bridges(blocks) if blocks else ""
    bridge_path = rules_dir / BRIDGES
    existing_bridges = bridge_path.read_text(encoding="utf-8") if bridge_path.is_file() else ""
    bridge_change = (new_bridges != existing_bridges) if not no_bridges else bridge_path.is_file()

    container_current = _container_is_current(inspect)
    if not container_current:
        changes.append("oauth2-proxy: conteneur à recréer (image/flags/montage)")
    if templates_updates:
        changes.append(f"templates: {', '.join(templates_updates)} à installer")
    if bridge_change and not no_bridges:
        changes.append(f"{BRIDGES}: {len(blocks)} routeur(s) à mettre à jour")
    if no_bridges and bridge_path.is_file():
        changes.append(f"{BRIDGES}: à supprimer (--no-bridges)")

    if not apply:
        return {
            "schema": SCHEMA_VERSION,
            "action": "oauth2.repair",
            "ok": True,
            "applied": False,
            "changes": changes,
            "message": "dry-run : relancer avec --apply pour appliquer",
        }

    if not changes:
        checks.append(_check("ping", _wait_ping(4180), "http://127.0.0.1:4180/ping"))
        status, body = _http_get(4180, "/oauth2/sign_in")
        checks.append(_check("sign_in", status == 200 and "Continuer avec Google" in body,
                             "page de connexion personnalisée"))
        return {
            "schema": SCHEMA_VERSION,
            "action": "oauth2.repair",
            "ok": all(item["ok"] for item in checks),
            "applied": True,
            "changes": [],
            "checks": checks,
            "message": "déjà à jour",
        }

    backup = _backup_dir(storage)
    _backup_files(storage, backup)

    # Patches TOML.
    if _write_if_changed(middlewares_path, new_mw):
        changes.append(f"{MIDDLEWARES}: mis à jour")
    if _write_if_changed(chains_path, new_ch):
        changes.append(f"{CHAINS}: mis à jour")
    _validate_toml(middlewares_path)
    _validate_toml(chains_path)

    # Templates.
    _run_sudo(["install", "-d", "-o", "root", "-g", "root", "-m", "0755", TEMPLATES_CONTAINER_DIR])
    for name in templates_updates:
        _run_sudo([
            "install", "-o", "root", "-g", "root", "-m", "0644",
            str(templates_repo / name), f"{TEMPLATES_CONTAINER_DIR}/{name}",
        ])
    if templates_updates:
        changes.append(f"templates installés dans {TEMPLATES_CONTAINER_DIR}")

    # Conteneur.
    if not container_current:
        _run(["docker", "pull", OAUTH2_IMAGE], timeout=300, check=True)
        ok, detail = _smoke_test(inspect)
        if not ok:
            raise RepairError(detail)
        _recreate_container(inspect)
        changes.append(f"oauth2-proxy recréé ({OAUTH2_IMAGE})")

    # Ponts API.
    if no_bridges:
        if bridge_path.is_file():
            bridge_path.unlink()
            changes.append(f"{BRIDGES}: supprimé (--no-bridges)")
    elif new_bridges:
        if _write_if_changed(bridge_path, new_bridges):
            changes.append(f"{BRIDGES}: {len(blocks)} routeur(s)")
    elif bridge_path.is_file():
        bridge_path.unlink()
        changes.append(f"{BRIDGES}: supprimé (plus nécessaire)")

    checks.append(_check("ping", _wait_ping(4180), "http://127.0.0.1:4180/ping"))
    status, body = _http_get(4180, "/oauth2/sign_in")
    checks.append(_check("sign_in", status == 200 and "Continuer avec Google" in body,
                         "page de connexion personnalisée"))
    return {
        "schema": SCHEMA_VERSION,
        "action": "oauth2.repair",
        "ok": all(item["ok"] for item in checks),
        "applied": True,
        "changes": changes,
        "checks": checks,
        "backup": str(backup),
    }


def rollback(source: Path, storage: Path, backup_arg: str | None, apply: bool) -> dict:
    if backup_arg:
        backup = Path(backup_arg)
    else:
        root = Path(os.environ.get("BACKUP_DIR") or (Path.home() / "backup")) / "oauth2-repair"
        candidates = sorted(p for p in root.glob("*") if p.is_dir()) if root.is_dir() else []
        if not candidates:
            raise RepairError("aucune sauvegarde oauth2-repair trouvée")
        backup = candidates[-1]
    if not backup.is_dir():
        raise RepairError(f"sauvegarde introuvable: {backup}")
    has_container_backup = _docker_inspect(OAUTH2_BACKUP) is not None
    if not apply:
        return {
            "schema": SCHEMA_VERSION,
            "action": "oauth2.rollback",
            "ok": True,
            "applied": False,
            "backup": str(backup),
            "container_restore": has_container_backup,
            "message": "dry-run : relancer avec --apply pour restaurer",
        }
    for name in (MIDDLEWARES, CHAINS):
        candidate = backup / name
        if candidate.is_file():
            _validate_toml(candidate)
    restored = _restore_files(storage, backup)
    if not has_container_backup:
        return {
            "schema": SCHEMA_VERSION,
            "action": "oauth2.rollback",
            "ok": True,
            "applied": True,
            "backup": str(backup),
            "restored": restored,
            "container_restored": False,
            "message": "règles restaurées ; aucune sauvegarde de conteneur (réparation sans recréation)",
        }
    failed = f"oauth2-proxy-pre-rollback-{_now()}"
    _run(["docker", "stop", OAUTH2_CONTAINER], timeout=60, check=True)
    _run(["docker", "rename", OAUTH2_CONTAINER, failed], timeout=30, check=True)
    _run(["docker", "rename", OAUTH2_BACKUP, OAUTH2_CONTAINER], timeout=30, check=True)
    _run(["docker", "start", OAUTH2_CONTAINER], timeout=60, check=True)
    ok = _wait_ping(4180)
    if ok:
        _run(["docker", "rm", "-f", failed], timeout=60)
    else:
        # La restauration ne répond pas : remettre le conteneur précédent.
        _run(["docker", "rm", "-f", OAUTH2_CONTAINER], timeout=60)
        _run(["docker", "rename", failed, OAUTH2_CONTAINER], timeout=30)
        _run(["docker", "start", OAUTH2_CONTAINER], timeout=60)
    return {
        "schema": SCHEMA_VERSION,
        "action": "oauth2.rollback",
        "ok": ok,
        "applied": True,
        "backup": str(backup),
        "restored": restored,
        "container_restored": True,
    }


# ---------------------------------------------------------------------------
# Sortie
# ---------------------------------------------------------------------------

def _print_status(payload: dict) -> None:
    print("OAuth2 Proxy — diagnostic")
    ok = payload.get("ok")
    summary = payload.get("summary") or {}
    print(f"État          : {'à jour' if ok else 'réparation requise'}")

    image = payload.get("image") or "absente"
    expected = payload.get("expected_image") or OAUTH2_IMAGE
    if image != expected and not ok:
        print(f"Image         : {image}  (attendu {expected})")
    else:
        print(f"Image         : {image}")

    if summary.get("container_update"):
        print("Conteneur     : à recréer")
    if summary.get("templates_missing"):
        print(f"Templates     : {summary['templates_missing']} fichier(s) à installer")
    else:
        print("Templates     : installés")
    if summary.get("traefik_corrections"):
        print(f"Règles Traefik: {summary['traefik_corrections']} correction(s) à appliquer")
    else:
        print("Règles Traefik: à jour")
    if summary.get("bridges_missing"):
        print(f"Applications  : {summary['bridges_missing']} pont(s) API à créer")
    else:
        print("Applications  : à jour")
    print(f"Rafraîchis.   : {payload.get('refresh_count_10m', 0)} sur 10 min")

    if ok:
        print("\nTous les contrôles sont OK.")
        return
    print(f"\nProchaine étape : {payload.get('next_action')}")
    fails = [item for item in payload.get("checks", []) if not item["ok"]]
    if fails:
        print("\nPoints à corriger :")
        for item in fails:
            print(f"  - {item['detail']}")


def _print_repair(payload: dict) -> None:
    print("OAuth2 Proxy — réparation")
    if payload.get("message") == "déjà à jour":
        print("Déjà à jour : aucune modification nécessaire.")
    elif payload.get("applied") and payload.get("backup"):
        print(f"Sauvegarde : {payload.get('backup')}")
    for change in payload.get("changes", []):
        print(f"  - {change}")
    for item in payload.get("checks", []):
        mark = "OK " if item["ok"] else "KO "
        print(f"  [{mark}] {item['name']}: {item['detail']}")
    if not payload.get("applied"):
        print("\nDry-run : relancer avec --apply pour appliquer.")
    print(f"\nRésultat : {'OK' if payload.get('ok') else 'ÉCHEC'}")


def _print_rollback(payload: dict) -> None:
    print("OAuth2 Proxy — rollback")
    print(f"Sauvegarde : {payload.get('backup')}")
    for item in payload.get("restored", []):
        print(f"  - restauré : {item}")
    if payload.get("container_restored") is False:
        print("  - conteneur inchangé (sauvegarde sans recréation)")
    if not payload.get("applied"):
        print("\nDry-run : relancer avec --apply pour restaurer.")
    print(f"\nRésultat : {'OK' if payload.get('ok') else 'ÉCHEC'}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="OAuth2 Proxy : diagnostic, réparation et rollback SSDV2")
    parser.add_argument("command", choices=["status", "repair", "rollback"])
    parser.add_argument("--apply", action="store_true", help="appliquer les changements")
    parser.add_argument("--no-bridges", action="store_true", help="ne pas générer les routeurs API de transition")
    parser.add_argument("--backup", help="sauvegarde à restaurer (rollback)")
    parser.add_argument("--source", help="dépôt SSDV2")
    parser.add_argument("--storage", help="stockage SSDV2")
    parser.add_argument("--json", action="store_true", help="sortie JSON")
    args = parser.parse_args(argv)

    source = Path(
        args.source
        or os.environ.get("SSDV2_SOURCE")
        or os.environ.get("SETTINGS_SOURCE")
        or Path(__file__).resolve().parents[3]
    )
    storage = Path(
        args.storage
        or os.environ.get("SSDV2_STORAGE")
        or os.environ.get("SETTINGS_STORAGE")
        or (Path.home() / "seedbox")
    )

    try:
        if args.command == "status":
            payload = collect_status(source, storage)
            if args.json:
                print(json.dumps(payload, indent=2, ensure_ascii=False))
            else:
                _print_status(payload)
            return 0 if payload["ok"] else 1
        if args.command == "repair":
            payload = repair(source, storage, args.apply, args.no_bridges)
            if args.json:
                print(json.dumps(payload, indent=2, ensure_ascii=False))
            else:
                _print_repair(payload)
            return 0 if payload["ok"] else 1
        payload = rollback(source, storage, args.backup, args.apply)
        if args.json:
            print(json.dumps(payload, indent=2, ensure_ascii=False))
        else:
            _print_rollback(payload)
        return 0 if payload["ok"] else 1
    except RepairError as exc:
        if args.json:
            print(json.dumps({
                "schema": SCHEMA_VERSION,
                "action": f"oauth2.{args.command}",
                "ok": False,
                "message": str(exc),
            }, indent=2, ensure_ascii=False))
        else:
            print(f"ERREUR : {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
