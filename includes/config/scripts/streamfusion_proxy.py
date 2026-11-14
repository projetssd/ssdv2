#!/usr/bin/env python3
"""Mémorise le proxy et réutilise la recréation SSDV2 sans pull ni playbook.

La valeur est lue sur stdin pour ne pas la transmettre dans les arguments
au processus de recréation. Aucun paramètre secret n'est affiché.
"""
from __future__ import annotations

import os
from pathlib import Path
import sys
import tempfile
from urllib.parse import urlsplit

from recreate_app_container import docker, recreate_container


def configure_proxy(client, directory: Path, value: str) -> bool:
    value = value.strip()
    try:
        parsed = urlsplit(value)
        valid = not value or (parsed.scheme and parsed.hostname)
    except ValueError:
        valid = False
    if not valid or '\n' in value or '\r' in value:
        print('URL du proxy invalide.', file=sys.stderr)
        return False

    # Vérifier les deux cibles avant d'enregistrer ou de recréer quoi que ce soit.
    containers = []
    for name in ('stream-fusion', 'taskiq-worker'):
        try:
            containers.append(client.containers.get(name))
        except Exception:
            print(f'Conteneur inaccessible : {name}. Aucun réglage modifié.', file=sys.stderr)
            return False

    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    directory.chmod(0o700)
    # Remplacement atomique : un lecteur ne peut pas importer un fichier tronqué.
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', dir=directory, delete=False) as handle:
            temporary = Path(handle.name)
            handle.write(value + '\n')
        temporary.replace(directory / 'PROXY_URL')
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)

    failed = []
    for container in containers:
        try:
            recreate_container(client, container, env_overrides={'PROXY_URL': value}, pull=False)
        except Exception:
            failed.append(container.name)
    if failed:
        print('Proxy mémorisé, application en échec pour : ' + ', '.join(failed)
              + '. Relancez la commande avec le même proxy.', file=sys.stderr)
        return False
    print('Proxy mémorisé et appliqué à StreamFusion et au worker.')
    return True


def main() -> int:
    if docker is None:
        print('SDK Docker requis : utilisez le Python du venv SSDV2.', file=sys.stderr)
        return 1
    storage = Path(os.environ.get('SETTINGS_STORAGE') or Path.home() / 'seedbox')
    directory = storage / 'docker' / os.environ['USER'] / 'streamfusion-secrets'
    try:
        with docker.from_env() as client:
            return 0 if configure_proxy(client, directory, sys.stdin.read()) else 1
    except Exception:
        print('Impossible de configurer le proxy. Vérifiez Docker et les permissions du dossier des secrets.',
              file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
