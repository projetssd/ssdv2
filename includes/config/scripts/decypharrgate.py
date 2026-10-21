#!/usr/bin/env python3
"""Gestion de la passerelle decypharrgate pour SSDV2.

Commandes :
  status            Etat JSON (gate, Sonarr, cache decypharr)
  configure-sonarr  Pointe le download client Sonarr vers decypharrgate
  restore-sonarr    Remet le download client Sonarr vers decypharrsonarr
  increase-cache    Passe le cache DFS de decypharrsonarr a 20 Go

Le script ne manipule aucun secret en clair : le mot de passe du client
qBittorrent est lu dans la configuration locale de decypharr (token de l'Arr).
"""

from __future__ import annotations

import argparse
import getpass
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime
from pathlib import Path

GATE_NAME = "decypharrgate"
UPSTREAM_HOST = "decypharrsonarr"
SONARR_URL = "http://127.0.0.1:8989"
CACHE_TARGET = "20GB"

SETTINGS_STORAGE = Path(os.environ.get("SETTINGS_STORAGE", Path.home() / "seedbox"))
USER = os.environ.get("USER") or getpass.getuser()
SONARR_DIR = SETTINGS_STORAGE / "docker" / USER / "sonarr" / "config"
DECYPHARR_DIR = SETTINGS_STORAGE / "docker" / USER / "decypharrsonarr" / "config"
SONARR_CONFIG = SONARR_DIR / "config.xml"
DECYPHARR_CONFIG = DECYPHARR_DIR / "config.json"


def _print(msg: str) -> None:
    print(msg, flush=True)


def _fail(msg: str) -> int:
    print(f"ERREUR: {msg}", file=sys.stderr, flush=True)
    return 1


def sonarr_api_key() -> str | None:
    if not SONARR_CONFIG.is_file():
        return None
    try:
        root = ET.parse(SONARR_CONFIG).getroot()
        node = root.find("ApiKey")
        return (node.text or "").strip() or None
    except (ET.ParseError, OSError):
        return None


def decypharr_token() -> str | None:
    if not DECYPHARR_CONFIG.is_file():
        return None
    try:
        cfg = json.loads(DECYPHARR_CONFIG.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    for arr in cfg.get("arrs", []) or []:
        name = str(arr.get("name", "")).lower()
        host = str(arr.get("host", "")).lower()
        if name == "sonarr" or "sonarr" in host:
            token = arr.get("token")
            if token:
                return str(token)
    return None


def sonarr_request(method: str, path: str, payload: dict | None = None) -> dict | list:
    key = sonarr_api_key()
    if not key:
        raise RuntimeError("cle API Sonarr introuvable")
    url = f"{SONARR_URL}/api/v3/{path.lstrip('/')}"
    data = None
    headers = {"X-Api-Key": key, "Accept": "application/json"}
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=30) as resp:
        body = resp.read()
        if not body:
            return {}
        return json.loads(body.decode("utf-8"))


def _field(client: dict, name: str) -> dict | None:
    for field in client.get("fields", []) or []:
        if field.get("name") == name:
            return field
    return None


def _client_host(client: dict) -> str:
    field = _field(client, "host")
    return str(field.get("value", "")) if field else ""


def find_client() -> dict | None:
    try:
        clients = sonarr_request("GET", "downloadclient")
    except (urllib.error.URLError, urllib.error.HTTPError, RuntimeError, ValueError) as exc:
        raise RuntimeError(f"API Sonarr indisponible: {exc}") from exc
    if not isinstance(clients, list):
        return None
    for client in clients:
        if client.get("name") == "decypharrsonarr":
            return client
    for client in clients:
        if _client_host(client) in (UPSTREAM_HOST, GATE_NAME):
            return client
    return None


def docker_health(name: str) -> str:
    try:
        out = subprocess.run(
            ["docker", "inspect", "-f", "{{.State.Health.Status}}", name],
            capture_output=True, text=True, timeout=10, check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return "absent"
    if out.returncode != 0:
        return "absent"
    status = (out.stdout or "").strip()
    if not status or status == "<no value>":
        return "none"
    return status


def cache_size() -> str | None:
    if not DECYPHARR_CONFIG.is_file():
        return None
    try:
        cfg = json.loads(DECYPHARR_CONFIG.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    value = cfg.get("mount", {}).get("dfs", {}).get("disk_cache_size")
    return str(value) if value is not None else None


def cmd_status(_args: argparse.Namespace) -> int:
    sonarr_installed = SONARR_CONFIG.is_file()
    host = None
    if sonarr_installed:
        try:
            client = find_client()
            host = _client_host(client) if client else None
        except RuntimeError:
            host = None
    payload = {
        "gate": docker_health(GATE_NAME),
        "sonarr_installed": sonarr_installed,
        "sonarr_host": host,
        "decypharr_installed": DECYPHARR_CONFIG.is_file(),
        "cache_size": cache_size(),
    }
    _print(json.dumps(payload, ensure_ascii=False))
    return 0


def _set_host(target: str, allowed_sources: tuple[str, ...]) -> int:
    if not SONARR_CONFIG.is_file():
        _print("Sonarr n'est pas installe : aucune modification.")
        return 0
    try:
        client = find_client()
    except RuntimeError as exc:
        return _fail(str(exc))
    if client is None:
        _print("Client de telechargement decypharrsonarr introuvable dans Sonarr.")
        return 0

    current = _client_host(client)
    if current == target:
        _print(f"Sonarr pointe deja vers {target}.")
        return 0
    if current not in allowed_sources:
        _print(
            f"Sonarr pointe vers '{current}' : modification refusee "
            f"(attendu: {', '.join(allowed_sources)})."
        )
        return 1

    host_field = _field(client, "host")
    if host_field is None:
        return _fail("champ 'host' introuvable dans le client Sonarr")
    host_field["value"] = target

    password = decypharr_token() or sonarr_api_key()
    password_field = _field(client, "password")
    if password_field is not None and password:
        password_field["value"] = password

    try:
        sonarr_request("PUT", f"downloadclient/{client['id']}", client)
    except (urllib.error.URLError, urllib.error.HTTPError, RuntimeError, ValueError) as exc:
        return _fail(f"mise a jour du client Sonarr impossible: {exc}")

    _print(f"Sonarr : host du download client -> {target}.")

    # Test de connectivite non bloquant (la gate peut etre en cours de demarrage).
    if docker_health(GATE_NAME) == "healthy" or target == UPSTREAM_HOST:
        try:
            sonarr_request("POST", "downloadclient/test", client)
            _print("Test du download client Sonarr : OK.")
        except (urllib.error.URLError, urllib.error.HTTPError, RuntimeError, ValueError) as exc:
            _print(f"Test du download client Sonarr en echec (non bloquant): {exc}")
    return 0


def cmd_configure_sonarr(_args: argparse.Namespace) -> int:
    return _set_host(GATE_NAME, (UPSTREAM_HOST,))


def cmd_restore_sonarr(_args: argparse.Namespace) -> int:
    return _set_host(UPSTREAM_HOST, (GATE_NAME,))


def _wait_decypharr(timeout: int = 60) -> bool:
    deadline = time.time() + timeout
    while time.time() < deadline:
        if docker_health(UPSTREAM_HOST) in ("healthy", "starting", "none", "inconnu"):
            # "none" = pas de healthcheck defini : le conteneur tourne.
            return True
        time.sleep(2)
    return False


def cmd_increase_cache(_args: argparse.Namespace) -> int:
    if not DECYPHARR_CONFIG.is_file():
        _print("decypharrsonarr n'est pas installe : aucune modification.")
        return 0
    try:
        cfg = json.loads(DECYPHARR_CONFIG.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        return _fail(f"lecture de {DECYPHARR_CONFIG} impossible: {exc}")

    dfs = cfg.setdefault("mount", {}).setdefault("dfs", {})
    current = str(dfs.get("disk_cache_size", ""))
    if current == CACHE_TARGET:
        _print(f"Le cache DFS est deja a {CACHE_TARGET}.")
        return 0

    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup = DECYPHARR_CONFIG.with_name(f"config.json.bak-{stamp}")
    try:
        backup.write_bytes(DECYPHARR_CONFIG.read_bytes())
    except OSError as exc:
        return _fail(f"backup impossible: {exc}")

    dfs["disk_cache_size"] = CACHE_TARGET
    tmp = DECYPHARR_CONFIG.with_name("config.json.tmp")
    try:
        tmp.write_text(json.dumps(cfg, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        os.replace(tmp, DECYPHARR_CONFIG)
    except OSError as exc:
        return _fail(f"ecriture de la configuration impossible: {exc}")

    _print(f"Cache DFS : {current or 'inconnu'} -> {CACHE_TARGET} (backup: {backup.name}).")

    try:
        subprocess.run(["docker", "restart", UPSTREAM_HOST], check=True, timeout=120)
    except (OSError, subprocess.SubprocessError) as exc:
        return _fail(f"redemarrage de {UPSTREAM_HOST} impossible: {exc}")

    if _wait_decypharr():
        _print(f"{UPSTREAM_HOST} redemarre.")
    else:
        _print(f"{UPSTREAM_HOST} redemarre, mais le healthcheck n'est pas encore vert.")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Gestion de decypharrgate (SSDV2)")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("status", help="etat JSON")
    sub.add_parser("configure-sonarr", help="pointer Sonarr vers decypharrgate")
    sub.add_parser("restore-sonarr", help="remettre Sonarr vers decypharrsonarr")
    sub.add_parser("increase-cache", help="passer le cache DFS a 20 Go")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    handlers = {
        "status": cmd_status,
        "configure-sonarr": cmd_configure_sonarr,
        "restore-sonarr": cmd_restore_sonarr,
        "increase-cache": cmd_increase_cache,
    }
    return handlers[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
