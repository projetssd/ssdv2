"""Tests du moteur d'audit apps_alignment sur un dépôt factice minimal.

Aucun accès réseau, aucun Docker : le test construit une arborescence temporaire
qui reproduit les contrats vérifiés, exécute le moteur deux fois et contrôle les
constats produits ainsi que la reproductibilité des sorties.

Lancement : python3 tests/test_apps_alignment.py
"""
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "scripts" / "audit" / "apps_alignment.py"

CATALOGUE = """\
goodapp - Application conforme
badapp - Application avec écarts
otherapp - Application qui partage un dossier
noimage - Entrée sans fichier de variables
"""

VARS_GOOD = """\
---
pgrole: 'goodapp'
intport: '8080'
image: 'vendor/good:latest'
pg_volumes:
  - "{{ settings.storage }}/docker/{{ lookup('env','USER') }}/{{ pgrole }}/config:/config"
pg_env:
  PUID: "{{ lookup('env','MYUID') }}"
  PGID: "{{ lookup('env','MYGID') }}"
  TZ: 'Europe/Paris'
"""

VARS_BAD = """\
---
pgrole: 'badapp'
intport: '8080'
image: 'vendor/bad:latest'
pg_volumes:
  - "{{ settings.storage }}/docker/{{ lookup('env','USER') }}/{{ pgrole }}/config:/config"
pg_env:
  DB_PASSWORD: 'changeme'
  TZ: 'Europe/Paris'
specific_docker_info:
  ports:
    - '8080:8080'
"""

PRETASK_BAD = """\
---
- name: Demander un mot de passe
  pause:
    prompt: |
      SSDV2_PROMPT {"id": "badapp.password", "label": "Mot de passe", "kind": "secret", "secret": true}
      Mot de passe ?
    echo: yes
  register: bad_password

- name: Créer un réseau dédié
  community.docker.docker_network:
    name: 'badapp-net'

- name: Redéployer le conteneur avec ses paramètres
  community.docker.docker_container: "{{ docker_info }}"

- name: Appeler une API avec le jeton
  ansible.builtin.uri:
    url: "http://127.0.0.1/api"
    headers:
      Authorization: "Bearer {{ fixture_token }}"

- name: Base dédiée nommée de façon générique
  community.docker.docker_container:
    name: mariadb
    volumes:
      - "{{ settings.storage }}/docker/{{ lookup('env','USER') }}/badapp-db:/var/lib/mysql"
"""

VARS_OTHER = """\
---
pgrole: 'otherapp'
intport: '8081'
image: 'vendor/other:latest'
pg_volumes:
  - "{{ settings.storage }}/docker/{{ lookup('env','USER') }}/shared-data:/data"
pg_env:
  TZ: 'Europe/Paris'
  REDIS_URL: "redis://redis:6379/0"
"""

PRETASK_OTHER = """\
---
- name: Conteneur nommé comme un service courant, sans volume persistant
  community.docker.docker_container:
    name: redis
    image: redis:7

- name: Conteneur compagnon propre à otherapp
  community.docker.docker_container:
    name: warp-fixture
    image: fixture/warp:latest
"""

PRETASK_BAD_DEBUG = """\
- name: Afficher le secret généré
  ansible.builtin.debug:
    msg: "Clé interne : {{ fixture_api_key }}"
"""

POSTTASK_BAD = """\
---
- name: Attendre un artefact de premier démarrage
  ansible.builtin.wait_for:
    path: "{{ settings.storage }}/docker/{{ lookup('env','USER') }}/{{ pgrole }}/token"
    timeout: 30
"""

FUNCTIONS = """\
suppression_appli() {
  case $APPSELECTED in
  badapp)
    sudo rm -rf ${SETTINGS_STORAGE}/docker/${USER}/shared-data
    sudo rm -rf ${SETTINGS_STORAGE}/docker/${USER}/badapp-db >/dev/null 2>&1
    sudo rm -rf ${SETTINGS_STORAGE}/docker/${USER}/unknown-dir
    docker rm -f warp-fixture badapp
    ;;
  safeapp)
    if [ $DELETE -eq 1 ]; then
      sudo rm -rf ${SETTINGS_STORAGE}/docker/${USER}/safeapp
    fi
    ;;
  esac
}
"""


def build_repo(root: Path) -> None:
    dockerapps = root / "includes" / "dockerapps"
    for name in ("vars", "pretasks", "posttasks"):
        (dockerapps / name).mkdir(parents=True, exist_ok=True)
    (root / "includes" / "config").mkdir(parents=True, exist_ok=True)
    (root / "includes" / "config" / "services-available").write_text(CATALOGUE)
    (root / "includes" / "functions.sh").write_text(FUNCTIONS)
    (dockerapps / "vars" / "goodapp.yml").write_text(VARS_GOOD)
    (dockerapps / "vars" / "badapp.yml").write_text(VARS_BAD)
    (dockerapps / "vars" / "otherapp.yml").write_text(VARS_OTHER)
    (dockerapps / "vars" / "orphan.yml").write_text("---\npgrole: 'orphan'\nimage: 'x/y'\n")
    (dockerapps / "pretasks" / "badapp.yml").write_text(PRETASK_BAD + PRETASK_BAD_DEBUG)
    (dockerapps / "pretasks" / "otherapp.yml").write_text(PRETASK_OTHER)
    (dockerapps / "posttasks" / "badapp.yml").write_text(POSTTASK_BAD)


def load_module():
    spec = importlib.util.spec_from_file_location("apps_alignment", MODULE)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class AppsAlignmentTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.module = load_module()
        cls.tmp = tempfile.TemporaryDirectory()
        cls.repo = Path(cls.tmp.name)
        build_repo(cls.repo)
        cls.out = cls.repo / "docs" / "audits"
        cls.module.main([
            "--repo", str(cls.repo),
            "--out", str(cls.out),
            "--curated", "",
            "--quiet",
        ])
        cls.data = json.loads((cls.out / "apps-alignment.json").read_text())

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def codes(self, app):
        return {finding["code"] for finding in self.data["apps"][app]["findings"]}

    def findings(self, app, code):
        return [f for f in self.data["apps"][app]["findings"] if f["code"] == code]

    def checks(self, app):
        return [c["detail"] for c in self.data["apps"][app]["checks"]]

    def test_catalogue_coverage(self):
        for name in ("goodapp", "badapp", "otherapp", "orphan"):
            self.assertIn(name, self.data["apps"])

    def test_missing_vars_reported(self):
        self.assertIn("CATALOGMISSING", self.codes("noimage"))

    def test_orphan_vars_reported(self):
        self.assertIn("CATALOGORPHAN", self.codes("orphan"))

    def test_conforming_app_is_clean(self):
        self.assertEqual(self.codes("goodapp"), set())

    def test_secrets_prompts_ports_network(self):
        codes = self.codes("badapp")
        for code in ("FIXEDSECRET", "GENLOG", "PROMPTECHO", "PROMPTLOG", "DEBUGSECRET",
                     "WEBHOSTPORT", "NETWORKCLEAN", "IDEMPOTENT"):
            self.assertIn(code, codes, f"constat {code} attendu")

    def test_cross_app_deletion_needs_volume_evidence(self):
        details = [f["detail"] for f in self.findings("badapp", "CROSSAPPDELETE")]
        self.assertTrue(any("shared-data" in d and "otherapp" in d for d in details), details)

    def test_name_collision_is_not_cross_app(self):
        # otherapp déclare un conteneur `redis` sans monter de dossier persistant :
        # le nom seul ne prouve aucune propriété de données.
        details = [f["detail"] for f in self.findings("badapp", "CROSSAPPDELETE")]
        self.assertFalse(any("redis" in d for d in details), details)

    def test_unattributed_directory_becomes_question(self):
        self.assertTrue(any("unknown-dir" in d for d in self.checks("badapp")), self.checks("badapp"))

    def test_own_directory_unguarded_is_partial_delete(self):
        details = [f["detail"] for f in self.findings("badapp", "PARTIALDELETE")]
        self.assertTrue(any("badapp-db" in d for d in details), details)
        self.assertEqual({f["severity"] for f in self.findings("badapp", "PARTIALDELETE")}, {"P1"})

    def test_foreign_container_deletion(self):
        details = [f["detail"] for f in self.findings("badapp", "OTHERAPPDELETE")]
        self.assertTrue(any("warp-fixture" in d and "otherapp" in d for d in details), details)

    def test_hook_redeploy_without_no_log_is_reported(self):
        details = [f["detail"] for f in self.findings("badapp", "GENLOG")]
        self.assertTrue(any("Hook redéployant" in d for d in details), details)

    def test_uri_with_bearer_is_reported(self):
        details = [f["detail"] for f in self.findings("badapp", "TASKLOG")]
        self.assertTrue(any("uri" in d and "Authorization" in d for d in details), details)

    def test_states_and_integration(self):
        states = self.data["apps"]["badapp"]["states"]
        self.assertEqual(states["secrets"], "écart confirmé")
        self.assertEqual(self.data["apps"]["goodapp"]["integration"], "Cas A — conteneur générique")
        self.assertEqual(self.data["apps"]["badapp"]["integration"], "Cas C — conteneur + compagnons")

    def test_outputs_exist(self):
        for name in ("apps-alignment.json", "apps-alignment.csv",
                     "apps-alignment.md", "apps-alignment-backlog.md"):
            path = self.out / name
            self.assertTrue(path.is_file(), name)
            self.assertGreater(path.stat().st_size, 0, name)

    def test_deterministic(self):
        other = self.repo / "docs" / "audits-bis"
        self.module.main([
            "--repo", str(self.repo),
            "--out", str(other),
            "--curated", "",
            "--quiet",
        ])
        for name in ("apps-alignment.csv", "apps-alignment.md",
                     "apps-alignment-backlog.md"):
            self.assertEqual(
                (self.out / name).read_text(),
                (other / name).read_text(),
                f"{name} non reproductible",
            )

    def test_curated_needle_stale_detection(self):
        curated = self.repo / "curated.yml"
        curated.write_text(
            "findings:\n"
            "  - app: badapp\n"
            "    code: SHELLSECRET\n"
            "    axis: secrets\n"
            "    severity: P0\n"
            "    path: includes/dockerapps/vars/badapp.yml\n"
            "    needle: 'chaine-absente'\n"
            "    detail: Constat obsolète\n"
        )
        out = self.repo / "docs" / "audits-curated"
        self.module.main([
            "--repo", str(self.repo),
            "--out", str(out),
            "--curated", str(curated),
            "--quiet",
        ])
        data = json.loads((out / "apps-alignment.json").read_text())
        self.assertEqual(len(data["stale_curated"]), 1)
        self.assertNotIn(
            "SHELLSECRET",
            {f["code"] for f in data["apps"]["badapp"]["findings"]},
        )

    def test_acknowledged_finding_is_excluded(self):
        curated = self.repo / "ack.yml"
        curated.write_text(
            "acknowledged:\n"
            "  - app: badapp\n"
            "    code: PARTIALDELETE\n"
            "    target: badapp-db\n"
            "    reason: Retrait volontaire, documenté et testé.\n"
        )
        out = self.repo / "docs" / "audits-ack"
        self.module.main([
            "--repo", str(self.repo),
            "--out", str(out),
            "--curated", str(curated),
            "--quiet",
        ])
        data = json.loads((out / "apps-alignment.json").read_text())
        details = [
            f["detail"] for f in data["apps"]["badapp"]["findings"]
            if f["code"] == "PARTIALDELETE"
        ]
        self.assertFalse(any("badapp-db" in d for d in details), details)
        self.assertTrue(data["acknowledged_seen"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
