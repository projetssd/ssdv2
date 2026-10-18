#!/usr/bin/env python3
"""Recrée un conteneur Docker à l'identique (mise à jour « image seule »).

Rejoue la configuration courante du conteneur (Config + HostConfig : env,
labels, binds, volumes nommés, réseau, ports, restart, devices, healthcheck…)
en pullant au préalable son image, avec des surcharges ciblées optionnelles
(`--env`, `--label`). Aucun playbook ni tâche SSDV2 : c'est l'équivalent
transparent de ``docker pull && recreate`` sans réinstallation.

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

import docker
from docker.types import Mount


def _build_mounts(mounts: list | None) -> list[Mount] | None:
    """Réutilise les volumes nommés (les binds sont déjà dans HostConfig.Binds)."""
    if not mounts:
        return None
    result: list[Mount] = []
    for mount in mounts:
        if mount.get("Type") != "volume" or not mount.get("Source"):
            continue
        result.append(
            Mount(
                target=mount["Destination"],
                source=mount["Source"],
                type="volume",
                read_only=not mount.get("RW", True),
            )
        )
    return result or None


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


def recreate_container(
    client: docker.DockerClient,
    container: docker.models.containers.Container,
    env_overrides: dict[str, str] | None = None,
    label_overrides: dict[str, str] | None = None,
    pull: bool = True,
) -> str:
    """Recrée un conteneur à l'identique ; retourne l'ID du nouveau conteneur."""
    attrs = container.attrs
    cfg = attrs.get("Config") or {}
    hc = attrs.get("HostConfig") or {}
    name = container.name
    was_running = container.status == "running"
    image = cfg.get("Image")

    if pull and image:
        client.images.pull(image)

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
            "mounts": _build_mounts(attrs.get("Mounts")),
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

    container.stop(timeout=30)
    container.remove()

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
        name=name,
    )
    if was_running:
        client.api.start(created["Id"])
    return created["Id"]


def _pairs(values: list[str], flag: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for item in values:
        key, sep, value = item.partition("=")
        if not sep or not key:
            raise SystemExit(f"{flag} attend CLE=VALEUR (reçu: {item!r})")
        result[key] = value
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Recrée un conteneur à l'identique.")
    parser.add_argument("container", help="nom du conteneur Docker")
    parser.add_argument("--env", action="append", default=[], help="surcharge d'env CLE=VALEUR")
    parser.add_argument("--label", action="append", default=[], help="surcharge de label CLE=VALEUR")
    parser.add_argument("--no-pull", action="store_true", help="ne pas puller l'image")
    args = parser.parse_args(argv)

    env_overrides = _pairs(args.env, "--env")
    label_overrides = _pairs(args.label, "--label")

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
