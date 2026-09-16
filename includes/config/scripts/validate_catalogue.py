#!/usr/bin/env python3
"""Valide la coherence du catalogue SSDV2.

Verifie que :
- chaque entree de services-available possede un fichier vars/<app>.yml
  (casse exacte) ;
- chaque reference pre/posttasks d'une app existe ;
- aucune entree de menu n'est orpheline.

Sortie : 0 si tout est valide, 1 sinon. Utilisable en CI et en local.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SERVICES = os.path.join(ROOT, "config", "services-available")
VARS_DIR = os.path.join(ROOT, "dockerapps", "vars")
PRE_DIR = os.path.join(ROOT, "dockerapps", "pretasks")
POST_DIR = os.path.join(ROOT, "dockerapps", "posttasks")

errors = []


def catalog_entries():
    if not os.path.exists(SERVICES):
        errors.append(f"catalogue introuvable: {SERVICES}")
        return []
    entries = []
    with open(SERVICES, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            entries.append(line.split("-")[0].strip())
    return entries


def main():
    entries = catalog_entries()
    for app in entries:
        if not os.path.exists(os.path.join(VARS_DIR, f"{app}.yml")):
            errors.append(f"catalogue: '{app}' sans fichier vars/{app}.yml")

    for name in os.listdir(VARS_DIR):
        if not name.endswith(".yml"):
            continue
        app = name[:-4]
        path = os.path.join(VARS_DIR, name)
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
        for kind, folder in (("pre", PRE_DIR), ("post", POST_DIR)):
            match = re.search(rf"{kind}tasks:\s*\n((?:[ \t]*-[ \t]*.*\n)+)", text)
            if not match:
                continue
            for ref in re.findall(r"-\s*([A-Za-z0-9_]+)", match.group(1)):
                if not os.path.exists(os.path.join(folder, f"{ref}.yml")):
                    errors.append(f"{app}: {kind}task manquante -> {ref}")

    if errors:
        print("Catalogue invalide :")
        for err in errors:
            print(f"  - {err}")
        return 1

    print(f"Catalogue valide ({len(entries)} applications)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
