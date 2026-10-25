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

try:  # le selftest doit rester utilisable sans SDK Docker (CI minimale)
    import docker
    from docker.types import Mount
except ImportError:  # pragma: no cover - dépend de l'environnement d'exécution
    docker = None  # type: ignore[assignment]
    Mount = None  # type: ignore[assignment]


def _bind_destinations(binds: list | None) -> set[str]:
    """Destinations déjà couvertes par HostConfig.Binds (``src:dst[:opts]``)."""
    destinations: set[str] = set()
    for bind in binds or []:
        parts = bind.split(":")
        if len(parts) >= 2:
            destinations.add(parts[1])
    return destinations


def _mount_specs(mounts: list | None, binds: list | None = None) -> list[dict]:
    """Sélectionne les montages absents de HostConfig.Binds (sans SDK Docker).

    Docker refuse (« Duplicate mount point ») une destination présente à la
    fois dans ``binds`` et ``mounts``. Les volumes nommés et les binds sont
    déjà décrits par ``HostConfig.Binds`` : on ne réinjecte donc que les
    montages qui n'y figurent pas (volumes anonymes, ``--mount`` explicites…).
    """
    if not mounts:
        return []
    covered = _bind_destinations(binds)
    result: list[dict] = []
    for mount in mounts:
        destination = mount.get("Destination")
        source = mount.get("Source")
        mount_type = mount.get("Type")
        if not destination or not source or destination in covered:
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


def _build_mounts(mounts: list | None, binds: list | None = None) -> list[Mount] | None:
    """Convertit les montages à rejouer en objets ``docker.types.Mount``."""
    specs = _mount_specs(mounts, binds)
    if not specs:
        return None
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
) -> str:
    """Crée un conteneur depuis une configuration inspectée ; retourne son ID."""
    cfg = attrs.get("Config") or {}
    hc = attrs.get("HostConfig") or {}
    image = cfg.get("Image")

    environment = list(cfg.get("Env") or [])
    if env_overrides:
        environment = [
            entry for entry in environment if entry.split("=", 1)[0] not in env_overrides
        ]
        environment.extend(f"{key}={value}" for key, value in env_overrides.items())

    labels = dict(cfg.get("Labels") or {})
    if label_overrides:
        labels.update(label_overrides)

    host_config = _create_host_config(
        client,
        {
            "binds": hc.get("Binds"),
            "port_bindings": hc.get("PortBindings"),
            "mounts": _build_mounts(attrs.get("Mounts"), hc.get("Binds")),
            "devices": hc.get("Devices"),
            "device_cgroup_rules": hc.get("DeviceCgroupRules"),
            "extra_hosts": hc.get("ExtraHosts"),
            "restart_policy": hc.get("RestartPolicy"),
            "log_config": hc.get("LogConfig"),
            "privileged": hc.get("Privileged", False),
            "read_only": hc.get("ReadonlyRootfs", False),
            "shm_size": hc.get("ShmSize"),
            "network_mode": hc.get("NetworkMode"),
            "cap_add": hc.get("CapAdd"),
            "cap_drop": hc.get("CapDrop"),
            "security_opt": hc.get("SecurityOpt"),
            "group_add": hc.get("GroupAdd"),
            "dns": hc.get("Dns"),
            "dns_search": hc.get("DnsSearch"),
            "dns_opt": hc.get("DnsOptions"),
            "tmpfs": hc.get("Tmpfs"),
            "sysctls": hc.get("Sysctls"),
            "ulimits": _ulimits(hc.get("Ulimits")),
            "pid_mode": hc.get("PidMode"),
            "ipc_mode": hc.get("IpcMode"),
            "init": hc.get("Init"),
            "runtime": hc.get("Runtime"),
        },
    )

    created = client.api.create_container(
        image,
        command=cfg.get("Cmd"),
        entrypoint=cfg.get("Entrypoint"),
        environment=environment,
        labels=labels or None,
        ports=list((cfg.get("ExposedPorts") or {}).keys()) or None,
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
    new_id = _create_container(client, attrs, temp_name, env_overrides, label_overrides)

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
    parser.add_argument("--no-pull", action="store_true", help="ne pas puller l'image")
    parser.add_argument("--selftest", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args(argv)

    if args.selftest:
        return run_selftest()
    if not args.container:
        parser.error("le nom du conteneur est requis")

    env_overrides = _pairs(args.env, "--env")
    label_overrides = _pairs(args.label, "--label")

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
            }
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
