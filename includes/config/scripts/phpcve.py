#!/usr/bin/env python3
"""phpcve.py - audit et remediation des CVE PHP2Shell.

CVE-2026-109618 / CVE-2026-109619 : corruption memoire dans le coeur de PHP,
execution de code a distance non authentifiee. Correctifs upstream :
PHP 8.2.35, 8.3.36, 8.4.27, 8.5.12.

Le script couvre :
  - l'hote (paquets PHP, SAPI, services, exposition) ;
  - les conteneurs Docker (PHP compile ou paquet de distribution) ;
  - l'inventaire SSDV2 (WebUI Python, applications PHP du catalogue).

Sortie JSON stable pour ssdv2ctl / WebUI, sortie lisible pour le menu.

Usage :
    phpcve.py scan [--json] [--deep]
    phpcve.py status
    phpcve.py report
    phpcve.py fix-host
    phpcve.py fix-app <app>
    phpcve.py fix-container <conteneur> [--force]
    phpcve.py stop <conteneur> [--force]
    phpcve.py harden-host
    phpcve.py selftest
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

VERSION = "1.0.0"
SCHEMA_VERSION = 1

CVE_IDS = ("CVE-2026-109618", "CVE-2026-109619")

FIXED_UPSTREAM = {
    (8, 2): (8, 2, 35),
    (8, 3): (8, 3, 36),
    (8, 4): (8, 4, 27),
    (8, 5): (8, 5, 12),
}

# Versions corrigees par Ubuntu (USN-8948-1). Le numero upstream de PHP ne
# change pas (8.3.6 reste 8.3.6) : il faut comparer la version du paquet.
UBUNTU_FIXED = {
    ("24.04", "8.3"): "8.3.6-0ubuntu0.24.04.13",
    ("22.04", "8.1"): "8.1.2-1ubuntu2.28",
    ("26.04", "8.5"): "8.5.4-0ubuntu1.5",
    ("26.10", "8.5"): "8.5.9-0ubuntu2.1",
}

# Index utilise uniquement pour signaler les applications PHP du catalogue
# SSDV2. La detection reelle reste dynamique (docker exec).
PHP_CATALOG_HINTS = (
    "nextcloud",
    "bookstack",
    "grocy",
    "piwigo",
    "wordpress",
    "yourls",
    "mediawiki",
    "chevereto",
    "espocrm",
    "freshrss",
    "shaarli",
    "ttrss",
    "cypht",
    "monica",
    "pterodactyl/panel",
    "vvveb",
    "baikal",
    "rutorrent",
    "prestashop",
)

PHP_INFO_CODE = (
    'echo json_encode(['
    '"version"=>PHP_VERSION,'
    '"sapi"=>PHP_SAPI,'
    '"ini"=>php_ini_loaded_file(),'
    '"scanned"=>php_ini_scanned_files(),'
    '"session_upload_progress"=>ini_get("session.upload_progress.enabled"),'
    '"memory_limit"=>ini_get("memory_limit"),'
    '"fatal_error_backtraces"=>ini_get("fatal_error_backtraces"),'
    '"post_max_size"=>ini_get("post_max_size"),'
    '"upload_max_filesize"=>ini_get("upload_max_filesize"),'
    '"opcache"=>ini_get("opcache.enable")'
    ']);'
)

SHELL_PROBE = (
    "for p in /usr/local/bin/php /usr/bin/php /usr/local/sbin/php-fpm "
    "/usr/sbin/php-fpm; do "
    "if [ -x \"$p\" ]; then "
    "if \"$p\" -r '" + PHP_INFO_CODE + "' 2>/dev/null; then exit 0; fi; "
    "if \"$p\" -v 2>/dev/null | head -1; then exit 0; fi; "
    "fi; done; exit 1"
)

ENV_FILE = Path.home() / ".config" / "ssd" / "env"


class ToolError(Exception):
    """Erreur d'execution d'un outil externe."""


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


def resolve_settings(source_arg: str | None, storage_arg: str | None) -> tuple[Path, Path]:
    values = load_env_file(ENV_FILE)
    source = (
        source_arg
        or os.environ.get("SETTINGS_SOURCE")
        or values.get("SETTINGS_SOURCE")
        or str(Path.home() / "seedbox-compose")
    )
    storage = (
        storage_arg
        or os.environ.get("SETTINGS_STORAGE")
        or values.get("SETTINGS_STORAGE")
        or str(Path.home() / "seedbox")
    )
    return Path(source), Path(storage)


def run_cmd(
    argv: list[str],
    timeout: int = 30,
    env: dict[str, str] | None = None,
    input_text: str | None = None,
) -> subprocess.CompletedProcess:
    kwargs: dict = {
        "capture_output": True,
        "text": True,
        "timeout": timeout,
        "check": False,
        "env": env,
    }
    if input_text is None:
        kwargs["stdin"] = subprocess.DEVNULL
    else:
        kwargs["input"] = input_text
    try:
        return subprocess.run(argv, **kwargs)
    except subprocess.TimeoutExpired as exc:
        raise ToolError(f"delai depasse ({timeout}s) : {' '.join(argv)}") from exc
    except OSError as exc:
        raise ToolError(f"execution impossible : {' '.join(argv)} : {exc}") from exc


def tail_lines(text: str | None, limit: int = 40) -> list[str]:
    if not text:
        return []
    return text.strip().splitlines()[-limit:]


def parse_json_stdout(text: str | None) -> dict | None:
    if not text:
        return None
    start = text.find("{")
    end = text.rfind("}")
    if start < 0 or end <= start:
        return None
    try:
        payload = json.loads(text[start : end + 1])
    except json.JSONDecodeError:
        return None
    return payload if isinstance(payload, dict) else None


def parse_os_release_text(text: str) -> dict[str, str | None]:
    values: dict[str, str] = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip('"').strip("'")
    return {
        "id": values.get("ID"),
        "version_id": values.get("VERSION_ID"),
        "pretty": values.get("PRETTY_NAME"),
    }


def parse_os_release_file(path: str = "/etc/os-release") -> dict[str, str | None]:
    try:
        return parse_os_release_text(Path(path).read_text(encoding="utf-8"))
    except OSError:
        return {"id": None, "version_id": None, "pretty": None}


def php_version_tuple(version: str | None) -> tuple[int, int, int] | None:
    if not version:
        return None
    match = re.match(r"(\d+)\.(\d+)\.(\d+)", version)
    if not match:
        return None
    return (int(match.group(1)), int(match.group(2)), int(match.group(3)))


def php_series(version: str | None) -> str | None:
    parsed = php_version_tuple(version)
    if not parsed:
        return None
    return f"{parsed[0]}.{parsed[1]}"


def parse_package_series(name: str) -> str | None:
    match = re.search(r"php[-_]?(\d+)\.(\d+)", name, re.IGNORECASE)
    if match:
        return f"{match.group(1)}.{match.group(2)}"
    match = re.search(r"php(\d)(\d)", name, re.IGNORECASE)
    if match:
        return f"{match.group(1)}.{match.group(2)}"
    return None


def _simple_version_compare(left: str, right: str) -> int:
    left_tokens = re.findall(r"\d+|[A-Za-z]+", left)
    right_tokens = re.findall(r"\d+|[A-Za-z]+", right)
    for index in range(max(len(left_tokens), len(right_tokens))):
        left_token = left_tokens[index] if index < len(left_tokens) else None
        right_token = right_tokens[index] if index < len(right_tokens) else None
        if left_token is None:
            return -1
        if right_token is None:
            return 1
        if left_token.isdigit() and right_token.isdigit():
            left_num = int(left_token)
            right_num = int(right_token)
            if left_num != right_num:
                return -1 if left_num < right_num else 1
        elif left_token != right_token:
            return -1 if left_token < right_token else 1
    return 0


def version_compare(left: str, right: str) -> int:
    """Compare deux versions Debian/Ubuntu, avec fallback portable."""
    debian_style = any(token in f"{left}{right}" for token in ("ubuntu", "deb", ":", "~"))
    if debian_style and shutil.which("dpkg") and os.path.exists("/usr/bin/dpkg"):
        try:
            less = run_cmd(["dpkg", "--compare-versions", left, "lt", right], timeout=5)
            if less.returncode == 0:
                return -1
            equal = run_cmd(["dpkg", "--compare-versions", left, "eq", right], timeout=5)
            if equal.returncode == 0:
                return 0
            if less.returncode != 2 and equal.returncode != 2:
                return 1
        except ToolError:
            pass
    return _simple_version_compare(left, right)


def upstream_vulnerable(version: str | None) -> bool | None:
    parsed = php_version_tuple(version)
    if parsed is None:
        return None
    branch = (parsed[0], parsed[1])
    fixed = FIXED_UPSTREAM.get(branch)
    if fixed is None:
        # PHP 8.1 et anterieurs : plus de correctif upstream.
        return True
    return parsed < fixed


def fixed_for_os(os_info: dict[str, str | None], series: str | None) -> str | None:
    if not series:
        return None
    if (os_info.get("id") or "").lower() == "ubuntu":
        return UBUNTU_FIXED.get((os_info.get("version_id") or "", series))
    return None


def parse_probe_output(stdout: str | None) -> dict | None:
    if not stdout:
        return None
    text = stdout.strip()
    payload = parse_json_stdout(text)
    if payload:
        return payload
    match = re.search(r"PHP (\d+\.\d+\.\d+)", text)
    if match:
        return {
            "version": match.group(1),
            "sapi": None,
            "ini": None,
            "scanned": None,
            "session_upload_progress": None,
            "memory_limit": None,
            "fatal_error_backtraces": None,
            "post_max_size": None,
            "upload_max_filesize": None,
            "opcache": None,
        }
    return None


def host_php_info() -> dict:
    php = shutil.which("php")
    if not php:
        return {"available": False}
    result = run_cmd([php, "-r", PHP_INFO_CODE], timeout=10)
    info = parse_probe_output(result.stdout) if result.returncode == 0 else None
    if not info:
        version_result = run_cmd([php, "-v"], timeout=10)
        info = parse_probe_output(version_result.stdout) or {}
    info["available"] = True
    info["binary"] = php
    info["series"] = php_series(info.get("version"))
    return info


def parse_dpkg_packages(text: str) -> list[dict[str, str | None]]:
    packages = []
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        if "\t" in line:
            name, version = line.split("\t", 1)
        else:
            parts = line.split(None, 1)
            if len(parts) != 2:
                continue
            name, version = parts
        if not (name.startswith("php") or name.startswith("libapache2-mod-php")):
            continue
        series = parse_package_series(name) or php_series(version)
        packages.append(
            {
                "name": name,
                "version": version.strip(),
                "series": series,
            }
        )
    return packages


def parse_apk_packages(text: str) -> list[dict[str, str | None]]:
    packages = []
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        match = re.match(r"^(php\S*?)-(\d[\w.+~:-]*)$", line)
        if not match:
            continue
        name, version = match.group(1), match.group(2)
        packages.append(
            {
                "name": name,
                "version": version,
                "series": parse_package_series(name),
            }
        )
    return packages


def host_packages() -> tuple[str | None, list[dict[str, str | None]]]:
    if shutil.which("dpkg-query"):
        result = run_cmd(
            ["dpkg-query", "-W", "-f=${Package}\t${Version}\n"], timeout=20
        )
        if result.returncode == 0:
            return "dpkg", parse_dpkg_packages(result.stdout)
    if shutil.which("rpm"):
        result = run_cmd(
            ["rpm", "-qa", "--qf", "%{NAME}\t%{VERSION}-%{RELEASE}\n"], timeout=20
        )
        if result.returncode == 0:
            return "rpm", parse_dpkg_packages(result.stdout)
    if shutil.which("apk"):
        result = run_cmd(["apk", "info", "-v"], timeout=20)
        if result.returncode == 0:
            return "apk", parse_apk_packages(result.stdout)
    return None, []


def apt_candidate(package: str) -> str | None:
    if not shutil.which("apt-cache"):
        return None
    result = run_cmd(["apt-cache", "policy", package], timeout=10)
    if result.returncode != 0:
        return None
    match = re.search(r"(?:Candidat|Candidate)\s*:\s*(\S+)", result.stdout)
    if not match:
        return None
    value = match.group(1).strip()
    if value in ("(aucun)", "(none)", "aucun", "none"):
        return None
    return value


def service_active(name: str) -> bool | None:
    if not shutil.which("systemctl"):
        return None
    try:
        result = run_cmd(["systemctl", "is-active", "--quiet", name], timeout=5)
    except ToolError:
        return None
    return result.returncode == 0


def host_series_results(
    os_info: dict[str, str | None],
    php_info: dict,
    packages: list[dict[str, str | None]],
) -> list[dict]:
    series_values = sorted(
        {p["series"] for p in packages if p.get("series")},
        key=lambda value: tuple(int(part) for part in value.split(".")),
    )
    if not series_values and php_info.get("series"):
        series_values = [php_info["series"]]

    results = []
    for series in series_values:
        relevant = [p for p in packages if p.get("series") == series]
        fixed = fixed_for_os(os_info, series)
        candidate = None
        candidate_package = None
        for preferred in (f"php{series}", f"php{series}-cli", f"php{series}-common"):
            if any(p["name"] == preferred for p in relevant):
                candidate = apt_candidate(preferred)
                candidate_package = preferred
                if candidate:
                    break
        if candidate is None and relevant:
            candidate_package = relevant[0]["name"]
            candidate = apt_candidate(candidate_package)

        package_status = []
        if fixed and relevant:
            for package in relevant:
                comparison = version_compare(str(package["version"]), fixed)
                package_status.append(
                    {
                        "name": package["name"],
                        "installed": package["version"],
                        "fixed": fixed,
                        "vulnerable": comparison < 0,
                    }
                )
            vulnerable = any(item["vulnerable"] for item in package_status)
            status = "vulnerable" if vulnerable else "patched"
            reason = (
                f"paquet {package_status[0]['name']} {package_status[0]['installed']} "
                f"< {fixed}"
                if vulnerable
                else f"paquet >= {fixed}"
            )
            fixed_version = fixed
        else:
            upstream_status = upstream_vulnerable(php_info.get("version"))
            if upstream_status is None:
                status = "unknown"
                reason = "version PHP non determinee"
            elif upstream_status:
                status = "vulnerable"
                reason = (
                    f"PHP {php_info.get('version')} < correctif upstream "
                    f"{'.'.join(str(part) for part in FIXED_UPSTREAM.get(tuple(int(x) for x in series.split('.')), (8, 3, 36)))}"
                )
            else:
                status = "patched"
                reason = "version PHP >= correctif upstream"
            if status == "vulnerable" and (os_info.get("id") or "").lower() != "ubuntu":
                reason += " (backport distributeur possible, verifier l'avis vendor)"
            fixed_version = fixed

        fix_available = False
        if fixed_version and candidate:
            fix_available = version_compare(candidate, fixed_version) >= 0

        results.append(
            {
                "series": series,
                "status": status,
                "reason": reason,
                "fixed": fixed_version,
                "candidate": candidate,
                "candidate_package": candidate_package,
                "fix_available": fix_available,
                "packages": package_status,
            }
        )
    return results


def scan_host() -> dict:
    os_info = parse_os_release_file()
    try:
        php_info = host_php_info()
    except ToolError as exc:
        php_info = {"available": False, "error": str(exc)}
    try:
        package_manager, packages = host_packages()
    except ToolError as exc:
        package_manager, packages = None, []
        packages_error = str(exc)
    else:
        packages_error = None

    series_values = sorted(
        {p["series"] for p in packages if p.get("series")},
        key=lambda value: tuple(int(part) for part in value.split(".")),
    )
    services: dict[str, bool | None] = {
        "apache2": service_active("apache2"),
        "nginx": service_active("nginx"),
    }
    for series in series_values:
        services[f"php{series}-fpm"] = service_active(f"php{series}-fpm")

    series_results = host_series_results(os_info, php_info, packages)
    if not series_results:
        status = "unknown"
        reason = "aucune installation PHP detectee"
    elif any(item["status"] == "vulnerable" for item in series_results):
        status = "vulnerable"
        reason = "au moins une installation PHP est vulnerable"
    elif any(item["status"] == "unknown" for item in series_results):
        status = "unknown"
        reason = "etat PHP indetermine"
    else:
        status = "patched"
        reason = "toutes les installations PHP sont patchees"

    sapi = php_info.get("sapi")
    web_sapi = sapi in ("apache2handler", "fpm-fcgi", "cgi-fcgi")
    web_service = any(
        value is True
        for name, value in services.items()
        if name in ("apache2", "nginx") or "fpm" in name
    )
    if web_sapi or web_service:
        exposure = "web"
    elif php_info.get("available"):
        exposure = "cli"
    else:
        exposure = "aucune"

    vulnerable_series = [
        item for item in series_results if item["status"] == "vulnerable"
    ]
    packages_to_upgrade: list[str] = []
    for item in vulnerable_series:
        for package in packages:
            if package.get("series") == item["series"]:
                packages_to_upgrade.append(str(package["name"]))
    packages_to_upgrade = sorted(set(packages_to_upgrade))

    return {
        "os": os_info,
        "php": php_info,
        "package_manager": package_manager,
        "packages": packages,
        "packages_error": packages_error,
        "services": services,
        "exposure": exposure,
        "status": status,
        "reason": reason,
        "series": series_results,
        "packages_to_upgrade": packages_to_upgrade,
        "fix_available": any(item["fix_available"] for item in series_results),
        "candidate": next(
            (
                item["candidate"]
                for item in series_results
                if item.get("candidate")
            ),
            None,
        ),
    }


def read_container_os(name: str) -> dict[str, str | None]:
    try:
        result = run_cmd(
            ["docker", "exec", name, "cat", "/etc/os-release"], timeout=10
        )
    except ToolError:
        return {"id": None, "version_id": None, "pretty": None}
    if result.returncode != 0:
        return {"id": None, "version_id": None, "pretty": None}
    return parse_os_release_text(result.stdout)


def read_container_packages(name: str) -> list[dict[str, str | None]]:
    probes = (
        ["docker", "exec", name, "dpkg-query", "-W", "-f=${Package}\t${Version}\n"],
        ["docker", "exec", name, "rpm", "-qa", "--qf", "%{NAME}\t%{VERSION}-%{RELEASE}\n"],
        ["docker", "exec", name, "apk", "info", "-v"],
    )
    for argv in probes:
        try:
            result = run_cmd(argv, timeout=15)
        except ToolError:
            continue
        if result.returncode != 0 or not result.stdout.strip():
            continue
        if argv[3] == "apk":
            packages = parse_apk_packages(result.stdout)
        else:
            packages = parse_dpkg_packages(result.stdout)
        if packages:
            return packages
    return []


def read_container_pm_max_requests(name: str) -> str | None:
    command = (
        "grep -Rhs 'pm.max_requests' /usr/local/etc/php-fpm.d "
        "/usr/local/etc/php /etc/php*/fpm/pool.d 2>/dev/null | tail -n 1"
    )
    try:
        result = run_cmd(["docker", "exec", name, "sh", "-c", command], timeout=10)
    except ToolError:
        return None
    if result.returncode != 0 or not result.stdout.strip():
        return None
    match = re.search(r"pm\.max_requests\s*=\s*(\d+)", result.stdout)
    return match.group(1) if match else None


def probe_container(name: str) -> dict | None:
    attempts = (
        ["docker", "exec", name, "php", "-r", PHP_INFO_CODE],
        ["docker", "exec", name, "sh", "-c", SHELL_PROBE],
        ["docker", "exec", "-u", "0", name, "sh", "-c", SHELL_PROBE],
        ["docker", "exec", name, "/usr/local/bin/php", "-r", PHP_INFO_CODE],
        ["docker", "exec", name, "/usr/bin/php", "-r", PHP_INFO_CODE],
        ["docker", "exec", name, "php-fpm", "-v"],
        ["docker", "exec", name, "/usr/local/sbin/php-fpm", "-v"],
        ["docker", "exec", name, "/usr/sbin/php-fpm", "-v"],
    )
    for argv in attempts:
        try:
            result = run_cmd(argv, timeout=20)
        except ToolError:
            continue
        if result.returncode == 0 and result.stdout.strip():
            parsed = parse_probe_output(result.stdout)
            if parsed:
                return parsed
    return None


def probe_image(image: str) -> dict | None:
    attempts = (
        [
            "docker",
            "run",
            "--rm",
            "--network",
            "none",
            "--pull",
            "never",
            "--entrypoint",
            "php",
            image,
            "-r",
            PHP_INFO_CODE,
        ],
        [
            "docker",
            "run",
            "--rm",
            "--network",
            "none",
            "--pull",
            "never",
            "--entrypoint",
            "sh",
            image,
            "-c",
            SHELL_PROBE,
        ],
    )
    for argv in attempts:
        try:
            result = run_cmd(argv, timeout=40)
        except ToolError:
            continue
        if result.returncode == 0 and result.stdout.strip():
            parsed = parse_probe_output(result.stdout)
            if parsed:
                return parsed
    return None


def mitigation_state(info: dict, pm_max_requests: str | None) -> dict:
    session_value = info.get("session_upload_progress")
    session_ok = str(session_value).strip().lower() in ("", "0", "off", "false")
    version = info.get("version")
    parsed = php_version_tuple(version)
    backtrace_relevant = bool(parsed and parsed[:2] >= (8, 5))
    backtrace_value = info.get("fatal_error_backtraces")
    backtrace_ok = None
    if backtrace_relevant:
        backtrace_ok = str(backtrace_value).strip().lower() in ("", "0", "off", "false")
    pm_ok = None
    if pm_max_requests is not None:
        pm_ok = str(pm_max_requests).strip() == "1"
    return {
        "source": "php-cli",
        "warning": (
            "Valeurs ini lues via le binaire CLI ; verifier la configuration "
            "FPM/Apache si le conteneur sert des requetes web."
        ),
        "session_upload_progress": {
            "value": session_value,
            "ok": session_ok,
        },
        "fatal_error_backtraces": {
            "value": backtrace_value,
            "relevant": backtrace_relevant,
            "ok": backtrace_ok,
        },
        "memory_limit": {
            "value": info.get("memory_limit"),
            "advisory_value": "-1",
        },
        "post_max_size": {"value": info.get("post_max_size")},
        "upload_max_filesize": {"value": info.get("upload_max_filesize")},
        "pm_max_requests": {
            "value": pm_max_requests,
            "ok": pm_ok,
        },
    }


def classify_container(
    info: dict,
    packages: list[dict[str, str | None]],
    os_info: dict[str, str | None],
) -> tuple[str, str | None, str]:
    version = info.get("version")
    if not version:
        return "unknown", None, "version PHP non determinee"
    series = php_series(version)
    ini_text = f"{info.get('ini') or ''} {info.get('scanned') or ''}"
    if "/usr/local/etc/php" in ini_text:
        origin = "upstream"
    elif packages:
        origin = "distro"
    else:
        origin = "unknown"

    fixed = fixed_for_os(os_info, series) if origin == "distro" else None
    if fixed and packages:
        relevant = [p for p in packages if p.get("series") == series]
        if relevant:
            if any(
                version_compare(str(package["version"]), fixed) < 0
                for package in relevant
            ):
                first = relevant[0]
                return (
                    "vulnerable",
                    fixed,
                    f"paquet {first['name']} {first['version']} < {fixed}",
                )
            return "patched", fixed, f"paquet >= {fixed}"

    upstream = upstream_vulnerable(version)
    if upstream is None:
        return "unknown", fixed, "version PHP non reconnue"
    if upstream:
        reason = f"PHP {version} < correctif upstream"
        if origin == "distro":
            reason += " (backport distributeur possible, verifier l'avis vendor)"
        return "vulnerable", fixed, reason
    return "patched", fixed, "version PHP >= correctif"


def scan_container(
    name: str,
    image: str,
    state: str,
    app: str | None,
    exposed: bool,
    deep: bool,
) -> dict:
    base = {
        "name": name,
        "image": image,
        "state": state,
        "app": app,
        "managed": bool(app),
        "exposed": exposed,
        "is_php": False,
        "php_version": None,
        "sapi": None,
        "origin": None,
        "packages": [],
        "os": None,
        "status": "not_php",
        "reason": "aucun runtime PHP detecte",
        "fixed": None,
        "mitigations": {},
        "update_strategy": "manual",
    }

    if state != "running":
        if not deep:
            base["status"] = "not_scanned"
            base["reason"] = "conteneur arrete (utiliser --deep pour inspecter l'image)"
            return base
        info = probe_image(image)
    else:
        info = probe_container(name)

    if not info:
        return base

    packages = read_container_packages(name) if state == "running" else []
    os_info = read_container_os(name) if state == "running" else {}
    pm_max_requests = (
        read_container_pm_max_requests(name) if state == "running" else None
    )
    status, fixed, reason = classify_container(info, packages, os_info or {})
    if state != "running":
        reason += " [scan image : paquets de distribution non inspectes]"
    ini_text = f"{info.get('ini') or ''} {info.get('scanned') or ''}"
    origin = (
        "upstream"
        if "/usr/local/etc/php" in ini_text
        else "distro"
        if packages
        else "unknown"
    )
    base.update(
        {
            "is_php": True,
            "php_version": info.get("version"),
            "sapi": info.get("sapi"),
            "origin": origin,
            "packages": packages,
            "os": os_info,
            "status": status,
            "reason": reason,
            "fixed": fixed,
            "mitigations": mitigation_state(info, pm_max_requests),
            "update_strategy": "update_app" if app else "manual",
        }
    )
    return base


def list_containers() -> list[dict]:
    try:
        result = run_cmd(
            ["docker", "ps", "-a", "--format", "{{json .}}"], timeout=30
        )
    except ToolError as exc:
        raise ToolError(f"Docker indisponible : {exc}") from exc
    if result.returncode != 0:
        raise ToolError(
            f"docker ps a echoue : {result.stderr.strip() or 'erreur inconnue'}"
        )
    containers = []
    for line in result.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        labels_text = entry.get("Labels") or ""
        labels: dict[str, str] = {}
        for item in labels_text.split(","):
            if "=" in item:
                key, value = item.split("=", 1)
                labels[key.strip()] = value.strip()
        ports = entry.get("Ports") or ""
        exposed = labels.get("traefik.enable", "").lower() == "true" or bool(
            ports.strip()
        )
        containers.append(
            {
                "name": entry.get("Names", ""),
                "image": entry.get("Image", ""),
                "state": entry.get("State", ""),
                "app": labels.get("ssdv2.app"),
                "exposed": exposed,
            }
        )
    return sorted(containers, key=lambda item: item["name"])


def scan_containers(deep: bool = False) -> list[dict]:
    results = []
    for entry in list_containers():
        results.append(
            scan_container(
                entry["name"],
                entry["image"],
                entry["state"],
                entry["app"],
                entry["exposed"],
                deep,
            )
        )
    return results


def discover_php_catalog(source: Path) -> list[str]:
    found: set[str] = set()
    vars_root = source / "includes" / "dockerapps" / "vars"
    pretasks_root = source / "includes" / "dockerapps" / "pretasks"
    templates_root = source / "includes" / "dockerapps" / "templates"
    roots = (vars_root, pretasks_root, templates_root)
    hints = [hint.lower() for hint in PHP_CATALOG_HINTS]
    for root in roots:
        if not root.is_dir():
            continue
        for path in root.rglob("*"):
            if not path.is_file() or path.suffix not in (".yml", ".yaml", ".j2"):
                continue
            try:
                text = path.read_text(encoding="utf-8", errors="ignore").lower()
            except OSError:
                continue
            image_lines = [
                line
                for line in text.splitlines()
                if re.match(r"\s*image\s*:", line, re.IGNORECASE)
            ]
            if not any(
                any(hint in line for hint in hints) or "php" in line
                for line in image_lines
            ):
                continue
            if root == templates_root:
                name = path.parent.name
                if path.parent == templates_root or name in (
                    "generique",
                    "ansible",
                    "traefik",
                ):
                    continue
            else:
                name = path.stem.split(".")[0]
            if name:
                found.add(name)
    return sorted(found)


def scan_ssdv2(source: Path, storage: Path, containers: list[dict]) -> dict:
    webui = next(
        (
            container
            for container in containers
            if container.get("name") == "ssdv2webui"
            or container.get("app") == "ssdv2webui"
        ),
        None,
    )
    installed_php_apps = sorted(
        {
            container["app"]
            for container in containers
            if container.get("app") and container.get("is_php")
        }
    )
    return {
        "source": str(source),
        "storage": str(storage),
        "webui": {
            "container": webui.get("name") if webui else None,
            "runtime": "python",
            "php": False,
        },
        "installed_php_apps": installed_php_apps,
        "php_catalog_apps": discover_php_catalog(source),
    }


def build_scan(source: Path, storage: Path, deep: bool = False) -> dict:
    host = scan_host()
    containers = scan_containers(deep=deep)
    ssdv2 = scan_ssdv2(source, storage, containers)
    vulnerable_containers = [
        container
        for container in containers
        if container.get("status") == "vulnerable"
    ]
    php_containers = [container for container in containers if container.get("is_php")]
    summary = {
        "host": host.get("status"),
        "containers_total": len(containers),
        "php_containers": len(php_containers),
        "vulnerable": len(vulnerable_containers)
        + (1 if host.get("status") == "vulnerable" else 0),
        "vulnerable_containers": len(vulnerable_containers),
        "patched": sum(
            1 for container in php_containers if container.get("status") == "patched"
        )
        + (1 if host.get("status") == "patched" else 0),
        "unknown": sum(
            1
            for container in php_containers
            if container.get("status") in ("unknown", "not_scanned")
        )
        + (1 if host.get("status") == "unknown" else 0),
        "not_php": len(containers) - len(php_containers),
    }
    summary["ok"] = summary["vulnerable"] == 0
    return {
        "schema": SCHEMA_VERSION,
        "version": VERSION,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "cves": list(CVE_IDS),
        "host": host,
        "containers": containers,
        "ssdv2": ssdv2,
        "summary": summary,
    }


def report_text(payload: dict) -> str:
    lines: list[str] = []
    lines.append("PHP2SHELL - CVE-2026-109618 / CVE-2026-109619")
    lines.append("=" * 68)
    host = payload.get("host", {})
    os_info = host.get("os", {})
    php_info = host.get("php", {})
    lines.append(f"Hote : {os_info.get('pretty') or 'inconnu'}")
    if php_info.get("available"):
        lines.append(
            f"  PHP : {php_info.get('version') or '?'} "
            f"({php_info.get('sapi') or 'sapi inconnu'})"
        )
        lines.append(f"  Binaire : {php_info.get('binary') or '?'}")
    else:
        lines.append("  PHP : non installe ou non detecte")
    lines.append(f"  Exposition : {host.get('exposure') or 'inconnue'}")
    lines.append(f"  Statut : {str(host.get('status') or 'inconnu').upper()}")
    if host.get("reason"):
        lines.append(f"  Detail : {host.get('reason')}")
    for item in host.get("series", []) or []:
        fixed = item.get("fixed") or "n/a"
        candidate = item.get("candidate") or "n/a"
        lines.append(
            f"  Serie {item.get('series')} : {str(item.get('status')).upper()} "
            f"(correctif {fixed}, candidat {candidate})"
        )
        if item.get("reason"):
            lines.append(f"    {item.get('reason')}")
    lines.append("")
    php_containers = [
        container for container in payload.get("containers", []) if container.get("is_php")
    ]
    if not php_containers:
        lines.append("Conteneurs PHP : aucun runtime PHP detecte.")
    else:
        lines.append("Conteneurs PHP :")
        for container in php_containers:
            app = container.get("app") or "hors SSDV2"
            lines.append(
                f"  - {container.get('name')} [{app}] "
                f"{container.get('php_version') or '?'} "
                f"({container.get('sapi') or '?'}) -> "
                f"{str(container.get('status')).upper()}"
            )
            if container.get("reason"):
                lines.append(f"      {container.get('reason')}")
            mitigations = container.get("mitigations") or {}
            session = (mitigations.get("session_upload_progress") or {}).get("value")
            pm_value = (mitigations.get("pm_max_requests") or {}).get("value")
            lines.append(
                f"      mitigations : session.upload_progress={session!r} "
                f"pm.max_requests={pm_value or 'n/a'}"
            )
    lines.append("")
    ssdv2 = payload.get("ssdv2", {})
    lines.append("SSDV2 :")
    webui = ssdv2.get("webui", {})
    lines.append(
        f"  WebUI : {webui.get('runtime') or '?'} (PHP : "
        f"{'oui' if webui.get('php') else 'non'})"
    )
    lines.append(
        "  Applications PHP installees : "
        + (", ".join(ssdv2.get("installed_php_apps") or []) or "aucune")
    )
    lines.append(
        "  Applications PHP du catalogue : "
        + (", ".join(ssdv2.get("php_catalog_apps") or []) or "aucune")
    )
    summary = payload.get("summary", {})
    lines.append("")
    lines.append(
        f"Resume : {summary.get('vulnerable', 0)} vulnerable(s), "
        f"{summary.get('patched', 0)} patche(s), "
        f"{summary.get('unknown', 0)} inconnu(s), "
        f"{summary.get('not_php', 0)} non PHP."
    )
    lines.append(
        "Rappel : les mitigations sont partielles ; le patch PHP reste obligatoire."
    )
    return "\n".join(lines)


def action_text(payload: dict) -> str:
    lines = [
        f"Action : {payload.get('action') or 'php2shell'}",
        f"Resultat : {'OK' if payload.get('ok') else 'ECHEC'}",
    ]
    if payload.get("message"):
        lines.append(str(payload["message"]))
    for command in payload.get("commands", []) or []:
        lines.append(f"  $ {command}")
    for item in payload.get("containers", []) or []:
        if isinstance(item, dict):
            lines.append(
                f"  - {item.get('name')} : "
                f"{'OK' if item.get('ok') else 'ECHEC'}"
                + (f" ({item.get('before')} -> {item.get('after')})" if item.get("before") else "")
            )
    for path in payload.get("files", []) or []:
        lines.append(f"  fichier : {path}")
    for line in payload.get("output_tail", []) or []:
        lines.append(f"  | {line}")
    return "\n".join(lines)


def emit(payload: dict, as_json: bool) -> None:
    if as_json:
        print(json.dumps(payload, indent=2, ensure_ascii=False))
    elif payload.get("action"):
        print(action_text(payload))
    else:
        print(report_text(payload))


def _sudo_prefix() -> list[str] | None:
    if os.geteuid() == 0:
        return []
    if not shutil.which("sudo"):
        return None
    try:
        result = run_cmd(["sudo", "-n", "true"], timeout=5)
    except ToolError:
        return None
    return ["sudo"] if result.returncode == 0 else None


def _restart_services(services: list[str], sudo: list[str], no_restart: bool) -> list[str]:
    restarted = []
    if no_restart:
        return restarted
    for service in services:
        if service_active(service):
            try:
                result = run_cmd([*sudo, "systemctl", "restart", service], timeout=120)
            except ToolError:
                continue
            if result.returncode == 0:
                restarted.append(service)
    return restarted


def fix_host(source: Path, storage: Path, no_restart: bool = False) -> dict:
    before = scan_host()
    if before.get("status") == "patched":
        return {
            "schema": SCHEMA_VERSION,
            "action": "fix-host",
            "ok": True,
            "message": "PHP est deja patche sur l'hote.",
            "before": before,
            "after": before,
        }

    sudo = _sudo_prefix()
    if sudo is None:
        return {
            "schema": SCHEMA_VERSION,
            "action": "fix-host",
            "ok": False,
            "message": "Droits root/sudo non disponibles (action a lancer en CLI sur l'hote).",
            "before": before,
        }

    package_manager = before.get("package_manager")
    commands: list[str] = []
    output: list[str] = []

    if package_manager == "dpkg":
        update = [*sudo, "apt-get", "update"]
        commands.append(" ".join(update))
        result = run_cmd(update, timeout=600)
        output.extend(tail_lines(result.stdout))
        output.extend(tail_lines(result.stderr))
        if result.returncode != 0:
            return {
                "schema": SCHEMA_VERSION,
                "action": "fix-host",
                "ok": False,
                "message": "apt-get update a echoue.",
                "commands": commands,
                "output_tail": output,
                "before": before,
            }
        refreshed = scan_host()
        packages = refreshed.get("packages_to_upgrade") or []
        if not packages:
            return {
                "schema": SCHEMA_VERSION,
                "action": "fix-host",
                "ok": False,
                "message": "Aucun paquet PHP a mettre a jour apres apt-get update.",
                "commands": commands,
                "output_tail": output,
                "before": before,
                "after": refreshed,
            }
        install = [
            *sudo,
            "env",
            "DEBIAN_FRONTEND=noninteractive",
            "apt-get",
            "install",
            "--only-upgrade",
            "-y",
            "-o",
            "Dpkg::Options::=--force-confdef",
            "-o",
            "Dpkg::Options::=--force-confold",
            *packages,
        ]
        commands.append(" ".join(install))
        result = run_cmd(install, timeout=900)
        output.extend(tail_lines(result.stdout))
        output.extend(tail_lines(result.stderr))
        if result.returncode != 0:
            return {
                "schema": SCHEMA_VERSION,
                "action": "fix-host",
                "ok": False,
                "message": "apt-get install a echoue.",
                "commands": commands,
                "output_tail": output,
                "before": before,
                "after": scan_host(),
            }
    elif package_manager == "rpm":
        packages = before.get("packages_to_upgrade") or []
        dnf = shutil.which("dnf") or shutil.which("yum") or "dnf"
        install = [*sudo, dnf, "upgrade", "-y", *packages]
        commands.append(" ".join(install))
        result = run_cmd(install, timeout=900)
        output.extend(tail_lines(result.stdout))
        output.extend(tail_lines(result.stderr))
    elif package_manager == "apk":
        packages = before.get("packages_to_upgrade") or []
        install = [*sudo, "apk", "upgrade", *packages]
        commands.append(" ".join(install))
        result = run_cmd(install, timeout=900)
        output.extend(tail_lines(result.stdout))
        output.extend(tail_lines(result.stderr))
    else:
        return {
            "schema": SCHEMA_VERSION,
            "action": "fix-host",
            "ok": False,
            "message": "Gestionnaire de paquets non supporte.",
            "before": before,
        }

    after = scan_host()
    services = ["apache2"]
    for item in after.get("series", []) or []:
        services.append(f"php{item.get('series')}-fpm")
    restarted = _restart_services(services, sudo, no_restart)
    ok = after.get("status") == "patched"
    return {
        "schema": SCHEMA_VERSION,
        "action": "fix-host",
        "ok": ok,
        "message": (
            "PHP est patche sur l'hote."
            if ok
            else "La mise a jour est terminee mais PHP reste vulnerable (depot non synchronise ?)."
        ),
        "commands": commands,
        "output_tail": output,
        "restarted": restarted,
        "before": before,
        "after": after,
    }


def _python_for_helper(source: Path) -> str:
    venv_python = source / "venv" / "bin" / "python"
    if venv_python.is_file() and os.access(venv_python, os.X_OK):
        try:
            result = run_cmd([str(venv_python), "--version"], timeout=10)
        except ToolError:
            result = None
        if result and result.returncode == 0:
            return str(venv_python)
    return sys.executable or "python3"


def recreate_container(source: Path, storage: Path, name: str) -> dict:
    helper = source / "includes" / "config" / "scripts" / "recreate_app_container.py"
    if not helper.is_file():
        raise ToolError(f"helper introuvable : {helper}")
    env = os.environ.copy()
    env["SETTINGS_SOURCE"] = str(source)
    env["SETTINGS_STORAGE"] = str(storage)
    python = _python_for_helper(source)
    result = run_cmd([python, str(helper), name], timeout=1200, env=env)
    payload = parse_json_stdout(result.stdout)
    ok = result.returncode == 0 and bool(payload and payload.get("ok"))
    return {
        "name": name,
        "ok": ok,
        "output": tail_lines(result.stdout),
        "error": None
        if ok
        else (result.stderr.strip() or (payload or {}).get("error") or "echec"),
    }


def _container_by_name(containers: list[dict], name: str) -> dict | None:
    return next(
        (container for container in containers if container.get("name") == name), None
    )


def fix_app(source: Path, storage: Path, app: str) -> dict:
    before = build_scan(source, storage)
    targets = [
        container
        for container in before.get("containers", [])
        if container.get("app") == app
        and container.get("state") == "running"
        and container.get("is_php")
        and container.get("status") == "vulnerable"
    ]
    if not targets:
        return {
            "schema": SCHEMA_VERSION,
            "action": "fix-app",
            "app": app,
            "ok": True,
            "message": f"Aucun conteneur PHP vulnerable pour {app}.",
            "containers": [],
        }
    results = []
    for container in targets:
        result = recreate_container(source, storage, container["name"])
        results.append(result)
    time.sleep(2)
    after = build_scan(source, storage)
    remaining = [
        container
        for container in after.get("containers", [])
        if container.get("app") == app
        and container.get("state") == "running"
        and container.get("is_php")
        and container.get("status") == "vulnerable"
    ]
    for result in results:
        updated = _container_by_name(after.get("containers", []), result["name"])
        if updated:
            result["after"] = updated.get("status")
            result["php_version_after"] = updated.get("php_version")
    ok = all(result["ok"] for result in results) and not remaining
    return {
        "schema": SCHEMA_VERSION,
        "action": "fix-app",
        "app": app,
        "ok": ok,
        "message": (
            f"{app} mis a jour."
            if ok
            else "Mise a jour effectuee mais des conteneurs restent vulnerables."
        ),
        "containers": results,
        "remaining": [container["name"] for container in remaining],
    }


def fix_container(
    source: Path, storage: Path, name: str, force: bool = False
) -> dict:
    before = build_scan(source, storage)
    container = _container_by_name(before.get("containers", []), name)
    if container is None:
        return {
            "schema": SCHEMA_VERSION,
            "action": "fix-container",
            "ok": False,
            "message": f"Conteneur introuvable : {name}",
        }
    if not container.get("is_php"):
        return {
            "schema": SCHEMA_VERSION,
            "action": "fix-container",
            "ok": False,
            "message": f"{name} ne contient pas de runtime PHP detecte.",
        }
    if not container.get("managed") and not force:
        return {
            "schema": SCHEMA_VERSION,
            "action": "fix-container",
            "ok": False,
            "message": f"{name} n'est pas gere par SSDV2 (utiliser --force).",
        }
    if container.get("state") != "running":
        return {
            "schema": SCHEMA_VERSION,
            "action": "fix-container",
            "ok": False,
            "message": f"{name} est arrete : le demarrer avant mise a jour.",
        }
    if container.get("status") == "patched":
        return {
            "schema": SCHEMA_VERSION,
            "action": "fix-container",
            "ok": True,
            "message": f"{name} est deja patche.",
        }
    result = recreate_container(source, storage, name)
    time.sleep(2)
    after = scan_container(
        name,
        container.get("image", ""),
        "running",
        container.get("app"),
        bool(container.get("exposed")),
        False,
    )
    result["before"] = container.get("status")
    result["after"] = after.get("status")
    result["php_version_after"] = after.get("php_version")
    result["ok"] = result["ok"] and after.get("status") == "patched"
    return {
        "schema": SCHEMA_VERSION,
        "action": "fix-container",
        "ok": result["ok"],
        "message": (
            f"{name} est patche."
            if result["ok"]
            else f"{name} reste vulnerable apres mise a jour."
        ),
        "containers": [result],
    }


def stop_container(name: str, force: bool = False) -> dict:
    try:
        inspect = run_cmd(["docker", "inspect", name], timeout=15)
    except ToolError as exc:
        return {
            "schema": SCHEMA_VERSION,
            "action": "stop",
            "ok": False,
            "message": str(exc),
        }
    if inspect.returncode != 0:
        return {
            "schema": SCHEMA_VERSION,
            "action": "stop",
            "ok": False,
            "message": f"Conteneur introuvable : {name}",
        }
    labels: dict[str, str] = {}
    try:
        raw = json.loads(inspect.stdout)
        payload = raw[0] if isinstance(raw, list) and raw else {}
        labels = (payload.get("Config") or {}).get("Labels") or {}
    except (json.JSONDecodeError, IndexError):
        labels = {}
    managed = bool(labels.get("ssdv2.app"))
    if not managed and not force:
        return {
            "schema": SCHEMA_VERSION,
            "action": "stop",
            "ok": False,
            "message": f"{name} n'est pas gere par SSDV2 (utiliser --force).",
        }
    result = run_cmd(["docker", "stop", name], timeout=120)
    ok = result.returncode == 0
    return {
        "schema": SCHEMA_VERSION,
        "action": "stop",
        "ok": ok,
        "message": (
            f"{name} arrete."
            if ok
            else f"Echec de l'arret de {name} : {result.stderr.strip()}"
        ),
        "containers": [{"name": name, "ok": ok}],
    }


def harden_host(no_restart: bool = False) -> dict:
    host = scan_host()
    if not host.get("php", {}).get("available"):
        return {
            "schema": SCHEMA_VERSION,
            "action": "harden-host",
            "ok": False,
            "message": "Aucune installation PHP detectee sur l'hote.",
        }
    sudo = _sudo_prefix()
    if sudo is None:
        return {
            "schema": SCHEMA_VERSION,
            "action": "harden-host",
            "ok": False,
            "message": "Droits root/sudo non disponibles (action a lancer en CLI sur l'hote).",
        }
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    written: list[str] = []
    commands: list[str] = []
    for item in host.get("series", []) or []:
        series = item.get("series")
        if not series:
            continue
        parsed = tuple(int(part) for part in series.split("."))
        content = (
            "; SSDV2 php2shell - mitigation partielle\n"
            "; CVE-2026-109618 / CVE-2026-109619\n"
            "session.upload_progress.enabled=0\n"
        )
        if parsed >= (8, 5):
            content += "fatal_error_backtraces=0\n"
        for sapi in ("fpm", "apache2", "cli"):
            directory = Path(f"/etc/php/{series}/{sapi}/conf.d")
            if not directory.is_dir():
                continue
            path = directory / "99-php2shell.ini"
            if path.exists():
                backup = path.with_name(f"{path.name}.bak.{timestamp}")
                backup_cmd = [*sudo, "cp", "-a", str(path), str(backup)]
                commands.append(" ".join(backup_cmd))
                run_cmd(backup_cmd, timeout=30)
            write_cmd = [*sudo, "tee", str(path)]
            commands.append(" ".join(write_cmd))
            result = run_cmd(write_cmd, timeout=30, input_text=content)
            if result.returncode == 0:
                written.append(str(path))
    services = ["apache2"]
    for item in host.get("series", []) or []:
        series = item.get("series")
        if series:
            services.append(f"php{series}-fpm")
    restarted = _restart_services(services, sudo, no_restart)
    return {
        "schema": SCHEMA_VERSION,
        "action": "harden-host",
        "ok": bool(written),
        "message": (
            "Mitigations partielles appliquees. Un patch PHP reste obligatoire."
            if written
            else "Aucun fichier de configuration PHP modifie."
        ),
        "files": written,
        "commands": commands,
        "restarted": restarted,
    }


def run_selftest() -> int:
    cases = (
        ("8.3.35", True),
        ("8.3.36", False),
        ("8.2.34", True),
        ("8.2.35", False),
        ("8.4.26", True),
        ("8.4.27", False),
        ("8.5.11", True),
        ("8.5.12", False),
        ("8.1.99", True),
        ("7.4.33", True),
    )
    for version, expected in cases:
        actual = upstream_vulnerable(version)
        if actual != expected:
            print(
                f"selftest: echec upstream_vulnerable({version}) "
                f"= {actual}, attendu {expected}",
                file=sys.stderr,
            )
            return 1
    checks = (
        ("8.3.6-0ubuntu0.24.04.12", "8.3.6-0ubuntu0.24.04.13", -1),
        ("8.3.6-0ubuntu0.24.04.13", "8.3.6-0ubuntu0.24.04.13", 0),
        ("8.3.6-0ubuntu0.24.04.14", "8.3.6-0ubuntu0.24.04.13", 1),
    )
    for left, right, expected in checks:
        actual = version_compare(left, right)
        if actual != expected:
            print(
                f"selftest: echec version_compare({left}, {right}) "
                f"= {actual}, attendu {expected}",
                file=sys.stderr,
            )
            return 1
    print("selftest: ok")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="phpcve.py",
        description="Audit et remediation des CVE PHP2Shell (CVE-2026-109618/109619).",
    )
    parser.add_argument("--version", action="version", version=f"%(prog)s {VERSION}")
    parser.add_argument("--source", help="chemin de SETTINGS_SOURCE")
    parser.add_argument("--storage", help="chemin de SETTINGS_STORAGE")
    parser.add_argument("--selftest", action="store_true", help=argparse.SUPPRESS)
    commands = parser.add_subparsers(dest="command")
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--json", action="store_true", help="sortie JSON")

    scan = commands.add_parser(
        "scan", parents=[common], help="audit hote + conteneurs + SSDV2"
    )
    scan.add_argument("--deep", action="store_true", help="inspecter les conteneurs arretes")

    commands.add_parser("status", parents=[common], help="audit JSON")
    commands.add_parser("report", parents=[common], help="rapport lisible")

    fix_host_parser = commands.add_parser(
        "fix-host", parents=[common], help="mettre a jour PHP sur l'hote"
    )
    fix_host_parser.add_argument("--no-restart", action="store_true")

    fix_app_parser = commands.add_parser(
        "fix-app", parents=[common], help="mettre a jour une application SSDV2"
    )
    fix_app_parser.add_argument("app")

    fix_container_parser = commands.add_parser(
        "fix-container", parents=[common], help="mettre a jour un conteneur PHP"
    )
    fix_container_parser.add_argument("container")
    fix_container_parser.add_argument("--force", action="store_true")

    stop_parser = commands.add_parser(
        "stop", parents=[common], help="arreter un conteneur vulnerable"
    )
    stop_parser.add_argument("container")
    stop_parser.add_argument("--force", action="store_true")

    harden_parser = commands.add_parser(
        "harden-host", parents=[common], help="mitigations partielles sur l'hote"
    )
    harden_parser.add_argument("--no-restart", action="store_true")

    commands.add_parser("selftest", help="tests internes")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.selftest or args.command == "selftest":
        return run_selftest()
    if not args.command:
        parser.error("une commande est requise")

    source, storage = resolve_settings(args.source, args.storage)
    try:
        if args.command in ("scan", "status"):
            payload = build_scan(source, storage, deep=bool(getattr(args, "deep", False)))
            emit(payload, as_json=args.json or args.command == "status")
            return 1 if payload["summary"]["vulnerable"] else 0
        if args.command == "report":
            payload = build_scan(source, storage)
            emit(payload, as_json=args.json)
            return 1 if payload["summary"]["vulnerable"] else 0
        if args.command == "fix-host":
            payload = fix_host(source, storage, no_restart=args.no_restart)
            emit(payload, as_json=args.json)
            return 0 if payload.get("ok") else 1
        if args.command == "fix-app":
            payload = fix_app(source, storage, args.app)
            emit(payload, as_json=args.json)
            return 0 if payload.get("ok") else 1
        if args.command == "fix-container":
            payload = fix_container(
                source, storage, args.container, force=args.force
            )
            emit(payload, as_json=args.json)
            return 0 if payload.get("ok") else 1
        if args.command == "stop":
            payload = stop_container(args.container, force=args.force)
            emit(payload, as_json=args.json)
            return 0 if payload.get("ok") else 1
        if args.command == "harden-host":
            payload = harden_host(no_restart=args.no_restart)
            emit(payload, as_json=args.json)
            return 0 if payload.get("ok") else 1
        parser.error("commande inconnue")
    except ToolError as exc:
        error_payload = {
            "schema": SCHEMA_VERSION,
            "action": args.command,
            "ok": False,
            "error": {"code": "tool_error", "message": str(exc)},
        }
        emit(error_payload, as_json=args.json)
        return 1
    except Exception as exc:
        error_payload = {
            "schema": SCHEMA_VERSION,
            "action": args.command,
            "ok": False,
            "error": {"code": "internal_error", "message": str(exc)},
        }
        emit(error_payload, as_json=args.json)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
