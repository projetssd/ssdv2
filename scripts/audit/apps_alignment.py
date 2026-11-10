#!/usr/bin/env python3
"""Audit statique des applications SSDV2 contre le contrat du skill `add-app`.

Le script ne modifie rien : il lit le catalogue, les variables et les hooks,
puis produit

- ``apps-alignment.json``  : données brutes (constats, questions, états)
- ``apps-alignment.csv``   : matrice une ligne par application
- ``apps-alignment.md``    : synthèse et constats détaillés
- ``apps-alignment-backlog.md`` : lots de correction prioritaires

Usage :
    python3 scripts/audit/apps_alignment.py --repo . --out docs/audits
    python3 scripts/audit/apps_alignment.py --repo /chemin/autre/worktree

L'outil est volontairement indépendant de toute image Docker : il ne vérifie ni
les ports réellement écoutés, ni les versions amont, ni les migrations de base.
"""

from __future__ import annotations

import argparse
import ast
import collections
import csv
import json
import re
import subprocess
import sys
from pathlib import Path

import yaml

try:  # optionnel : validation syntaxique des templates
    from jinja2 import Environment
except ImportError:  # pragma: no cover
    Environment = None

AXES = [
    "catalogue",
    "deploiement",
    "assistance",
    "secrets",
    "traefik",
    "persistance",
    "permissions",
    "cycle",
    "minimalisme",
]

AXIS_LABELS = {
    "catalogue": "Catalogue / nommage",
    "deploiement": "Déploiement / Docker / environnement",
    "assistance": "Installation assistée / invites",
    "secrets": "Secrets / journaux",
    "traefik": "Traefik / DNS / authentification / ports",
    "persistance": "Volumes / persistance",
    "permissions": "Permissions / UID / GID",
    "cycle": "Réinstallation / réinitialisation / suppression",
    "minimalisme": "Minimalisme / mutualisation",
}

FIXES = {
    "NAME": "Aligner pgrole sur l'identifiant catalogue et sur le nom du fichier.",
    "IMAGE": "Déclarer l'image principale ou passer docker_deploy_enabled: false.",
    "PORT": "Déclarer intport (port interne HTTP) ou désactiver les labels génériques.",
    "INTIGNORED": "Retirer intport ou activer les labels génériques : la valeur n'est pas consommée.",
    "GENLOG": "Activer docker_no_log pour l'application et vérifier les hooks qui redéploient docker_info.",
    "TASKLOG": "Ajouter no_log aux tâches ou blocs manipulant ces secrets.",
    "FIXEDSECRET": "Générer une valeur persistante propre à l'installation, avec migration compatible.",
    "PROMPTMARK": "Préfixer l'invite du marqueur SSDV2_PROMPT {id,label,kind,secret}.",
    "PROMPTECHO": "Désactiver l'écho (echo: no) en conservant secret: true dans le marqueur.",
    "PROMPTLOG": "Ajouter no_log: true à l'invite et aux tâches qui réutilisent la réponse.",
    "RAWLABEL": "Retirer les labels à la racine : passer par les labels génériques ou extra_labels.",
    "DOUBLEHOOK": "Retirer la référence explicite homonyme, le chargement est déjà automatique.",
    "MISSINGREF": "Corriger la référence locale introuvable.",
    "GLOBALPRUNE": "Supprimer l'appel global ; utiliser la suppression ciblée du registre.",
    "NOHOOKSCUSTOM": "Déclarer au moins une posttask qui réalise le déploiement complet.",
    "NOIMAGEHOOKS": "Vérifier le déploiement des conteneurs : aucune image principale déclarée.",
    "IDEMPOTENT": "Tester l'état (stat) avant wait_for : ignorer l'attente si l'installation existe déjà.",
    "COURTESY": "Remplacer pause() de courtoisie par une vraie question marquée, ou la retirer.",
    "NETWORKCLEAN": "Prévoir la suppression ciblée du réseau dédié dans suppression_appli.",
    "SUPPARG": "Passer explicitement 0 (partiel) ou 1 (complet) dans un appel scripté.",
    "ORPHANROOT": "Ranger les données sous le dossier {{ pgrole }} ou documenter l'exception.",
    "WEBHOSTPORT": "Retirer la publication Web hôte ou la borner au loopback.",
    "LOCALPULL": "Déclarer pull_image: false pour une image construite localement.",
    "REGISTRYLOCAL": "Vérifier l'utilité de pull_image: false : l'image semble provenir d'un registre.",
    "TZ": "Déclarer TZ: Europe/Paris si l'image le supporte, ou monter /etc/localtime.",
    "CATALOGMISSING": "Ajouter l'application au catalogue ou la retirer du dépôt.",
    "CATALOGDESC": "Compléter la description visible dans le menu.",
    "CATALOGORPHAN": "Documenter l'entrée hors catalogue (interne, exemple, relay) ou l'ajouter.",
    "PROMPTJSON": "Corriger le JSON du marqueur SSDV2_PROMPT.",
    "SUBDIRUID": "Créer le sous-dossier en pretask avec MYUID/MYGID avant le montage.",
    "WORLDWRITE": "Remplacer 0777 par les permissions minimales utiles.",
    "SECRETFILEMODE": "Créer le fichier de secret en 0600 (umask 077 ou mode explicite).",
    "SHELLSECRET": "Protéger par no_log et passer les arguments sans shell, ou avec un quoting adapté.",
    "DEBUGSECRET": "Retirer l'affichage brut du secret dans debug.",
    "ROTATESECRET": "Relire le secret existant et ne le générer qu'en son absence.",
    "ORPHANDATA": "Aligner les chemins persistants et la branche de suppression.",
    "PARTIALDELETE": "Conditionner l'effacement des données à DELETE=1.",
    "OTHERAPPDELETE": "Ne supprimer que les ressources de l'application concernée.",
    "MANUALSTEP": "Intégrer la saisie ou la génération dans l'assistant SSDV2.",
    "CFUNCONDITIONAL": "Conditionner l'appel Cloudflare et prévoir le parcours DNS manuel.",
    "HOSTLESSAUTH": "Borner le router au Host choisi et appliquer une authentification.",
    "PORTCONFLICT": "Aligner intport et le port du service Traefik.",
    "WRONGROUTER": "Corriger le nom du router modifié.",
    "IGNOREDOPTION": "Déplacer l'option sous specific_docker_info ou la retirer.",
    "JSONESCAPE": "Sérialiser avec to_json au lieu d'interpoler les saisies.",
    "GID": "Utiliser MYGID pour GID.",
    "FIXEDBPASS": "Générer un secret de base persistant au lieu d'une chaîne prévisible.",
    "MISSINGDEP": "Déployer le compagnon requis ou guider la configuration d'une base externe.",
    "CROSSAPPDELETE": "Conditionner tout effacement à DELETE=1 et ne jamais retirer les dossiers d'une autre application.",
    "KEYCLEAN": "Gérer la clé authorized_keys de façon idempotente et la retirer à la suppression.",
    "WEBUIPROMPT": "Documenter l'invite pour la WebUI.",
}

RULES = {
    "NAME": "Catalogue — pgrole identique au nom du fichier.",
    "IMAGE": "Déploiement — une image ou un déploiement custom explicite.",
    "PORT": "Traefik — intport obligatoire si les labels génériques sont actifs.",
    "INTIGNORED": "Contrat vars — pas de variable morte.",
    "GENLOG": "Secrets — ne pas exposer les secrets dans les journaux.",
    "TASKLOG": "Secrets — no_log sur les traitements sensibles.",
    "FIXEDSECRET": "Secrets — générer les secrets internes.",
    "PROMPTMARK": "Invites — marqueur SSDV2_PROMPT obligatoire.",
    "PROMPTECHO": "Invites — jamais d'écho sur un secret.",
    "PROMPTLOG": "Invites — no_log sur les invites secrètes.",
    "RAWLABEL": "Traefik — labels génériques, pas de labels bruts.",
    "DOUBLEHOOK": "Minimalisme — les hooks homonymes sont chargés automatiquement.",
    "MISSINGREF": "Déploiement — références locales valides.",
    "GLOBALPRUNE": "Cycle de vie — aucune suppression Docker globale.",
    "NOHOOKSCUSTOM": "Déploiement custom — les hooks doivent déployer.",
    "NOIMAGEHOOKS": "Déploiement — un conteneur principal doit être défini.",
    "IDEMPOTENT": "Réinstallation — ne pas bloquer sur un artefact de premier démarrage.",
    "COURTESY": "Invites — pas de saisie derrière un pause de courtoisie.",
    "NETWORKCLEAN": "Réseaux — suppression dédiée, non couverts par le registre.",
    "SUPPARG": "Suppression — arguments explicites en contexte non interactif.",
    "ORPHANROOT": "Volumes — données persistantes sous le dossier applicatif.",
    "WEBHOSTPORT": "Ports — pas de port Web hôte inutile.",
    "LOCALPULL": "Déploiement — pull_image: false pour une image locale.",
    "REGISTRYLOCAL": "Déploiement — pull_image: false cohérent avec l'image.",
    "TZ": "Environnement — TZ Europe/Paris sauf raison contraire.",
    "CATALOGMISSING": "Catalogue — chaque application installable y figure.",
    "CATALOGDESC": "Catalogue — description utile dans le menu.",
    "CATALOGORPHAN": "Catalogue — entrées internes assumées.",
    "PROMPTJSON": "Invites — marqueur JSON exploitable par la WebUI.",
    "SUBDIRUID": "Volumes — préparer les sous-dossiers pour un UID non-root.",
    "WORLDWRITE": "Permissions — droits ciblés.",
    "SECRETFILEMODE": "Secrets — permissions restreintes.",
    "SHELLSECRET": "Secrets — pas de fuite par le shell.",
    "DEBUGSECRET": "Secrets — pas de secret réel dans debug.",
    "ROTATESECRET": "Réinstallation — secrets persistants.",
    "ORPHANDATA": "Cycle de vie — nettoyage des fichiers hors dossier applicatif.",
    "PARTIALDELETE": "Suppression partielle — données conservées.",
    "OTHERAPPDELETE": "Registre — ne pas toucher aux ressources d'une autre app.",
    "MANUALSTEP": "Assistance — éviter les étapes manuelles automatisables.",
    "CFUNCONDITIONAL": "Assistance — Cloudflare ou parcours DNS manuel.",
    "HOSTLESSAUTH": "Traefik — Host et authentification maîtrisés.",
    "PORTCONFLICT": "Traefik — cohérence intport / service.",
    "WRONGROUTER": "Traefik — nommage cohérent.",
    "IGNOREDOPTION": "Contrat vars — options Docker dans specific_docker_info.",
    "JSONESCAPE": "Assistance — configuration toujours valide.",
    "GID": "Environnement — UID et GID distincts.",
    "FIXEDBPASS": "Secrets — mot de passe de base imprévisible.",
    "MISSINGDEP": "Dépendances — composant requis déployé.",
    "CROSSAPPDELETE": "Suppression — aucune donnée hors périmètre applicatif.",
    "KEYCLEAN": "Cycle de vie — fichiers externes nettoyés.",
    "WEBUIPROMPT": "Invites — détection fiable par la WebUI.",
}

# Pour chaque famille : déclencheur, impact et niveau de certitude.
# « confirmé (code) » = la preuve est dans le dépôt ; « dépend de l'exécution » =
# la conséquence ne peut pas être certifiée sans installer l'application.
EVIDENCE = {
    "DEBUGSECRET": ("tâche `debug` interpolant une valeur secrète",
                    "le secret est recopié dans la sortie d'installation et les journaux Ansible",
                    "confirmé (code)"),
    "TASKLOG": ("tâche `set_fact` ou `docker_container` d'un hook exposant un champ sensible",
                "le secret apparaît dans le résultat de tâche et les journaux d'installation",
                "confirmé (code)"),
    "GENLOG": ("`no_log` des tâches de déploiement vaut `docker_no_log | default(false)`",
               "les paramètres sensibles de `pg_env` apparaissent en verbosité et dans les journaux",
               "confirmé (code)"),
    "PROMPTECHO": ("invite `secret: true` sans `echo: no`",
                   "la saisie s'affiche au terminal et dans la transcription de session",
                   "confirmé (code)"),
    "PROMPTLOG": ("`pause` secrète sans `no_log` sur la tâche elle-même",
                  "la valeur saisie est journalisée dans le résultat de tâche Ansible",
                  "confirmé (code)"),
    "SECRETFILE": ("fichier de configuration contenant un secret écrit en 0644",
                   "tout utilisateur local peut lire le secret",
                   "confirmé (code)"),
    "SHELLSECRET": ("secret interpolé dans une commande `shell` sans quoting ni `no_log`",
                    "caractères spéciaux interprétés ; valeur exposable en erreur ou verbosité",
                    "confirmé (code)"),
    "FIXEDSECRET": ("secret interne défini par une chaîne prévisible (`{{ pgrole }}`, `changeme`)",
                    "accès interne trivial pour qui connaît le nom de l'application",
                    "confirmé (code)"),
    "ROTATESECRET": ("secret régénéré à chaque exécution sans relecture de la valeur persistante",
                     "réinstallation : sessions invalidées, base désynchronisée de son mot de passe",
                     "confirmé (code)"),
    "PARTIALDELETE": ("branche legacy de `suppression_appli` supprimant des données sans tester `DELETE=1`",
                      "réinstallation (`suppression_appli <app> 0`) efface les données que l'utilisateur voulait conserver",
                      "confirmé (code)"),
    "CROSSAPPDELETE": ("suppression d'un dossier monté par une autre application",
                       "perte de données d'une application non concernée",
                       "confirmé (code)"),
    "OTHERAPPDELETE": ("suppression d'un conteneur créé par une autre application",
                       "arrêt d'un service d'une autre application, recréé seulement à sa prochaine installation",
                       "confirmé (code)"),
    "NETWORKCLEAN": ("réseau `<app>-net` créé par un template sans suppression dans `suppression_appli`",
                     "réseaux orphelins accumulés ; le registre ne suit pas les réseaux",
                     "confirmé (code)"),
    "WEBHOSTPORT": ("`specific_docker_info.ports` publie le port HTTP interne sur l'hôte",
                    "accès direct contournant Traefik et la chaîne d'authentification",
                    "confirmé (code)"),
    "HOSTLESSAUTH": ("router Traefik sans règle `Host` ni chaîne d'authentification",
                     "le sous-domaine et le choix d'authentification ne bornent pas l'exposition",
                     "confirmé (code)"),
    "PORTCONFLICT": ("`intport` et port du service Traefik différents",
                     "route vers un port non écouté, ou port inattendu",
                     "dépend de l'exécution"),
    "WRONGROUTER": ("labels du compagnon appliqués au router de l'application principale",
                    "collision de routers : routage du panneau perturbé",
                    "confirmé (code)"),
    "CFUNCONDITIONAL": ("création DNS Cloudflare hors condition `cloudflare_enabled`",
                        "échec ou entrée DNS parasite lorsque Cloudflare est désactivé",
                        "confirmé (code)"),
    "LOCALPULL": ("image construite localement sans `pull_image: false`",
                  "le déploiement tente un `pull` d'une image absente d'un registre et échoue",
                  "confirmé (code)"),
    "MISSINGDEP": ("configuration pointant vers un compagnon qu'aucun hook ne déploie",
                   "application démarrée sans base : installation incomplète",
                   "à vérifier (déploiement externe possible)"),
    "SUBDIRUID": ("sous-dossier monté par une image non-root, non créé avant le montage",
                  "Docker crée le dossier en root : écriture refusée au premier démarrage",
                  "dépend de l'exécution"),
    "ORPHANDATA": ("données persistantes hors du dossier applicatif sans nettoyage ciblé",
                   "rémanence après suppression complète",
                   "confirmé (code)"),
    "KEYCLEAN": ("fichier externe modifié (clé SSH) sans retrait à la suppression",
                 "résidu et doublons à chaque réinstallation",
                 "confirmé (code)"),
    "MANUALSTEP": ("étape laissée à une commande manuelle documentée",
                   "installation non reproductible sans intervention",
                   "confirmé (code)"),
    "JSONESCAPE": ("saisie interpolée directement dans un document JSON",
                   "fichier invalide si la valeur contient guillemet ou antislash",
                   "confirmé (code)"),
    "SECRETFILEMODE": ("fichier de secret écrit sans mode explicite",
                       "permissions dépendantes de l'umask ambiant",
                       "confirmé (code)"),
    "WORLDWRITE": ("dossier créé ou modifié en 0777",
                   "écriture possible par tout utilisateur local",
                   "confirmé (code)"),
    "GID": ("`GID` alimenté par `MYUID`",
            "groupe erroné si UID et GID diffèrent",
            "confirmé (code)"),
    "IGNOREDOPTION": ("option Docker placée à la racine des variables",
                      "option silencieusement ignorée par le playbook générique",
                      "confirmé (code)"),
    "INTIGNORED": ("`intport` déclaré avec Traefik désactivé",
                   "variable morte, source de confusion",
                   "confirmé (code)"),
    "DOUBLEHOOK": ("hook homonyme chargé automatiquement puis explicitement",
                   "exécution en double",
                   "confirmé (code)"),
    "ORPHANROOT": ("données persistantes hors du dossier de l'application",
                   "partage involontaire entre applications, suppression incertaine",
                   "à vérifier (partage parfois volontaire)"),
    "TZ": ("ni `TZ` ni montage `/etc/localtime`",
           "horodatage en UTC dans l'interface et les journaux",
           "confirmé (code)"),
    "CATALOGORPHAN": ("fichier de variables absent du catalogue",
                      "aucun impact si le fichier est interne ; sinon application non installable",
                      "à vérifier (interne ou oubli)"),
    "IDEMPOTENT": ("`wait_for` sans test d'état préalable",
                   "immédiat si l'artefact existe, sinon attente complète avant échec",
                   "confirmé (code)"),
}

# Hypothèses testées puis écartées : conservées pour éviter de les rejouer.
REJECTED = {
    "paperless supprime `mariadb`, espocrm supprime `mysql`": (
        "seuls paperless et espocrm montent ces dossiers dans le dépôt : le nom est "
        "générique, le partage n'est pas démontré. Réel défaut : suppression non "
        "conditionnée à `DELETE=1` (`PARTIALDELETE`)."
    ),
    "paperless supprime `redis`, partagé": (
        "immich déclare un conteneur nommé `redis` mais ne monte aucun volume ; les "
        "autres occurrences sont des hôtes `*redis` distincts. Le nom seul ne prouve "
        "aucun partage de données."
    ),
    "`sffs-secrets` supprimé en mode partiel": (
        "retrait documenté dans `functions.sh` : la configuration StreamFusion liée à "
        "la clé d'API supprimée devient invalide et une réinstallation la régénère. "
        "Classé `acknowledged`, hors compteurs."
    ),
    "streamfusion supprime des conteneurs d'autres apps": (
        "`warp` est bien créé par sftorznab/stremthru et pas par streamfusion : "
        "suppression croisée confirmée. En revanche `stremio-redis` et "
        "`stremio-postgres` sont créés par les deux : définition partagée, "
        "classée en question et non en défaut."
    ),
    "jetons de premier démarrage (symlink, ssdv2webui) exposés": (
        "affichage volontaire pour l'utilisateur ; le risque est la journalisation "
        "persistante, pas la divulgation accidentelle. Classés P1, pas P0."
    ),
    "webdav publie le port 8080 alors que `intport` vaut 80": (
        "le port réellement écouté dépend de l'image ; le constat reste une question "
        "(`PORTCONFLICT`), pas un défaut confirmé."
    ),
}

SEVERITY_ORDER = {"P0": 0, "P1": 1, "P2": 2, "P3": 3}

# Chantiers transverses : un seul correctif ferme plusieurs dizaines de constats.
SYSTEMIC = {
    "GENLOG": ("generique.yml", "Même mécanisme pour toutes : les tâches `set_fact`/`docker_container` "
               "utilisent `no_log: {{ docker_no_log | default(false) }}`. Basculer le défaut à vrai, ou "
               "n'exposer les variables qu'en mode debug explicite."),
    "NETWORKCLEAN": ("suppression_appli", "Les réseaux `<app>-net` créés par les templates mariadb, "
                     "postgresql, redis et memcached ne sont jamais retirés. Un `cleanup_app_network "
                     "\"${APPSELECTED}-net\"` générique ferme la famille entière."),
    "PROMPTECHO": ("pretasks", "Invites secrètes déclarées avec `echo: yes` ou `echo: \"yes\"`. "
                   "Un contrôle du contrat d'invite en CI empêche la réapparition."),
    "PROMPTLOG": ("pretasks", "Invites secrètes sans `no_log` sur la tâche `pause` elle-même, "
                  "même quand le bloc appelant est protégé."),
    "FIXEDSECRET": ("vars", "Secrets internes fixés à une chaîne prévisible (`{{ pgrole }}`, "
                    "`changeme`). Générer un secret persistant via `lookup('password', chemin)`."),
    "TZ": ("vars", "Aucun `TZ` ni montage `/etc/localtime`. Un défaut "
           "`TZ: Europe/Paris` dans `docker_info` ferme la famille."),
    "PARTIALDELETE": ("functions.sh", "Les branches legacy effacent des données sans tester "
                      "`DELETE=1`, alors que la réinitialisation appelle `suppression_appli` avec 0."),
    "CROSSAPPDELETE": ("functions.sh", "Des branches effacent les dossiers `mariadb`/`mysql`/`redis`, "
                       "partagés par plusieurs applications : perte de données hors périmètre."),
    "ORPHANROOT": ("vars", "Données persistées hors du dossier applicatif ; "
                   "aligner les chemins ou documenter l'exception."),
    "INTIGNORED": ("vars", "`intport` déclaré alors que Traefik est désactivé."),
}


class MD(dict):
    """Dict YAML enrichi des numéros de ligne."""

    line: int = 1
    lines: dict = {}


class LineLoader(yaml.SafeLoader):
    pass


def _mapping(loader, node):
    value = MD(loader.construct_pairs(node))
    value.line = node.start_mark.line + 1
    value.lines = {
        loader.construct_object(k, deep=True): v.start_mark.line + 1
        for k, v in node.value
    }
    return value


LineLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, _mapping)


class Repo:
    def __init__(self, root: Path):
        self.root = root.resolve()
        self.dockerapps = self.root / "includes" / "dockerapps"
        self.catalogue = self.root / "includes" / "config" / "services-available"
        self.functions = self.root / "includes" / "functions.sh"
        self._cache: dict[str, object] = {}
        self.yaml_errors: dict[str, str] = {}

    def path(self, rel: str) -> Path:
        return self.root / rel

    def exists(self, rel: str) -> bool:
        return self.path(rel).is_file()

    def text(self, rel: str) -> str:
        return self.path(rel).read_text(encoding="utf-8")

    def load(self, rel: str):
        if rel not in self._cache:
            try:
                self._cache[rel] = yaml.load(self.text(rel), Loader=LineLoader)
            except Exception as exc:  # noqa: BLE001 - on collecte l'erreur
                self._cache[rel] = None
                self.yaml_errors[rel] = str(exc)
        return self._cache[rel]

    def sha(self) -> str:
        try:
            return subprocess.check_output(
                ["git", "rev-parse", "HEAD"], cwd=self.root, text=True,
                stderr=subprocess.DEVNULL,
            ).strip()
        except Exception:  # noqa: BLE001
            return "inconnu"

    def branch(self) -> str:
        try:
            return subprocess.check_output(
                ["git", "rev-parse", "--abbrev-ref", "HEAD"], cwd=self.root, text=True,
                stderr=subprocess.DEVNULL,
            ).strip()
        except Exception:  # noqa: BLE001
            return "inconnu"


def walk(value):
    if isinstance(value, dict):
        yield value
        for item in value.values():
            yield from walk(item)
    elif isinstance(value, list):
        for item in value:
            yield from walk(item)


def module(task, kind):
    for key, value in task.items():
        if str(key).split(".")[-1] == kind:
            return value
    return None


def tasks(document, inherited=False, app=None):
    """Itère les tâches en propageant no_log et en filtrant les blocs d'une autre app."""
    if isinstance(document, list):
        for item in document:
            yield from tasks(item, inherited, app)
    elif isinstance(document, dict):
        conditions = document.get("when", [])
        conditions = conditions if isinstance(conditions, list) else [conditions]
        if app:
            for cond in conditions:
                if not isinstance(cond, str):
                    continue
                match = re.fullmatch(
                    r"pgrole\s*==\s*['\"]([A-Za-z0-9_-]+)['\"]", cond.strip()
                )
                if match and match.group(1) != app:
                    return
        protected = inherited or document.get("no_log") is True
        yield document, protected
        for key in ("tasks", "pre_tasks", "post_tasks", "block", "rescue", "always", "handlers"):
            if key in document:
                yield from tasks(document[key], protected, app)


SECRET_KEY = re.compile(
    r"(?:PASSWORD|PASSWD|DBPASS|(?:^|_)PASS$|SECRET|(?:^|_)TOKEN$|(?:^|_)KEY$|"
    r"API_KEY|APIKEY|APP_KEY|ENCRYPTION_KEY|ENCRYPTION_SALT|JWT_KEY|PRIVATE_KEY)",
    re.I,
)
SECRET_EXCLUDE = re.compile(
    r"(?:_FILE|_DIR|_PATH|_EXISTS|_LENGTH|_METHOD|_ENABLED|_CHECK|_RAW)$|"
    r"masked|NO_PASSWORD|VITE_YOUTUBE_API_KEY",
    re.I,
)


def is_sensitive(key, value) -> bool:
    if SECRET_EXCLUDE.search(str(key)):
        return False
    if isinstance(value, (bool, dict, list)) or value in ("", None):
        return False
    if SECRET_KEY.search(str(key)):
        return True
    return bool(
        re.search(r"user\.pass|(?:AD|YGG)_PASSWORD|AD_TOKEN|://[^/\s]+:[^/\s]+@|[?&]p=", str(value))
    )


def is_fixed(rendered: str) -> bool:
    """Vrai si la valeur ne dépend d'aucune variable : secret potentiellement prévisible."""
    if re.fullmatch(r"\{\{\s*pgrole\s*\}\}", rendered.strip()):
        return True
    return "{{" not in rendered and "${" not in rendered and "$" not in rendered


class Audit:
    def __init__(self, repo: Repo):
        self.repo = repo
        self.apps: list[str] = []
        self.descriptions: dict[str, str] = {}
        self.records: dict[str, dict] = {}
        self.checks: dict[str, list] = collections.defaultdict(list)
        self.stale: list[dict] = []
        self.catalog_orphans: list[str] = []
        # Constats volontairement écartés, justifiés dans curated_findings.yml.
        self.acknowledged: set[tuple[str, str, str]] = set()
        self.acknowledged_reasons: dict[tuple[str, str, str], str] = {}
        self.acknowledged_seen: list[tuple[str, str]] = []

    # ------------------------------------------------------------------ collecte
    def load_catalogue(self):
        orphan_doc = self.repo.dockerapps / "vars"
        for line in self.repo.text("includes/config/services-available").splitlines():
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            ident, _, desc = stripped.partition(" - ")
            ident = ident.strip()
            if not ident:
                continue
            self.apps.append(ident)
            self.descriptions[ident] = desc.strip()
        known = set(self.apps)
        if orphan_doc.is_dir():
            for file in sorted(orphan_doc.glob("*.yml")):
                name = file.stem
                if name not in known:
                    self.catalog_orphans.append(name)

    def resolve_files(self, app: str) -> dict:
        main = f"includes/dockerapps/vars/{app}.yml"
        data = self.repo.load(main) if self.repo.exists(main) else None
        start = {main}
        for kind in ("pretasks", "posttasks"):
            homonym = f"includes/dockerapps/{kind}/{app}.yml"
            if self.repo.exists(homonym):
                start.add(homonym)
            if isinstance(data, dict):
                refs = data.get(kind, [])
                if isinstance(refs, list):
                    for name in refs:
                        start.add(f"includes/dockerapps/{kind}/{name}.yml")
        files: set[str] = set()
        unresolved: list[tuple[str, int, str]] = []
        pending = list(start)
        while pending:
            rel = pending.pop()
            if rel in files:
                continue
            files.add(rel)
            if not self.repo.exists(rel):
                unresolved.append((rel, 0, "MISSING"))
                continue
            if rel.endswith((".yml", ".yaml")):
                refs, unknown = self.references(rel, app)
                pending.extend(refs - files)
                unresolved.extend((rel, line, ref) for line, ref in unknown)
        return {
            "files": sorted(files),
            "unresolved": unresolved,
            "findings": [],
            "data": data,
        }

    def references(self, rel: str, app: str | None = None):
        result: set[str] = set()
        unresolved: list[tuple[int, str]] = []
        document = self.repo.load(rel)
        for task in walk(document):
            for key in ("include_tasks", "import_tasks", "include_vars"):
                value = module(task, key)
                if value is None:
                    continue
                if isinstance(value, dict):
                    value = value.get("file", "")
                if not isinstance(value, str):
                    continue
                targets = [value]
                if "{{ item }}" in value:
                    loop = task.get("loop", task.get("with_items", []))
                    if isinstance(loop, list):
                        targets = [value.replace("{{ item }}", str(x)) for x in loop]
                for target in targets:
                    target = re.sub(r"{{\s*settings.source\s*}}/?", "", target)
                    if "{{" in target or "{%" in target:
                        unresolved.append((getattr(task, "line", 1), target))
                        continue
                    path = Path(target) if target.startswith("includes/") else Path(rel).parent / target
                    if self.repo.exists(str(path)):
                        result.add(str(path))
                    else:
                        unresolved.append((getattr(task, "line", 1), "MISSING:" + str(path)))
            for key in ("template", "copy", "script"):
                value = module(task, key)
                if isinstance(value, dict):
                    value = value.get("src", "")
                if not isinstance(value, str) or not value:
                    continue
                value = re.sub(r"{{\s*settings.source\s*}}/?", "", value)
                if app:
                    value = re.sub(r"{{\s*pgrole\s*}}", app, value)
                candidates = [value]
                loop = task.get("loop", task.get("with_items", []))
                if isinstance(loop, list):
                    for entry in loop:
                        if isinstance(entry, dict):
                            expanded = value
                            for k, v in entry.items():
                                expanded = re.sub(r"{{\s*item\." + str(k) + r"\s*}}", str(v), expanded)
                            candidates.append(expanded)
                        elif isinstance(entry, str):
                            candidates.append(re.sub(r"{{\s*item\s*}}", entry, value))
                for candidate in candidates:
                    if "{{" in candidate or "{%" in candidate:
                        continue
                    for path in (
                        Path(candidate),
                        Path(rel).parent / candidate,
                        Path("includes/dockerapps/templates") / candidate,
                    ):
                        if self.repo.exists(str(path)):
                            result.add(str(path))
                            break
        for match in re.finditer(r"includes/[A-Za-z0-9_./-]+\.(?:yml|yaml|j2|sh|py)", self.repo.text(rel)):
            if self.repo.exists(match.group()):
                result.add(match.group())
        return result, unresolved

    def collect(self):
        self.load_catalogue()
        for app in self.apps:
            self.records[app] = self.resolve_files(app)

    # ------------------------------------------------------------------ constats
    def add(self, app, code, axis, severity, path, line, detail):
        finding = {
            "code": code,
            "axis": axis,
            "severity": severity,
            "path": path,
            "line": max(int(line or 1), 1),
            "detail": detail,
        }
        if finding not in self.records[app]["findings"]:
            self.records[app]["findings"].append(finding)

    def line_of(self, rel, key):
        data = self.repo.load(rel)
        return getattr(data, "lines", {}).get(key, getattr(data, "line", 1))

    def structural(self):
        for app, record in self.records.items():
            main = f"includes/dockerapps/vars/{app}.yml"
            data = record["data"]
            self.check_catalogue(app, main, data)
            if not isinstance(data, dict):
                continue
            self.check_deployment(app, main, data, record)
            self.check_env(app, main, data)
            self.check_prompts(app, record)
            self.check_debug(app, record)
            self.check_task_secrets(app, record)
            self.check_deploy_hooks(app, record)
            self.check_cycle(app, record)
        self.check_catalogue_vars_files()
        self.check_legacy_deletions()

    def check_catalogue(self, app, main, data):
        if not self.repo.exists(main):
            self.add(app, "CATALOGMISSING", "catalogue", "P1", main, 1,
                     "Entrée catalogue sans fichier de variables")
            return
        if not self.descriptions.get(app):
            self.add(app, "CATALOGDESC", "catalogue", "P3",
                     "includes/config/services-available", 0,
                     "Description absente ou vide dans le menu")
        if isinstance(data, dict) and data.get("pgrole") != app:
            self.add(app, "NAME", "catalogue", "P1", main,
                     self.line_of(main, "pgrole"),
                     f"pgrole « {data.get('pgrole')} » différent de l'identifiant catalogue")

    def check_catalogue_vars_files(self):
        catalog = set(self.apps)
        for name in self.catalog_orphans:
            severity = "P3"
            detail = "Fichier de variables hors catalogue"
            self.records.setdefault(
                name,
                {"files": [f"includes/dockerapps/vars/{name}.yml"], "unresolved": [],
                 "findings": [], "data": self.repo.load(f"includes/dockerapps/vars/{name}.yml")},
            )
            self.add(name, "CATALOGORPHAN", "catalogue", severity,
                     f"includes/dockerapps/vars/{name}.yml", 1, detail)
        for app in self.apps:
            if app not in catalog:  # pragma: no cover - garde-fou
                continue

    def check_deployment(self, app, main, data, record):
        generic = data.get("docker_deploy_enabled", True) is not False
        traefik = data.get("traefik_labels_enabled", True) is not False
        has_hooks = len(record["files"]) > 1
        if generic and not data.get("image"):
            self.add(app, "IMAGE", "deploiement", "P1", main, 1,
                     "Image principale absente malgré le déploiement générique")
        if generic and traefik and "intport" not in data:
            self.add(app, "PORT", "traefik", "P1", main, 1,
                     "Port interne absent avec labels génériques actifs")
        if not traefik and "intport" in data:
            self.add(app, "INTIGNORED", "minimalisme", "P3", main,
                     self.line_of(main, "intport"),
                     "intport déclaré alors que les labels génériques sont désactivés")
        if not generic and not has_hooks:
            self.add(app, "NOHOOKSCUSTOM", "deploiement", "P1", main,
                     self.line_of(main, "docker_deploy_enabled"),
                     "Déploiement générique désactivé sans hook pour déployer l'application")
        if not generic and not data.get("image") and not has_hooks:
            self.add(app, "NOIMAGEHOOKS", "deploiement", "P2", main, 1,
                     "Ni image principale ni hook de déploiement")
        if data.get("pull_image") is False:
            image = str(data.get("image", ""))
            if image and not re.search(r"(^|/)local|localhost|127\.0\.0\.1|:ssdv2", image):
                self.add(app, "REGISTRYLOCAL", "deploiement", "P3", main,
                         self.line_of(main, "pull_image"),
                         f"pull_image: false sur une image de registre ({image})")
        volumes = data.get("pg_volumes") or []
        if isinstance(volumes, list):
            for volume in volumes:
                text = str(volume)
                match = re.search(
                    r"settings\.storage\s*\}\}/docker/\{\{\s*lookup\('env','USER'\)\s*\}\}/([^/{\s]+)", text
                )
                if not match:
                    continue
                root = match.group(1).rstrip(":")
                if root != app and not root.startswith("{{") and ":" not in root:
                    self.add(app, "ORPHANROOT", "persistance", "P3", main,
                             self.line_of(main, "pg_volumes"),
                             f"Données persistantes sous « {root} » au lieu de {app}")
        if data.get("labels") and generic:
            self.add(app, "RAWLABEL", "traefik", "P1", main, self.line_of(main, "labels"),
                     "Labels à la racine ignorés par le conteneur générique")
        for key in ("pretasks", "posttasks"):
            refs = data.get(key, [])
            if isinstance(refs, list) and app in refs and self.repo.exists(
                f"includes/dockerapps/{key}/{app}.yml"
            ):
                self.add(app, "DOUBLEHOOK", "minimalisme", "P3", main, self.line_of(main, key),
                         f"Chargement homonyme automatique puis explicite de {key}")
        env = data.get("pg_env")
        if isinstance(env, dict) and generic:
            if "TZ" not in env and not any(
                "/etc/localtime" in str(v) for v in (volumes or [])
            ):
                self.add(app, "TZ", "deploiement", "P3", main, 1,
                         "Aucun TZ ni montage /etc/localtime dans les variables principales")
        if "healthcheck" in data:
            self.add(app, "IGNOREDOPTION", "deploiement", "P2", main,
                     self.line_of(main, "healthcheck"),
                     "healthcheck à la racine des variables : non transmis par le playbook générique")
        if "hostname" in data:
            self.add(app, "IGNOREDOPTION", "minimalisme", "P3", main,
                     self.line_of(main, "hostname"),
                     "hostname à la racine des variables : non transmis au conteneur")
        specific = data.get("specific_docker_info")
        if isinstance(specific, dict) and traefik:
            ports = specific.get("ports") or specific.get("published_ports") or []
            intport = str(data.get("intport", "")).strip()
            for binding in ports if isinstance(ports, list) else []:
                text = str(binding)
                container = text.rsplit(":", 1)[-1].split("/")[0]
                host = text.rsplit(":", 2)[0] if text.count(":") >= 2 else ""
                if host.split(":")[0] in {"127.0.0.1", "localhost"}:
                    continue
                if intport and container == intport:
                    self.add(app, "WEBHOSTPORT", "traefik", "P2", main,
                             getattr(specific, "lines", {}).get("ports", self.line_of(main, "pg_env")),
                             f"Port Web {text} publié sur l'hôte en plus du routage Traefik")

    def generic_no_log_default(self) -> bool:
        """Vrai si le playbook générique masque les paramètres Docker par défaut."""
        document = self.repo.load("includes/dockerapps/vars/generique.yml")
        for task in walk(document):
            if isinstance(task, dict) and task.get("name") == "Prepare docker info":
                return bool(re.search(r"default\(\s*true\s*\)", str(task.get("no_log", ""))))
        return False

    def check_env(self, app, main, data):
        env = data.get("pg_env")
        if not isinstance(env, dict):
            return
        sensitive = [k for k, v in env.items() if is_sensitive(k, v)]
        masked = self.generic_no_log_default()
        if data.get("docker_no_log") is False:
            masked = False
        elif data.get("docker_no_log") is True:
            masked = True
        if (
            sensitive
            and not masked
            and data.get("docker_deploy_enabled", True) is not False
        ):
            self.add(app, "GENLOG", "secrets", "P1", main, self.line_of(main, "pg_env"),
                     "Paramètres sensibles dans pg_env sans docker_no_log : "
                     + ", ".join(map(str, sensitive)))
        for key, value in env.items():
            if not is_sensitive(key, value):
                continue
            if str(key).upper() in {"PASSWORD_LENGTH", "PASSWORD_MIN_LENGTH"}:
                continue
            if is_fixed(str(value)):
                self.add(app, "FIXEDSECRET", "secrets", "P2", main,
                         getattr(env, "lines", {}).get(key, self.line_of(main, "pg_env")),
                         f"Secret interne ou identifiant d'accès prévisible dans {key}")

    def check_prompts(self, app, record):
        for rel in record["files"]:
            if not rel.endswith((".yml", ".yaml")) or not self.repo.exists(rel):
                continue
            document = self.repo.load(rel)
            for task, protected in tasks(document, app=app):
                pause = module(task, "pause")
                if pause is None:
                    continue
                prompt = str(pause.get("prompt", "")) if isinstance(pause, dict) else str(pause)
                if "SSDV2_PROMPT" not in prompt:
                    self.add(app, "PROMPTMARK", "assistance", "P2", rel,
                             getattr(task, "line", 1),
                             "Invite pause sans marqueur SSDV2_PROMPT")
                secret = bool(re.search(r'"secret"\s*:\s*true|"kind"\s*:\s*"secret"', prompt))
                if not secret:
                    continue
                if not isinstance(pause, dict) or pause.get("echo", True) is not False:
                    self.add(app, "PROMPTECHO", "secrets", "P1", rel,
                             getattr(task, "line", 1),
                             "Invite déclarée secrète avec écho actif ou non désactivé")
                if not protected:
                    self.add(app, "PROMPTLOG", "secrets", "P1", rel,
                             getattr(task, "line", 1),
                             "Invite déclarée secrète sans no_log hérité ou local")

    SECRET_EXCLUDE_NAME = re.compile(
        r"(?:masked|_dir$|_path$|_file$|_id$|_name$|_url$|_env$|_length$|_exists$)",
        re.I,
    )
    SECRET_NAME = re.compile(
        r"(?:password|passwd|secret|token|apikey|api_key|appkey|jwtsecret|jwt_secret|"
        r"adminpassword|admin_password|_key$)",
        re.I,
    )

    def check_debug(self, app, record):
        """Une tâche `debug` ne doit pas interpoler une valeur secrète.

        La valeur est recopiée dans le journal persistant (`log_path`), où elle
        survit à toute rotation ultérieure. Les chemins de fichiers sont exclus :
        afficher où lire un secret n'est pas l'afficher.
        """
        for rel in record["files"]:
            if not rel.endswith((".yml", ".yaml")) or not self.repo.exists(rel):
                continue
            for task, _ in tasks(self.repo.load(rel), app=app):
                debug = module(task, "debug")
                if debug is None:
                    continue
                text = str(debug.get("msg", "")) + " " + str(debug.get("var", ""))
                for expression in re.findall(r"{{(.*?)}}", text):
                    if "/" in expression or "settings.storage" in expression:
                        continue
                    bare = expression.split("|")[0]
                    if self.SECRET_EXCLUDE_NAME.search(bare.strip()):
                        continue
                    if self.SECRET_NAME.search(bare):
                        self.add(app, "DEBUGSECRET", "secrets", "P0", rel,
                                 getattr(task, "line", 1),
                                 "Secret interpolé dans un message d'installation : "
                                 + bare.strip())
                        break

    MODULE_SECRET = re.compile(
        r"(?:password|passwd|token|secret|Authorization|api_?key|X-Plex-Token|--client-secret)",
        re.I,
    )

    def _sensitive_payload(self, kind, payload):
        """Champs sensibles d'une tâche, selon le type de module.

        Les modules `uri`, `command`, `shell` et `get_url` n'ont pas d'`env` :
        on inspecte les en-têtes, le corps et la commande, en repérant les
        variables interpolées dont le nom est secret.
        """
        keys: list[str] = []
        if kind == "docker_container" and isinstance(payload, dict):
            env = payload.get("env")
            if isinstance(env, dict):
                keys += [str(k) for k, v in env.items() if is_sensitive(k, v)]
            return keys
        if kind == "set_fact" and isinstance(payload, dict):
            return [str(k) for k, v in payload.items() if is_sensitive(k, v)]
        if kind in ("uri", "get_url") and isinstance(payload, dict):
            for header, value in (payload.get("headers") or {}).items():
                if self.MODULE_SECRET.search(str(header)) or self.MODULE_SECRET.search(str(value)):
                    keys.append(str(header))
            body = payload.get("body")
            if isinstance(body, dict):
                keys += [str(k) for k, v in body.items() if is_sensitive(k, v)]
            url = str(payload.get("url", ""))
            if self.MODULE_SECRET.search(url):
                keys.append("url")
            return keys
        if kind in ("command", "shell", "docker_container_exec"):
            text = str(payload)
            for expression in re.findall(r"{{(.*?)}}", text):
                bare = expression.split("|")[0]
                if self.SECRET_NAME.search(bare) and not self.SECRET_EXCLUDE_NAME.search(bare):
                    keys.append(bare.strip())
            for literal in ("--client-secret", "X-Plex-Token", "PGPASSWORD", "--password"):
                if literal in text:
                    keys.append(literal)
            return keys
        return keys

    def check_task_secrets(self, app, record):
        """Tâches qui manipulent un secret sans protection, hors invites."""
        for rel in record["files"]:
            if not rel.endswith((".yml", ".yaml")) or not self.repo.exists(rel):
                continue
            for task, protected in tasks(self.repo.load(rel), app=app):
                if protected:
                    continue
                for kind in ("docker_container", "set_fact", "uri", "get_url",
                             "command", "shell", "docker_container_exec"):
                    payload = module(task, kind)
                    if payload is None:
                        continue
                    keys = self._sensitive_payload(kind, payload)
                    if not keys:
                        continue
                    self.add(app, "TASKLOG", "secrets", "P1", rel,
                             getattr(task, "line", 1),
                             f"Tâche {kind} manipulant des champs sensibles sans no_log : "
                             + ", ".join(sorted(set(keys))))

    def check_deploy_hooks(self, app, record):
        """Hooks qui redéploient `docker_info` (donc `pg_env`) sans masquage."""
        for rel in record["files"]:
            if not rel.endswith((".yml", ".yaml")) or not self.repo.exists(rel):
                continue
            for task, protected in tasks(self.repo.load(rel), app=app):
                payload = module(task, "docker_container")
                if not isinstance(payload, str) or "docker_info" not in payload:
                    continue
                if protected:
                    continue
                self.add(app, "GENLOG", "secrets", "P1", rel,
                         getattr(task, "line", 1),
                         "Hook redéployant docker_info sans no_log : les paramètres "
                         "sensibles repartent dans le journal")

    def check_cycle(self, app, record):
        stat_paths = set()
        waits = []
        functions_text = self.repo.text("includes/functions.sh") if self.repo.functions.is_file() else ""
        for rel in record["files"]:
            if not rel.endswith((".yml", ".yaml")) or not self.repo.exists(rel):
                continue
            for index, line in enumerate(self.repo.text(rel).splitlines(), 1):
                stripped = line.lstrip()
                if stripped.startswith("#"):
                    continue
                if re.search(r"docker\s+volume\s+prune\s+.*-[^\s]*[af]", line):
                    self.add(app, "GLOBALPRUNE", "cycle", "P0", rel, index,
                             "Suppression globale de volumes Docker")
            document = self.repo.load(rel)
            for task, _ in tasks(document, app=app):
                stat = module(task, "stat")
                if isinstance(stat, dict) and stat.get("path"):
                    stat_paths.add(str(stat["path"]))
                wait = module(task, "wait_for")
                if isinstance(wait, dict) and wait.get("path"):
                    waits.append((rel, getattr(task, "line", 1), str(wait["path"]), task))
                shell = module(task, "shell") or module(task, "command")
                if isinstance(shell, str) and re.search(r"^\s*pause\b", shell, re.M):
                    self.add(app, "COURTESY", "assistance", "P2", rel,
                             getattr(task, "line", 1),
                             "pause shell de courtoisie : sauté en mode non interactif")
                file_module = module(task, "file")
                if isinstance(file_module, dict) and file_module.get("state") == "directory":
                    mode = file_module.get("mode")
                    if str(mode) in {"0777", "777", "511"}:
                        self.add(app, "WORLDWRITE", "permissions", "P2", rel,
                                 getattr(task, "line", 1),
                                 "Dossier créé ou modifié en 0777")
                network = module(task, "docker_network")
                if isinstance(network, dict) and network.get("state") != "absent":
                    name = str(network.get("name", ""))
                    resolved = re.sub(r"{{\s*pgrole\s*}}", app, name).strip()
                    if resolved and resolved != "traefik_proxy" and "{{" not in resolved:
                        cleaned = (
                            f"docker network rm {resolved}" in functions_text
                            or f"cleanup_app_network {resolved}" in functions_text
                        )
                        if not cleaned:
                            self.add(app, "NETWORKCLEAN", "cycle", "P2", rel,
                                     getattr(task, "line", 1),
                                     f"Réseau dédié « {resolved} » sans suppression ciblée dans suppression_appli")
            for match in re.finditer(r"suppression_appli\s+([^\s;]+)", self.repo.text(rel)):
                target = match.group(1)
                if target.endswith('"') or target.endswith("'") or "$" in target:
                    continue
                line_no = self.repo.text(rel)[: match.start()].count("\n") + 1
                self.add(app, "SUPPARG", "cycle", "P2", rel, line_no,
                         f"Appel suppression_appli {target} sans argument 0/1 explicite")
        if waits and not stat_paths:
            for rel, line, path, task in waits:
                when = str(task.get("when", ""))
                if "stat" in when:
                    continue
                self.add(app, "IDEMPOTENT", "cycle", "P2", rel, line,
                         f"wait_for sur {path} sans test stat préalable : immédiat si le fichier existe, "
                         "mais un artefact absent au premier démarrage coûte le timeout complet")

    def _app_lines(self, app: str):
        for rel in self.records[app]["files"]:
            if not rel.endswith((".yml", ".yaml")) or not self.repo.exists(rel):
                continue
            for number, line in enumerate(self.repo.text(rel).splitlines(), 1):
                if line.lstrip().startswith("#"):
                    continue
                yield rel, number, line

    def owners_of_dir(self, segment: str) -> dict[str, list[str]]:
        """Applications qui montent réellement le dossier hôte `.../<segment>`.

        La propriété est prouvée par le montage, jamais par un nom de conteneur
        ou d'hôte : deux apps peuvent nommer un conteneur `redis` sans partager
        le même dossier persistant.
        """
        pattern = re.compile(
            r"docker/\{\{\s*lookup\('env','USER'\)\s*\}\}/" + re.escape(segment) + r"(?::|/|\"|$)"
        )
        owners: dict[str, list[str]] = {}
        for app in self.records:
            for rel, number, line in self._app_lines(app):
                if pattern.search(line):
                    owners.setdefault(app, []).append(f"{rel}:{number}")
                    break
        return owners

    def owners_of_container(self, name: str) -> dict[str, list[str]]:
        """Applications qui créent le conteneur `<name>` (docker_container ou docker run)."""
        pattern = re.compile(r"^\s*name:\s*['\"]?" + re.escape(name) + r"['\"]?\s*$")
        run_pattern = re.compile(r"docker\s+run\b[^\n]*--name[= ]" + re.escape(name) + r"\b")
        owners: dict[str, list[str]] = {}
        for app in self.records:
            for rel, number, line in self._app_lines(app):
                if pattern.match(line) or run_pattern.search(line):
                    owners.setdefault(app, []).append(f"{rel}:{number}")
                    break
        return owners

    def _foreign(self, owners: dict[str, list[str]], apps: list[str]) -> dict[str, list[str]]:
        return {name: refs for name, refs in owners.items() if name not in apps}

    def check_legacy_deletions(self):
        """Analyse le bloc `case $APPSELECTED in` de suppression_appli (filet legacy)."""
        if not self.repo.functions.is_file():
            return
        lines = self.repo.text("includes/functions.sh").splitlines()
        start = None
        for index, line in enumerate(lines):
            if re.match(r"\s*case\s+\$APPSELECTED\s+in", line):
                start = index
                break
        if start is None:
            return
        branch = None
        tokens: list[str] = []
        guarded = 0
        pending_if = 0
        for index in range(start + 1, len(lines)):
            line = lines[index]
            stripped = line.strip()
            rel = index + 1
            if re.match(r"^\s*esac\s*$", line):
                break
            header = re.match(r"^\s{2}([A-Za-z0-9_.*|-]+)\)\s*$", line)
            if header:
                branch = header.group(1)
                tokens = [token.strip() for token in branch.split("|")]
                guarded = 0
                pending_if = 0
                continue
            if branch is None:
                continue
            if re.search(r"\bif\b.*\bDELETE\b", line):
                pending_if += 1
            if pending_if:
                if re.search(r"\bthen\s*$", stripped):
                    guarded += 1
                    pending_if -= 1
                continue
            if re.match(r"^\s*fi\s*$", line) and guarded:
                guarded -= 1
                continue
            apps = [token[:-1] if token.endswith("*") else token for token in tokens]
            apps = [name for name in apps if name in self.records]
            if not apps:
                continue

            removed_dir = re.search(
                r"\brm\s+-rf\s+\S*/docker/\$\{USER\}/([A-Za-z0-9_.-]+)", line
            )
            if removed_dir:
                segment = removed_dir.group(1).lstrip(".")
                if guarded:
                    continue
                owners = self.owners_of_dir(segment)
                foreign = self._foreign(owners, apps)
                evidence = ""
                if foreign:
                    name = sorted(foreign)[0]
                    evidence = f" (preuve : {name} → {foreign[name][0]})"
                for app in apps:
                    if foreign:
                        self.add(app, "CROSSAPPDELETE", "cycle", "P1", "includes/functions.sh", rel,
                                 f"La branche de {app} supprime le dossier « {segment} », monté par "
                                 f"{', '.join(sorted(foreign))}{evidence}, sans vérifier DELETE=1")
                    elif app in owners or segment == app or segment.startswith(app + "-"):
                        self.add(app, "PARTIALDELETE", "cycle", "P1", "includes/functions.sh", rel,
                                 f"La branche de {app} supprime « {segment} » (données propres) sans "
                                 "vérifier DELETE=1 : une réinstallation (suppression partielle) l'efface")
                    else:
                        self.checks[app].append({
                            "axis": "cycle",
                            "path": "includes/functions.sh",
                            "line": rel,
                            "detail": f"Suppression de « {segment} » non attribuable à {app} : "
                                      "vérifier si ce dossier contient des données d'une autre application",
                        })
                continue

            removed_containers = re.search(r"\bdocker\s+rm\s+-f\s+([^\n>&|]+)", line)
            if removed_containers and not guarded:
                for name in removed_containers.group(1).split():
                    owners = self.owners_of_container(name)
                    foreign = self._foreign(owners, apps)
                    if not foreign:
                        continue
                    for app in apps:
                        if app in owners:
                            self.checks[app].append({
                                "axis": "cycle",
                                "path": "includes/functions.sh",
                                "line": rel,
                                "detail": f"Le conteneur « {name} » est créé à la fois par {app} et par "
                                          f"{', '.join(sorted(foreign))} : définition partagée à clarifier",
                            })
                            continue
                        name_app = sorted(foreign)[0]
                        self.add(app, "OTHERAPPDELETE", "cycle", "P1", "includes/functions.sh", rel,
                                 f"La branche de {app} supprime le conteneur « {name} », créé par "
                                 f"{', '.join(sorted(foreign))} (preuve : {foreign[name_app][0]})")

    # ------------------------------------------------------------------ curation
    def apply_acknowledged(self):
        """Retire les constats déclarés et justifiés dans `acknowledged`."""
        if not self.acknowledged:
            return
        for app, record in self.records.items():
            kept = []
            for finding in record["findings"]:
                matched = next(
                    (
                        (code, target)
                        for owner, code, target in sorted(self.acknowledged)
                        if owner == app
                        and code == finding["code"]
                        and (not target or target in finding["detail"])
                    ),
                    None,
                )
                if matched:
                    self.acknowledged_seen.append(
                        (app, f"{matched[0]} {matched[1]}".strip())
                    )
                    continue
                kept.append(finding)
            record["findings"] = kept

    def load_acknowledged(self, path: Path):
        """Charge les écarts assumés avant les contrôles structurels."""
        if not path.is_file():
            return
        document = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        for entry in document.get("acknowledged", []) or []:
            key = (entry["app"], entry["code"], str(entry.get("target", "")))
            self.acknowledged.add(key)
            self.acknowledged_reasons[key] = entry.get("reason", "")

    def load_curated(self, path: Path):
        if not path.is_file():
            return
        document = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        for entry in document.get("findings", []) or []:
            app = entry["app"]
            if app not in self.records:
                self.stale.append({"app": app, "path": entry.get("path"), "detail": entry["detail"],
                                   "reason": "application absente du catalogue"})
                continue
            rel = entry["path"]
            path = self.repo.path(rel)
            needle = entry.get("needle")
            line = entry.get("line", 1)
            if needle:
                if not path.is_file():
                    self.stale.append({"app": app, "path": rel, "detail": entry["detail"],
                                       "reason": "fichier absent"})
                    continue
                found = None
                for index, text in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                    if needle in text:
                        found = index
                        break
                if found is None:
                    self.stale.append({"app": app, "path": rel, "detail": entry["detail"],
                                       "reason": f"motif introuvable : {needle}"})
                    continue
                line = found
            self.add(app, entry["code"], entry["axis"], entry["severity"], rel, line, entry["detail"])
        for entry in document.get("checks", []) or []:
            app = entry["app"]
            if app not in self.records:
                continue
            rel = entry["path"]
            needle = entry.get("needle")
            line = entry.get("line", 1)
            if needle:
                path = self.repo.path(rel)
                if not path.is_file():
                    continue
                found = None
                for index, text in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                    if needle in text:
                        found = index
                        break
                if found is None:
                    self.stale.append({"app": app, "path": rel, "detail": entry["detail"],
                                       "reason": f"question obsolète : {needle}"})
                    continue
                line = found
            self.checks[app].append({
                "axis": entry["axis"], "path": rel, "line": line, "detail": entry["detail"],
            })

    # ------------------------------------------------------------------ sorties
    def states(self, app):
        record = self.records[app]
        data = record["data"]
        result = {axis: "aucun écart détecté" for axis in AXES}
        if isinstance(data, dict) and data.get("traefik_labels_enabled", True) is False:
            text = "\n".join(
                self.repo.text(rel) for rel in record["files"] if self.repo.exists(rel)
            )
            if "traefik.http.routers." not in text:
                result["traefik"] = "non applicable"
        for check in self.checks[app]:
            result[check["axis"]] = "à vérifier"
        for finding in record["findings"]:
            result[finding["axis"]] = "écart confirmé"
        return result

    def integration_type(self, app):
        record = self.records[app]
        data = record["data"]
        if isinstance(data, list):
            return "Cas E — playbook dédié"
        if app in self.catalog_orphans:
            return "Fichier interne / exemple"
        if not isinstance(data, dict):
            return "inconnu"
        if data.get("docker_deploy_enabled", True) is False:
            return "Cas D — déploiement custom"
        hooks = len(record["files"]) > 1
        post = data.get("posttasks") or []
        database = any(
            name in ("mariadb", "postgresql") for name in (post if isinstance(post, list) else [])
        )
        if database:
            return "Cas B — conteneur + base"
        if hooks:
            return "Cas C — conteneur + compagnons"
        return "Cas A — conteneur générique"

    def priority(self, app):
        severities = [f["severity"] for f in self.records[app]["findings"]]
        return min(severities, key=SEVERITY_ORDER.get) if severities else "—"


def write_outputs(audit: Audit, repo: Repo, out: Path, baseline: dict | None = None):
    out.mkdir(parents=True, exist_ok=True)
    states = {app: audit.states(app) for app in audit.records}
    counts = collections.Counter(audit.priority(app) for app in audit.records)
    unique = collections.defaultdict(list)
    for app, record in audit.records.items():
        for finding in record["findings"]:
            key = (finding["code"], finding["path"], finding["line"], finding["detail"])
            unique[key].append(app)
    total = sum(len(record["findings"]) for record in audit.records.values())
    codes = collections.defaultdict(set)
    for app, record in audit.records.items():
        for finding in record["findings"]:
            codes[finding["code"]].add(app)
    all_files = sorted({rel for record in audit.records.values() for rel in record["files"]})
    acknowledged_entries = [
        {
            "app": app,
            "code": code,
            "target": target,
            "reason": audit.acknowledged_reasons.get((app, code, target), ""),
            "seen": (app, f"{code} {target}".strip()) in audit.acknowledged_seen,
        }
        for app, code, target in sorted(audit.acknowledged)
    ]

    git_sha = repo.sha()
    git_branch = repo.branch()

    def link(rel, line=1):
        return f"[{rel}:{line}](../../{rel}#L{line})"

    def fix(code):
        return FIXES.get(code, "Constater et corriger selon la règle du skill.")

    def rule(code):
        return RULES.get(code, "Écart au contrat add-app.")

    # --------------------------------------------------------------- JSON
    payload = {
        "repo": str(repo.root),
        "branch": git_branch,
        "commit": git_sha,
        "generated_by": "scripts/audit/apps_alignment.py",
        "apps": {
            app: {
                "files": record["files"],
                "unresolved": [list(item) for item in record["unresolved"]],
                "findings": record["findings"],
                "checks": audit.checks[app],
                "states": states[app],
                "integration": audit.integration_type(app),
                "priority": audit.priority(app),
            }
            for app, record in audit.records.items()
        },
        "catalog_orphans": audit.catalog_orphans,
        "stale_curated": audit.stale,
        "acknowledged": [
            {"app": app, "code": code, "target": target,
             "reason": audit.acknowledged_reasons.get((app, code, target), ""),
             "applied": (app, f"{code} {target}".strip()) in audit.acknowledged_seen}
            for app, code, target in sorted(audit.acknowledged)
        ],
        "acknowledged_seen": [f"{app}: {label}" for app, label in audit.acknowledged_seen],
        "yaml_errors": repo.yaml_errors,
        "totals": {
            "apps": len(audit.records),
            "files": len(all_files),
            "unique_findings": len(unique),
            "occurrences": total,
            "priorities": dict(counts),
        },
    }
    (out / "apps-alignment.json").write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    # --------------------------------------------------------------- CSV
    fields = [
        "application", "description", "type_integration", "fichiers_audites",
        *AXES, "priorite_max", "codes_ecarts", "nb_ecarts", "preuves",
        "recommandations", "verifications_restantes", "ecarts_assumes",
    ]
    with (out / "apps-alignment.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for app, record in audit.records.items():
            app_codes = sorted({f["code"] for f in record["findings"]})
            writer.writerow({
                "application": app,
                "description": audit.descriptions.get(app, ""),
                "type_integration": audit.integration_type(app),
                "fichiers_audites": " | ".join(record["files"]),
                **states[app],
                "priorite_max": audit.priority(app),
                "codes_ecarts": " | ".join(app_codes),
                "nb_ecarts": len(record["findings"]),
                "preuves": " | ".join(
                    f"{f['code']} {f['path']}:{f['line']} — {f['detail']}"
                    for f in record["findings"]
                ),
                "recommandations": " | ".join(f"{code}: {fix(code)}" for code in app_codes),
                "verifications_restantes": " | ".join(
                    f"{c['axis']}: {c['path']}:{c['line']} — {c['detail']}"
                    for c in audit.checks[app]
                ),
                "ecarts_assumes": " | ".join(
                    f"{entry['code']} {entry['target']}: {entry['reason']}"
                    for entry in acknowledged_entries
                    if entry["app"] == app
                ),
            })

    # --------------------------------------------------------------- Markdown
    md: list[str] = []

    def emit(text=""):
        md.append(text)

    emit("# Alignement des applications SSDV2 sur le skill `add-app`")
    emit()
    emit(
        f"Audit statique de la branche `{git_branch}` ({git_sha[:12]}). "
        "Source du contrat : skill `add-app`. Catalogue : `includes/config/services-available`."
    )
    emit()
    emit(
        f"**{len(audit.records)} applications couvertes ; {len(all_files)} fichiers associés ; "
        f"{len(unique)} constats distincts ({total} occurrences application/constat).** "
        "Un défaut partagé est compté sur chaque application concernée. "
        "Ces compteurs décrivent des écarts statiques, pas une note de sécurité. "
        f"Le total inclut les {len(audit.apps)} entrées du catalogue et "
        f"{len(audit.catalog_orphans)} fichier(s) de variables interne(s) ou d'exemple."
    )
    emit()
    emit("## 1. Synthèse")
    emit()
    emit("| Priorité maximale | Applications | Signification |")
    emit("|---|---:|---|")
    for priority, description in [
        ("P0", "Destructif ou secret réel exposé : correction immédiate."),
        ("P1", "Données menacées, installation compromise ou secret journalisé."),
        ("P2", "Robustesse, exposition, permissions ou nettoyage à corriger."),
        ("P3", "Conventions et champs inutilisés."),
        ("—", "Aucun écart retenu par les contrôles statiques."),
    ]:
        emit(f"| {priority} | {counts[priority]} | {description} |")
    emit()
    order = sorted(
        codes,
        key=lambda c: (
            min(SEVERITY_ORDER[f["severity"]] for r in audit.records.values() for f in r["findings"] if f["code"] == c),
            -len(codes[c]),
        ),
    )
    emit("### À traiter en premier")
    emit()
    for code in order[:6]:
        severity = min(
            (f["severity"] for r in audit.records.values() for f in r["findings"] if f["code"] == code),
            key=SEVERITY_ORDER.get,
        )
        emit(f"- **{severity} {code}** ({len(codes[code])} application(s)) — {fix(code)}")
    emit()
    emit("### Couverture par axe")
    emit()
    emit("| Axe | Aucun écart | Écart confirmé | À vérifier | Non applicable |")
    emit("|---|---:|---:|---:|---:|")
    for axis in AXES:
        counter = collections.Counter(state[axis] for state in states.values())
        emit(
            f"| {AXIS_LABELS[axis]} | {counter['aucun écart détecté']} | "
            f"{counter['écart confirmé']} | {counter['à vérifier']} | "
            f"{counter['non applicable']} |"
        )
    emit()
    emit("### Classement de la revue")
    emit()
    families_here: dict[tuple[str, str], set[str]] = collections.defaultdict(set)
    for app, record in audit.records.items():
        for finding in record["findings"]:
            families_here[(finding["severity"], finding["code"])].add(app)
    emit("**Écarts confirmés par lecture du code :** "
         + ", ".join(
             f"`{code}` ({severity}, {len(apps)} app.)"
             for (severity, code), apps in sorted(
                 families_here.items(),
                 key=lambda item: (SEVERITY_ORDER[item[0][0]], item[0][1]),
             )
             if severity in ("P0", "P1")
         ))
    emit()
    emit("**Faux positifs écartés pendant la revue** (aucun compteur ne les inclut) :")
    emit()
    for hypothesis, why in REJECTED.items():
        emit(f"- *{hypothesis}* — {why}")
    emit()
    uncertain = sorted(
        code for code in codes
        if EVIDENCE.get(code, ("", "", "à vérifier"))[2] != "confirmé (code)"
    )
    emit("**Points restant à vérifier :** "
         + (", ".join(f"`{code}`" for code in uncertain) or "aucun")
         + f" ; {sum(len(items) for items in audit.checks.values())} question(s) "
           "détaillées en section 5, qui ne sont pas des défauts affirmés.")
    emit()
    emit("### Types d'intégration")
    emit()
    emit("| Cas | Applications |")
    emit("|---|---:|")
    kinds = collections.Counter(audit.integration_type(app) for app in audit.records)
    for kind, number in sorted(kinds.items()):
        emit(f"| {kind} | {number} |")
    emit()
    if audit.catalog_orphans:
        emit("### Fichiers de variables hors catalogue")
        emit()
        emit(
            "Ces fichiers ne sont pas installables depuis le menu. Les cas internes "
            "(`generique`, `traefik`) et d'exemple sont normaux ; les autres sont à qualifier."
        )
        emit()
        for name in audit.catalog_orphans:
            emit(f"- `includes/dockerapps/vars/{name}.yml`")
        emit()

    emit("## 2. Méthode et limites")
    emit()
    emit(
        "Le script `scripts/audit/apps_alignment.py` combine : parsing YAML avec numéros de ligne, "
        "suivi récursif des hooks homonymes et explicites, inclusions et templates référencés, "
        "puis contrôles structurels et relecture curatée. Les conditions `pgrole == …` des "
        "templates communs sont respectées : une branche dédiée à une application n'est pas "
        "imputée aux autres. Il est reproductible : deux exécutions sur le même commit "
        "produisent les mêmes sorties."
    )
    emit()
    emit(
        "Limites : aucune image n'est téléchargée ni démarrée. Les ports réellement écoutés, "
        "les versions amont et CVE, les migrations de base, les volumes anonymes implicites, "
        "le DNS, TLS et le comportement des clients machine ne sont pas certifiés. "
        "Les variables personnalisées de `~/seedbox/vars` et l'état installé sont hors périmètre."
    )
    emit()
    if audit.stale:
        emit(f"**{len(audit.stale)} constat(s) curaté(s) obsolète(s)** sur cette branche "
             "(motif introuvable ou application absente) : voir `apps-alignment.json`, "
             "clé `stale_curated`. Ces entrées sont exclues des compteurs.")
        emit()
    emit("## 3. Constats détaillés")
    emit()
    families: dict[tuple[str, str], set[str]] = collections.defaultdict(set)
    for app, record in audit.records.items():
        for finding in record["findings"]:
            families[(finding["severity"], finding["code"])].add(app)
    for severity, code in sorted(families, key=lambda key: (SEVERITY_ORDER[key[0]], key[1])):
        occurrences = sorted(
            (key, users)
            for key, users in unique.items()
            if key[0] == code
            and any(
                f["severity"] == severity
                for r in audit.records.values()
                for f in r["findings"]
                if f["code"] == code
            )
        )
        apps_here = sorted(families[(severity, code)])
        emit(f"### {code} — {severity} — {len(apps_here)} application(s)")
        emit()
        trigger, impact, certainty = EVIDENCE.get(
            code, ("motif détecté dans le code", "à qualifier", "à vérifier"))
        emit(f"- **Déclencheur :** {trigger}")
        emit(f"- **Impact :** {impact}")
        emit(f"- **Certitude :** {certainty}")
        emit(f"- **Règle :** {rule(code)}")
        emit(f"- **Correction :** {fix(code)}")
        emit()
        emit("| Preuve | Applications | Constat |")
        emit("|---|---|---|")
        for (_, rel, line, detail), users in occurrences:
            shared = sorted(set(users) & set(apps_here))
            if not shared:
                continue
            emit(f"| {link(rel, line)} | {', '.join(shared)} | {detail.replace('|', '&#124;')} |")
        emit()

    emit("## 4. Matrice des applications")
    emit()
    emit("Le détail par axe est dans [apps-alignment.csv](apps-alignment.csv).")
    emit()
    emit("| Application | Intégration | Priorité | Codes | À vérifier |")
    emit("|---|---|---|---|---|")
    for app, record in audit.records.items():
        todo = ", ".join(sorted({c["axis"] for c in audit.checks[app]})) or "—"
        app_codes = ", ".join(sorted({f["code"] for f in record["findings"]})) or "aucun"
        emit(f"| {app} | {audit.integration_type(app)} | {audit.priority(app)} | {app_codes} | {todo} |")
    emit()

    questions = [(app, c) for app in audit.records for c in audit.checks[app]]
    if questions:
        emit("## 5. Vérifications restantes")
        emit()
        emit("| Application | Axe | Preuve | Vérification attendue |")
        emit("|---|---|---|---|")
        for app, check in questions:
            emit(
                f"| {app} | {check['axis']} | {link(check['path'], check['line'])} | "
                f"{check['detail'].replace('|', '&#124;')} |"
            )
        emit()

    emit("## 6. Écarts assumés (hors compteurs)")
    emit()
    if acknowledged_entries:
        emit("Ces constats sont volontairement exclus des compteurs. Ils restent "
             "listés ici avec leur justification : aucune suppression silencieuse.")
        emit()
        emit("| Application | Constat | Cible | Justification |")
        emit("|---|---|---|---|")
        for entry in acknowledged_entries:
            emit(f"| {entry['app']} | {entry['code']} | `{entry['target']}` | "
                 f"{entry['reason'].replace('|', '&#124;')} |")
    else:
        emit("Aucun écart assumé.")
    emit()
    emit("## 7. Chantiers transverses")
    emit()
    emit("Ces familles se corrigent par un changement unique et non application par application.")
    emit()
    emit("| Constat | Levier | Applications | Correctif transverse |")
    emit("|---|---|---:|---|")
    for code, (lever, detail) in SYSTEMIC.items():
        if code not in codes:
            continue
        emit(f"| {code} | {lever} | {len(codes[code])} | {detail} |")
    emit()
    if baseline:
        emit("## 8. Écart avec une référence")
        emit()
        emit(f"Référence : `{baseline.get('branch')}` ({str(baseline.get('commit', ''))[:12]}) — "
             f"{baseline.get('totals', {}).get('occurrences', '?')} occurrences.")
        emit()

        def per_code(document):
            result = collections.defaultdict(set)
            for name, record in (document.get("apps") or {}).items():
                for finding in record.get("findings", []):
                    result[finding["code"]].add(name)
            return result

        current = per_code(payload)
        previous = per_code(baseline)
        rows = []
        for code in sorted(set(current) | set(previous)):
            now, before = current.get(code, set()), previous.get(code, set())
            if now == before:
                continue
            rows.append((code, len(now), len(before), sorted(now - before), sorted(before - now)))
        if rows:
            emit("« Présent ici seulement » signale une régression propre à cette branche ; "
                 "« présent en référence seulement » un écart déjà corrigé dans la référence.")
            emit()
            emit("| Constat | Ici | Référence | Présent ici seulement | Présent en référence seulement |")
            emit("|---|---:|---:|---|---|")
            for code, now, before, added, removed in rows:
                emit(f"| {code} | {now} | {before} | {', '.join(added) or '—'} | {', '.join(removed) or '—'} |")
        else:
            emit("Aucun écart de constats entre les deux branches.")
        emit()
        emit("## 9. Ordre de remise en conformité")
    emit()
    emit("1. **P0/P1 secrets et données** : couper les fuites de journaux, corriger les suppressions destructives.")
    emit("2. **P1 cycle de vie** : réseaux et fichiers hors dossier applicatif, réinstallation idempotente.")
    emit("3. **P1 Traefik** : ports, routes et authentification.")
    emit("4. **P2/P3 conventions** : champs inutilisés, TZ, nommage, minimalisme.")
    emit("5. **Validation réelle** : installer, réinstaller, supprimer partiellement puis complètement sur des données de test.")
    emit()
    (out / "apps-alignment.md").write_text("\n".join(md) + "\n", encoding="utf-8")

    # --------------------------------------------------------------- backlog
    backlog: list[str] = []
    backlog.append("# Backlog de remise en conformité `add-app`")
    backlog.append("")
    backlog.append(f"Branche `{git_branch}` ({git_sha[:12]}). Généré par `scripts/audit/apps_alignment.py`.")
    backlog.append("")
    for severity in ("P0", "P1", "P2", "P3"):
        selected = [
            code for code in codes
            if min(SEVERITY_ORDER[f["severity"]] for r in audit.records.values() for f in r["findings"] if f["code"] == code)
            == SEVERITY_ORDER[severity]
        ]
        if not selected:
            continue
        backlog.append(f"## {severity} — {len(selected)} famille(s) de constats")
        backlog.append("")
        for code in sorted(selected):
            apps = sorted(codes[code])
            backlog.append(f"### {code} — {len(apps)} application(s)")
            backlog.append("")
            backlog.append(f"- Règle : {rule(code)}")
            backlog.append(f"- Correction : {fix(code)}")
            backlog.append(f"- Applications : {', '.join(apps)}")
            backlog.append("")
    (out / "apps-alignment-backlog.md").write_text("\n".join(backlog) + "\n", encoding="utf-8")

    return payload["totals"], len(audit.stale)


def syntax_checks(audit: Audit, repo: Repo):
    files = sorted({rel for record in audit.records.values() for rel in record["files"]})
    templates = 0
    python_files = 0
    shell_files = 0
    prompts = 0
    prompt_errors = []
    for rel in files:
        if not repo.exists(rel):
            continue
        text = repo.text(rel)
        if rel.endswith(".j2") and Environment is not None:
            templates += 1
            try:
                Environment().parse(text)
            except Exception as exc:  # noqa: BLE001
                prompt_errors.append({"type": "template", "path": rel, "error": str(exc)})
        if rel.endswith(".py"):
            python_files += 1
            try:
                ast.parse(text, filename=rel)
            except SyntaxError as exc:
                prompt_errors.append({"type": "python", "path": rel, "error": str(exc)})
        if rel.endswith(".sh"):
            shell_files += 1
            result = subprocess.run(["bash", "-n", str(repo.path(rel))], capture_output=True, text=True)
            if result.returncode:
                prompt_errors.append({"type": "shell", "path": rel, "error": result.stderr.strip()})
        for index, line in enumerate(text.splitlines(), 1):
            if "SSDV2_PROMPT " not in line or line.lstrip().startswith("#"):
                continue
            match = re.search(r"SSDV2_PROMPT\s+(\{.*\})", line)
            if not match:
                continue
            prompts += 1
            try:
                marker = json.loads(match.group(1))
                assert marker.get("id"), "id manquant"
                if marker.get("kind") == "choice":
                    assert marker.get("options"), "options manquantes pour kind=choice"
            except Exception as exc:  # noqa: BLE001
                prompt_errors.append({"type": "prompt", "path": rel, "line": index, "error": str(exc)})
    return {
        "templates": templates,
        "python": python_files,
        "shell": shell_files,
        "prompts": prompts,
        "errors": prompt_errors,
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=".", help="racine du dépôt à auditer")
    parser.add_argument("--out", default="docs/audits", help="répertoire des livrables")
    parser.add_argument(
        "--curated",
        default="scripts/audit/curated_findings.yml",
        help="constats relus manuellement (chemin relatif au dépôt)",
    )
    parser.add_argument("--json", dest="json_path", default=None,
                        help="écrire aussi un JSON à cet emplacement absolu")
    parser.add_argument("--quiet", action="store_true", help="ne pas résumer sur stdout")
    parser.add_argument("--compare", default=None,
                        help="JSON apps-alignment.json d'une autre branche à comparer")
    args = parser.parse_args(argv)

    repo = Repo(Path(args.repo))
    if not repo.catalogue.is_file():
        print(f"Catalogue introuvable : {repo.catalogue}", file=sys.stderr)
        return 2

    audit = Audit(repo)
    audit.collect()
    audit.load_acknowledged(repo.path(args.curated))
    audit.structural()
    curated = repo.path(args.curated)
    audit.load_curated(curated)
    audit.apply_acknowledged()
    syntax = syntax_checks(audit, repo)
    baseline = json.loads(Path(args.compare).read_text(encoding="utf-8")) if args.compare else None
    totals, stale = write_outputs(audit, repo, repo.path(args.out), baseline)
    payload = {"totals": totals, "stale_curated": stale, "syntax": syntax}
    if args.json_path:
        Path(args.json_path).write_text(
            json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
    if not args.quiet:
        print(json.dumps(payload, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
