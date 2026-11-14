#!/usr/bin/env python3
"""SSDV2 - inventaire pseudonyme, stdlib uniquement, sans lecture de secrets.

Le serveur distant ne reçoit ni IP, ni MAC, ni hostname, ni domaine,
ni nom d'image Docker, ni configuration ni identifiant utilisateur.
En cas d'échec la commande reste non bloquante et silencieuse.
"""
from __future__ import annotations

import argparse
import fcntl
import json
import os
import re
import sqlite3
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

SOURCE = Path(os.environ.get("SETTINGS_SOURCE") or Path(__file__).resolve().parents[3])
CONFIG = Path.home() / ".config" / "ssd"
ENDPOINT_FILE = SOURCE / "includes" / "config" / "telemetry-endpoint.txt"
ID_FILE = CONFIG / "telemetry-id"
DISABLED_FILE = CONFIG / "telemetry.disabled"
LAST_SEND_FILE = CONFIG / "telemetry-last-send"
LOCK_FILE = CONFIG / "telemetry.lock"
APP_RE = re.compile(r"^[a-z0-9][a-z0-9_-]{0,47}$")
VERSION_RE = re.compile(r"^[a-zA-Z0-9][a-zA-Z0-9.+_-]{0,39}$")
MAX_APPS = 180


def enabled() -> bool:
    val = os.environ.get("SSDV2_TELEMETRY", "").strip().lower()
    return val not in {"0", "off", "false", "no", "disabled"} and not DISABLED_FILE.exists()


def endpoint() -> str | None:
    """Le mainteneur configure l'URL publique dans le dépôt, pas l'utilisateur."""
    try:
        url = (os.environ.get("SSDV2_TELEMETRY_ENDPOINT") or ENDPOINT_FILE.read_text(encoding="utf-8")).strip()
    except OSError:
        return None
    parsed = urllib.parse.urlsplit(url)
    if (parsed.scheme != "https" or not parsed.hostname or parsed.username or
            parsed.password or parsed.query or parsed.fragment or
            parsed.path != "/api/v1/snapshot" or parsed.port not in (None, 443)):
        return None
    return url


def ensure_config() -> None:
    CONFIG.mkdir(mode=0o700, parents=True, exist_ok=True)
    try:
        CONFIG.chmod(0o700)
    except OSError:
        pass


def private_file(path: Path, value: str) -> None:
    """Création atomique en droits 0600 (pas de fuite entre utilisateurs)."""
    ensure_config()
    temp = CONFIG / ("." + path.name + "-" + uuid.uuid4().hex)
    fd = os.open(temp, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(value)
        os.replace(temp, path)
        path.chmod(0o600)
    finally:
        try:
            temp.unlink(missing_ok=True)
        except OSError:
            pass


def installation_id() -> str:
    try:
        current = str(uuid.UUID(ID_FILE.read_text(encoding="utf-8").strip()))
        if uuid.UUID(current).version == 4:
            return current
    except (OSError, ValueError):
        pass
    value = str(uuid.uuid4())
    private_file(ID_FILE, value + "\n")
    return value


def command(*argv: str, timeout: int = 8) -> str | None:
    try:
        result = subprocess.run(argv, text=True, capture_output=True, timeout=timeout, check=False)
        return result.stdout.strip() if result.returncode == 0 else None
    except (OSError, subprocess.TimeoutExpired):
        return None


def project_version() -> tuple[str, str]:
    branch = command("git", "-C", str(SOURCE), "symbolic-ref", "--quiet", "--short", "HEAD")
    revision = command("git", "-C", str(SOURCE), "rev-parse", "--short=12", "HEAD")
    return (branch if branch in {"master", "dev"} else "unknown",
            revision if revision and VERSION_RE.fullmatch(revision) else "unknown")


def catalogue_apps() -> set[str]:
    source = SOURCE / "includes" / "config" / "services-available"
    try:
        lines = source.read_text(encoding="utf-8").splitlines()
    except OSError:
        return set()
    result: set[str] = set()
    for line in lines:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        name = line.split(" - ", 1)[0].strip()
        if APP_RE.fullmatch(name):
            result.add(name)
    return result


def database_apps() -> set[str] | None:
    db = SOURCE / "ssddb"
    if not db.is_file():
        return None
    try:
        # SQLite utilisé en lecture seule ; aucun secret de account.yml n'est consulté.
        with sqlite3.connect(db.as_uri() + "?mode=ro", uri=True, timeout=2) as conn:
            return {row[0] for row in conn.execute(
                "SELECT name FROM applications WHERE status = 2"
            ) if isinstance(row[0], str) and APP_RE.fullmatch(row[0])}
    except (sqlite3.Error, OSError):
        return None


def image_tag(image: str) -> str:
    # Uniquement le tag. Aucun nom d'image ni registre privé n'est envoyé.
    tail = image.rsplit("/", 1)[-1]
    if "@" in tail or ":" not in tail:
        return "unknown"
    tag = tail.rsplit(":", 1)[-1]
    return tag if VERSION_RE.fullmatch(tag) else "unknown"


def docker_apps() -> dict[str, tuple[str, str]] | None:
    fmt = '{{.Label "ssdv2.app"}}\t{{.Names}}\t{{.Image}}\t{{.Label "org.opencontainers.image.version"}}'
    raw = command("docker", "ps", "-a", "--filter", "label=ssdv2.app", "--format", fmt, timeout=12)
    if raw is None:
        return None
    rows: dict[str, tuple[str, str]] = {}
    for line in raw.splitlines():
        fields = line.split("\t")
        if len(fields) != 4:
            continue
        app, name, image, oci_version = fields
        if not APP_RE.fullmatch(app):
            continue
        # Le container applicatif principal prime sur les dépendances DB/cache.
        score = 2 if name == app else (1 if name.startswith(app + "-") else 0)
        if app not in rows or (score > rows[app][0]):
            rows[app] = (score, oci_version if VERSION_RE.fullmatch(oci_version) else image_tag(image))
    return {app: item[1] for app, item in rows.items()}


def snapshot() -> dict | None:
    db_apps = database_apps()
    images = docker_apps()
    allowed = catalogue_apps()
    # Ne pas envoyer de snapshot incomplet : une panne Docker pourrait
    # sinon être interprétée comme une suppression de toutes les applications.
    if db_apps is None or images is None or not allowed:
        return None
    apps = (db_apps | set(images)) & allowed
    if len(apps) > MAX_APPS:
        return None
    branch, revision = project_version()
    return {
        "schema": 1,
        "installation_id": installation_id(),
        "branch": branch,
        "core_version": revision,
        "apps": [{"name": app, "version": images.get(app, "unknown")} for app in sorted(apps)]
    }


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def send(url: str, payload: dict) -> None:
    body = json.dumps(payload, ensure_ascii=True, separators=(",", ":")).encode("ascii")
    if len(body) > 24_576:
        return
    req = urllib.request.Request(
        url, data=body, headers={"Content-Type": "application/json", "User-Agent": "SSDV2-telemetry/1"},
        method="POST"
    )
    handler = urllib.request.build_opener(NoRedirect)
    with handler.open(req, timeout=5) as response:
        if response.status != 204:
            raise RuntimeError("Telemetry endpoint declined snapshot")


def sync(force: bool = False) -> None:
    if not enabled():
        return
    url = endpoint()
    if not url:
        return
    ensure_config()
    with LOCK_FILE.open("a+", encoding="utf-8") as lock:
        os.chmod(LOCK_FILE, 0o600)
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        try:
            last = float(LAST_SEND_FILE.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            last = 0.0
        if not force and time.time() - last < 3600:
            return
        payload = snapshot()
        if payload is None:
            return
        send(url, payload)
        private_file(LAST_SEND_FILE, str(time.time()))


def main() -> None:
    parser = argparse.ArgumentParser(description="Collecte communautaire SSDV2 respectueuse de la vie privée")
    parser.add_argument("action", nargs="?", choices=["sync", "status", "disable", "enable", "forget"], default="sync")
    parser.add_argument("--force", action="store_true", help="Ignorer la temporisation locale")
    args = parser.parse_args()
    if args.action == "status":
        print("Collecte :", "activée" if enabled() else "désactivée")
        print("Point de collecte :", "configuré" if endpoint() else "non configuré")
        return
    if args.action == "disable":
        ensure_config()
        private_file(DISABLED_FILE, "disabled\n")
        print("Collecte désactivée. Aucun nouvel événement ne sera envoyé.")
        return
    if args.action == "enable":
        DISABLED_FILE.unlink(missing_ok=True)
        print("Collecte activée.")
        return
    if args.action == "forget":
        ensure_config()
        private_file(DISABLED_FILE, "disabled\n")
        ID_FILE.unlink(missing_ok=True)
        LAST_SEND_FILE.unlink(missing_ok=True)
        print("Identifiant local supprimé, collecte désactivée. Les agrégats anonymisés sont conservés côté serveur.")
        return
    try:
        sync(args.force)
    except (OSError, ValueError, RuntimeError, urllib.error.URLError, sqlite3.Error):
        # Le fonctionnement de SSDV2 ne dépend jamais de la télémétrie.
        pass


if __name__ == "__main__":
    main()
