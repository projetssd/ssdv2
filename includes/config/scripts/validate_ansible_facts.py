#!/usr/bin/env python3
"""Détecte l'usage de facts Ansible comme variables de premier niveau.

SSDV2 génère des `~/.ansible.cfg` avec `inject_facts_as_vars = False`
(suppression de l'avertissement « args-template »). Dans ce mode, les facts ne
sont plus exposés sous forme `ansible_<fact>` mais uniquement via
`ansible_facts['<fact>']`. Utiliser `ansible_env`, `ansible_default_ipv4`, etc.
directement provoquerait une erreur « undefined ».

Les variables magiques (`ansible_connection`, `ansible_host`, `ansible_facts`,
`ansible_run_tags`, ...) ne sont PAS concernées.

Sortie : 0 si aucun usage risqué, 1 sinon.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Facts (noms injectés de premier niveau). Non exhaustif mais couvre les usages courants.
FACTS = [
    "env", "hostname", "fqdn", "domain", "dns",
    "distribution", "distribution_version", "distribution_release", "distribution_major_version",
    "os_family", "architecture", "machine", "kernel", "system", "service_mgr",
    "virtualization_type", "virtualization_role", "pkg_mgr",
    "default_ipv4", "default_ipv6", "all_ipv4_addresses", "all_ipv6_addresses",
    "interfaces", "mounts", "processor", "processor_cores", "processor_count",
    "processor_vcpus", "memtotal_mb", "memfree_mb", "swaptotal_mb", "swapfree_mb",
    "date_time", "user_id", "user_uid", "user_gid", "user_dir", "user_gecos", "user_shell",
    "cmdline", "localhost", "selinux", "apparmor", "iscsi_iqn", "hostname_short",
]

PATTERN = re.compile(r"\bansible_(" + "|".join(re.escape(f) for f in FACTS) + r")\b")
SKIP_DIRS = {".git", "venv", "__pycache__", "tests"}
EXT = {".yml", ".yaml", ".j2", ".sh"}

hits = []
for base, dirs, files in os.walk(ROOT):
    dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
    for name in files:
        if os.path.splitext(name)[1] not in EXT:
            continue
        path = os.path.join(base, name)
        try:
            with open(path, encoding="utf-8") as fh:
                for lineno, line in enumerate(fh, 1):
                    if line.lstrip().startswith("#"):
                        continue
                    if PATTERN.search(line):
                        hits.append((os.path.relpath(path, ROOT), lineno, line.strip()))
        except (UnicodeDecodeError, IsADirectoryError):
            continue

if hits:
    print("Usage de facts Ansible de premier niveau détecté (incompatible inject_facts_as_vars=False) :")
    for path, lineno, line in hits:
        print(f"  {path}:{lineno}: {line}")
    print("\nUtiliser ansible_facts['<fact>'] à la place.")
    sys.exit(1)

print("Aucun usage de fact Ansible de premier niveau.")
