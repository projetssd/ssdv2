#!/usr/bin/env python3
"""plexcve.py - audit et remediation Plex2Shell.

CVE-2026-96652 / 96654 / 96655 / 96656 : chaine SSRF -> vol de token ->
ecriture de .so dans Codecs -> execution de code. Correctif : Plex >= 1.43.3.10861.

Le script couvre :
  - la version PMS et la variable VERSION ;
  - les ports publies, les montages et les options de securite ;
  - les labels Traefik (middleware CrowdSec/WAF) ;
  - Preferences.xml (TranscoderH264Options) ;
  - Codecs/ (zz*.so, .so hors bundle, queue ELF uniforme) ;
  - les logs Plex (tentatives, succes, IP sources) ;
  - la correlation avec le log d'acces Traefik (32400 direct vs 443) ;
  - les autres ports publies et Watchtower.

Usage :
    plexcve.py scan [--json] [--deep] [--fixture DIR]
    plexcve.py status
    plexcve.py report
    plexcve.py logs [--json]
    plexcve.py fix-plex [--apply] [--dry-run] [--force] [--media-path PATH]...
    plexcve.py public-https [--apply] [--dry-run] [--disable]
    plexcve.py close-port [--apply] [--dry-run] [--ports 32400,...] [--allow-lan CIDR]
    plexcve.py quarantine [--apply]
    plexcve.py rollback [--backup DIR] [--apply]
    plexcve.py selftest

Sortie JSON stable pour ssdv2ctl / WebUI, sortie lisible pour le menu.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import sqlite3
import ssl
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from xml.etree import ElementTree as ET

try:  # Python 3.11+
    import tomllib
except ModuleNotFoundError:  # pragma: no cover - Python 3.10
    try:
        import tomli as tomllib  # type: ignore[no-redef]
    except ModuleNotFoundError:  # pragma: no cover
        tomllib = None  # type: ignore[assignment]

VERSION = "1.1.0"
SCHEMA_VERSION = 1

CVE_IDS = (
    "CVE-2026-96652",
    "CVE-2026-96654",
    "CVE-2026-96655",
    "CVE-2026-96656",
)

FIXED_VERSION = (1, 43, 3, 10861)
RECOMMENDED_VERSION = (1, 43, 5)

PLEX_NAME = "plex"
PLEX_PORT = 32400
PLEX_CAP_ADD = ("CHOWN", "DAC_OVERRIDE", "FOWNER", "SETGID", "SETUID")
ALLOWED_HOST_PORTS = {80, 443, 6881}
DEFAULT_TRAEFIK_LOG = "docker/traefik/logs/access.log"
DEFAULT_TRAEFIK_RULES = "docker/traefik/rules"

# Mode public HTTPS (opt-in, plex.public_https dans account.yml).
PLEX_PUBLIC_CHAIN = "chain-plex@file"
PLEX_TRANSPORT = "plex-transport@file"
PLEX_ALLOWLIST_MIDDLEWARE = "middlewares-allowlist@file"
CLOUDFLARE_SAMPLE_IPS = (
    "173.245.48.0/20",
    "104.16.0.0/12",
    "2400:cb00::/32",
)

ENV_FILE = Path.home() / ".config" / "ssd" / "env"
SECRET_PATHS = (
    "/.ssh",
    "/.ansible",
    "/.vault_pass",
    "/.config/rclone",
    "/.config/ssd",
)

TOKEN_RE = re.compile(r"(?i)(X-Plex-Token=)[^&\"\s]+")
PLEX_LOG_DATE_RE = re.compile(r"^(\w{3} \d{1,2}, \d{4} \d{2}:\d{2}:\d{2}\.\d+)")
PLEX_REQUEST_RE = re.compile(
    r"Request: \[([0-9a-fA-F:.]+):\d+ \([^)]*\)\] (\w+) ([^ ]+)"
)
PLEX_COMPLETED_RE = re.compile(
    r"Completed: \[([0-9a-fA-F:.]+):\d+\] (\d+) \w+ ([^ ]+)"
)
PUBLISHED_PORT_RE = re.compile(
    r"(?:0\.0\.0\.0|\[::\]|:::)(?::(\d+))->(\d+)/(tcp|udp)"
)
CODEC_BUNDLE_RE = re.compile(r"^[0-9a-f]+-[0-9a-f]+-linux-(aarch64|x86_64|armv7|armhf)$")


class ToolError(Exception):
    """Erreur d'execution d'un outil externe."""


# ---------------------------------------------------------------------------
# Environnement / chemins
# ---------------------------------------------------------------------------


def load_env_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.is_file():
        return values
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return values
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def settings_paths() -> tuple[Path, Path]:
    env = load_env_file(ENV_FILE)
    source = Path(
        os.environ.get("SETTINGS_SOURCE")
        or env.get("SETTINGS_SOURCE")
        or Path.home() / "seedbox-compose"
    )
    storage = Path(
        os.environ.get("SETTINGS_STORAGE")
        or env.get("SETTINGS_STORAGE")
        or Path.home() / "seedbox"
    )
    return source, storage


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def cache_path(storage: Path) -> Path:
    return storage / "conf" / "plexcve-status.json"


def invalidate_cache(storage: Path) -> None:
    try:
        cache_path(storage).unlink()
    except OSError:
        pass


def load_cached_scan(storage: Path) -> dict | None:
    path = cache_path(storage)
    if not path.is_file():
        return None
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    return payload if isinstance(payload, dict) else None


def redact(text: str) -> str:
    return TOKEN_RE.sub(r"\1***", text)


# ---------------------------------------------------------------------------
# Outils / Docker
# ---------------------------------------------------------------------------


def run_cmd(args: list[str], timeout: int = 30) -> subprocess.CompletedProcess:
    try:
        return subprocess.run(
            args,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise ToolError(str(exc)) from exc


def docker_json(args: list[str], timeout: int = 30) -> object:
    result = run_cmd(["docker", *args], timeout=timeout)
    if result.returncode != 0:
        raise ToolError(result.stderr.strip() or "docker en echec")
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise ToolError(f"sortie docker invalide: {exc}") from exc


def docker_names() -> list[str]:
    result = run_cmd(["docker", "ps", "-a", "--format", "{{.Names}}"], timeout=30)
    if result.returncode != 0:
        raise ToolError(result.stderr.strip() or "docker ps en echec")
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def find_plex_container() -> str | None:
    names = docker_names()
    if PLEX_NAME in names:
        return PLEX_NAME
    for name in names:
        try:
            labels = docker_json(
                ["inspect", name, "--format", "{{json .Config.Labels}}"]
            )
        except ToolError:
            continue
        if isinstance(labels, dict) and labels.get("ssdv2.app") == PLEX_NAME:
            return name
    return None


def inspect_container(name: str) -> dict:
    data = docker_json(["inspect", name])
    if isinstance(data, list) and data:
        return data[0]
    if isinstance(data, dict):
        return data
    raise ToolError(f"inspection impossible: {name}")


def container_ip(attrs: dict) -> str | None:
    networks = (attrs.get("NetworkSettings") or {}).get("Networks") or {}
    preferred = networks.get("traefik_proxy")
    ordered = [preferred, *networks.values()] if preferred else list(networks.values())
    for network in ordered:
        if not isinstance(network, dict):
            continue
        ip = network.get("IPAddress")
        if ip:
            return ip
    return None


def unverified_ssl_context() -> ssl.SSLContext:
    """Contexte TLS pour le certificat plex.direct / l'API locale Plex."""
    context = ssl.create_default_context()
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE
    return context


def plex_identity(attrs: dict, name: str) -> str | None:
    ip = container_ip(attrs)
    hosts = [host for host in (ip, "127.0.0.1") if host]
    urls = []
    for host in hosts:
        urls.append(f"https://{host}:{PLEX_PORT}/identity")
        urls.append(f"http://{host}:{PLEX_PORT}/identity")
    for url in urls:
        try:
            context = unverified_ssl_context() if url.startswith("https://") else None
            with urllib.request.urlopen(url, timeout=4, context=context) as response:
                return response.read().decode("utf-8", errors="ignore")
        except (urllib.error.URLError, OSError, TimeoutError):
            continue
    try:
        result = run_cmd(
            [
                "docker",
                "exec",
                name,
                "sh",
                "-c",
                f"curl -k -fsS --max-time 3 https://127.0.0.1:{PLEX_PORT}/identity",
            ],
            timeout=10,
        )
        if result.returncode == 0:
            return result.stdout
    except ToolError:
        pass
    return None


def parse_version(text: str | None) -> tuple[int, int, int, int] | None:
    if not text:
        return None
    match = re.search(r"(\d+)\.(\d+)\.(\d+)\.(\d+)", text)
    if not match:
        return None
    return tuple(int(part) for part in match.groups())  # type: ignore[return-value]


def version_str(version: tuple[int, int, int, int] | None) -> str | None:
    return ".".join(str(part) for part in version) if version else None


def version_status(version: tuple[int, int, int, int] | None) -> str:
    if version is None:
        return "unknown"
    return "patched" if version >= FIXED_VERSION else "vulnerable"


def env_dict(attrs: dict) -> dict[str, str]:
    result: dict[str, str] = {}
    for entry in (attrs.get("Config") or {}).get("Env") or []:
        key, sep, value = str(entry).partition("=")
        if sep:
            result[key] = value
    return result


def labels_dict(attrs: dict) -> dict[str, str]:
    return dict((attrs.get("Config") or {}).get("Labels") or {})


def mounts_list(attrs: dict) -> list[dict]:
    return list(attrs.get("Mounts") or [])


def find_mount(attrs: dict, destination: str) -> dict | None:
    for mount in mounts_list(attrs):
        if mount.get("Destination") == destination:
            return mount
    return None


CROWDSEC_WHITELIST_FILE = "plex-clients-whitelist.yaml"


def crowdsec_whitelist_source(source: Path) -> Path:
    return (
        source
        / "includes"
        / "config"
        / "files"
        / "crowdsec"
        / CROWDSEC_WHITELIST_FILE
    )


def crowdsec_config_dir() -> Path | None:
    try:
        attrs = inspect_container("crowdsec")
    except ToolError:
        return None
    mount = find_mount(attrs, "/etc/crowdsec")
    if not mount or not mount.get("Source"):
        return None
    return Path(str(mount["Source"]))


def install_crowdsec_plex_whitelist(
    source: Path, enabled: bool
) -> tuple[bool, str]:
    """Installe ou retire la whitelist CrowdSec des clients Plex.

    Plex Web et Infuse parcourent legitimement la bibliotheque : sans cette
    whitelist, CrowdSec declenche http-probing/http-crawl-non_statics et
    bannit l'IP du foyer (donc aussi l'acces aux autres apps).
    """
    config_dir = crowdsec_config_dir()
    if config_dir is None:
        return True, "CrowdSec non installe : whitelist ignoree"
    target = config_dir / "parsers" / "s02-enrich" / CROWDSEC_WHITELIST_FILE
    if not enabled:
        if target.is_file():
            try:
                target.unlink()
            except OSError as exc:
                return False, str(exc)
            run_cmd(["docker", "kill", "-s", "HUP", "crowdsec"], timeout=15)
            return True, f"whitelist retiree : {target}"
        return True, "whitelist absente"
    src = crowdsec_whitelist_source(source)
    if not src.is_file():
        return False, f"fichier source introuvable : {src}"
    try:
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, target)
        os.chmod(target, 0o644)
    except OSError as exc:
        return False, str(exc)
    run_cmd(["docker", "kill", "-s", "HUP", "crowdsec"], timeout=15)
    return True, f"whitelist installee : {target}"


def plex_paths(attrs: dict) -> dict[str, Path | None]:
    config_mount = find_mount(attrs, "/config")
    config_source = Path(config_mount["Source"]) if config_mount else None
    if config_source:
        base = config_source / "Library" / "Application Support" / "Plex Media Server"
    else:
        base = None
    return {
        "config": config_source,
        "base": base,
        "preferences": (base / "Preferences.xml") if base else None,
        "codecs": (base / "Codecs") if base else None,
        "logs": (base / "Logs") if base else None,
        "db": (base / "Plug-in Support" / "Databases" / "com.plexapp.plugins.library.db")
        if base
        else None,
    }


def scan_ports(attrs: dict) -> list[dict]:
    bindings = (attrs.get("HostConfig") or {}).get("PortBindings") or {}
    result = []
    for container_port, hosts in bindings.items():
        for host in hosts or []:
            result.append(
                {
                    "container_port": container_port,
                    "host_ip": host.get("HostIp") or "",
                    "host_port": host.get("HostPort") or "",
                }
            )
    return result


def scan_mounts(attrs: dict, home: Path) -> list[dict]:
    result = []
    for mount in mounts_list(attrs):
        source = str(mount.get("Source") or "")
        destination = str(mount.get("Destination") or "")
        rw = bool(mount.get("RW", True))
        dangers = []
        if destination == str(home) or source == str(home):
            dangers.append("home")
        if destination == "/tmp":
            dangers.append("tmp")
        if destination == "/dev/shm":
            dangers.append("dev_shm")
        if destination == "/mnt" and rw:
            dangers.append("mnt_rw")
        if any(secret in source for secret in SECRET_PATHS):
            dangers.append("secret")
        result.append(
            {
                "source": source,
                "destination": destination,
                "rw": rw,
                "type": mount.get("Type"),
                "dangers": dangers,
            }
        )
    return result


def scan_security(attrs: dict) -> dict:
    host_config = attrs.get("HostConfig") or {}
    security_opt = list(host_config.get("SecurityOpt") or [])
    cap_drop = list(host_config.get("CapDrop") or [])
    return {
        "security_opt": security_opt,
        "no_new_privileges": any("no-new-privileges" in item for item in security_opt),
        "cap_drop": cap_drop,
        "cap_drop_all": "ALL" in cap_drop,
        "read_only": bool(host_config.get("ReadonlyRootfs", False)),
        "privileged": bool(host_config.get("Privileged", False)),
    }


def scan_traefik(attrs: dict) -> dict:
    labels = labels_dict(attrs)
    router = "plex-rtr"
    middleware = labels.get(f"traefik.http.routers.{router}.middlewares")
    service_port = labels.get("traefik.http.services.plex-svc.loadbalancer.server.port")
    scheme = labels.get("traefik.http.services.plex-svc.loadbalancer.server.scheme")
    transport = labels.get(
        "traefik.http.services.plex-svc.loadbalancer.serverstransport"
    )
    entrypoints = labels.get(f"traefik.http.routers.{router}.entrypoints")
    chain_plex = PLEX_PUBLIC_CHAIN.split("@", 1)[0] in str(middleware or "")
    public_https = bool(
        chain_plex or scheme == "https" or transport
    )
    return {
        "router": router,
        "middlewares": middleware,
        "service_port": service_port,
        "has_middleware": bool(middleware),
        "entrypoints": entrypoints,
        "scheme": scheme or "http",
        "serverstransport": transport,
        "chain_plex": chain_plex,
        "public_https": public_https,
    }


# ---------------------------------------------------------------------------
# Preferences / Codecs / Logs
# ---------------------------------------------------------------------------


def scan_preferences(path: Path | None) -> dict:
    result = {
        "path": str(path) if path else None,
        "exists": bool(path and path.is_file()),
        "transcoder_h264_options": None,
        "transcoder_temp_directory": None,
        "custom_connections": None,
        "manual_port_mapping_mode": None,
        "manual_port_mapping_port": None,
        "secure_connections": None,
        "relay_enabled": None,
        "publish_server_on_plex_online_key": None,
        "has_token": False,
        "parse_error": None,
    }
    if not path or not path.is_file():
        return result
    try:
        root = ET.parse(path).getroot()
    except (ET.ParseError, OSError) as exc:
        result["parse_error"] = str(exc)
        return result
    result["transcoder_h264_options"] = root.get("TranscoderH264Options")
    result["transcoder_temp_directory"] = root.get("TranscoderTempDirectory")
    result["custom_connections"] = root.get("customConnections")
    result["manual_port_mapping_mode"] = root.get("ManualPortMappingMode")
    result["manual_port_mapping_port"] = root.get("ManualPortMappingPort")
    result["secure_connections"] = root.get("secureConnections")
    result["relay_enabled"] = root.get("RelayEnabled")
    result["publish_server_on_plex_online_key"] = root.get(
        "PublishServerOnPlexOnlineKey"
    )
    result["has_token"] = bool((root.get("PlexOnlineToken") or "").strip())
    return result


def _is_uniform_tail(path: Path, size: int = 65536) -> bool:
    try:
        with path.open("rb") as handle:
            handle.seek(0, os.SEEK_END)
            length = handle.tell()
            if length < size:
                return False
            handle.seek(-size, os.SEEK_END)
            data = handle.read(size)
    except OSError:
        return False
    return len(set(data)) == 1


def scan_codecs(codecs_dir: Path | None, deep: bool = False) -> dict:
    result = {
        "path": str(codecs_dir) if codecs_dir else None,
        "exists": bool(codecs_dir and codecs_dir.is_dir()),
        "bundles": [],
        "suspicious": [],
        "unknown": [],
        "has_zz": False,
    }
    if not codecs_dir or not codecs_dir.is_dir():
        return result
    allowed_roots = {"EasyAudioEncoder", ".device-id"}
    for entry in sorted(codecs_dir.iterdir()):
        if entry.is_dir() and CODEC_BUNDLE_RE.match(entry.name):
            files = [item.name for item in entry.iterdir() if item.is_file()]
            result["bundles"].append({"name": entry.name, "files": len(files)})
            for item in entry.iterdir():
                if not item.is_file() or item.suffix != ".so":
                    continue
                reasons = []
                if item.name.lower().startswith("zz"):
                    reasons.append("zz_so")
                elif not item.name.startswith("lib"):
                    reasons.append("unexpected_name")
                if deep and not reasons and _is_uniform_tail(item):
                    reasons.append("uniform_tail")
                if reasons:
                    result["suspicious"].append(
                        {"path": str(item), "reasons": reasons}
                    )
            continue
        if entry.is_dir() or entry.name in allowed_roots:
            continue
        if entry.name.endswith(".zip") or "license" in entry.name.lower():
            continue
        if entry.suffix == ".so":
            result["unknown"].append(str(entry))
            result["suspicious"].append(
                {"path": str(entry), "reasons": ["so_outside_bundle"]}
            )
            if entry.name.lower().startswith("zz"):
                result["has_zz"] = True
        elif entry.name.startswith("EasyAudioEncoder"):
            continue
        else:
            result["unknown"].append(str(entry))
    if any(
        item["path"].lower().split("/")[-1].startswith("zz")
        for item in result["suspicious"]
    ):
        result["has_zz"] = True
    return result


def _parse_log_date(line: str) -> str | None:
    match = PLEX_LOG_DATE_RE.match(line)
    if not match:
        return None
    try:
        parsed = datetime.strptime(match.group(1), "%b %d, %Y %H:%M:%S.%f")
        return parsed.replace(tzinfo=timezone.utc).isoformat()
    except ValueError:
        return match.group(1)


def scan_logs(logs_dir: Path | None) -> dict:
    result = {
        "path": str(logs_dir) if logs_dir else None,
        "files": 0,
        "attempts": 0,
        "blocked": 0,
        "success": 0,
        "sources": [],
        "last_seen": None,
        "suspicious": [],
        "samples": [],
        "attempts_detail": [],
        "lines": 0,
    }
    if not logs_dir or not logs_dir.is_dir():
        return result
    sources: set[str] = set()
    suspicious: list[str] = []
    samples: list[str] = []
    last_seen: str | None = None
    attempts = 0
    blocked = 0
    success = 0
    attempts_detail: list[dict] = []
    pending: dict[tuple[str, str], list[dict]] = {}
    files = sorted(logs_dir.glob("Plex Media Server*.log"))
    result["files"] = len(files)

    def normalize(path: str) -> str:
        return path.split("?", 1)[0]

    for path in files:
        try:
            handle = path.open("r", encoding="utf-8", errors="ignore")
        except OSError:
            continue
        with handle:
            for line in handle:
                result["lines"] += 1
                lowered = line.lower()
                request = PLEX_REQUEST_RE.search(line)
                if request:
                    source, _method, raw_path = request.groups()
                    normalized = normalize(raw_path)
                    malicious = any(
                        marker in lowered
                        for marker in ("poc_", "searchone", "sslip.io", "getresultfromnetwork")
                    )
                    if normalized.startswith("/player/timeline/subscribe") and "protocol=http" in lowered:
                        malicious = True
                    if malicious:
                        date = _parse_log_date(line)
                        entry = {
                            "source": source,
                            "path": normalized,
                            "timestamp": date,
                            "status": None,
                        }
                        attempts += 1
                        sources.add(source)
                        attempts_detail.append(entry)
                        pending.setdefault((source, normalized), []).append(entry)
                        if date:
                            last_seen = max(last_seen, date) if last_seen else date
                        if len(samples) < 20:
                            samples.append(redact(line.strip())[:500])
                        continue
                completed = PLEX_COMPLETED_RE.search(line)
                if completed:
                    source, status, raw_path = completed.groups()
                    normalized = normalize(raw_path)
                    entries = pending.get((source, normalized))
                    if entries:
                        entry = entries.pop(0)
                        if not entries:
                            pending.pop((source, normalized), None)
                        code = int(status)
                        entry["status"] = code
                        if code in (200, 201, 500, 502):
                            success += 1
                        elif code == 400:
                            blocked += 1
                        if len(samples) < 20:
                            samples.append(redact(line.strip())[:500])
                        continue
                if "dump-yuv" in lowered or "stats=" in lowered:
                    suspicious.append(redact(line.strip())[:400])
                if re.search(r"zz[0-9a-f]+\.so", lowered):
                    suspicious.append(redact(line.strip())[:400])
    result["attempts"] = attempts
    result["blocked"] = blocked
    result["success"] = success
    result["sources"] = sorted(sources)
    result["last_seen"] = last_seen
    result["suspicious"] = suspicious[:20]
    result["samples"] = samples[:20]
    result["attempts_detail"] = attempts_detail[:100]
    return result


def scan_traefik_log(
    path: Path | None, attempts_detail: list[dict]
) -> dict:
    result = {
        "path": str(path) if path else None,
        "available": bool(path and path.is_file()),
        "matching_requests": 0,
        "matched_sources": [],
        "samples": [],
    }
    if not path or not path.is_file():
        return result
    sources = sorted({item.get("source") for item in attempts_detail if item.get("source")})
    if not sources:
        return result
    patterns = [re.escape(source) for source in sources]
    patterns.extend([r"/player/timeline/subscribe", r"searchOne", r"sslip\.io"])
    regex = "|".join(patterns)
    try:
        process = subprocess.Popen(
            ["grep", "-a", "-E", regex, str(path)],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            errors="ignore",
        )
    except OSError:
        return result
    assert process.stdout is not None
    matched_sources: set[str] = set()
    samples: list[str] = []
    count = 0
    with process.stdout:
        for line in process.stdout:
            lowered = line.lower()
            if not any(source in line for source in sources):
                continue
            if not any(
                marker in lowered
                for marker in ("/player/timeline/subscribe", "searchone", "sslip.io")
            ):
                continue
            if "plex" not in lowered:
                continue
            count += 1
            if len(samples) < 10:
                samples.append(redact(line.strip())[:500])
            for source in sources:
                if source in line:
                    matched_sources.add(source)
    result["matching_requests"] = count
    result["matched_sources"] = sorted(matched_sources)
    result["samples"] = samples
    process.wait()
    return result


def scan_traefik_rules(rules_dir: Path | None) -> dict:
    """Controle les fichiers /rules de Traefik (allowlist, chain-plex)."""
    result = {
        "path": str(rules_dir) if rules_dir else None,
        "available": False,
        "chain_plex": None,
        "non_plex_chains": {},
        "allowlist_ips": [],
        "has_transport": False,
        "error": None,
    }
    if not rules_dir or not rules_dir.is_dir():
        return result
    middlewares_path = rules_dir / "middlewares.toml"
    chains_path = rules_dir / "middlewares-chains.toml"
    if not middlewares_path.is_file() or not chains_path.is_file():
        return result
    if tomllib is None:  # pragma: no cover - Python 3.10 sans tomli
        result["error"] = "module tomllib/tomli indisponible"
        return result
    try:
        middlewares_data = tomllib.loads(
            middlewares_path.read_text(encoding="utf-8")
        )
        chains_data = tomllib.loads(chains_path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        # tomllib.TOMLDecodeError derive de ValueError.
        result["error"] = str(exc)
        return result
    result["available"] = True
    http_middlewares = (middlewares_data.get("http") or {}).get("middlewares") or {}
    http_chains = (chains_data.get("http") or {}).get("middlewares") or {}
    result["has_transport"] = "plex-transport" in (
        (middlewares_data.get("http") or {}).get("serversTransports") or {}
    )
    allowlist = (
        (http_middlewares.get("middlewares-allowlist") or {}).get("ipAllowList")
        or {}
    )
    result["allowlist_ips"] = list(allowlist.get("sourceRange") or [])
    chain_plex = (http_chains.get("chain-plex") or {}).get("chain") or {}
    if "chain-plex" in http_chains:
        result["chain_plex"] = list(chain_plex.get("middlewares") or [])
    for name, spec in http_chains.items():
        if name == "chain-plex":
            continue
        middlewares = (spec.get("chain") or {}).get("middlewares") or []
        result["non_plex_chains"][name] = PLEX_ALLOWLIST_MIDDLEWARE in middlewares
    return result


def scan_traefik_token_leak(path: Path | None) -> dict:
    """Detecte des tokens Plex dans les URLs du log d'acces Traefik."""
    result = {
        "path": str(path) if path else None,
        "available": bool(path and path.is_file()),
        "matches": 0,
        "samples": [],
    }
    if not path or not path.is_file():
        return result
    try:
        process = subprocess.Popen(
            ["grep", "-a", "-i", "x-plex-token=", str(path)],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            errors="ignore",
        )
    except OSError:
        result["available"] = False
        return result
    assert process.stdout is not None
    with process.stdout:
        for line in process.stdout:
            result["matches"] += 1
            if len(result["samples"]) < 5:
                result["samples"].append(redact(line.strip())[:300])
    process.wait()
    return result


def compute_attack_path(plex_logs: dict, traefik_logs: dict) -> tuple[str, dict]:
    attempts = int(plex_logs.get("attempts") or 0)
    plex_sources = set(plex_logs.get("sources") or [])
    traefik_sources = set(traefik_logs.get("matched_sources") or [])
    matching = int(traefik_logs.get("matching_requests") or 0)
    if attempts == 0 and matching == 0:
        path = "none"
    elif attempts > 0 and matching == 0:
        path = "direct_32400"
    elif plex_sources & traefik_sources and (plex_sources - traefik_sources):
        path = "both"
    else:
        path = "traefik_443"
    return path, {
        "plex_logs": {
            "attempts": attempts,
            "blocked": int(plex_logs.get("blocked") or 0),
            "success": int(plex_logs.get("success") or 0),
            "sources": sorted(plex_sources),
            "last_seen": plex_logs.get("last_seen"),
        },
        "traefik_logs": {
            "matching_requests": matching,
            "matched_sources": sorted(traefik_sources),
        },
    }


# ---------------------------------------------------------------------------
# Hôte / ports / watchtower
# ---------------------------------------------------------------------------


def sudo_prefix() -> list[str] | None:
    if os.geteuid() == 0:
        return []
    if not shutil.which("sudo"):
        return None
    try:
        result = run_cmd(["sudo", "-n", "true"], timeout=5)
    except ToolError:
        return None
    return ["sudo"] if result.returncode == 0 else None


def host_firewall() -> dict:
    result = {"ufw": "unknown", "docker_user": "unknown", "docker_user_rules": 0}
    sudo = sudo_prefix()
    prefix = sudo or []
    try:
        ufw = run_cmd([*prefix, "ufw", "status"], timeout=10)
        if ufw.returncode == 0:
            first = ufw.stdout.splitlines()[0] if ufw.stdout else ""
            result["ufw"] = "active" if "active" in first.lower() else "inactive"
    except ToolError:
        pass
    try:
        rules = run_cmd([*prefix, "iptables", "-S", "DOCKER-USER"], timeout=10)
        if rules.returncode == 0:
            lines = [line for line in rules.stdout.splitlines() if line.startswith("-A")]
            result["docker_user_rules"] = len(lines)
            result["docker_user"] = "configured" if lines else "empty"
    except ToolError:
        pass
    return result


def published_ports() -> list[dict]:
    result = run_cmd(
        ["docker", "ps", "--format", "{{.Names}}\t{{.Ports}}"], timeout=30
    )
    if result.returncode != 0:
        return []
    ports: list[dict] = []
    for line in result.stdout.splitlines():
        name, _, raw = line.partition("\t")
        for match in PUBLISHED_PORT_RE.finditer(raw):
            ports.append(
                {
                    "name": name,
                    "host_ip": match.group(0).split(":")[0],
                    "host_port": int(match.group(1)),
                    "container_port": int(match.group(2)),
                    "protocol": match.group(3),
                }
            )
    return ports


def watchtower_info() -> dict:
    names = docker_names()
    if "watchtower" not in names:
        return {"present": False, "cleanup": False, "schedule": None}
    try:
        attrs = inspect_container("watchtower")
    except ToolError:
        return {"present": True, "cleanup": False, "schedule": None}
    cmd = (attrs.get("Config") or {}).get("Cmd") or []
    text = " ".join(str(item) for item in cmd)
    return {
        "present": True,
        "cleanup": "--cleanup" in text,
        "schedule": text,
    }


def other_exposed_ports(ports: list[dict]) -> list[dict]:
    result = []
    for port in ports:
        if port["host_port"] in ALLOWED_HOST_PORTS:
            continue
        if port["host_port"] == PLEX_PORT:
            continue
        result.append(port)
    return result


# ---------------------------------------------------------------------------
# Médias / préférences
# ---------------------------------------------------------------------------


def detect_media_paths(db_path: Path | None) -> list[str]:
    if not db_path or not db_path.is_file():
        return []
    uri = f"file:{db_path}?mode=ro"
    try:
        connection = sqlite3.connect(uri, uri=True, timeout=5)
    except sqlite3.Error:
        return []
    try:
        cursor = connection.execute("SELECT root_path FROM section_locations")
        return [str(row[0]) for row in cursor.fetchall() if row and row[0]]
    except sqlite3.Error:
        return []
    finally:
        connection.close()


def map_media_paths(paths: list[str], home: Path) -> tuple[list[str], list[str]]:
    mounts: set[str] = set()
    warnings: list[str] = []
    home_text = str(home)
    for raw in paths:
        path = Path(raw)
        if not raw:
            continue
        if raw == home_text:
            mounts.add(f"{home_text}:{home_text}:ro")
            warnings.append(
                f"bibliotheque a la racine de {home_text} : montage complet en lecture seule"
            )
            continue
        if raw.startswith(home_text + "/"):
            relative = Path(raw).relative_to(home)
            top = home / relative.parts[0]
            mounts.add(f"{top}:{top}:ro")
            continue
        if raw.startswith("/mnt/"):
            mounts.add("/mnt:/mnt:ro")
            continue
        if raw.startswith("/media/") or raw.startswith("/data/"):
            top = "/" + raw.split("/")[1]
            mounts.add(f"{top}:{top}:ro")
            continue
        if path.is_dir():
            mounts.add(f"{raw}:{raw}:ro")
            continue
        warnings.append(f"chemin de bibliotheque introuvable ou non monte: {raw}")
    return sorted(mounts), warnings


def _mount_root_for(target: str, home: Path) -> str:
    target = os.path.normpath(target)
    current = target
    while current not in ("/", ""):
        if os.path.ismount(current):
            return current
        current = os.path.dirname(current)
    home_text = str(home)
    if target.startswith(home_text + "/"):
        relative = target[len(home_text) + 1 :].split("/")
        if relative:
            return os.path.join(home_text, relative[0])
        return home_text
    if target.startswith("/mnt/"):
        parts = target.split("/")
        return "/" + "/".join(parts[1:4]) if len(parts) >= 4 else "/mnt"
    if target.startswith("/data/"):
        return "/data"
    parts = target.split("/")
    return "/" + "/".join(parts[1:4]) if len(parts) >= 4 else target


def detect_symlink_targets(
    media_roots: list[str],
    container_mounts: list[dict],
    max_symlinks: int = 50000,
) -> dict:
    """Detecte les cibles de symlinks et verifie si elles sont montees.

    Les bibliotheques Plex contiennent souvent des symlinks vers /mnt (FUSE
    decypharr, rclone...). Si la cible n'est pas couverte par un montage du
    conteneur, la lecture echoue avec « fichier introuvable ».
    """
    targets: dict[str, dict] = {}
    scanned = 0
    home = Path.home()
    for root in media_roots:
        if not root or not os.path.isdir(root):
            continue
        for dirpath, dirnames, filenames in os.walk(root, followlinks=False):
            for name in list(dirnames) + list(filenames):
                path = os.path.join(dirpath, name)
                if not os.path.islink(path):
                    continue
                try:
                    target = os.readlink(path)
                except OSError:
                    continue
                if not os.path.isabs(target):
                    target = os.path.join(dirpath, target)
                target = os.path.normpath(target)
                mount_root = _mount_root_for(target, home)
                entry = targets.setdefault(
                    mount_root,
                    {"root": mount_root, "count": 0, "example": target, "visible": False},
                )
                entry["count"] += 1
                scanned += 1
                if scanned >= max_symlinks:
                    break
            if scanned >= max_symlinks:
                break
        if scanned >= max_symlinks:
            break
    destinations = [
        str(mount.get("Destination"))
        for mount in container_mounts
        if mount.get("Destination")
    ]
    for entry in targets.values():
        root = entry["root"]
        entry["visible"] = any(
            root == destination
            or root.startswith(destination.rstrip("/") + "/")
            for destination in destinations
        )
    ordered = sorted(targets.values(), key=lambda item: (-item["count"], item["root"]))
    return {
        "scanned_symlinks": scanned,
        "targets": ordered,
        "unmounted": sorted(
            entry["root"] for entry in ordered if not entry["visible"]
        ),
    }


def fix_preferences(path: Path | None) -> dict:
    if not path or not path.is_file():
        return {"ok": False, "message": "Preferences.xml introuvable"}
    try:
        tree = ET.parse(path)
    except (ET.ParseError, OSError) as exc:
        return {"ok": False, "message": f"Preferences.xml illisible: {exc}"}
    root = tree.getroot()
    value = root.get("TranscoderH264Options")
    if value is None:
        return {"ok": True, "changed": False, "message": "option absente"}
    if value and "dump-yuv" not in value.lower() and "stats=" not in value.lower():
        return {"ok": True, "changed": False, "message": "option non suspecte"}
    backup = path.with_name(
        f"{path.name}.bak-{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')}"
    )
    shutil.copy2(path, backup)
    try:
        os.chmod(backup, 0o600)
    except OSError:
        pass
    root.attrib.pop("TranscoderH264Options", None)
    tree.write(path, encoding="UTF-8", xml_declaration=True)
    try:
        ET.parse(path)
    except ET.ParseError as exc:
        shutil.copy2(backup, path)
        return {"ok": False, "message": f"XML invalide apres correction, restaure: {exc}"}
    return {
        "ok": True,
        "changed": True,
        "backup": str(backup),
        "old_value": redact(value)[:200],
    }


# ---------------------------------------------------------------------------
# Scan principal
# ---------------------------------------------------------------------------


def _load_fixture(fixture: Path) -> dict:
    container = json.loads((fixture / "container.json").read_text(encoding="utf-8"))
    if isinstance(container, list):
        container = container[0]
    host = {}
    host_path = fixture / "host.json"
    if host_path.is_file():
        host = json.loads(host_path.read_text(encoding="utf-8"))
    media = fixture / "Medias"
    return {
        "attrs": container,
        "preferences": fixture / "Preferences.xml",
        "codecs": fixture / "Codecs",
        "logs": fixture / "Logs",
        "traefik_log": fixture / "traefik.log",
        "traefik_rules": fixture / "traefik-rules",
        "host": host,
        "media_roots": [str(media)] if media.is_dir() else [],
    }


def _recommendations(
    issues: list[dict],
    status: str,
    compromised: bool,
    vulnerable: bool,
) -> list[str]:
    codes = {issue.get("code") for issue in issues}
    recommendations: list[str] = []
    if compromised:
        return [
            "IoC detecte : ne pas nettoyer. Utiliser l'option 5 (quarantaine), "
            "rotation des secrets et restauration."
        ]
    if vulnerable:
        recommendations.append("Mettre a jour Plex >= 1.43.3.10861 (option 2).")
    if "version_env_missing" in codes:
        recommendations.append("Ajouter VERSION=latest (option 2).")
    if "port_32400_public" in codes:
        recommendations.append("Retirer la publication 0.0.0.0:32400 (option 2 ou 3).")
    if "traefik_no_middleware" in codes:
        recommendations.append("Ajouter chain-no-auth@file sur la route Plex 443 (option 2).")
    if any(code.startswith("mount_") for code in codes):
        recommendations.append("Retirer les montages $HOME, /tmp et /dev/shm (option 2).")
    if "cap_drop_missing" in codes or "no_new_privileges_missing" in codes:
        recommendations.append("Ajouter no-new-privileges et les capabilities Plex (option 2).")
    if "transcoder_options_suspicious" in codes:
        recommendations.append("Nettoyer TranscoderH264Options (option 2) et verifier les secrets.")
    if "remote_access_insecure_fallback" in codes or "remote_access_manual_32400" in codes:
        recommendations.append(
            "Acces distant : garder customConnections HTTPS uniquement et "
            "desactiver le port manuel 32400 (fix-remote / option 2)."
        )
    if "traefik_plex_chain_missing" in codes:
        recommendations.append(
            "Mode public HTTPS : router Plex avec chain-plex@file (option 9)."
        )
    if "traefik_plex_backend_not_https" in codes or "traefik_plex_transport_missing" in codes:
        recommendations.append(
            "Mode public HTTPS : backend Plex scheme=https + "
            "serverstransport=plex-transport@file (option 9)."
        )
    if "traefik_allowlist_missing" in codes or "traefik_allowlist_on_plex" in codes:
        recommendations.append(
            "Mode public HTTPS : allowlist Cloudflare sur les chaines "
            "non-Plex, absente de chain-plex (option 9)."
        )
    if "traefik_rules_missing" in codes or "traefik_rules_unreadable" in codes:
        recommendations.append(
            "Regenerer les regles Traefik (option 9 ou reinstallation Traefik)."
        )
    if "plex_secure_connections_not_required" in codes:
        recommendations.append(
            "Mode public HTTPS : secureConnections=0 (Required)."
        )
    if "plex_relay_enabled" in codes:
        recommendations.append("Mode public HTTPS : desactiver Plex Relay.")
    if "plex_publish_disabled" in codes:
        recommendations.append(
            "Mode public HTTPS : PublishServerOnPlexOnlineKey=1."
        )
    if "plex_custom_url_has_port" in codes:
        recommendations.append(
            "customConnections doit etre https://plex.<domaine> sans :443."
        )
    if "plex_manual_port_not_zero" in codes:
        recommendations.append(
            "Mode public HTTPS : ManualPortMappingPort=0."
        )
    if "plex_loopback_port_missing" in codes:
        recommendations.append(
            "Mode public HTTPS : publier 32400 sur 127.0.0.1 uniquement."
        )
    if "plex_token_in_traefik_log" in codes:
        recommendations.append(
            "Token Plex dans access.log : restreindre les droits du log, "
            "le rotationner et eviter les tokens en query string."
        )
    if "symlink_target_not_mounted" in codes:
        recommendations.append(
            "Monter les cibles de symlinks en lecture seule : /mnt en mode "
            "generique (option 2) ou les cibles specifiques en mode strict."
        )
    if "other_port_published" in codes:
        recommendations.append(
            "Fermer les autres ports publies (option 3) ou les passer derriere Traefik avec auth."
        )
    if "watchtower_cleanup" in codes:
        recommendations.append(
            "Watchtower --cleanup : desactiver --cleanup ou le remplacer ; "
            "les images de rollback sont supprimees."
        )
    if not recommendations:
        recommendations.append("Aucune action requise. Continuer a surveiller les logs et les mises a jour.")
    return recommendations


def _analyze(
    attrs: dict,
    preferences: Path | None,
    codecs_dir: Path | None,
    logs_dir: Path | None,
    traefik_log: Path | None,
    host: dict,
    deep: bool = False,
    media_roots: list[str] | None = None,
    traefik_rules_dir: Path | None = None,
) -> dict:
    version_env = env_dict(attrs).get("VERSION")
    image = (attrs.get("Config") or {}).get("Image") or ""
    labels = labels_dict(attrs)
    label_version = (
        labels.get("org.opencontainers.image.version")
        or labels.get("build_version")
    )
    version = parse_version(label_version)
    version_source = "label" if version else "unknown"
    ports = scan_ports(attrs)
    mounts = scan_mounts(attrs, Path.home())
    security = scan_security(attrs)
    traefik = scan_traefik(attrs)
    preferences_data = scan_preferences(preferences)
    codecs = scan_codecs(codecs_dir, deep=deep)
    symlink_targets = detect_symlink_targets(
        media_roots or [],
        attrs.get("Mounts") or [],
    )
    logs = scan_logs(logs_dir)
    traefik_logs = scan_traefik_log(traefik_log, logs.get("attempts_detail", []))
    attack_path, evidence = compute_attack_path(logs, traefik_logs)
    traefik_rules = scan_traefik_rules(traefik_rules_dir)
    token_leak = scan_traefik_token_leak(traefik_log)
    evidence["traefik_token_leak"] = token_leak
    plex_ports = [port for port in ports if str(port["container_port"]).startswith(str(PLEX_PORT))]
    issues: list[dict] = []
    compromised_reasons: list[str] = []
    public_https = bool(
        traefik.get("public_https")
        or traefik_rules.get("chain_plex")
        or traefik_rules.get("allowlist_ips")
    )

    if version_status(version) == "vulnerable":
        issues.append(
            {
                "code": "version_vulnerable",
                "severity": "critical",
                "message": f"Plex {version_str(version)} < 1.43.3.10861",
            }
        )
    elif version is None:
        issues.append(
            {
                "code": "version_unknown",
                "severity": "warning",
                "message": "version Plex inconnue",
            }
        )

    if not version_env:
        issues.append(
            {
                "code": "version_env_missing",
                "severity": "warning",
                "message": "VERSION absent : PMS peut rester fige",
            }
        )

    if any(port["host_ip"] in ("0.0.0.0", "::", "") for port in plex_ports):
        issues.append(
            {
                "code": "port_32400_public",
                "severity": "critical",
                "message": "32400 publie sur 0.0.0.0",
            }
        )

    if not traefik.get("has_middleware"):
        issues.append(
            {
                "code": "traefik_no_middleware",
                "severity": "high",
                "message": "routeur Plex sans CrowdSec/WAF",
            }
        )

    for mount in mounts:
        for danger in mount.get("dangers") or []:
            issues.append(
                {
                    "code": f"mount_{danger}",
                    "severity": "high",
                    "message": f"montage dangereux: {mount['source']} -> {mount['destination']}",
                }
            )

    if not security.get("no_new_privileges"):
        issues.append(
            {
                "code": "no_new_privileges_missing",
                "severity": "medium",
                "message": "no-new-privileges absent",
            }
        )
    if not security.get("cap_drop_all"):
        issues.append(
            {
                "code": "cap_drop_missing",
                "severity": "medium",
                "message": "cap_drop ALL absent",
            }
        )

    options = preferences_data.get("transcoder_h264_options")
    if options is not None:
        lowered = str(options).lower()
        if "dump-yuv" in lowered or "stats=" in lowered:
            compromised_reasons.append("TranscoderH264Options suspect")
            issues.append(
                {
                    "code": "transcoder_options_suspicious",
                    "severity": "critical",
                    "message": "TranscoderH264Options contient dump-yuv/stats",
                }
            )
        elif options == "":
            issues.append(
                {
                    "code": "transcoder_options_empty",
                    "severity": "warning",
                    "message": "TranscoderH264Options vide (nettoyage PoC possible)",
                }
            )

    custom_connections = str(
        preferences_data.get("custom_connections") or ""
    ).lower()
    if "http://" in custom_connections or ":32400" in custom_connections:
        issues.append(
            {
                "code": "remote_access_insecure_fallback",
                "severity": "medium",
                "message": (
                    "customConnections contient une URL HTTP ou le port 32400 "
                    "alors que 32400 est ferme"
                ),
            }
        )
    manual_mode = str(preferences_data.get("manual_port_mapping_mode") or "")
    manual_port = str(preferences_data.get("manual_port_mapping_port") or "")
    if manual_mode == "1" and manual_port in ("32400", ""):
        issues.append(
            {
                "code": "remote_access_manual_32400",
                "severity": "medium",
                "message": (
                    "port public manuel 32400 configure alors que 32400 est ferme"
                ),
            }
        )

    if public_https:
        if not traefik.get("chain_plex"):
            issues.append(
                {
                    "code": "traefik_plex_chain_missing",
                    "severity": "high",
                    "message": "mode public HTTPS : Plex n'utilise pas chain-plex@file",
                }
            )
        if traefik.get("scheme") != "https":
            issues.append(
                {
                    "code": "traefik_plex_backend_not_https",
                    "severity": "high",
                    "message": "mode public HTTPS : backend Plex en HTTP",
                }
            )
        if str(traefik.get("serverstransport") or "") != PLEX_TRANSPORT:
            issues.append(
                {
                    "code": "traefik_plex_transport_missing",
                    "severity": "high",
                    "message": "mode public HTTPS : serverstransport plex-transport@file absent",
                }
            )
        if str(traefik.get("entrypoints") or "") not in ("https", ""):
            issues.append(
                {
                    "code": "traefik_plex_entrypoint_not_https",
                    "severity": "medium",
                    "message": "mode public HTTPS : entrypoint Plex non limite a https",
                }
            )
        if str(preferences_data.get("secure_connections") or "") != "0":
            issues.append(
                {
                    "code": "plex_secure_connections_not_required",
                    "severity": "high",
                    "message": "mode public HTTPS : secureConnections != Required (0)",
                }
            )
        if str(preferences_data.get("relay_enabled") or "") == "1":
            issues.append(
                {
                    "code": "plex_relay_enabled",
                    "severity": "medium",
                    "message": "mode public HTTPS : Plex Relay actif",
                }
            )
        if str(
            preferences_data.get("publish_server_on_plex_online_key") or ""
        ) != "1":
            issues.append(
                {
                    "code": "plex_publish_disabled",
                    "severity": "medium",
                    "message": "mode public HTTPS : publication Plex Online desactivee",
                }
            )
        custom_url = str(preferences_data.get("custom_connections") or "")
        if ":443" in custom_url or ":32400" in custom_url:
            issues.append(
                {
                    "code": "plex_custom_url_has_port",
                    "severity": "medium",
                    "message": "mode public HTTPS : customConnections contient un port",
                }
            )
        if str(preferences_data.get("manual_port_mapping_port") or "") not in ("", "0"):
            issues.append(
                {
                    "code": "plex_manual_port_not_zero",
                    "severity": "low",
                    "message": "mode public HTTPS : ManualPortMappingPort != 0",
                }
            )
        if not any(
            str(port.get("host_ip") or "") == "127.0.0.1" for port in plex_ports
        ):
            issues.append(
                {
                    "code": "plex_loopback_port_missing",
                    "severity": "medium",
                    "message": "mode public HTTPS : 32400 non publie sur 127.0.0.1",
                }
            )

        if traefik_rules.get("error"):
            issues.append(
                {
                    "code": "traefik_rules_unreadable",
                    "severity": "medium",
                    "message": (
                        "regles Traefik illisibles : "
                        + str(traefik_rules.get("error"))[:200]
                    ),
                }
            )
        elif not traefik_rules.get("available"):
            issues.append(
                {
                    "code": "traefik_rules_missing",
                    "severity": "medium",
                    "message": "fichiers /rules Traefik introuvables",
                }
            )
        if traefik_rules.get("available"):
            chain_plex = traefik_rules.get("chain_plex")
            if not chain_plex:
                issues.append(
                    {
                        "code": "traefik_chain_plex_missing",
                        "severity": "high",
                        "message": "fichier Traefik : chain-plex absente",
                    }
                )
            elif PLEX_ALLOWLIST_MIDDLEWARE in chain_plex:
                issues.append(
                    {
                        "code": "traefik_allowlist_on_plex",
                        "severity": "high",
                        "message": "fichier Traefik : allowlist presente sur chain-plex",
                    }
                )
            missing_chains = sorted(
                name
                for name, allowed in (traefik_rules.get("non_plex_chains") or {}).items()
                if not allowed
            )
            if missing_chains:
                issues.append(
                    {
                        "code": "traefik_allowlist_missing",
                        "severity": "high",
                        "message": (
                            "fichier Traefik : allowlist absente de "
                            + ", ".join(missing_chains)
                        ),
                    }
                )
            allowlist_ips = set(traefik_rules.get("allowlist_ips") or [])
            if allowlist_ips and not any(
                ip in allowlist_ips for ip in CLOUDFLARE_SAMPLE_IPS
            ):
                issues.append(
                    {
                        "code": "traefik_allowlist_cloudflare_missing",
                        "severity": "high",
                        "message": "fichier Traefik : allowlist sans CIDR Cloudflare",
                    }
                )
            if not traefik_rules.get("has_transport"):
                issues.append(
                    {
                        "code": "traefik_rules_transport_missing",
                        "severity": "high",
                        "message": "fichier Traefik : serversTransports plex-transport absent",
                    }
                )

    if token_leak.get("matches"):
        issues.append(
            {
                "code": "plex_token_in_traefik_log",
                "severity": "medium",
                "message": (
                    f"{token_leak['matches']} token(s) Plex dans le log d'acces Traefik"
                ),
            }
        )

    if codecs.get("has_zz"):
        compromised_reasons.append("Codecs/zz*.so")
    for item in codecs.get("suspicious") or []:
        if "so_outside_bundle" in item.get("reasons", []):
            compromised_reasons.append(f".so hors bundle: {item['path']}")
        if "uniform_tail" in item.get("reasons", []):
            compromised_reasons.append(f".so avec queue uniforme: {item['path']}")

    for root in symlink_targets.get("unmounted") or []:
        issues.append(
            {
                "code": "symlink_target_not_mounted",
                "severity": "high",
                "message": f"cible de symlink non montee: {root}",
            }
        )

    if logs.get("success"):
        compromised_reasons.append("tentative Plex2Shell avec code 2xx/5xx")
    if logs.get("suspicious"):
        compromised_reasons.append("motifs suspects dans les logs Plex")

    if compromised_reasons:
        issues.append(
            {
                "code": "compromised",
                "severity": "critical",
                "message": "IoC détecté: " + "; ".join(sorted(set(compromised_reasons))),
            }
        )

    exposed = other_exposed_ports(host.get("published_ports") or [])
    for port in exposed:
        issues.append(
            {
                "code": "other_port_published",
                "severity": "medium",
                "message": f"{port['name']} publie {port['host_ip']}:{port['host_port']}",
            }
        )

    if host.get("watchtower", {}).get("cleanup"):
        issues.append(
            {
                "code": "watchtower_cleanup",
                "severity": "medium",
                "message": "Watchtower --cleanup supprime les images de rollback",
            }
        )

    if compromised_reasons:
        status = "compromised"
    elif version_status(version) == "vulnerable":
        status = "vulnerable"
    elif issues:
        status = "hardening_required"
    else:
        status = "ok"

    return {
        "container": {
            "name": PLEX_NAME,
            "image": image,
            "image_id": attrs.get("Image"),
            "version": version_str(version),
            "version_status": version_status(version),
            "version_source": version_source,
            "version_env": version_env,
            "ports": plex_ports,
            "all_ports": ports,
            "mounts": mounts,
            "security": security,
            "traefik": traefik,
            "traefik_rules": traefik_rules,
            "token_leak": token_leak,
            "preferences": preferences_data,
            "codecs": codecs,
            "symlink_targets": symlink_targets,
            "logs": logs,
            "public_https": public_https,
        },
        "public_https": public_https,
        "attack_path": attack_path,
        "evidence": evidence,
        "host": host,
        "other_exposed_ports": exposed,
        "summary": {
            "status": status,
            "ok": status == "ok",
            "compromised": bool(compromised_reasons),
            "vulnerable": version_status(version) == "vulnerable",
            "hardening_required": status == "hardening_required",
            "public_https": public_https,
            "plex_conform": not (
                {issue.get("code") for issue in issues}
                - {"other_port_published", "watchtower_cleanup"}
            ),
            "recommendations": _recommendations(
                issues,
                status,
                bool(compromised_reasons),
                version_status(version) == "vulnerable",
            ),
            "issues": issues,
            "issue_count": len(issues),
        },
    }


def build_scan(
    deep: bool = False,
    fixture: Path | None = None,
    traefik_log: Path | None = None,
) -> dict:
    if fixture:
        data = _load_fixture(fixture)
        host = data["host"]
        host.setdefault("ufw", "unknown")
        host.setdefault("docker_user", "unknown")
        host.setdefault("docker_user_rules", 0)
        host.setdefault("published_ports", [])
        host.setdefault("watchtower", {"present": False, "cleanup": False, "schedule": None})
        payload = _analyze(
            data["attrs"],
            data["preferences"],
            data["codecs"],
            data["logs"],
            data["traefik_log"],
            host,
            deep=deep,
            media_roots=data.get("media_roots") or [],
            traefik_rules_dir=data.get("traefik_rules"),
        )
        payload["schema"] = SCHEMA_VERSION
        payload["version"] = VERSION
        payload["generated_at"] = now_iso()
        payload["cves"] = list(CVE_IDS)
        return payload

    name = find_plex_container()
    if not name:
        raise ToolError("conteneur Plex introuvable")
    attrs = inspect_container(name)
    paths = plex_paths(attrs)
    identity = plex_identity(attrs, name)
    identity_version = parse_version(identity)
    if identity_version:
        labels = labels_dict(attrs)
        labels["org.opencontainers.image.version"] = version_str(identity_version)
        attrs.setdefault("Config", {})["Labels"] = labels
    host = {
        **host_firewall(),
        "published_ports": published_ports(),
        "watchtower": watchtower_info(),
    }
    _, storage = settings_paths()
    log_path = traefik_log
    if log_path is None:
        log_path = storage / DEFAULT_TRAEFIK_LOG
    rules_dir = storage / DEFAULT_TRAEFIK_RULES
    media_roots = detect_media_paths(paths.get("db"))
    for default_root in (Path.home() / "Medias", Path.home() / "local"):
        if default_root.is_dir() and str(default_root) not in media_roots:
            media_roots.append(str(default_root))
    payload = _analyze(
        attrs,
        paths.get("preferences"),
        paths.get("codecs"),
        paths.get("logs"),
        log_path,
        host,
        deep=deep,
        media_roots=media_roots,
        traefik_rules_dir=rules_dir,
    )
    payload["schema"] = SCHEMA_VERSION
    payload["version"] = VERSION
    payload["generated_at"] = now_iso()
    payload["cves"] = list(CVE_IDS)
    payload["plex_paths"] = {key: str(value) if value else None for key, value in paths.items()}
    payload["container"]["name"] = name
    return payload


def status_payload(payload: dict) -> dict:
    return {
        "schema": payload.get("schema", SCHEMA_VERSION),
        "version": payload.get("version", VERSION),
        "generated_at": payload.get("generated_at"),
        "cves": payload.get("cves", list(CVE_IDS)),
        "attack_path": payload.get("attack_path"),
        "container": {
            "name": payload.get("container", {}).get("name"),
            "version": payload.get("container", {}).get("version"),
            "version_status": payload.get("container", {}).get("version_status"),
            "version_env": payload.get("container", {}).get("version_env"),
            "ports": payload.get("container", {}).get("ports"),
            "traefik": payload.get("container", {}).get("traefik"),
            "traefik_rules": payload.get("container", {}).get("traefik_rules"),
            "token_leak": payload.get("container", {}).get("token_leak"),
            "public_https": payload.get("container", {}).get("public_https"),
            "security": payload.get("container", {}).get("security"),
            "mounts": payload.get("container", {}).get("mounts"),
            "preferences": payload.get("container", {}).get("preferences"),
            "codecs": payload.get("container", {}).get("codecs"),
            "symlink_targets": payload.get("container", {}).get("symlink_targets"),
            "logs": payload.get("container", {}).get("logs"),
        },
        "host": payload.get("host"),
        "other_exposed_ports": payload.get("other_exposed_ports"),
        "evidence": payload.get("evidence"),
        "summary": payload.get("summary"),
    }


def report_text(payload: dict) -> str:
    plex = payload.get("container", {})
    summary = payload.get("summary", {})
    lines = [
        "PLEX2SHELL - CVE-2026-96652 / 96654 / 96655 / 96656",
        "=" * 68,
        f"Statut : {str(summary.get('status') or 'inconnu').upper()}",
        f"Plex conforme : {'oui' if summary.get('plex_conform') else 'non'}",
        f"Version : {plex.get('version') or '?'} ({plex.get('version_status')})",
        f"VERSION env : {plex.get('version_env') or 'absent'}",
        f"Mode public HTTPS : {'oui' if plex.get('public_https') else 'non'}",
        f"Chemin d'attaque : {payload.get('attack_path') or 'inconnu'}",
        "",
        "Reseau :",
    ]
    ports = plex.get("ports") or []
    if not ports:
        lines.append("  aucun port 32400 publie")
    for port in ports:
        lines.append(
            f"  {port.get('host_ip')}:{port.get('host_port')} -> {port.get('container_port')}"
        )
    traefik = plex.get("traefik") or {}
    lines.append(
        f"  middleware Traefik : {traefik.get('middlewares') or 'ABSENT'}"
    )
    lines.append(
        "  backend : "
        f"scheme={traefik.get('scheme') or '?'} "
        f"transport={traefik.get('serverstransport') or 'aucun'} "
        f"entrypoints={traefik.get('entrypoints') or '?'}"
    )
    rules = plex.get("traefik_rules") or {}
    if rules.get("available"):
        lines.append(
            "  regles : "
            f"chain-plex={'oui' if rules.get('chain_plex') is not None else 'non'} "
            f"allowlist={'oui' if any((rules.get('non_plex_chains') or {}).values()) else 'non'} "
            f"transport={'oui' if rules.get('has_transport') else 'non'}"
        )
    lines.append("")
    lines.append("Montages :")
    for mount in plex.get("mounts") or []:
        flag = ",".join(mount.get("dangers") or []) or "ok"
        mode = "rw" if mount.get("rw") else "ro"
        lines.append(
            f"  {mount.get('source')} -> {mount.get('destination')} ({mode}) [{flag}]"
        )
    security = plex.get("security") or {}
    lines.append("")
    lines.append(
        "Securite : no-new-privileges="
        f"{security.get('no_new_privileges')} cap_drop_all={security.get('cap_drop_all')} "
        f"read_only={security.get('read_only')}"
    )
    preferences = plex.get("preferences") or {}
    lines.append("")
    lines.append("Preferences.xml :")
    lines.append(
        "  TranscoderH264Options="
        f"{preferences.get('transcoder_h264_options')!r} "
        f"(token={preferences.get('has_token')})"
    )
    lines.append(
        "  customConnections="
        f"{preferences.get('custom_connections')!r} "
        f"manual_mode={preferences.get('manual_port_mapping_mode')!r} "
        f"manual_port={preferences.get('manual_port_mapping_port')!r}"
    )
    lines.append(
        "  secure_connections="
        f"{preferences.get('secure_connections')!r} "
        f"relay={preferences.get('relay_enabled')!r} "
        f"publish={preferences.get('publish_server_on_plex_online_key')!r}"
    )
    token_leak = plex.get("token_leak") or {}
    lines.append(
        f"  Tokens Plex dans access.log : {token_leak.get('matches', 0)}"
    )
    codecs = plex.get("codecs") or {}
    lines.append("")
    lines.append(
        f"Codecs : {len(codecs.get('suspicious') or [])} suspect(s), "
        f"zz={codecs.get('has_zz')}"
    )
    for item in codecs.get("suspicious") or []:
        lines.append(f"  - {item.get('path')} ({','.join(item.get('reasons') or [])})")
    logs = plex.get("logs") or {}
    lines.append("")
    lines.append(
        f"Logs Plex : {logs.get('attempts', 0)} tentative(s), "
        f"{logs.get('blocked', 0)} bloquee(s), {logs.get('success', 0)} succes"
    )
    if logs.get("sources"):
        lines.append("  sources : " + ", ".join(logs.get("sources") or []))
    if logs.get("last_seen"):
        lines.append(f"  derniere : {logs.get('last_seen')}")
    evidence = payload.get("evidence") or {}
    traefik_evidence = evidence.get("traefik_logs") or {}
    lines.append(
        f"  Traefik : {traefik_evidence.get('matching_requests', 0)} requete(s) "
        "correspondante(s)"
    )
    host = payload.get("host") or {}
    lines.append("")
    lines.append(
        f"Firewall : UFW={host.get('ufw')} DOCKER-USER={host.get('docker_user')} "
        f"({host.get('docker_user_rules', 0)} regle(s))"
    )
    watchtower = host.get("watchtower") or {}
    lines.append(
        f"Watchtower : present={watchtower.get('present')} cleanup={watchtower.get('cleanup')}"
    )
    exposed = payload.get("other_exposed_ports") or []
    if exposed:
        lines.append("")
        lines.append("Autres ports publies :")
        for port in exposed:
            lines.append(
                f"  - {port.get('name')} {port.get('host_ip')}:{port.get('host_port')}"
            )
    symlinks = plex.get("symlink_targets") or {}
    lines.append("")
    lines.append(
        f"Cibles de symlinks : {symlinks.get('scanned_symlinks', 0)} symlink(s)"
    )
    symlink_targets = symlinks.get("targets") or []
    if symlink_targets:
        for target in symlink_targets:
            visible = "visible" if target.get("visible") else "NON MONTEE"
            lines.append(
                f"  - {target.get('root')} ({target.get('count', 0)}) [{visible}]"
            )
    else:
        lines.append("  aucune")
    lines.append("")
    lines.append("Problemes :")
    for issue in summary.get("issues") or []:
        lines.append(f"  - [{issue.get('severity')}] {issue.get('message')}")
    if not summary.get("issues"):
        lines.append("  aucun")
    lines.append("")
    lines.append("Recommandations :")
    recommendations = summary.get("recommendations") or []
    if recommendations:
        for recommendation in recommendations:
            lines.append(f"  -> {recommendation}")
    else:
        lines.append("  -> Aucune action requise.")
    lines.append("")
    if summary.get("compromised"):
        lines.append(
            "Rappel : IoC detecte. Ne pas nettoyer a l'aveugle ; option 5 "
            "(quarantaine), rotation des secrets et restauration."
        )
    elif summary.get("plex_conform"):
        lines.append(
            "Rappel : Plex est conforme. Traiter les points restants ci-dessus "
            "(ports publies, Watchtower, etc.)."
        )
    else:
        lines.append(
            "Rappel : les tentatives Plex2Shell sont pre-authentification. "
            "Mettre a jour, fermer 32400 et ajouter le middleware 443."
        )
    return "\n".join(lines)


def logs_text(data: dict) -> str:
    logs = data.get("logs") or {}
    evidence = data.get("evidence") or {}
    traefik = evidence.get("traefik_logs") or {}
    lines = [
        "PLEX2SHELL - Analyse des logs Plex",
        "=" * 40,
        f"Chemin d'attaque : {data.get('attack_path') or 'inconnu'}",
        f"Tentatives : {logs.get('attempts', 0)}",
        f"Bloquees : {logs.get('blocked', 0)}",
        f"Succes : {logs.get('success', 0)}",
        f"Derniere : {logs.get('last_seen') or 'n/a'}",
    ]
    if logs.get("sources"):
        lines.append("Sources : " + ", ".join(logs.get("sources") or []))
    lines.append(
        f"Traefik : {traefik.get('matching_requests', 0)} requete(s) correspondante(s)"
    )
    for sample in logs.get("samples") or []:
        lines.append(f"  | {sample}")
    return "\n".join(lines)


def action_text(payload: dict) -> str:
    lines = [
        f"Action : {payload.get('action') or 'plex-cve'}",
        f"Resultat : {'OK' if payload.get('ok') else 'ECHEC'}",
    ]
    if payload.get("message"):
        lines.append(str(payload["message"]))
    if payload.get("backup"):
        lines.append(f"Sauvegarde : {payload['backup']}")
    for change in payload.get("changes") or []:
        lines.append(f"  - {change}")
    for command in payload.get("commands") or []:
        lines.append(f"  $ {command}")
    health = payload.get("health") or {}
    if health:
        lines.append(
            f"Healthcheck : {'OK' if health.get('ok') else 'ECHEC'} "
            f"(version {health.get('version') or '?'})"
        )
    remote = payload.get("remote_access") or {}
    if remote:
        lines.append(
            f"Acces distant : {'OK' if remote.get('ok') else 'ECHEC'} | "
            f"{remote.get('desired_custom_connections') or '?'}"
        )
        if remote.get("message"):
            lines.append(f"  {remote['message']}")
    nested = payload.get("plex") or {}
    if nested:
        lines.append(
            "Plex : "
            f"{'OK' if nested.get('ok') else 'ECHEC'} | "
            f"mode public HTTPS={'oui' if nested.get('public_https') else 'non'}"
        )
        remote = nested.get("remote_access") or {}
        if remote:
            lines.append(
                "  acces distant : "
                f"{'OK' if remote.get('ok') else 'ECHEC'} | "
                f"{remote.get('desired_custom_connections') or '?'}"
            )
    validation = payload.get("validation") or {}
    if validation:
        lines.append(
            f"Validation : {'OK' if validation.get('ok') else 'ECHEC'}"
        )
        for key, value in (validation.get("checks") or {}).items():
            lines.append(f"  - {key}: {'OK' if value else 'ECHEC'}")
    restore = payload.get("restore") or []
    if restore:
        lines.append("Restaure :")
        for item in restore:
            lines.append(f"  - {item}")
    for warning in payload.get("warnings") or []:
        lines.append(f"Attention : {warning}")
    return "\n".join(lines)


def emit(payload: dict, as_json: bool) -> None:
    if as_json:
        print(json.dumps(payload, indent=2, ensure_ascii=False))
    elif payload.get("action"):
        print(action_text(payload))
    else:
        print(report_text(payload))


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------


def _helper_python(source: Path) -> str:
    candidate = source / "venv" / "bin" / "python"
    if candidate.is_file() and os.access(candidate, os.X_OK):
        return str(candidate)
    return sys.executable or "python3"


def _backup_dir(storage: Path) -> Path:
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    path = storage / "backup" / "plexsec" / stamp
    path.mkdir(parents=True, exist_ok=True, mode=0o700)
    try:
        os.chmod(path, 0o700)
    except OSError:
        pass
    return path


def _write_backup(
    scan: dict,
    attrs: dict,
    paths: dict,
    backup: Path,
    extra_files: dict[str, str] | None = None,
    state: dict | None = None,
) -> None:
    files = {
        "inspect.json": json.dumps(attrs, indent=2, ensure_ascii=False),
        "scan-before.json": json.dumps(scan, indent=2, ensure_ascii=False),
    }
    files.update(extra_files or {})
    if state is not None:
        files["state.json"] = json.dumps(state, indent=2, ensure_ascii=False)
    codecs = paths.get("codecs")
    if codecs and Path(codecs).is_dir():
        lines = [str(item) for item in Path(codecs).rglob("*") if item.is_file()]
        files["codecs.txt"] = "\n".join(lines) + "\n"
    for name, content in files.items():
        target = backup / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")
        try:
            os.chmod(target, 0o600)
        except OSError:
            pass
    preferences = paths.get("preferences")
    if preferences and Path(preferences).is_file():
        target = backup / "Preferences.xml"
        shutil.copy2(preferences, target)
        try:
            os.chmod(target, 0o600)
        except OSError:
            pass


def _find_media_mounts(
    attrs: dict,
    db_path: Path | None,
    explicit: list[str],
    media_mode: str = "generic",
) -> tuple[list[str], list[str], list[str]]:
    warnings: list[str] = []
    if explicit:
        paths = explicit
    else:
        paths = detect_media_paths(db_path)
        if not paths:
            warnings.append(
                "bibliotheques Plex non detectees ; utilisation de ~/Medias ou /mnt si present"
            )
    if not paths:
        default = Path.home() / "Medias"
        if default.is_dir():
            paths = [str(default)]
        elif find_mount(attrs, "/mnt"):
            paths = ["/mnt"]
            warnings.append("/mnt conserve en lecture seule (detection DB impossible)")
    mounts, mapping_warnings = map_media_paths(paths, Path.home())
    warnings.extend(mapping_warnings)

    symlink_data = detect_symlink_targets(
        [path for path in paths if os.path.isdir(path)],
        attrs.get("Mounts") or [],
    )
    targets = symlink_data.get("targets") or []
    unmounted = symlink_data.get("unmounted") or []
    home = Path.home()
    home_media = (str(home / "Medias"), str(home / "local"))
    by_dest: dict[str, str] = {}
    for bind in mounts:
        parts = bind.split(":")
        if len(parts) >= 2:
            by_dest[parts[1]] = bind

    if media_mode == "strict":
        for root in unmounted:
            if root.startswith(str(home)) and not root.startswith(home_media):
                warnings.append(
                    f"cible hors ~/Medias et ~/local : {root} (verifier avant montage)"
                )
            by_dest[root] = f"{root}:{root}:ro"
        if unmounted:
            warnings.append("mode strict : montage des cibles de symlinks en lecture seule")
    else:
        mnt_roots = [
            str(entry.get("root"))
            for entry in targets
            if entry.get("root") == "/mnt"
            or str(entry.get("root", "")).startswith("/mnt/")
        ]
        if mnt_roots or any(str(path).startswith("/mnt") for path in paths):
            by_dest["/mnt"] = "/mnt:/mnt:ro,rslave"
            warnings.append("montage generique /mnt en lecture seule (rslave)")
        for root in unmounted:
            if root == "/mnt" or root.startswith("/mnt/"):
                continue
            if root.startswith(str(home)) and not root.startswith(home_media):
                warnings.append(
                    f"cible hors /mnt : {root} (utiliser --media-path ou le mode strict)"
                )
                continue
            by_dest[root] = f"{root}:{root}:ro"
    return sorted(by_dest.values()), paths, warnings


def _wait_identity(name: str, attrs: dict, timeout: int = 120) -> dict:
    deadline = datetime.now(timezone.utc).timestamp() + timeout
    last = None
    while datetime.now(timezone.utc).timestamp() < deadline:
        try:
            current = inspect_container(name)
        except ToolError:
            current = attrs
        identity = plex_identity(current, name)
        if identity:
            version = parse_version(identity)
            if version:
                return {"ok": True, "version": version_str(version)}
        last = identity
        import time

        time.sleep(2)
    return {"ok": False, "version": None, "detail": "identity indisponible"}


def desired_public_url(attrs: dict, preferences: dict) -> str | None:
    labels = labels_dict(attrs)
    rule = labels.get("traefik.http.routers.plex-rtr.rule") or ""
    match = re.search(r"Host\(`?([^`\")]+)`?\)", rule)
    if match:
        return f"https://{match.group(1)}"
    current = str(preferences.get("custom_connections") or "")
    for part in current.split(","):
        part = part.strip()
        if part.startswith("https://"):
            return part.removesuffix(":443")
    return None


def _plex_owner_token(preferences_path: Path | None) -> str | None:
    if not preferences_path or not preferences_path.is_file():
        return None
    try:
        root = ET.parse(preferences_path).getroot()
    except (ET.ParseError, OSError):
        return None
    token = (root.get("PlexOnlineToken") or "").strip()
    return token or None


def _plex_api_hosts(attrs: dict) -> list[str]:
    hosts = ["127.0.0.1"]
    ip = container_ip(attrs)
    if ip and ip not in hosts:
        hosts.append(ip)
    return hosts


def _plex_api_request(
    attrs: dict, token: str, path: str, method: str = "PUT"
) -> tuple[int | None, str, str | None, str | None]:
    """Appelle l'API Plex locale en HTTPS (certificat plex.direct) puis HTTP."""
    errors: list[str] = []
    for host in _plex_api_hosts(attrs):
        for scheme in ("https", "http"):
            request = urllib.request.Request(
                f"{scheme}://{host}:{PLEX_PORT}{path}",
                method=method,
                headers={"X-Plex-Token": token},
            )
            context = unverified_ssl_context() if scheme == "https" else None
            try:
                with urllib.request.urlopen(
                    request, timeout=10, context=context
                ) as response:
                    return (
                        response.status,
                        response.read(500).decode("utf-8", errors="ignore"),
                        host,
                        scheme,
                    )
            except urllib.error.HTTPError as exc:
                return (
                    exc.code,
                    exc.read(500).decode("utf-8", errors="ignore"),
                    host,
                    scheme,
                )
            except (urllib.error.URLError, OSError, TimeoutError) as exc:
                errors.append(f"{scheme}://{host}: {exc}")
    return None, "; ".join(errors), None, None


def fix_remote_access(apply: bool = False, public_https: bool | None = None) -> dict:
    """Configure customConnections HTTPS et desactive le port manuel 32400.

    En mode public HTTPS, applique aussi secureConnections=0 (Required),
    RelayEnabled=0 et PublishServerOnPlexOnlineKey=1. Ne publie pas 32400 :
    l'acces distant passe par Traefik/443. Le test « Remote Access » de Plex
    peut rester indisponible car il teste 32400.
    """
    name = find_plex_container()
    if not name:
        return {
            "schema": SCHEMA_VERSION,
            "action": "fix-remote",
            "ok": False,
            "applied": False,
            "message": "conteneur Plex introuvable",
        }
    attrs = inspect_container(name)
    paths = plex_paths(attrs)
    preferences = scan_preferences(paths.get("preferences"))
    if public_https is None:
        public_https = bool(scan_traefik(attrs).get("public_https"))
    desired = desired_public_url(attrs, preferences)
    if not desired:
        return {
            "schema": SCHEMA_VERSION,
            "action": "fix-remote",
            "ok": False,
            "applied": False,
            "message": "URL publique introuvable (label Traefik ou customConnections HTTPS)",
        }
    current = preferences.get("custom_connections")
    manual_mode = preferences.get("manual_port_mapping_mode")
    manual_port = preferences.get("manual_port_mapping_port")
    secure = preferences.get("secure_connections")
    relay = preferences.get("relay_enabled")
    publish = preferences.get("publish_server_on_plex_online_key")
    prefs = {
        "customConnections": desired,
        "ManualPortMappingMode": "0",
        "ManualPortMappingPort": "0",
    }
    changes = []
    if str(current or "") != desired:
        changes.append(f"customConnections -> {desired}")
    if str(manual_mode or "") != "0":
        changes.append("ManualPortMappingMode -> 0")
    if str(manual_port or "") not in ("", "0"):
        changes.append("ManualPortMappingPort -> 0")
    if public_https:
        if str(secure or "") != "0":
            changes.append("secureConnections -> 0 (Required)")
        prefs["secureConnections"] = "0"
        if str(relay or "") != "0":
            changes.append("RelayEnabled -> 0")
        prefs["RelayEnabled"] = "0"
        if str(publish or "") != "1":
            changes.append("PublishServerOnPlexOnlineKey -> 1")
        prefs["PublishServerOnPlexOnlineKey"] = "1"
    elif str(secure or "") == "0":
        # Backend Traefik en HTTP : Required rendrait Plex injoignable.
        changes.append("secureConnections -> 1 (Preferred, backend HTTP)")
        prefs["secureConnections"] = "1"
    payload = {
        "schema": SCHEMA_VERSION,
        "action": "fix-remote",
        "ok": True,
        "applied": False,
        "public_https": public_https,
        "desired_custom_connections": desired,
        "custom_connections": current,
        "manual_port_mapping_mode": manual_mode,
        "manual_port_mapping_port": manual_port,
        "secure_connections": secure,
        "relay_enabled": relay,
        "publish_server_on_plex_online_key": publish,
        "changes": changes,
    }
    if not apply:
        payload["dry_run"] = True
        payload["message"] = "Plan acces distant (aucune modification)."
        return payload
    if not changes:
        payload["message"] = "Acces distant deja conforme."
        return payload
    token = _plex_owner_token(paths.get("preferences"))
    if not token:
        payload["ok"] = False
        payload["message"] = "PlexOnlineToken absent de Preferences.xml"
        return payload
    query = urllib.parse.urlencode(prefs)
    status, body, host, scheme = _plex_api_request(
        attrs, token, f"/:/prefs?{query}"
    )
    payload["prefs_status"] = status
    payload["prefs_host"] = host
    payload["prefs_scheme"] = scheme
    if status != 200:
        payload["ok"] = False
        payload["message"] = (
            f"mise a jour des prefs en echec (HTTP {status}) {body[:200]}"
        )
        return payload
    refresh_status, refresh_body, _, _ = _plex_api_request(
        attrs, token, "/myplex/refreshReachability"
    )
    payload["refresh_status"] = refresh_status
    payload["applied"] = True
    payload["ok"] = True
    payload["message"] = (
        f"Acces distant configure sur {desired}. "
        "Le statut « non disponible » de Plex teste 32400 : il peut rester "
        "affiche sans affecter l'acces via le domaine."
    )
    if refresh_status not in (200, 204):
        payload["warning"] = (
            "refreshReachability a echoue "
            f"(HTTP {refresh_status}) : les prefs sont appliquees, "
            "cliquer sur Retry dans Plex ou recharger la page."
        )
    return payload


def plex_label_overrides(
    public_https: bool, host: str | None = None
) -> dict[str, str]:
    """Labels Traefik Plex pour le mode public HTTPS ou le mode historique."""
    common = {
        "traefik.enable": "true",
        "traefik.http.routers.plex-rtr.service": "plex-svc",
        "traefik.http.routers.plex-rtr.tls": "true",
        "traefik.http.routers.plex-rtr.tls.certresolver": "letsencrypt",
    }
    if public_https:
        labels = {
            **common,
            "traefik.http.routers.plex-rtr.entrypoints": "https",
            "traefik.http.routers.plex-rtr.middlewares": PLEX_PUBLIC_CHAIN,
            "traefik.http.services.plex-svc.loadbalancer.server.port": str(PLEX_PORT),
            "traefik.http.services.plex-svc.loadbalancer.server.scheme": "https",
            "traefik.http.services.plex-svc.loadbalancer.serverstransport": PLEX_TRANSPORT,
        }
        if host:
            labels["traefik.http.routers.plex-rtr.rule"] = f"Host(`{host}`)"
        return labels
    # Valeur vide = suppression du label (voir recreate_app_container.py).
    return {
        **common,
        "traefik.http.routers.plex-rtr.entrypoints": "http,https",
        "traefik.http.routers.plex-rtr.middlewares": "chain-no-auth@file",
        "traefik.http.services.plex-svc.loadbalancer.server.scheme": "",
        "traefik.http.services.plex-svc.loadbalancer.serverstransport": "",
    }


def fix_plex(
    apply: bool = False,
    force: bool = False,
    media_paths: list[str] | None = None,
    localhost_port: bool = False,
    no_pull: bool = False,
    use_cache: bool = False,
    media_mode: str = "generic",
    public_https: bool | None = None,
    backup_dir: Path | None = None,
) -> dict:
    material = media_paths or []
    source, storage = settings_paths()
    if use_cache:
        cached = load_cached_scan(storage)
        if cached is None:
            return {
                "schema": SCHEMA_VERSION,
                "action": "fix-plex",
                "ok": False,
                "applied": False,
                "message": (
                    "Aucun audit en cache. Lancer d'abord l'audit "
                    "(option 1 / scan --json) avant de corriger."
                ),
            }
        scan = cached
    else:
        try:
            scan = build_scan()
        except ToolError as exc:
            return {
                "schema": SCHEMA_VERSION,
                "action": "fix-plex",
                "ok": False,
                "message": str(exc),
                "applied": False,
            }
    name = str((scan.get("container") or {}).get("name") or PLEX_NAME)
    if (scan.get("summary") or {}).get("compromised") and not force:
        return {
            "schema": SCHEMA_VERSION,
            "action": "fix-plex",
            "ok": False,
            "applied": False,
            "message": (
                "IoC de compromission detecte : fix-plex refuse. "
                "Utiliser quarantine, rotation des secrets et restauration."
            ),
            "summary": scan.get("summary"),
        }
    try:
        attrs = inspect_container(name)
    except ToolError:
        fallback = find_plex_container()
        if not fallback:
            return {
                "schema": SCHEMA_VERSION,
                "action": "fix-plex",
                "ok": False,
                "applied": False,
                "message": f"conteneur Plex introuvable: {name}",
            }
        name = fallback
        attrs = inspect_container(name)
    paths = plex_paths(attrs)
    live_preferences = scan_preferences(paths.get("preferences"))
    if public_https is None:
        public_https = bool(scan_traefik(attrs).get("public_https"))
    media_mounts, detected_paths, warnings = _find_media_mounts(
        attrs, paths.get("db"), material, media_mode=media_mode
    )
    live_mounts = scan_mounts(attrs, Path.home())
    dangerous = [
        mount["destination"]
        for mount in live_mounts
        if mount.get("dangers")
    ]
    changes = [
        "ajouter VERSION=latest",
        (
            "ajouter chain-plex@file + backend HTTPS + plex-transport@file"
            if public_https
            else "ajouter le middleware chain-no-auth@file"
        ),
        (
            "publier 32400 sur 127.0.0.1 uniquement"
            if public_https or localhost_port
            else "retirer la publication 0.0.0.0:32400"
        ),
        "retirer les montages " + (", ".join(dangerous) or "dangereux"),
        f"mode medias : {media_mode}",
        "ajouter les montages medias: " + (", ".join(media_mounts) or "aucun"),
        "ajouter no-new-privileges, cap_drop ALL et les capabilities Plex",
        "ajouter tmpfs /tmp et shm_size 256m",
    ]
    if not apply:
        return {
            "schema": SCHEMA_VERSION,
            "action": "fix-plex",
            "ok": True,
            "applied": False,
            "dry_run": True,
            "public_https": public_https,
            "message": "Plan de correction (aucune modification).",
            "changes": changes,
            "media_paths": detected_paths,
            "media_mounts": media_mounts,
            "warnings": warnings,
            "summary": scan["summary"],
        }

    backup = backup_dir or _backup_dir(storage)
    _write_backup(scan, attrs, paths, backup)

    preferences_changed = {"changed": False}
    was_running = bool((attrs.get("State") or {}).get("Running"))
    if live_preferences.get("transcoder_h264_options") is not None:
        if was_running:
            run_cmd(["docker", "stop", name], timeout=60)
        preferences_changed = fix_preferences(paths.get("preferences"))
        if not preferences_changed.get("ok"):
            if was_running:
                run_cmd(["docker", "start", name], timeout=60)
            return {
                "schema": SCHEMA_VERSION,
                "action": "fix-plex",
                "ok": False,
                "applied": False,
                "backup": str(backup),
                "message": preferences_changed.get("message")
                or "correction Preferences.xml impossible",
            }

    helper = source / "includes" / "config" / "scripts" / "recreate_app_container.py"
    if not helper.is_file():
        return {
            "schema": SCHEMA_VERSION,
            "action": "fix-plex",
            "ok": False,
            "applied": False,
            "backup": str(backup),
            "message": f"helper introuvable: {helper}",
        }

    desired = desired_public_url(attrs, live_preferences)
    host = urllib.parse.urlsplit(desired).hostname if desired else None
    label_overrides = plex_label_overrides(public_https, host)
    command = [
        _helper_python(source),
        str(helper),
        name,
        "--env",
        "VERSION=latest",
        *sum(
            (["--label", f"{key}={value}"] for key, value in label_overrides.items()),
            [],
        ),
        "--security-opt",
        "no-new-privileges:true",
        "--cap-drop",
        "ALL",
        *sum((["--cap-add", cap] for cap in PLEX_CAP_ADD), []),
        "--tmpfs",
        "/tmp:rw,noexec,nosuid,size=256m",
        "--shm-size",
        "256m",
    ]
    if public_https or localhost_port:
        command.extend(["--publish", f"{PLEX_PORT}=127.0.0.1:{PLEX_PORT}"])
    else:
        command.extend(["--unpublish", str(PLEX_PORT)])
    for destination in dangerous:
        command.extend(["--drop-bind", destination])
    for bind in media_mounts:
        command.extend(["--add-bind", bind])
    if no_pull:
        command.append("--no-pull")
    try:
        result = run_cmd(command, timeout=900)
    except ToolError as exc:
        return {
            "schema": SCHEMA_VERSION,
            "action": "fix-plex",
            "ok": False,
            "applied": False,
            "backup": str(backup),
            "message": str(exc),
            "commands": [" ".join(command)],
        }
    try:
        helper_payload = json.loads(result.stdout.strip().splitlines()[-1])
    except (json.JSONDecodeError, IndexError):
        helper_payload = {"ok": False, "error": result.stdout.strip() or result.stderr.strip()}
    if result.returncode != 0 or not helper_payload.get("ok"):
        return {
            "schema": SCHEMA_VERSION,
            "action": "fix-plex",
            "ok": False,
            "applied": False,
            "backup": str(backup),
            "message": helper_payload.get("error") or "recreation en echec",
            "commands": [" ".join(command)],
        }
    health = _wait_identity(name, attrs)
    after = None if use_cache else build_scan()
    summary = after["summary"] if after else {
        "status": "audit_required",
        "ok": False,
        "compromised": False,
        "vulnerable": False,
        "hardening_required": False,
        "issues": [],
        "issue_count": 0,
    }
    payload = {
        "schema": SCHEMA_VERSION,
        "action": "fix-plex",
        "ok": bool(health.get("ok")),
        "applied": True,
        "public_https": public_https,
        "backup": str(backup),
        "changes": changes,
        "media_paths": detected_paths,
        "media_mounts": media_mounts,
        "warnings": warnings,
        "preferences": preferences_changed,
        "health": health,
        "summary": summary,
        "attack_path": after.get("attack_path") if after else None,
        "commands": [" ".join(command)],
    }
    payload["remote_access"] = fix_remote_access(
        apply=True, public_https=public_https
    )
    if public_https:
        whitelist_ok, whitelist_output = install_crowdsec_plex_whitelist(
            source, True
        )
        payload["crowdsec_whitelist"] = whitelist_output
        if not whitelist_ok:
            payload.setdefault("warnings", []).append(
                "Whitelist CrowdSec Plex : " + whitelist_output
            )
    if not payload["remote_access"].get("ok"):
        payload.setdefault("warnings", []).append(
            "Acces distant : " + str(payload["remote_access"].get("message") or "echec")
        )
    invalidate_cache(storage)
    if use_cache:
        payload["audit_required"] = True
        payload["message"] = (
            "Correction appliquee. Relancer l'audit (option 1) pour actualiser."
        )
    return payload


def _ssdv2_env(source: Path, storage: Path) -> dict[str, str]:
    environment = os.environ.copy()
    environment["SETTINGS_SOURCE"] = str(source)
    environment["SETTINGS_STORAGE"] = str(storage)
    if not environment.get("USER"):
        environment["USER"] = Path(
            environment.get("HOME", str(Path.home()))
        ).name
    # Les playbooks Ansible utilisent lookup('env','MYUID'/'MYGID'/'MYGIDNAME').
    environment.setdefault("MYUID", str(os.getuid()))
    environment.setdefault("MYGID", str(os.getgid()))
    if not environment.get("MYGIDNAME"):
        try:
            import grp

            environment["MYGIDNAME"] = grp.getgrgid(os.getgid()).gr_name
        except (ImportError, KeyError):
            environment["MYGIDNAME"] = str(os.getgid())
    return environment


def _set_plex_public_flag(
    source: Path, storage: Path, enabled: bool
) -> tuple[bool, str]:
    """Ecrit plex.public_https dans account.yml via la fonction bash SSDV2."""
    script = source / "includes" / "config" / "scripts" / "generique.sh"
    if not script.is_file():
        return False, f"generique.sh introuvable: {script}"
    try:
        result = subprocess.run(
            [
                "/bin/bash",
                str(script),
                "manage_account_yml",
                "plex.public_https",
                "true" if enabled else "false",
            ],
            capture_output=True,
            text=True,
            timeout=180,
            env=_ssdv2_env(source, storage),
            cwd=str(source),
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        return False, str(exc)
    output = (result.stdout + "\n" + result.stderr).strip()
    if result.returncode != 0 or "impossible de continuer" in output.lower():
        return False, output[:500] or "manage_account_yml en echec"
    return True, output[:500]


def _run_ansible_playbook(
    source: Path,
    storage: Path,
    playbook: Path,
    extra_vars: dict[str, str] | None = None,
    timeout: int = 1800,
) -> tuple[bool, str, list[str]]:
    if not playbook.is_file():
        return False, f"playbook introuvable: {playbook}", []
    command = ["ansible-playbook", str(playbook)]
    for key, value in (extra_vars or {}).items():
        command.extend(["--extra-vars", f"{key}={value}"])
    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=timeout,
            env=_ssdv2_env(source, storage),
            cwd=str(source),
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        return False, str(exc), [" ".join(command)]
    output = (result.stdout + "\n" + result.stderr).strip()
    return result.returncode == 0, output[-2000:], [" ".join(command)]


def _curl_status(url: str, host: str) -> int | None:
    if not shutil.which("curl"):
        return None
    import time

    for attempt in range(3):
        try:
            result = run_cmd(
                [
                    "curl",
                    "-k",
                    "-s",
                    "-o",
                    "/dev/null",
                    "-w",
                    "%{http_code}",
                    "--resolve",
                    f"{host}:443:127.0.0.1",
                    url,
                ],
                timeout=20,
            )
        except ToolError:
            result = None
        if result is not None and result.returncode == 0:
            try:
                return int(result.stdout.strip()[-3:])
            except ValueError:
                return None
        if attempt < 2:
            time.sleep(2)
    return None


def _validate_public_https(desired: str | None, attrs: dict, scan: dict) -> dict:
    host = urllib.parse.urlsplit(desired).hostname if desired else None
    labels = scan_traefik(attrs)
    prefs = (scan.get("container") or {}).get("preferences") or {}
    rules = (scan.get("container") or {}).get("traefik_rules") or {}
    ports = [
        port
        for port in scan_ports(attrs)
        if str(port.get("container_port") or "").startswith(str(PLEX_PORT))
    ]
    checks = {
        "chain_plex": bool(labels.get("chain_plex")),
        "backend_https": labels.get("scheme") == "https",
        "transport": str(labels.get("serverstransport") or "") == PLEX_TRANSPORT,
        "loopback_only": bool(ports)
        and all(port.get("host_ip") == "127.0.0.1" for port in ports),
        "secure_required": str(prefs.get("secure_connections") or "") == "0",
        "relay_disabled": str(prefs.get("relay_enabled") or "") == "0",
        "published": str(prefs.get("publish_server_on_plex_online_key") or "") == "1",
        "allowlist": bool(rules.get("available"))
        and bool(rules.get("non_plex_chains"))
        and all((rules.get("non_plex_chains") or {}).values()),
        "chain_plex_no_allowlist": bool(rules.get("chain_plex"))
        and PLEX_ALLOWLIST_MIDDLEWARE not in (rules.get("chain_plex") or []),
    }
    if host:
        checks["identity"] = _curl_status(f"https://{host}/identity", host) == 200
        checks["web"] = _curl_status(f"https://{host}/web", host) in (
            301,
            302,
            303,
            307,
            308,
        )
    return {
        "ok": all(bool(value) for value in checks.values()),
        "host": host,
        "checks": checks,
    }


def public_https(
    apply: bool = False, disable: bool = False, use_cache: bool = False
) -> dict:
    """Active/desactive le mode Plex public HTTPS (opt-in)."""
    source, storage = settings_paths()
    if use_cache and load_cached_scan(storage) is None:
        return {
            "schema": SCHEMA_VERSION,
            "action": "public-https",
            "ok": False,
            "applied": False,
            "message": (
                "Aucun audit en cache. Relancer l'audit (option 1 / scan) "
                "ou retirer --use-cache."
            ),
        }
    name = find_plex_container()
    if not name:
        return {
            "schema": SCHEMA_VERSION,
            "action": "public-https",
            "ok": False,
            "applied": False,
            "message": "conteneur Plex introuvable",
        }
    attrs = inspect_container(name)
    paths = plex_paths(attrs)
    preferences = scan_preferences(paths.get("preferences"))
    traefik = scan_traefik(attrs)
    desired = desired_public_url(attrs, preferences)
    target = not disable
    changes = (
        [
            "activer plex.public_https dans account.yml",
            "passer le DNS Plex en DNS-only (gris)",
            "regenerer Traefik : allowlist Cloudflare sur les chaines non-Plex",
            "recreer Plex : chain-plex@file, backend HTTPS, 32400 loopback",
            "appliquer secureConnections=0, RelayEnabled=0, Publish=1",
            f"customConnections -> {desired or 'https://plex.<domaine>'}",
        ]
        if target
        else [
            "desactiver plex.public_https dans account.yml",
            "remettre le DNS Plex en proxied Cloudflare",
            "regenerer Traefik sans allowlist sur les chaines non-Plex",
            "recreer Plex : chain-no-auth@file, backend HTTP",
        ]
    )
    payload = {
        "schema": SCHEMA_VERSION,
        "action": "public-https" if target else "public-https-disable",
        "ok": True,
        "applied": False,
        "public_https": target,
        "previous_public_https": bool(traefik.get("public_https")),
        "desired_url": desired,
        "changes": changes,
    }
    if not apply:
        payload["dry_run"] = True
        payload["message"] = (
            "Plan mode Plex public HTTPS (aucune modification)."
            if target
            else "Plan retour au mode Cloudflare (aucune modification)."
        )
        return payload
    if target and not desired:
        payload["ok"] = False
        payload["message"] = (
            "URL publique Plex introuvable (label Traefik Host ou customConnections)"
        )
        return payload

    try:
        scan = build_scan()
    except ToolError as exc:
        scan = {"container": {"name": name}, "summary": {"status": "unknown"}, "error": str(exc)}
    if (scan.get("summary") or {}).get("compromised"):
        return {
            "schema": SCHEMA_VERSION,
            "action": "public-https",
            "ok": False,
            "applied": False,
            "message": (
                "IoC de compromission detecte : activation refusee. "
                "Utiliser quarantine, rotation des secrets et restauration."
            ),
            "summary": scan.get("summary"),
        }
    backup = _backup_dir(storage)
    rules_dir = storage / DEFAULT_TRAEFIK_RULES
    extra_files: dict[str, str] = {}
    for rule_name in ("middlewares.toml", "middlewares-chains.toml"):
        rule_path = rules_dir / rule_name
        if rule_path.is_file():
            try:
                extra_files[f"traefik/{rule_name}"] = rule_path.read_text(
                    encoding="utf-8"
                )
            except OSError:
                pass
    state = {
        "public_https_before": bool(traefik.get("public_https")),
        "cloudflare_proxied_before": not bool(traefik.get("public_https")),
    }
    _write_backup(
        scan,
        attrs,
        paths,
        backup,
        extra_files=extra_files,
        state=state,
    )

    flag_ok, flag_output = _set_plex_public_flag(source, storage, target)
    if not flag_ok:
        payload.update(
            {
                "ok": False,
                "backup": str(backup),
                "message": f"ecriture de plex.public_https en echec: {flag_output}",
            }
        )
        return payload

    whitelist_ok, whitelist_output = install_crowdsec_plex_whitelist(source, target)
    payload["crowdsec_whitelist"] = whitelist_output
    if not whitelist_ok:
        payload.setdefault("warnings", []).append(
            "Whitelist CrowdSec Plex : " + whitelist_output
        )

    traefik_ok, traefik_output, traefik_commands = _run_ansible_playbook(
        source,
        storage,
        source / "includes" / "dockerapps" / "vars" / "traefik.yml",
    )
    payload["traefik_commands"] = traefik_commands
    if not traefik_ok:
        payload.update(
            {
                "ok": False,
                "backup": str(backup),
                "message": "regeneration Traefik en echec",
                "traefik_output": traefik_output,
            }
        )
        return payload

    dns_ok, dns_output, dns_commands = _run_ansible_playbook(
        source,
        storage,
        source / "includes" / "config" / "playbooks" / "plex_dns.yml",
        {"plex_dns_proxied": "false" if target else "true"},
    )
    payload["dns_commands"] = dns_commands
    if not dns_ok:
        payload.setdefault("warnings", []).append(
            "DNS Plex non mis a jour : " + dns_output[:300]
        )
    elif "Cloudflare n'est pas configure" in dns_output:
        payload.setdefault("warnings", []).append(
            "Cloudflare non configure : creer manuellement un A DNS-only "
            "pour plex.<domaine>."
        )

    plex_payload = fix_plex(
        apply=True,
        public_https=target,
        use_cache=use_cache,
        backup_dir=backup,
        no_pull=True,
    )
    payload["plex"] = plex_payload
    payload["applied"] = bool(plex_payload.get("applied"))
    if not plex_payload.get("ok"):
        payload["ok"] = False
        payload["message"] = (
            plex_payload.get("message") or "recreation Plex en echec"
        )
        payload["backup"] = str(backup)
        return payload

    if target:
        validation = {"ok": False, "message": "validation impossible"}
        try:
            after = build_scan()
            try:
                after_attrs = inspect_container(name)
            except ToolError:
                after_attrs = attrs
            validation = _validate_public_https(desired, after_attrs, after)
            payload["summary"] = after.get("summary")
        except ToolError as exc:
            validation["message"] = str(exc)
    else:
        validation = {
            "ok": bool(plex_payload.get("ok")),
            "checks": {"plex_recreate": bool(plex_payload.get("ok"))},
        }
    payload["validation"] = validation
    payload["backup"] = str(backup)
    payload["ok"] = bool(plex_payload.get("ok")) and bool(validation.get("ok"))
    invalidate_cache(storage)
    payload["message"] = (
        "Mode Plex public HTTPS actif."
        if target and payload["ok"]
        else "Retour au mode Cloudflare effectue."
        if not target and payload["ok"]
        else "Mode applique mais validation incomplete ; verifier les checks."
    )
    return payload


def _iptables_commands(ports: list[int], allow_lan: str | None, rollback: bool) -> list[list[str]]:
    commands: list[list[str]] = []
    for port in ports:
        if rollback:
            commands.append(["iptables", "-D", "DOCKER-USER", "-p", "tcp", "--dport", str(port), "-j", "DROP"])
            commands.append(["ip6tables", "-D", "DOCKER-USER", "-p", "tcp", "--dport", str(port), "-j", "DROP"])
            if allow_lan:
                commands.append(["iptables", "-D", "DOCKER-USER", "-s", allow_lan, "-p", "tcp", "--dport", str(port), "-j", "ACCEPT"])
                commands.append(["ip6tables", "-D", "DOCKER-USER", "-s", allow_lan, "-p", "tcp", "--dport", str(port), "-j", "ACCEPT"])
            continue
        commands.append(["iptables", "-I", "DOCKER-USER", "-p", "tcp", "--dport", str(port), "-j", "DROP"])
        commands.append(["ip6tables", "-I", "DOCKER-USER", "-p", "tcp", "--dport", str(port), "-j", "DROP"])
        if allow_lan:
            commands.append(["iptables", "-I", "DOCKER-USER", "-s", allow_lan, "-p", "tcp", "--dport", str(port), "-j", "ACCEPT"])
            commands.append(["ip6tables", "-I", "DOCKER-USER", "-s", allow_lan, "-p", "tcp", "--dport", str(port), "-j", "ACCEPT"])
    return commands


def close_port(
    apply: bool = False,
    ports: list[int] | None = None,
    allow_lan: str | None = None,
    rollback: bool = False,
) -> dict:
    port_list = sorted({int(port) for port in (ports or [PLEX_PORT])})
    commands = _iptables_commands(port_list, allow_lan, rollback)
    rendered = [" ".join(command) for command in commands]
    if not apply:
        return {
            "schema": SCHEMA_VERSION,
            "action": "close-port",
            "ok": True,
            "applied": False,
            "dry_run": True,
            "ports": port_list,
            "commands": rendered,
            "message": "Plan de fermeture (aucune modification).",
        }
    sudo = sudo_prefix()
    if sudo is None:
        return {
            "schema": SCHEMA_VERSION,
            "action": "close-port",
            "ok": False,
            "applied": False,
            "message": "sudo non disponible ; appliquer les commandes manuellement",
            "commands": rendered,
        }
    for command in commands:
        try:
            result = run_cmd([*sudo, *command], timeout=30)
        except ToolError as exc:
            return {
                "schema": SCHEMA_VERSION,
                "action": "close-port",
                "ok": False,
                "applied": False,
                "message": str(exc),
                "commands": rendered,
            }
        if result.returncode != 0 and "-C" not in command:
            return {
                "schema": SCHEMA_VERSION,
                "action": "close-port",
                "ok": False,
                "applied": False,
                "message": result.stderr.strip() or f"echec: {' '.join(command)}",
                "commands": rendered,
            }
    saved = []
    for save in (
        [*sudo, "netfilter-persistent", "save"],
        [*sudo, "sh", "-c", "iptables-save > /etc/iptables/rules.v4 && ip6tables-save > /etc/iptables/rules.v6"],
    ):
        try:
            result = run_cmd(save, timeout=60)
        except ToolError:
            continue
        if result.returncode == 0:
            saved.append(" ".join(save))
            break
    return {
        "schema": SCHEMA_VERSION,
        "action": "close-port",
        "ok": True,
        "applied": True,
        "ports": port_list,
        "commands": rendered,
        "saved": saved,
        "message": "Regles appliquees. Verifier depuis l'exterieur.",
    }


def quarantine(apply: bool = False) -> dict:
    commands = [
        ["docker", "stop", PLEX_NAME],
        ["docker", "network", "disconnect", "traefik_proxy", PLEX_NAME],
    ]
    rendered = [" ".join(command) for command in commands]
    if not apply:
        return {
            "schema": SCHEMA_VERSION,
            "action": "quarantine",
            "ok": True,
            "applied": False,
            "dry_run": True,
            "commands": rendered,
            "message": "Plan de quarantaine (aucune modification).",
        }
    results = []
    for command in commands:
        result = run_cmd(command, timeout=60)
        results.append(
            {
                "command": " ".join(command),
                "returncode": result.returncode,
                "stderr": result.stderr.strip()[:300],
            }
        )
    return {
        "schema": SCHEMA_VERSION,
        "action": "quarantine",
        "ok": True,
        "applied": True,
        "commands": rendered,
        "results": results,
        "message": (
            "Plex arrete et retire de traefik_proxy. "
            "Ne pas supprimer les donnees. Rotation des secrets et restauration si besoin."
        ),
    }


def rollback(backup: Path, apply: bool = False) -> dict:
    backup = Path(backup)
    inspect_file = backup / "inspect.json"
    if not inspect_file.is_file():
        return {
            "schema": SCHEMA_VERSION,
            "action": "rollback",
            "ok": False,
            "message": f"inspect.json absent: {inspect_file}",
        }
    source, storage = settings_paths()
    helper = source / "includes" / "config" / "scripts" / "recreate_app_container.py"
    command = [
        _helper_python(source),
        str(helper),
        PLEX_NAME,
        "--from-inspect",
        str(inspect_file),
        "--no-pull",
    ]
    state: dict = {}
    state_file = backup / "state.json"
    if state_file.is_file():
        try:
            loaded = json.loads(state_file.read_text(encoding="utf-8"))
            if isinstance(loaded, dict):
                state = loaded
        except (OSError, json.JSONDecodeError):
            state = {}
    restored: list[str] = []
    warnings: list[str] = []
    if not apply:
        if state:
            restored.extend(
                [
                    "fichiers Traefik depuis " + str(backup / "traefik"),
                    "Preferences.xml",
                    "plex.public_https=" + str(state.get("public_https_before")),
                    "DNS Plex proxied=" + str(state.get("cloudflare_proxied_before")),
                ]
            )
        return {
            "schema": SCHEMA_VERSION,
            "action": "rollback",
            "ok": True,
            "applied": False,
            "dry_run": True,
            "restore": restored,
            "commands": [" ".join(command)],
        }

    attrs: dict = {}
    try:
        attrs_raw = json.loads(inspect_file.read_text(encoding="utf-8"))
        attrs = attrs_raw[0] if isinstance(attrs_raw, list) and attrs_raw else attrs_raw
        paths = plex_paths(attrs if isinstance(attrs, dict) else {})
    except (OSError, json.JSONDecodeError):
        paths = {"preferences": None}

    # 1. Preferences.xml (avant recreation du conteneur).
    preferences_backup = backup / "Preferences.xml"
    preferences_target = paths.get("preferences")
    if preferences_backup.is_file() and preferences_target:
        run_cmd(["docker", "stop", PLEX_NAME], timeout=60)
        target = Path(preferences_target)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(preferences_backup, target)
        try:
            os.chmod(target, 0o600)
        except OSError:
            pass
        restored.append("Preferences.xml")

    # 2. Regles Traefik (avant recreation du conteneur).
    rules_backup = backup / "traefik"
    rules_target = storage / DEFAULT_TRAEFIK_RULES
    if rules_backup.is_dir():
        rules_target.mkdir(parents=True, exist_ok=True)
        for rule_file in rules_backup.iterdir():
            if not rule_file.is_file():
                continue
            shutil.copy2(rule_file, rules_target / rule_file.name)
            restored.append(f"Traefik/{rule_file.name}")
        run_cmd(["docker", "restart", "traefik"], timeout=60)

    # 3. Flag account.yml.
    if "public_https_before" in state:
        flag_ok, flag_output = _set_plex_public_flag(
            source, storage, bool(state.get("public_https_before"))
        )
        if flag_ok:
            restored.append(
                "plex.public_https=" + str(state.get("public_https_before"))
            )
        else:
            warnings.append(f"flag plex.public_https non restaure: {flag_output}")

    # 4. DNS Plex.
    if "cloudflare_proxied_before" in state:
        dns_ok, dns_output, _ = _run_ansible_playbook(
            source,
            storage,
            source / "includes" / "config" / "playbooks" / "plex_dns.yml",
            {
                "plex_dns_proxied": "true"
                if state.get("cloudflare_proxied_before")
                else "false"
            },
        )
        if dns_ok:
            restored.append(
                "DNS proxied=" + str(state.get("cloudflare_proxied_before"))
            )
        else:
            warnings.append(f"DNS non restaure: {dns_output[:300]}")

    # 5. Conteneur Plex depuis l'inspect sauvegarde.
    result = run_cmd(command, timeout=900)
    try:
        payload = json.loads(result.stdout.strip().splitlines()[-1])
    except (json.JSONDecodeError, IndexError):
        payload = {"ok": False, "error": result.stderr.strip()}
    health = _wait_identity(PLEX_NAME, attrs, timeout=120)
    return {
        "schema": SCHEMA_VERSION,
        "action": "rollback",
        "ok": result.returncode == 0 and bool(payload.get("ok")),
        "applied": True,
        "restore": restored,
        "warnings": warnings,
        "health": health,
        "commands": [" ".join(command)],
        "result": payload,
    }


# ---------------------------------------------------------------------------
# Selftest
# ---------------------------------------------------------------------------


def selftest(as_json: bool = False) -> int:
    try:
        assert parse_version("1.43.5.11029-6bf8af3f0") == (1, 43, 5, 11029)
        assert version_status((1, 43, 2, 0)) == "vulnerable"
        assert version_status(FIXED_VERSION) == "patched"
        assert version_status(None) == "unknown"

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            codecs = root / "Codecs"
            bundle = codecs / "a336ba9-deadbeef-linux-aarch64"
            bundle.mkdir(parents=True)
            (bundle / "libh264_decoder.so").write_bytes(b"\x7fELF" + b"\0" * 128)
            (codecs / ".device-id").write_text("id")
            (codecs / "zz123.so").write_bytes(b"\x7fELF" + b"\0" * 128)
            result = scan_codecs(codecs)
            assert result["has_zz"] is True
            assert any("zz123.so" in item["path"] for item in result["suspicious"])

            prefs = root / "Preferences.xml"
            prefs.write_text('<Preferences TranscoderH264Options="dump-yuv=/x"/>')
            data = scan_preferences(prefs)
            assert data["transcoder_h264_options"] == "dump-yuv=/x"
            prefs.write_text(
                '<Preferences secureConnections="0" RelayEnabled="0" '
                'PublishServerOnPlexOnlineKey="1" />'
            )
            data = scan_preferences(prefs)
            assert data["secure_connections"] == "0"
            assert data["relay_enabled"] == "0"
            assert data["publish_server_on_plex_online_key"] == "1"
            prefs.write_text("<Preferences />")
            data = scan_preferences(prefs)
            assert data["transcoder_h264_options"] is None

            logs = root / "Logs"
            logs.mkdir()
            (logs / "Plex Media Server.log").write_text(
                "Oct 24, 2026 16:55:10.151 [1] DEBUG - Request: [91.92.40.202:43822 (WAN)] "
                "GET /player/timeline/subscribe?protocol=http%3A%2F%2F127.0.0.1%3A32400%2Fsystem"
                "%2Fagents%2Fz%2FsearchOne HTTP/1.1\n"
                "Oct 24, 2026 16:55:10.151 [1] WARN - [Req#1/CompanionProxy/Subscribe/poc_1] "
                "wanted to subscribe with an unsupported protocol\n"
                "Oct 24, 2026 16:55:10.152 [2] DEBUG - Completed: [91.92.40.202:43822] "
                "400 GET /player/timeline/subscribe (1 live)\n"
            )
            logs_data = scan_logs(logs)
            assert logs_data["attempts"] == 1
            assert logs_data["blocked"] == 1
            assert logs_data["success"] == 0
            assert "91.92.40.202" in logs_data["sources"]

            traefik = root / "traefik.log"
            traefik.write_text("")
            traefik_data = scan_traefik_log(traefik, logs_data["attempts_detail"])
            assert traefik_data["matching_requests"] == 0
            path, _ = compute_attack_path(logs_data, traefik_data)
            assert path == "direct_32400"
            traefik.write_text('{"ClientHost":"91.92.40.202","RequestHost":"plex.kesurof.eu","RequestPath":"/player/timeline/subscribe"}\n')
            traefik_data = scan_traefik_log(traefik, logs_data["attempts_detail"])
            assert traefik_data["matching_requests"] == 1
            path, _ = compute_attack_path(logs_data, traefik_data)
            assert path == "traefik_443"

            mounts, warnings = map_media_paths(
                ["/home/kesurof/Medias/Films", "/mnt/media"], Path("/home/kesurof")
            )
            assert "/home/kesurof/Medias:/home/kesurof/Medias:ro" in mounts
            assert "/mnt:/mnt:ro" in mounts
            assert warnings == []

            media = root / "Medias"
            media.mkdir()
            (media / "film.mkv").symlink_to("/mnt/fake/root/film.mkv")
            symlink_data = detect_symlink_targets([str(media)], [])
            assert "/mnt/fake/root" in symlink_data["unmounted"]
            visible = detect_symlink_targets(
                [str(media)], [{"Destination": "/mnt"}]
            )
            assert visible["unmounted"] == []
            already_mounted, _, _ = _find_media_mounts(
                {"Mounts": [{"Destination": "/mnt"}]},
                None,
                [str(media)],
                media_mode="generic",
            )
            assert any(
                bind.startswith("/mnt:/mnt:ro,rslave") for bind in already_mounted
            )
            generic, _, _ = _find_media_mounts(
                {"Mounts": []}, None, [str(media)], media_mode="generic"
            )
            assert any(bind.startswith("/mnt:/mnt:ro,rslave") for bind in generic)
            strict, _, _ = _find_media_mounts(
                {"Mounts": []}, None, [str(media)], media_mode="strict"
            )
            assert any(bind.startswith("/mnt/fake/root:") for bind in strict)

            attrs = {
                "Config": {
                    "Labels": {
                        "traefik.http.routers.plex-rtr.rule": "Host(`plex.example.com`)"
                    }
                }
            }
            assert desired_public_url(attrs, {}) == "https://plex.example.com"
            public_labels = plex_label_overrides(True, "plex.example.com")
            assert public_labels["traefik.http.routers.plex-rtr.middlewares"] == PLEX_PUBLIC_CHAIN
            assert public_labels["traefik.http.services.plex-svc.loadbalancer.server.scheme"] == "https"
            assert public_labels["traefik.http.services.plex-svc.loadbalancer.serverstransport"] == PLEX_TRANSPORT
            private_labels = plex_label_overrides(False)
            assert private_labels["traefik.http.routers.plex-rtr.middlewares"] == "chain-no-auth@file"
            assert private_labels["traefik.http.services.plex-svc.loadbalancer.server.scheme"] == ""

            rules = root / "rules"
            rules.mkdir()
            (rules / "middlewares.toml").write_text(
                "[http.middlewares.middlewares-allowlist.ipAllowList]\n"
                '  sourceRange = ["10.0.0.0/8", "127.0.0.1/32", '
                '"172.16.0.0/12", "192.168.0.0/16", "100.64.0.0/10", '
                '"104.16.0.0/12"]\n'
                "[http.serversTransports.plex-transport]\n"
                "  insecureSkipVerify = true\n",
                encoding="utf-8",
            )
            (rules / "middlewares-chains.toml").write_text(
                "[http.middlewares.chain-no-auth.chain]\n"
                '  middlewares = ["middlewares-allowlist@file"]\n'
                "[http.middlewares.chain-plex.chain]\n"
                '  middlewares = ["crowdsec@file"]\n',
                encoding="utf-8",
            )
            rules_data = scan_traefik_rules(rules)
            assert rules_data["available"] is True
            assert rules_data["chain_plex"] == ["crowdsec@file"]
            assert rules_data["non_plex_chains"]["chain-no-auth"] is True
            assert rules_data["has_transport"] is True
            assert rules_data["allowlist_ips"]

            token_log = root / "token.log"
            token_log.write_text(
                '{"RequestPath":"/library/parts/1?a=1&X-Plex-Token=abc"}\n',
                encoding="utf-8",
            )
            leak = scan_traefik_token_leak(token_log)
            assert leak["matches"] == 1
            assert "abc" not in (leak["samples"][0] if leak["samples"] else "")

            assert _iptables_commands([32400], None, False)[0][:3] == [
                "iptables",
                "-I",
                "DOCKER-USER",
            ]
    except AssertionError as exc:
        if as_json:
            print(json.dumps({"ok": False, "error": f"selftest: echec {exc}"}))
        else:
            print(f"selftest: echec {exc}", file=sys.stderr)
        return 1
    if as_json:
        print(json.dumps({"ok": True, "selftest": "ok"}))
    else:
        print("selftest: ok")
    return 0


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Audit et remediation Plex2Shell (CVE-2026-96652/96654/96655/96656)."
    )
    parser.add_argument("--json", action="store_true", help="sortie JSON")
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument(
        "--json", action="store_true", default=argparse.SUPPRESS, help="sortie JSON"
    )
    sub = parser.add_subparsers(dest="command", required=True)

    scan = sub.add_parser("scan", parents=[common], help="audit Plex")
    scan.add_argument("--deep", action="store_true", help="inspection approfondie des .so")
    scan.add_argument("--fixture", type=Path, help="repertoire de test (sans Docker)")
    scan.add_argument("--traefik-log", type=Path, help="log d'acces Traefik")

    sub.add_parser("status", parents=[common], help="resume JSON")
    report = sub.add_parser("report", parents=[common], help="rapport lisible")
    report.add_argument("--input", type=Path, help="lire un scan JSON deja produit")
    logs = sub.add_parser("logs", parents=[common], help="analyse des logs Plex")
    logs.add_argument("--input", type=Path, help="lire un scan JSON deja produit")

    fix = sub.add_parser("fix-plex", parents=[common], help="corrige Plex avec sauvegarde/rollback")
    fix.add_argument("--apply", action="store_true", help="appliquer les changements")
    fix.add_argument("--dry-run", action="store_true", help="afficher le plan")
    fix.add_argument("--force", action="store_true", help="continuer meme si IoC")
    fix.add_argument("--media-path", action="append", default=[], help="chemin media a monter")
    fix.add_argument(
        "--media-mode",
        choices=("generic", "strict"),
        default="generic",
        help="generic=/mnt ro,rslave ; strict=cibles de symlinks en ro",
    )
    fix.add_argument("--localhost-port", action="store_true", help="publier 32400 sur 127.0.0.1")
    fix.add_argument("--no-pull", action="store_true", help="ne pas puller l'image")
    fix.add_argument(
        "--use-cache",
        action="store_true",
        help="utiliser le dernier scan en cache (pas de scan implicite)",
    )
    fix_mode = fix.add_mutually_exclusive_group()
    fix_mode.add_argument(
        "--public-https",
        dest="public_https",
        action="store_true",
        default=None,
        help="forcer le mode Plex public HTTPS (chain-plex + backend HTTPS)",
    )
    fix_mode.add_argument(
        "--no-public-https",
        dest="public_https",
        action="store_false",
        help="forcer le mode historique (chain-no-auth + backend HTTP)",
    )

    close = sub.add_parser("close-port", parents=[common], help="ferme les ports via DOCKER-USER")
    close.add_argument("--apply", action="store_true", help="appliquer")
    close.add_argument("--dry-run", action="store_true", help="afficher les commandes")
    close.add_argument("--ports", default=str(PLEX_PORT), help="liste separee par des virgules")
    close.add_argument("--allow-lan", help="CIDR LAN a autoriser avant le DROP")
    close.add_argument("--rollback", action="store_true", help="supprimer les regles")

    remote = sub.add_parser(
        "fix-remote",
        parents=[common],
        help="customConnections HTTPS, prefs Plex et port manuel 32400",
    )
    remote.add_argument("--apply", action="store_true", help="appliquer")
    remote.add_argument(
        "--public-https",
        dest="public_https",
        action="store_true",
        default=None,
        help="appliquer aussi secureConnections=Required, Relay=0, Publish=1",
    )
    remote.add_argument(
        "--no-public-https",
        dest="public_https",
        action="store_false",
        help="forcer le mode historique (Preferred, backend HTTP)",
    )

    public_parser = sub.add_parser(
        "public-https",
        parents=[common],
        help="active/desactive Plex public HTTPS (DNS-only, 443, allowlist)",
    )
    public_parser.add_argument("--apply", action="store_true", help="appliquer")
    public_parser.add_argument("--dry-run", action="store_true", help="afficher le plan")
    public_parser.add_argument(
        "--disable",
        action="store_true",
        help="revenir au mode Cloudflare (Plex non public)",
    )
    public_parser.add_argument(
        "--use-cache",
        action="store_true",
        help="utiliser le dernier scan en cache",
    )

    quarantine_parser = sub.add_parser("quarantine", parents=[common], help="arrete et isole Plex")
    quarantine_parser.add_argument("--apply", action="store_true", help="appliquer")

    rollback_parser = sub.add_parser("rollback", parents=[common], help="restaure une sauvegarde fix-plex")
    rollback_parser.add_argument("--backup", type=Path, required=True, help="dossier de sauvegarde")
    rollback_parser.add_argument("--apply", action="store_true", help="appliquer")

    sub.add_parser("selftest", parents=[common], help="tests internes")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    as_json = bool(getattr(args, "json", False))
    if args.command == "selftest":
        return selftest(as_json=as_json)
    try:
        if args.command == "scan":
            payload = build_scan(
                deep=args.deep,
                fixture=args.fixture,
                traefik_log=args.traefik_log,
            )
            emit(payload, as_json)
            return 0 if payload.get("summary", {}).get("status") == "ok" else 1
        if args.command == "status":
            payload = build_scan()
            emit(status_payload(payload), True)
            return 0 if payload.get("summary", {}).get("status") == "ok" else 1
        if args.command == "report":
            if args.input:
                try:
                    payload = json.loads(args.input.read_text(encoding="utf-8"))
                except (OSError, json.JSONDecodeError) as exc:
                    raise ToolError(f"scan JSON illisible: {exc}") from exc
                if not isinstance(payload, dict):
                    raise ToolError("scan JSON invalide")
            else:
                payload = build_scan()
            emit(payload, as_json)
            return 0 if (payload.get("summary") or {}).get("status") == "ok" else 1
        if args.command == "logs":
            if args.input:
                try:
                    payload = json.loads(args.input.read_text(encoding="utf-8"))
                except (OSError, json.JSONDecodeError) as exc:
                    raise ToolError(f"scan JSON illisible: {exc}") from exc
                if not isinstance(payload, dict):
                    raise ToolError("scan JSON invalide")
            else:
                payload = build_scan()
            data = {
                "schema": SCHEMA_VERSION,
                "generated_at": now_iso(),
                "attack_path": payload.get("attack_path"),
                "evidence": payload.get("evidence"),
                "logs": payload.get("container", {}).get("logs") or payload.get("logs"),
            }
            if as_json:
                print(json.dumps(data, indent=2, ensure_ascii=False))
            else:
                print(logs_text(data))
            return 0
        if args.command == "fix-plex":
            payload = fix_plex(
                apply=bool(args.apply and not args.dry_run),
                force=args.force,
                media_paths=args.media_path,
                localhost_port=args.localhost_port,
                no_pull=args.no_pull,
                use_cache=bool(args.use_cache),
                media_mode=args.media_mode,
                public_https=args.public_https,
            )
            emit(payload, as_json)
            return 0 if payload.get("ok") else 1
        if args.command == "close-port":
            ports = [int(part) for part in str(args.ports).split(",") if part.strip().isdigit()]
            payload = close_port(
                apply=bool(args.apply and not args.dry_run),
                ports=ports or [PLEX_PORT],
                allow_lan=args.allow_lan,
                rollback=args.rollback,
            )
            emit(payload, as_json)
            return 0 if payload.get("ok") else 1
        if args.command == "fix-remote":
            payload = fix_remote_access(
                apply=bool(args.apply), public_https=args.public_https
            )
            emit(payload, as_json)
            return 0 if payload.get("ok") else 1
        if args.command == "public-https":
            payload = public_https(
                apply=bool(args.apply and not args.dry_run),
                disable=bool(args.disable),
                use_cache=bool(args.use_cache),
            )
            emit(payload, as_json)
            return 0 if payload.get("ok") else 1
        if args.command == "quarantine":
            payload = quarantine(apply=bool(args.apply))
            emit(payload, as_json)
            return 0 if payload.get("ok") else 1
        if args.command == "rollback":
            payload = rollback(args.backup, apply=bool(args.apply))
            emit(payload, as_json)
            return 0 if payload.get("ok") else 1
    except ToolError as exc:
        print(json.dumps({"error": str(exc)}, indent=2))
        return 2
    return 2


if __name__ == "__main__":
    sys.exit(main())
