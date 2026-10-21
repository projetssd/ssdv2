#!/usr/bin/env python3
"""Gestion de decypharrgate pour SSDV2.

La gate est un correctif pour Sonarr v5+ : Sonarr v5 transforme un echec
d'ajout au client de telechargement en "client indisponible" (pending).
Radarr v6 et Sonarr v4 skippent deja les echecs generiques : ils ne sont pas
configures.

Commandes :
  detect-upstreams                 Instances decypharr detectees (JSON)
  current-upstream --gate G        Upstream actuellement associe a une gate
  menu-status                      Etat global instances/gates/Sonarr (JSON)
  status --gate G                  Etat de la gate et des Sonarr concernes (JSON)
  configure --gate G               Pointe les Sonarr eligibles vers la gate
  restore --gate G                 Remet les Sonarr de la gate vers l'upstream
  increase-cache --upstream U      Cache DFS de l'instance U -> 20 Go
  write-gate-vars --gate G --upstream U
                                   Cree les vars custom d'une gate
"""

from __future__ import annotations

import argparse
import getpass
import json
import os
import re
import sqlite3
import subprocess
import sys
import time
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime
from pathlib import Path

SETTINGS_SOURCE = Path(os.environ.get("SETTINGS_SOURCE", Path.home() / "seedbox-compose"))
SETTINGS_STORAGE = Path(os.environ.get("SETTINGS_STORAGE", Path.home() / "seedbox"))
USER = os.environ.get("USER") or getpass.getuser()
SSDDB = SETTINGS_SOURCE / "ssddb"
CACHE_TARGET = "20GB"
DEFAULT_DECYPHARR_PORT = 8282
GATE_PREFIX = "decypharrgate"
ARR_NAMES = ("sonarr", "sonarr4k", "radarr", "radarr4k")


def _print(msg: str) -> None:
    print(msg, flush=True)


def _fail(msg: str) -> int:
    print(f"ERREUR: {msg}", file=sys.stderr, flush=True)
    return 1


def run(cmd: list[str], timeout: int = 30) -> subprocess.CompletedProcess:
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, check=False)
    except (OSError, subprocess.SubprocessError) as exc:
        return subprocess.CompletedProcess(cmd, 1, "", str(exc))


def docker_ps() -> list[tuple[str, str, str]]:
    fmt = '{{.Names}}|{{.Image}}|{{.Label "ssdv2.app"}}'
    out = run(["docker", "ps", "--format", fmt], timeout=20)
    rows = []
    if out.returncode != 0:
        return rows
    for line in out.stdout.splitlines():
        parts = line.split("|", 2)
        if len(parts) == 3:
            rows.append((parts[0], parts[1], parts[2]))
    return rows


def docker_health(name: str) -> str:
    out = run(["docker", "inspect", "-f", "{{.State.Health.Status}}", name], timeout=10)
    if out.returncode != 0:
        return "absent"
    status = (out.stdout or "").strip()
    if not status or status == "<no value>":
        return "none"
    return status


def ssddb_apps() -> dict[str, int]:
    if not SSDDB.is_file():
        return {}
    try:
        con = sqlite3.connect(f"file:{SSDDB}?mode=ro", uri=True)
        rows = con.execute("select name, port from applications").fetchall()
        con.close()
    except sqlite3.Error:
        return {}
    return {str(name): int(port) for name, port in rows if port is not None}


def decypharr_instances() -> list[dict]:
    apps = ssddb_apps()
    result = []
    for name, image, label in docker_ps():
        if name.startswith(GATE_PREFIX) or name == "decypharrseed":
            continue
        if "decypharr" not in name and "blackhole" not in image and not label.startswith("decypharr"):
            continue
        port = apps.get(name, DEFAULT_DECYPHARR_PORT)
        result.append({"name": name, "port": port, "upstream": f"{name}:{port}"})
    return sorted(result, key=lambda item: item["name"])


def upstream_state_path(gate: str) -> Path:
    return SETTINGS_STORAGE / "conf" / f"{gate}.upstream"


def read_upstream_state(gate: str) -> str:
    path = upstream_state_path(gate)
    if not path.is_file():
        return ""
    try:
        return path.read_text(encoding="utf-8").strip()
    except OSError:
        return ""


def write_upstream_state(gate: str, upstream: str) -> None:
    path = upstream_state_path(gate)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(upstream.strip() + "\n", encoding="utf-8")


def current_upstream(gate: str) -> str:
    state = read_upstream_state(gate)
    if state:
        return state
    out = run(
        ["docker", "exec", gate, "grep", "-oE", "decypharr[a-zA-Z0-9_-]*:[0-9]+",
         "/etc/nginx/conf.d/default.conf"],
        timeout=10,
    )
    if out.returncode == 0:
        for line in out.stdout.splitlines():
            line = line.strip()
            if line:
                return line
    return ""


def upstream_name(upstream: str) -> str:
    return upstream.split(":", 1)[0] if upstream else ""


def arr_config_path(app: str) -> Path:
    return SETTINGS_STORAGE / "docker" / USER / app / "config"


def arr_api_key(app: str) -> str | None:
    cfg = arr_config_path(app) / "config.xml"
    if not cfg.is_file():
        return None
    try:
        root = ET.parse(cfg).getroot()
        node = root.find("ApiKey")
        return (node.text or "").strip() or None
    except (ET.ParseError, OSError):
        return None


def docker_host_port(app: str, port: int) -> str | None:
    out = run(["docker", "port", app, str(port)], timeout=10)
    if out.returncode != 0:
        return None
    for line in out.stdout.splitlines():
        line = line.strip()
        if not line or line.startswith("[::]"):
            continue
        host, _, host_port = line.rpartition(":")
        if host_port.isdigit():
            return f"http://127.0.0.1:{host_port}"
    return None


def container_ip(app: str) -> str | None:
    out = run(
        ["docker", "inspect", "-f", "{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}", app],
        timeout=10,
    )
    if out.returncode != 0:
        return None
    for ip in (out.stdout or "").split():
        if ip:
            return ip
    return None


def arr_base_url(app: str, port: int) -> str | None:
    published = docker_host_port(app, port)
    if published:
        return published
    ip = container_ip(app)
    if ip:
        return f"http://{ip}:{port}"
    return None


def api_request(base: str, key: str, path: str, method: str = "GET", payload: dict | None = None):
    url = f"{base}/api/v3/{path.lstrip('/')}"
    headers = {"X-Api-Key": key, "Accept": "application/json"}
    data = None
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=60) as resp:
        body = resp.read()
        return json.loads(body.decode("utf-8")) if body else {}


def _field(client: dict, name: str) -> dict | None:
    for field in client.get("fields", []) or []:
        if field.get("name") == name:
            return field
    return None


def client_host(client: dict) -> str:
    field = _field(client, "host")
    return str(field.get("value", "")) if field else ""


def find_client(clients: list[dict], hosts: set[str] | None) -> dict | None:
    candidates = []
    for client in clients:
        host = client_host(client)
        if hosts is not None and host not in hosts:
            continue
        if hosts is None and "decypharr" not in host.lower() and "decypharr" not in str(client.get("name", "")).lower():
            continue
        candidates.append(client)
    if not candidates:
        return None
    candidates.sort(key=lambda c: ("decypharr" not in str(c.get("name", "")).lower(), str(c.get("name", ""))))
    return candidates[0]


def collect_sonarrs(candidate_hosts: set[str] | None, gate: str | None) -> tuple[list[dict], list[dict]]:
    apps = ssddb_apps()
    arrs: list[dict] = []
    skipped: list[dict] = []
    for app in ARR_NAMES:
        cfg_dir = arr_config_path(app)
        if not (cfg_dir / "config.xml").is_file():
            continue
        port = apps.get(app, 8989 if app.startswith("sonarr") else 7878)
        key = arr_api_key(app)
        base = arr_base_url(app, port)
        if not base or not key:
            skipped.append({"name": app, "reason": "configuration ou API inaccessible"})
            continue
        try:
            status = api_request(base, key, "system/status")
        except (urllib.error.URLError, urllib.error.HTTPError, ValueError, OSError) as exc:
            skipped.append({"name": app, "reason": f"API inaccessible: {exc}"})
            continue
        app_name = str(status.get("appName", ""))
        version = str(status.get("version", ""))
        major = 0
        try:
            major = int(version.lstrip("v").split(".", 1)[0])
        except ValueError:
            major = 0
        if app_name != "Sonarr":
            if app_name == "Radarr" and major >= 6:
                reason = "Radarr v6 : les echecs generiques sont deja skippes, pas besoin de gate"
            else:
                reason = f"{app_name or app} non concerne"
            skipped.append({"name": app, "type": app_name, "version": version, "reason": reason})
            continue
        if major < 5:
            skipped.append({"name": app, "type": app_name, "version": version,
                            "reason": "Sonarr v4 : les echecs generiques sont deja skippes, pas besoin de gate"})
            continue
        try:
            clients = api_request(base, key, "downloadclient")
        except (urllib.error.URLError, urllib.error.HTTPError, ValueError, OSError) as exc:
            skipped.append({"name": app, "type": app_name, "version": version,
                            "reason": f"download clients illisibles: {exc}"})
            continue
        if not isinstance(clients, list):
            skipped.append({"name": app, "type": app_name, "version": version,
                            "reason": "download clients invalides"})
            continue
        client = find_client(clients, candidate_hosts)
        if client is None:
            skipped.append({"name": app, "type": app_name, "version": version,
                            "reason": "client decypharr introuvable"})
            continue
        host = client_host(client)
        if gate and host == gate:
            state = "configured"
        elif candidate_hosts is not None and host in candidate_hosts:
            state = "eligible"
        elif gate:
            state = "other"
        else:
            state = "configured" if host.startswith(GATE_PREFIX) else (
                "eligible" if "decypharr" in host.lower() else "other"
            )
        arrs.append({
            "name": app,
            "type": app_name,
            "version": version,
            "port": port,
            "api_base": base,
            "client_name": str(client.get("name", "")),
            "client_host": host,
            "state": state,
            "_client": client,
            "_api_key": key,
        })
    return arrs, skipped


def public_arr(arr: dict) -> dict:
    return {k: v for k, v in arr.items() if not k.startswith("_")}


def cache_size(upstream: str) -> str | None:
    name = upstream_name(upstream)
    if not name:
        return None
    cfg = SETTINGS_STORAGE / "docker" / USER / name / "config" / "config.json"
    if not cfg.is_file():
        return None
    try:
        data = json.loads(cfg.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    value = data.get("mount", {}).get("dfs", {}).get("disk_cache_size")
    return str(value) if value is not None else None


def cmd_detect_upstreams(_args: argparse.Namespace) -> int:
    _print(json.dumps(decypharr_instances(), ensure_ascii=False))
    return 0


def cmd_current_upstream(args: argparse.Namespace) -> int:
    _print(current_upstream(args.gate))
    return 0


def cmd_menu_status(_args: argparse.Namespace) -> int:
    instances = decypharr_instances()
    apps = ssddb_apps()
    gates = []
    for gate in sorted(name for name in apps if name.startswith(GATE_PREFIX)):
        upstream = current_upstream(gate)
        gates.append({"name": gate, "upstream": upstream, "health": docker_health(gate)})

    known: set[str] = set()
    for inst in instances:
        known.add(inst["name"])
        known.add(inst["upstream"])
        known.add(f"{inst['name']}-gate")
    for gate in gates:
        known.add(gate["name"])

    sonarrs, skipped = collect_sonarrs(known, gate=None)
    for arr in sonarrs:
        host = arr["client_host"]
        gate = next((g for g in gates if g["name"] == host), None)
        if gate:
            arr["gate"] = gate["name"]
            arr["upstream"] = gate["upstream"]
            arr["state"] = "configured"
            continue
        inst = next(
            (i for i in instances if host in (i["name"], i["upstream"], f"{i['name']}-gate")),
            None,
        )
        if inst:
            arr["upstream"] = inst["upstream"]
            arr["gate"] = None
            arr["state"] = "eligible"
        else:
            arr["gate"] = None
            arr["upstream"] = None
            arr["state"] = "other"

    for inst in instances:
        inst["gate"] = next((g["name"] for g in gates if g["upstream"] == inst["upstream"]), None)
        inst["cache_size"] = cache_size(inst["upstream"])
        inst["used_by_sonarr"] = any(
            a.get("upstream") == inst["upstream"] and a.get("state") in ("configured", "eligible")
            for a in sonarrs
        )

    _print(json.dumps({
        "instances": instances,
        "gates": gates,
        "sonarrs": [public_arr(a) for a in sonarrs],
        "skipped": skipped,
    }, ensure_ascii=False))
    return 0


def _require_upstream(gate: str) -> str:
    upstream = current_upstream(gate)
    if not upstream:
        raise RuntimeError(f"upstream introuvable pour la gate {gate}")
    return upstream


def cmd_status(args: argparse.Namespace) -> int:
    try:
        upstream = _require_upstream(args.gate)
    except RuntimeError as exc:
        return _fail(str(exc))
    host = upstream_name(upstream)
    candidates = {args.gate, upstream, host, f"{host}-gate"}
    sonarrs, skipped = collect_sonarrs(candidates, args.gate)
    _print(json.dumps({
        "gate": args.gate,
        "upstream": upstream,
        "health": docker_health(args.gate),
        "cache_size": cache_size(upstream),
        "sonarrs": [public_arr(a) for a in sonarrs],
        "skipped": skipped,
    }, ensure_ascii=False))
    return 0


def _set_client_host(arr: dict, target: str, gate: str, upstream: str) -> int:
    client = arr["_client"]
    key = arr["_api_key"]
    host_field = _field(client, "host")
    if host_field is None:
        return _fail(f"champ host introuvable pour {arr['name']}")
    if host_field.get("value") == target:
        _print(f"{arr['name']}: deja sur {target}.")
        return 0
    host_field["value"] = target
    password_field = _field(client, "password")
    if password_field is not None:
        password_field["value"] = key
    try:
        api_request(arr["api_base"], key, f"downloadclient/{client['id']}", "PUT", client)
    except (urllib.error.URLError, urllib.error.HTTPError, ValueError, OSError) as exc:
        return _fail(f"{arr['name']}: mise a jour impossible: {exc}")
    _print(f"{arr['name']}: host download client -> {target}.")
    try:
        api_request(arr["api_base"], key, "downloadclient/test", "POST", client)
        _print(f"{arr['name']}: test du client OK.")
    except (urllib.error.URLError, urllib.error.HTTPError, ValueError, OSError) as exc:
        _print(f"{arr['name']}: test du client en echec (non bloquant): {exc}")
    return 0


def cmd_configure(args: argparse.Namespace) -> int:
    try:
        upstream = _require_upstream(args.gate)
    except RuntimeError as exc:
        return _fail(str(exc))
    host = upstream_name(upstream)
    candidates = {args.gate, upstream, host, f"{host}-gate"}
    sonarrs, _skipped = collect_sonarrs(candidates, args.gate)
    rc = 0
    for arr in sonarrs:
        if arr["state"] == "configured":
            _print(f"{arr['name']}: deja configure sur {args.gate}.")
            continue
        if arr["state"] != "eligible":
            _print(f"{arr['name']}: host {arr['client_host']} non eligible, ignore.")
            continue
        rc |= _set_client_host(arr, args.gate, args.gate, upstream)
    return rc


def cmd_restore(args: argparse.Namespace) -> int:
    try:
        upstream = _require_upstream(args.gate)
    except RuntimeError as exc:
        return _fail(str(exc))
    host = upstream_name(upstream)
    candidates = {args.gate, upstream, host, f"{host}-gate"}
    sonarrs, _skipped = collect_sonarrs(candidates, args.gate)
    rc = 0
    for arr in sonarrs:
        if arr["state"] != "configured":
            continue
        rc |= _set_client_host(arr, host, args.gate, upstream)
    return rc


def cmd_increase_cache(args: argparse.Namespace) -> int:
    name = upstream_name(args.upstream)
    if not name:
        return _fail("upstream invalide")
    cfg = SETTINGS_STORAGE / "docker" / USER / name / "config" / "config.json"
    if not cfg.is_file():
        _print(f"{name}: configuration introuvable, aucune modification.")
        return 0
    try:
        data = json.loads(cfg.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        return _fail(f"lecture de {cfg} impossible: {exc}")
    dfs = data.setdefault("mount", {}).setdefault("dfs", {})
    current = str(dfs.get("disk_cache_size", ""))
    if current == CACHE_TARGET:
        _print(f"{name}: cache DFS deja a {CACHE_TARGET}.")
        return 0
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup = cfg.with_name(f"config.json.bak-{stamp}")
    try:
        backup.write_bytes(cfg.read_bytes())
    except OSError as exc:
        return _fail(f"backup impossible: {exc}")
    dfs["disk_cache_size"] = CACHE_TARGET
    tmp = cfg.with_name("config.json.tmp")
    try:
        tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        os.replace(tmp, cfg)
    except OSError as exc:
        return _fail(f"ecriture de la configuration impossible: {exc}")
    _print(f"{name}: cache DFS {current or 'inconnu'} -> {CACHE_TARGET} (backup: {backup.name}).")
    out = run(["docker", "restart", name], timeout=120)
    if out.returncode != 0:
        return _fail(f"redemarrage de {name} impossible: {out.stderr.strip()}")
    deadline = time.time() + 60
    while time.time() < deadline:
        if docker_health(name) in ("healthy", "none"):
            _print(f"{name}: redemarre.")
            return 0
        time.sleep(2)
    _print(f"{name}: redemarre, healthcheck pas encore vert.")
    return 0


GATE_VARS_TEMPLATE = """---
pgrole: '__GATE__'
image: 'openresty/openresty:1.27.1.2-alpine'
decypharrgate_upstream: '__UPSTREAM__'
traefik_labels_enabled: false
pg_volumes:
  - "{{ settings.storage }}/docker/{{ lookup('env','USER') }}/{{ pgrole }}:/etc/nginx/conf.d:ro"
pretasks:
  - decypharrgate
posttasks:
  - decypharrgate
specific_docker_info:
  restart_policy: unless-stopped
  healthcheck:
    test: ["CMD-SHELL", "wget -qO- http://127.0.0.1:8282/api/v2/app/version >/dev/null || exit 1"]
    interval: 30s
    timeout: 5s
    retries: 3
    start_period: 10s
"""


def cmd_write_gate_vars(args: argparse.Namespace) -> int:
    gate = args.gate.strip()
    upstream = args.upstream.strip()
    if not gate or not upstream:
        return _fail("gate ou upstream manquant")
    path = SETTINGS_STORAGE / "vars" / f"{gate}.yml"
    if path.exists():
        _print(f"{path} existe deja.")
        return 0
    path.parent.mkdir(parents=True, exist_ok=True)
    content = GATE_VARS_TEMPLATE.replace("__GATE__", gate).replace("__UPSTREAM__", upstream)
    path.write_text(content, encoding="utf-8")
    _print(str(path))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Gestion de decypharrgate (SSDV2)")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("detect-upstreams", help="instances decypharr detectees")
    p = sub.add_parser("current-upstream", help="upstream d'une gate")
    p.add_argument("--gate", required=True)
    sub.add_parser("menu-status", help="etat global JSON")
    p = sub.add_parser("status", help="etat d'une gate")
    p.add_argument("--gate", required=True)
    p = sub.add_parser("configure", help="configurer les Sonarr eligibles")
    p.add_argument("--gate", required=True)
    p = sub.add_parser("restore", help="restaurer les Sonarr de la gate")
    p.add_argument("--gate", required=True)
    p = sub.add_parser("increase-cache", help="cache DFS d'une instance decypharr")
    p.add_argument("--upstream", required=True)
    p = sub.add_parser("write-gate-vars", help="vars custom d'une gate")
    p.add_argument("--gate", required=True)
    p.add_argument("--upstream", required=True)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    handlers = {
        "detect-upstreams": cmd_detect_upstreams,
        "current-upstream": cmd_current_upstream,
        "menu-status": cmd_menu_status,
        "status": cmd_status,
        "configure": cmd_configure,
        "restore": cmd_restore,
        "increase-cache": cmd_increase_cache,
        "write-gate-vars": cmd_write_gate_vars,
    }
    return handlers[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
