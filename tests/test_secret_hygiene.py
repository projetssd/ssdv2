"""Hygiène des secrets : invites, sorties de tâches et restitution à l'utilisateur.

Deux niveaux :

- contrat statique sur tous les `pretasks`/`posttasks` : aucune invite secrète
  avec écho, `no_log` sur la tâche ou un bloc parent, aucun `debug` de secret ;
- comportement réel avec Ansible sur les posttasks concernées : un secret fictif
  n'apparaît ni dans la sortie ni dans les journaux, même en verbosité `-vv`,
  et l'utilisateur reçoit le chemin d'un fichier en 0600.

Lancement : python3 tests/test_secret_hygiene.py
"""
import json
import os
import re
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
SECRET_MARKER = re.compile(r'"secret"\s*:\s*true')


def walk_tasks(document, inherited=False):
    if isinstance(document, list):
        for item in document:
            yield from walk_tasks(item, inherited)
    elif isinstance(document, dict):
        protected = inherited or document.get("no_log") is True
        yield document, protected
        for key in ("tasks", "pre_tasks", "post_tasks", "block", "rescue", "always"):
            if key in document:
                yield from walk_tasks(document[key], protected)


def hook_files():
    for folder in ("pretasks", "posttasks", "templates"):
        yield from sorted((ROOT / "includes/dockerapps" / folder).rglob("*.yml"))


class PromptContractTest(unittest.TestCase):
    def test_secret_prompts_hide_echo_and_enable_no_log(self):
        problems = []
        for path in hook_files():
            try:
                document = yaml.safe_load(path.read_text())
            except yaml.YAMLError:
                # Un fichier préexistant invalide ne doit pas masquer les autres.
                continue
            for task, protected in walk_tasks(document):
                pause = next(
                    (value for key, value in task.items()
                     if str(key).split(".")[-1] == "pause"),
                    None,
                )
                if pause is None:
                    continue
                prompt = str(pause.get("prompt", "")) if isinstance(pause, dict) else str(pause)
                if not SECRET_MARKER.search(prompt):
                    continue
                rel = path.relative_to(ROOT)
                if not isinstance(pause, dict) or pause.get("echo", True) is not False:
                    problems.append(f"{rel}: invite secrète avec écho actif")
                if not protected:
                    problems.append(f"{rel}: invite secrète sans no_log")
        self.assertEqual(problems, [])

    def test_no_debug_prints_secret_values(self):
        # Variables dont le nom suffit à qualifier un secret durable.
        forbidden = re.compile(
            r"{{\s*("
            r"ygg_password|password|appkey\.[A-Za-z_]+|"
            r"[A-Za-z_]*jwt_?secret[A-Za-z_]*|[A-Za-z_]*admin_password|"
            r"[A-Za-z_]*api_password|[A-Za-z_]*setup_token|[A-Za-z_]*secret_key[A-Za-z_]*"
            r")\s*}}"
        )
        problems = []
        for path in hook_files():
            try:
                document = yaml.safe_load(path.read_text())
            except yaml.YAMLError:
                continue
            for task, _ in walk_tasks(document):
                debug = next(
                    (value for key, value in task.items()
                     if str(key).split(".")[-1] == "debug"),
                    None,
                )
                if debug is None:
                    continue
                text = json.dumps(debug, ensure_ascii=False)
                for match in forbidden.finditer(text):
                    problems.append(f"{path.relative_to(ROOT)}: debug expose {match.group(1)}")
        self.assertEqual(problems, [])


@unittest.skipUnless(ANSIBLE.is_file(), "Ansible requis")
class SecretOutputTest(unittest.TestCase):
    def run_hook(self, hook, variables, extra_files=None, storage=None, token_mode=0o600):
        if storage is None:
            directory = tempfile.TemporaryDirectory()
            self.addCleanup(directory.cleanup)
            base = Path(directory.name)
            storage = base / "storage"
            storage.mkdir()
        else:
            base = storage.parent
        data_dir = storage / "docker" / os.environ.get("USER", "fixture") / "ssdv2webui" / "data"
        data_dir.mkdir(parents=True, exist_ok=True)
        token = "fixture-token-3d9c1f"
        token_file = data_dir / "setup-token"
        if not token_file.exists():
            token_file.write_text(token + "\n")
            token_file.chmod(token_mode)
        if extra_files:
            extra_files(storage, data_dir, token)
        variables = dict(variables, settings={"storage": str(storage)})
        play = [{
            "hosts": "localhost",
            "gather_facts": False,
            "vars": variables,
            "tasks": [{"include_tasks": str(ROOT / "includes/dockerapps" / "posttasks" / hook)}],
        }]
        path = base / "play.json"
        path.write_text(json.dumps(play))
        result = subprocess.run(
            [str(ANSIBLE), "-i", "localhost,", "-c", "local", str(path), "-vv"],
            capture_output=True, text=True, timeout=120,
        )
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, output[-3000:])
        return output, storage, token

    def test_webui_token_is_never_printed(self):
        output, storage, token = self.run_hook(
            "ssdv2webui.yml",
            {
                "pgrole": "ssdv2webui",
                "sub_enabled": False,
                "user": {"domain": "example.invalid"},
                "ssdv2webui_existing_db": {"stat": {"exists": True}},
            },
        )
        self.assertNotIn(token, output)
        self.assertIn("setup-token", output)
        token_file = storage / "docker" / os.environ.get("USER", "fixture") / "ssdv2webui" / "data" / "setup-token"
        self.assertTrue(token_file.is_file())
        self.assertEqual(oct(token_file.stat().st_mode & 0o777), "0o600")

    def test_setup_token_mode_is_tightened_even_if_created_permissive(self):
        output, storage, token = self.run_hook(
            "ssdv2webui.yml",
            {
                "pgrole": "ssdv2webui",
                "sub_enabled": False,
                "user": {"domain": "example.invalid"},
                "ssdv2webui_existing_db": {"stat": {"exists": True}},
            },
            token_mode=0o644,
        )
        self.assertNotIn(token, output)
        token_file = (
            storage / "docker" / os.environ.get("USER", "fixture")
            / "ssdv2webui" / "data" / "setup-token"
        )
        self.assertEqual(oct(token_file.stat().st_mode & 0o777), "0o600")

    def test_mediaflowproxy_password_is_preserved_on_reinstall(self):
        def prepare(storage, _data_dir, _token):
            (storage / "docker" / os.environ.get("USER", "fixture") / "mediaflowproxy").mkdir(
                parents=True, exist_ok=True)

        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        storage = Path(directory.name) / "storage"
        storage.mkdir()
        variables = {
            "pgrole": "mediaflowproxy",
            "sub_enabled": False,
            "user": {"domain": "example.invalid"},
        }
        password_file = (
            storage / "docker" / os.environ.get("USER", "fixture")
            / "mediaflowproxy" / "api_password"
        )
        first_output, _, _ = self.run_hook(
            "mediaflowproxy.yml", variables, extra_files=prepare, storage=storage)
        first = password_file.read_text().strip()
        second_output, _, _ = self.run_hook(
            "mediaflowproxy.yml", variables, extra_files=prepare, storage=storage)
        second = password_file.read_text().strip()
        self.assertEqual(first, second)
        self.assertNotIn(first, first_output)
        self.assertNotIn(second, second_output)

    def test_mediaflowproxy_password_is_never_printed(self):
        def prepare(storage, _data_dir, _token):
            (storage / "docker" / os.environ.get("USER", "fixture") / "mediaflowproxy").mkdir(parents=True)

        output, storage, _token = self.run_hook(
            "mediaflowproxy.yml",
            {
                "pgrole": "mediaflowproxy",
                "sub_enabled": False,
                "user": {"domain": "example.invalid"},
            },
            extra_files=prepare,
        )
        password_file = (
            storage / "docker" / os.environ.get("USER", "fixture")
            / "mediaflowproxy" / "api_password"
        )
        self.assertTrue(password_file.is_file())
        secret = password_file.read_text().strip()
        self.assertTrue(secret)
        self.assertNotIn(secret, output)
        self.assertIn("api_password", output)
        self.assertEqual(oct(password_file.stat().st_mode & 0o777), "0o600")


if __name__ == "__main__":
    unittest.main(verbosity=2)
