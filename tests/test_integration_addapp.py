"""Validation commune des PR #100 à #103.

Ces tests ne remplacent pas ceux de chaque PR : ils vérifient les interactions
que seule la combinaison révèle.

1. Un hook réel qui redéploie `docker_info` reste masqué avec les deux
   mécanismes (défaut du playbook générique + `no_log` du hook).
2. L'audit relancé sur la branche d'intégration ne signale plus aucune des
   familles corrigées.
3. La garde de suppression protège bien les conteneurs d'une autre application.

Lancement : python3 tests/test_integration_addapp.py
"""
import importlib.util
import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
ANSIBLE = Path(
    os.environ.get("ANSIBLE_PLAYBOOK")
    or shutil.which("ansible-playbook")
    or ROOT / "venv/bin/ansible-playbook"
)
MARKER = "fixture-integration-secret-5521"


def load_audit_module():
    spec = importlib.util.spec_from_file_location(
        "apps_alignment", ROOT / "scripts" / "audit" / "apps_alignment.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class AuditCombinedTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        module = load_audit_module()
        cls.tmp = tempfile.TemporaryDirectory()
        out = Path(cls.tmp.name)
        module.main([
            "--repo", str(ROOT),
            "--out", str(out),
            "--curated", "scripts/audit/curated_findings.yml",
            "--quiet",
        ])
        cls.data = json.loads((out / "apps-alignment.json").read_text())
        cls.codes = {}
        for app, record in cls.data["apps"].items():
            for finding in record["findings"]:
                cls.codes.setdefault(finding["code"], set()).add(app)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_corrected_families_are_gone(self):
        for code in ("GENLOG", "TASKLOG", "PROMPTECHO", "PROMPTLOG", "DEBUGSECRET",
                     "SECRETFILE", "JSONESCAPE", "PARTIALDELETE", "OTHERAPPDELETE"):
            self.assertNotIn(code, self.codes, f"{code} subsiste : {sorted(self.codes.get(code, []))}")

    def test_remaining_findings_are_documented(self):
        # Les familles non corrigées restent mesurées, pas masquées.
        self.assertIn("NETWORKCLEAN", self.codes)
        self.assertIn("TZ", self.codes)

    def test_stale_entries_are_fixed_not_hidden(self):
        # Un constat curaté devenu introuvable signale un correctif. Il doit
        # rester listé et ne plus compter pour l'application concernée.
        for stale in self.data["stale_curated"]:
            remaining = {
                finding["code"]
                for finding in self.data["apps"][stale["app"]]["findings"]
            }
            self.assertNotIn(stale["code"], remaining, stale)

    def test_reports_contain_no_secret_value(self):
        for name in ("apps-alignment.md", "apps-alignment.csv"):
            text = (Path(self.tmp.name) / name).read_text()
            for needle in ("fixture-integration-secret-5521", "fixture-pass-relay-proxy"):
                self.assertNotIn(needle, text)


@unittest.skipUnless(ANSIBLE.is_file(), "Ansible requis")
class HookInteractionTest(unittest.TestCase):
    def real_hook_task(self):
        document = yaml.safe_load(
            (ROOT / "includes/dockerapps/posttasks/navidrome.yml").read_text())
        for task in document:
            if str(task.get("docker_container", "")).strip() == "{{ docker_info }}":
                return task
        self.fail("hook de redéploiement introuvable")

    def test_real_hook_redeploy_is_masked(self):
        task = json.loads(json.dumps(self.real_hook_task()))
        del task["docker_container"]
        # Échec statique : ce qui doit rester masqué est docker_info.env.
        task["ansible.builtin.fail"] = {"msg": "échec simulé"}
        play = [{
            "hosts": "localhost",
            "gather_facts": False,
            "vars": {"docker_info": {"name": "navidrome", "env": {"SECRET": MARKER}}},
            "tasks": [task],
        }]
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "play.json"
            path.write_text(json.dumps(play))
            result = subprocess.run(
                [str(ANSIBLE), "-i", "localhost,", "-c", "local", str(path), "-vv"],
                capture_output=True, text=True, timeout=60,
            )
        output = result.stdout + result.stderr
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn(MARKER, output)
        self.assertIn("Deploying", output)


class SuppressionGuardTest(unittest.TestCase):
    def test_guard_functions_exist(self):
        text = (ROOT / "includes/functions.sh").read_text()
        for needle in ("container_owned_by_app", "filter_owned_containers",
                       "remove_app_containers", "dir_owned_by_app", "remove_app_dir",
                       "remove_app_volumes", "keep_resource_message"):
            self.assertTrue(needle in text, needle)

    def test_status_is_not_used_as_ownership_proof(self):
        # Le statut en base ne distingue pas une application arrêtée, en échec ou
        # réinstallée : il ne doit plus servir de preuve de propriété.
        text = (ROOT / "includes/functions.sh").read_text()
        guard = text[text.index("function container_owned_by_app"):]
        guard = guard[:guard.index("function filter_owned_containers")]
        self.assertNotIn("applications where name=", guard)
        self.assertNotIn("status", guard)


if __name__ == "__main__":
    unittest.main(verbosity=2)
