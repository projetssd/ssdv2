#!/usr/bin/env python3
"""Recrée un conteneur Docker à l'identique (mise à jour « image seule »).

Rejoue la configuration courante du conteneur (Config + HostConfig : env,
labels, binds, volumes nommés, réseau, ports, restart, devices, healthcheck…)
en pullant au préalable son image, avec des surcharges ciblées optionnelles
(`--env`, `--label`). Aucun playbook ni tâche SSDV2 : c'est l'équivalent
transparent de ``docker pull && recreate`` sans réinstallation.

La recréation est non destructive : le nouveau conteneur est créé avant que
l'ancien ne soit arrêté/supprimé. En cas d'échec, l'ancien conteneur est
restauré (redémarrage ou recréation depuis sa configuration).

Utilisé par SSDV2 (fonctions ``update_container`` / ``apply_auth_label``) et donc
par ``ssdv2ctl`` et la WebUI.

Usage :
    recreate_app_container.py <conteneur> [--env CLE=VALEUR]... [--label CLE=VALEUR]...
                              [--no-pull]

Sortie : un objet JSON sur stdout ``{"ok": true, "container": ..., "changed": ...}``.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

try:  # le selftest doit rester utilisable sans SDK Docker (CI minimale)
    import docker
    from docker.types import Mount
except ImportError:  # pragma: no cover - dépend de l'environnement d'exécution
    docker = None  # type: ignore[assignment]
    Mount = None  # type: ignore[assignment]


def _bind_destination(bind: str) -> str | None:
    parts = bind.split(":")
    if len(parts) >= 2:
        return parts[1]
    return None


def _bind_destinations(binds: list | None) -> set[str]:
    """Destinations déjà couvertes par HostConfig.Binds (``src:dst[:opts]``)."""
    destinations: set[str] = set()
    for bind in binds or []:
        dest = _bind_destination(bind)
        if dest:
            destinations.add(dest)
    return destinations


def _filter_binds(
    binds: list | None,
    drop_destinations: list | None = None,
    add_destinations: set[str] | None = None,
) -> list[str] | None:
    """Retire les binds dont la destination est supprimée ou remplacée."""
    drop = set(drop_destinations or [])
    add = set(add_destinations or [])
    kept = []
    for bind in binds or []:
        dest = _bind_destination(bind)
        if dest in drop or dest in add:
            continue
        kept.append(bind)
    return kept or None


def _normalize_port(port: str) -> str:
    return port if "/" in port else f"{port}/tcp"


def _parse_publish(value: str) -> tuple[str, dict]:
    """Parse ``PORT=HOSTIP:HOSTPORT`` (ou ``PORT=HOSTPORT``)."""
    container, sep, host = value.partition("=")
    if not sep or not container or not host:
        raise SystemExit(f"--publish attend PORT=HOSTIP:HOSTPORT (reçu: {value!r})")
    host_ip, sep2, host_port = host.rpartition(":")
    if not sep2:
        host_ip, host_port = "", host
    return _normalize_port(container), {"HostIp": host_ip, "HostPort": host_port}


def _apply_port_overrides(
    port_bindings: dict | None,
    unpublish: list | None = None,
    publish: list[tuple[str, dict]] | None = None,
) -> dict | None:
    result = dict(port_bindings or {})
    for port in unpublish or []:
        result.pop(_normalize_port(port), None)
    for key, binding in publish or []:
        result[key] = [binding]
    return result or None


def _parse_tmpfs(values: list[str] | None) -> dict[str, str] | None:
    result: dict[str, str] = {}
    for value in values or []:
        destination, sep, options = value.partition(":")
        if not destination:
            continue
        result[destination] = options if sep else "rw"
    return result or None


def _parse_size(value: str | int | None) -> int | None:
    if value is None or isinstance(value, int):
        return value
    match = re.fullmatch(r"(\d+)([kmg]?)", str(value).strip().lower())
    if not match:
        raise SystemExit(f"taille invalide: {value!r}")
    number = int(match.group(1))
    factor = {"": 1, "k": 1024, "m": 1024**2, "g": 1024**3}[match.group(2)]
    return number * factor


def _merge_list(existing: list | None, additions: list | None) -> list | None:
    if additions is None:
        return existing
    merged = list(existing or [])
    for item in additions:
        if item not in merged:
            merged.append(item)
    return merged or None


def _mount_specs(
    mounts: list | None,
    binds: list | None = None,
    drop_destinations: list | None = None,
    add_destinations: set[str] | None = None,
) -> list[dict]:
    """Sélectionne les montages absents de HostConfig.Binds (sans SDK Docker).

    Docker refuse (« Duplicate mount point ») une destination présente à la
    fois dans ``binds`` et ``mounts``. Les volumes nommés et les binds sont
    déjà décrits par ``HostConfig.Binds`` : on ne réinjecte donc que les
    montages qui n'y figurent pas (volumes anonymes, ``--mount`` explicites…).
    """
    if not mounts:
        return []
    covered = _bind_destinations(binds)
    skip = set(drop_destinations or []) | set(add_destinations or [])
    result: list[dict] = []
    for mount in mounts:
        destination = mount.get("Destination")
        source = mount.get("Source")
        mount_type = mount.get("Type")
        if not destination or not source or destination in covered or destination in skip:
            continue
        if mount_type not in ("volume", "bind"):
            continue
        result.append(
            {
                "target": destination,
                "source": source,
                "type": mount_type,
                "read_only": not mount.get("RW", True),
                "propagation": mount.get("Propagation"),
            }
        )
    return result


def _build_mounts(
    mounts: list | None,
    binds: list | None = None,
    drop_destinations: list | None = None,
    add_destinations: set[str] | None = None,
) -> list[Mount] | None:
    """Convertit les montages à rejouer en objets ``docker.types.Mount``."""
    specs = _mount_specs(
        mounts, binds, drop_destinations=drop_destinations, add_destinations=add_destinations
    )
    if not specs:
        return None
    if Mount is None:
        raise RuntimeError("SDK Python docker introuvable")
    return [Mount(**spec) for spec in specs]


def _ulimits(raw: list | None) -> list[dict] | None:
    if not raw:
        return None
    limits = []
    for item in raw:
        if isinstance(item, dict) and item.get("Name"):
            limits.append({"Name": item["Name"], "Soft": item.get("Soft"), "Hard": item.get("Hard")})
    return limits or None


def _create_host_config(client: docker.DockerClient, kwargs: dict):
    """Construit un HostConfig en tolérant les champs non supportés par le SDK."""
    remaining = {key: value for key, value in kwargs.items() if value is not None}
    for _ in range(len(remaining) + 1):
        try:
            return client.api.create_host_config(**remaining)
        except TypeError as exc:
            match = re.search(r"unexpected keyword argument '([^']+)'", str(exc))
            if match is None or match.group(1) not in remaining:
                raise
            remaining.pop(match.group(1))
    raise RuntimeError("configuration Docker non rejouable")


def _healthcheck(cfg: dict) -> dict | None:
    raw = cfg.get("Healthcheck")
    if not raw or not raw.get("Test"):
        return None
    mapping = {
        "test": raw.get("Test"),
        "interval": raw.get("Interval"),
        "timeout": raw.get("Timeout"),
        "retries": raw.get("Retries"),
        "start_period": raw.get("StartPeriod"),
    }
    return {key: value for key, value in mapping.items() if value is not None}


def _build_networking_config(client: docker.DockerClient, attrs: dict):
    """Rejoue le réseau (IP statique, alias) pour les réseaux définis par l'utilisateur."""
    networks = (attrs.get("NetworkSettings") or {}).get("Networks") or {}
    network_mode = str((attrs.get("HostConfig") or {}).get("NetworkMode") or "")
    if not networks or network_mode in ("", "default", "bridge", "host", "none"):
        return None
    if network_mode.startswith("container:"):
        return None

    endpoints = {}
    for network_name, network in networks.items():
        if not network_name:
            continue
        ipam = network.get("IPAMConfig") or {}
        aliases = [alias for alias in (network.get("Aliases") or []) if alias]
        options: dict = {}
        if ipam.get("IPv4Address"):
            options["ipv4_address"] = ipam["IPv4Address"]
        if ipam.get("IPv6Address"):
            options["ipv6_address"] = ipam["IPv6Address"]
        if aliases:
            options["aliases"] = aliases
        endpoints[network_name] = client.api.create_endpoint_config(**options)
    if not endpoints:
        return None
    return client.api.create_networking_config(endpoints)


def _create_container(
    client: docker.DockerClient,
    attrs: dict,
    name: str,
    env_overrides: dict[str, str] | None = None,
    label_overrides: dict[str, str] | None = None,
    overrides: dict | None = None,
) -> str:
    """Crée un conteneur depuis une configuration inspectée ; retourne son ID."""
    cfg = attrs.get("Config") or {}
    hc = attrs.get("HostConfig") or {}
    image = cfg.get("Image")
    overrides = overrides or {}

    environment = list(cfg.get("Env") or [])
    merged_env = {**(env_overrides or {}), **(overrides.get("env") or {})}
    if merged_env:
        environment = [
            entry for entry in environment if entry.split("=", 1)[0] not in merged_env
        ]
        environment.extend(f"{key}={value}" for key, value in merged_env.items())

    labels = dict(cfg.get("Labels") or {})
    labels.update(label_overrides or {})
    labels.update(overrides.get("labels") or {})

    drop_bind = overrides.get("drop_bind_destinations") or []
    add_binds = overrides.get("add_binds") or []
    add_bind_dest = {
        dest for dest in (_bind_destination(bind) for bind in add_binds) if dest
    }
    binds = _filter_binds(hc.get("Binds"), drop_bind, add_bind_dest)
    if add_binds:
        binds = list(binds or []) + list(add_binds)

    port_bindings = _apply_port_overrides(
        hc.get("PortBindings"),
        overrides.get("unpublish_ports"),
        overrides.get("publish_ports"),
    )
    mounts = _build_mounts(
        attrs.get("Mounts"),
        binds,
        drop_bind,
        add_bind_dest,
    )

    security_opt = _merge_list(hc.get("SecurityOpt"), overrides.get("security_opt"))
    cap_drop = (
        overrides.get("cap_drop")
        if overrides.get("cap_drop") is not None
        else hc.get("CapDrop")
    )
    cap_add = (
        overrides.get("cap_add")
        if overrides.get("cap_add") is not None
        else hc.get("CapAdd")
    )
    group_add = _merge_list(hc.get("GroupAdd"), overrides.get("group_add"))
    tmpfs = dict(hc.get("Tmpfs") or {})
    tmpfs.update(overrides.get("tmpfs") or {})
    shm_size = (
        overrides.get("shm_size")
        if overrides.get("shm_size") is not None
        else hc.get("ShmSize")
    )
    read_only = (
        overrides.get("read_only")
        if overrides.get("read_only") is not None
        else hc.get("ReadonlyRootfs", False)
    )

    host_config = _create_host_config(
        client,
        {
            "binds": binds,
            "port_bindings": port_bindings,
            "mounts": mounts,
            "devices": hc.get("Devices"),
            "device_cgroup_rules": hc.get("DeviceCgroupRules"),
            "extra_hosts": hc.get("ExtraHosts"),
            "restart_policy": hc.get("RestartPolicy"),
            "log_config": hc.get("LogConfig"),
            "privileged": hc.get("Privileged", False),
            "read_only": read_only,
            "shm_size": shm_size,
            "network_mode": hc.get("NetworkMode"),
            "cap_add": cap_add,
            "cap_drop": cap_drop,
            "security_opt": security_opt,
            "group_add": group_add,
            "dns": hc.get("Dns"),
            "dns_search": hc.get("DnsSearch"),
            "dns_opt": hc.get("DnsOptions"),
            "tmpfs": tmpfs or None,
            "sysctls": hc.get("Sysctls"),
            "ulimits": _ulimits(hc.get("Ulimits")),
            "pid_mode": hc.get("PidMode"),
            "ipc_mode": hc.get("IpcMode"),
            "init": hc.get("Init"),
            "runtime": hc.get("Runtime"),
        },
    )

    exposed = set((cfg.get("ExposedPorts") or {}).keys())
    exposed.update((port_bindings or {}).keys())

    created = client.api.create_container(
        image,
        command=cfg.get("Cmd"),
        entrypoint=cfg.get("Entrypoint"),
        environment=environment,
        labels=labels or None,
        ports=sorted(exposed) or None,
        user=cfg.get("User") or None,
        working_dir=cfg.get("WorkingDir") or None,
        domainname=cfg.get("Domainname") or None,
        stop_signal=cfg.get("StopSignal") or None,
        tty=bool(cfg.get("Tty")),
        healthcheck=_healthcheck(cfg),
        host_config=host_config,
        networking_config=_build_networking_config(client, attrs),
        name=name,
    )
    return created["Id"]


def _remove_quietly(client: docker.DockerClient, ref: str) -> None:
    try:
        client.api.remove_container(ref, force=True)
    except docker.errors.NotFound:
        pass


def _restore_container(
    client: docker.DockerClient, attrs: dict, name: str, was_running: bool
) -> None:
    """Restaure l'ancien conteneur après un échec de recréation."""
    try:
        existing = client.containers.get(name)
    except docker.errors.NotFound:
        new_id = _create_container(client, attrs, name)
        if was_running:
            client.api.start(new_id)
        return
    if was_running and existing.status != "running":
        existing.start()


def recreate_container(
    client: docker.DockerClient,
    container: docker.models.containers.Container,
    env_overrides: dict[str, str] | None = None,
    label_overrides: dict[str, str] | None = None,
    pull: bool = True,
    overrides: dict | None = None,
) -> str:
    """Recrée un conteneur à l'identique ; retourne l'ID du nouveau conteneur."""
    attrs = container.attrs
    name = container.name
    was_running = container.status == "running"
    image = (attrs.get("Config") or {}).get("Image")

    if pull and image:
        client.images.pull(image)

    # Validation par création sous un nom temporaire, sans toucher à l'ancien.
    temp_name = f"{name}.ssdv2-new"
    _remove_quietly(client, temp_name)
    new_id = _create_container(
        client, attrs, temp_name, env_overrides, label_overrides, overrides
    )

    try:
        if was_running:
            container.stop(timeout=30)
        container.remove()
        client.api.rename(new_id, name)
        if was_running:
            client.api.start(new_id)
    except docker.errors.DockerException:
        _remove_quietly(client, new_id)
        try:
            _restore_container(client, attrs, name, was_running)
        except docker.errors.DockerException:
            pass
        raise
    return new_id


def create_from_inspect(
    client: docker.DockerClient, attrs: dict, name: str
) -> str:
    """Recrée un conteneur depuis un ``docker inspect`` sauvegarde (rollback)."""
    temp_name = f"{name}.ssdv2-rollback"
    _remove_quietly(client, temp_name)
    new_id = _create_container(client, attrs, temp_name)
    try:
        _remove_quietly(client, name)
        client.api.rename(new_id, name)
        client.api.start(new_id)
    except docker.errors.DockerException:
        _remove_quietly(client, new_id)
        raise
    return new_id


def _pairs(values: list[str], flag: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for item in values:
        key, sep, value = item.partition("=")
        if not sep or not key:
            raise SystemExit(f"{flag} attend CLE=VALEUR (reçu: {item!r})")
        result[key] = value
    return result


def run_selftest() -> int:
    """Vérifie le filtrage des doublons de montage et la conservation du réseau."""
    class _StubApi:
        def create_endpoint_config(self, **kwargs):
            return {"endpoint": kwargs}

        def create_networking_config(self, endpoints):
            return {"EndpointsConfig": endpoints}

    class _StubClient:
        api = _StubApi()

    try:
        assert _bind_destinations(["a:/b:ro", "c:/d"]) == {"/b", "/d"}
        assert _bind_destinations(None) == set()
        assert _filter_binds(
            ["/home/u:/home/u:rw", "/tmp:/tmp:rw"], ["/home/u"], {"/home/u/Medias"}
        ) == ["/tmp:/tmp:rw"]
        assert _parse_publish("32400=127.0.0.1:32400") == (
            "32400/tcp",
            {"HostIp": "127.0.0.1", "HostPort": "32400"},
        )
        assert _apply_port_overrides(
            {"32400/tcp": [{"HostIp": "0.0.0.0", "HostPort": "32400"}]},
            ["32400"],
            [("32400/tcp", {"HostIp": "127.0.0.1", "HostPort": "32400"})],
        ) == {"32400/tcp": [{"HostIp": "127.0.0.1", "HostPort": "32400"}]}
        assert _parse_size("256m") == 256 * 1024 * 1024
        assert _parse_tmpfs(["/tmp:rw,noexec"]) == {"/tmp": "rw,noexec"}

        binds = ["warp-data:/var/lib/cloudflare-warp:rw", "/host/path:/data"]
        mounts = [
            {
                "Type": "volume",
                "Source": "warp-data",
                "Destination": "/var/lib/cloudflare-warp",
                "RW": True,
            },
            {"Type": "volume", "Source": "anon", "Destination": "/anon", "RW": False},
            {"Type": "bind", "Source": "/host/path", "Destination": "/data", "RW": True},
            {"Type": "bind", "Source": "/other", "Destination": "/other", "RW": True},
            {"Type": "tmpfs", "Source": "", "Destination": "/tmp", "RW": True},
        ]
        result = _mount_specs(mounts, binds)
        targets = sorted(mount["target"] for mount in result)
        assert targets == ["/anon", "/other"], targets
        anonymous = next(mount for mount in result if mount["target"] == "/anon")
        assert anonymous["read_only"] is True

        attrs = {
            "HostConfig": {"NetworkMode": "traefik_proxy"},
            "NetworkSettings": {
                "Networks": {
                    "traefik_proxy": {
                        "IPAMConfig": {"IPv4Address": "172.18.0.250"},
                        "Aliases": ["warp"],
                    }
                }
            },
        }
        networking = _build_networking_config(_StubClient(), attrs)
        endpoint = networking["EndpointsConfig"]["traefik_proxy"]["endpoint"]
        assert endpoint["ipv4_address"] == "172.18.0.250"
        assert endpoint["aliases"] == ["warp"]

        bridge = {
            "HostConfig": {"NetworkMode": "bridge"},
            "NetworkSettings": {"Networks": {"bridge": {}}},
        }
        assert _build_networking_config(_StubClient(), bridge) is None
    except AssertionError as exc:
        print(f"selftest: echec {exc}", file=sys.stderr)
        return 1
    print("selftest: ok")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Recrée un conteneur à l'identique.")
    parser.add_argument("container", nargs="?", help="nom du conteneur Docker")
    parser.add_argument("--env", action="append", default=[], help="surcharge d'env CLE=VALEUR")
    parser.add_argument("--label", action="append", default=[], help="surcharge de label CLE=VALEUR")
    parser.add_argument("--unpublish", action="append", default=[], metavar="PORT",
                        help="supprime la publication d'un port conteneur (ex. 32400)")
    parser.add_argument("--publish", action="append", default=[], metavar="PORT=HOSTIP:HOSTPORT",
                        help="remplace la publication d'un port conteneur")
    parser.add_argument("--drop-bind", action="append", default=[], metavar="DEST",
                        help="supprime un bind par destination")
    parser.add_argument("--add-bind", action="append", default=[], metavar="SRC:DST[:ro|rw]",
                        help="ajoute ou remplace un bind")
    parser.add_argument("--security-opt", action="append", default=[], help="ajoute une option de sécurité")
    parser.add_argument("--cap-drop", action="append", default=[], help="remplace les capabilities droppées")
    parser.add_argument("--cap-add", action="append", default=[], help="remplace les capabilities ajoutées")
    parser.add_argument("--group-add", action="append", default=[], help="ajoute un groupe")
    parser.add_argument("--tmpfs", action="append", default=[], metavar="DEST[:OPTS]",
                        help="ajoute un tmpfs")
    parser.add_argument("--shm-size", default=None, help="taille de /dev/shm (ex. 256m)")
    parser.add_argument("--read-only", action="store_true", help="rootfs en lecture seule")
    parser.add_argument("--dry-run", action="store_true", help="affiche les changements sans agir")
    parser.add_argument("--from-inspect", metavar="FILE",
                        help="recrée depuis un fichier docker inspect (rollback)")
    parser.add_argument("--no-pull", action="store_true", help="ne pas puller l'image")
    parser.add_argument("--selftest", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args(argv)

    if args.selftest:
        return run_selftest()
    if not args.container and not args.from_inspect:
        parser.error("le nom du conteneur est requis")

    env_overrides = _pairs(args.env, "--env")
    label_overrides = _pairs(args.label, "--label")
    overrides = {
        "unpublish_ports": args.unpublish or None,
        "publish_ports": [_parse_publish(value) for value in args.publish] or None,
        "drop_bind_destinations": args.drop_bind or None,
        "add_binds": args.add_bind or None,
        "security_opt": args.security_opt or None,
        "cap_drop": args.cap_drop or None,
        "cap_add": args.cap_add or None,
        "group_add": args.group_add or None,
        "tmpfs": _parse_tmpfs(args.tmpfs),
        "shm_size": _parse_size(args.shm_size),
        "read_only": True if args.read_only else None,
    }

    if args.from_inspect:
        try:
            raw = json.loads(Path(args.from_inspect).read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            print(json.dumps({"ok": False, "error": f"inspect illisible: {exc}"}))
            return 1
        attrs = raw[0] if isinstance(raw, list) and raw else raw
        if not isinstance(attrs, dict):
            print(json.dumps({"ok": False, "error": "inspect invalide"}))
            return 1
        name = args.container or str(attrs.get("Name") or "").lstrip("/")
        if not name:
            print(json.dumps({"ok": False, "error": "nom du conteneur introuvable"}))
            return 1
        if args.dry_run:
            print(
                json.dumps(
                    {
                        "ok": True,
                        "dry_run": True,
                        "from_inspect": args.from_inspect,
                        "container": name,
                    },
                    indent=2,
                )
            )
            return 0
        if docker is None:
            print(json.dumps({"ok": False, "error": "SDK Python docker introuvable"}))
            return 1
        client = docker.from_env()
        try:
            new_id = create_from_inspect(client, attrs, name)
        except docker.errors.DockerException as exc:
            print(json.dumps({"ok": False, "error": str(exc)}))
            return 1
        print(json.dumps({"ok": True, "container": name, "id": new_id}))
        return 0

    if args.dry_run:
        print(
            json.dumps(
                {
                    "ok": True,
                    "dry_run": True,
                    "container": args.container,
                    "env": env_overrides,
                    "labels": label_overrides,
                    "overrides": overrides,
                },
                indent=2,
            )
        )
        return 0

    if docker is None:
        print(json.dumps({"ok": False, "error": "SDK Python docker introuvable"}))
        return 1

    client = docker.from_env()
    try:
        container = client.containers.get(args.container)
    except docker.errors.NotFound:
        print(json.dumps({"ok": False, "error": f"conteneur introuvable: {args.container}"}))
        return 1

    try:
        new_id = recreate_container(
            client,
            container,
            env_overrides=env_overrides or None,
            label_overrides=label_overrides or None,
            pull=not args.no_pull,
            overrides=overrides,
        )
    except docker.errors.DockerException as exc:
        print(json.dumps({"ok": False, "error": str(exc)}))
        return 1

    print(
        json.dumps(
            {
                "ok": True,
                "container": args.container,
                "id": new_id,
                "labels": label_overrides,
                "env": list(env_overrides),
                "overrides": overrides,
            }
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
