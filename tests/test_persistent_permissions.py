"""Exécute uniquement le helper de permissions sur des données temporaires."""
import json
import os
import shutil
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
ANSIBLE = Path(os.environ.get("ANSIBLE_PLAYBOOK") or shutil.which("ansible-playbook")
               or ROOT / "venv/bin/ansible-playbook")


@unittest.skipUnless(ANSIBLE.is_file(), "Ansible local requis")
class PersistentPermissionsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="ssdv2-p2-permissions-")
        self.base = Path(self.temp.name)

    def tearDown(self):
        self.temp.cleanup()

    def run_helper(self, roots):
        play = [{"hosts": "localhost", "gather_facts": False,
                 "vars": {"ansible_become": False, "permission_roots": roots},
                 "tasks": [{"ansible.builtin.include_tasks": str(ROOT / "includes/dockerapps/templates/generique/persistent_permissions.yml")}]}]
        playbook = self.base / "play.json"
        playbook.write_text(json.dumps(play))
        return subprocess.run([str(ANSIBLE), "-i", "localhost,", "-c", "local", str(playbook)],
                              capture_output=True, text=True, timeout=60)

    def test_private_public_modes_symlinks_and_idempotence(self):
        private = self.base / "config"
        public = self.base / "downloads"
        outside = self.base / "outside"
        for path in [private, public, outside]:
            path.mkdir(mode=0o777)
            (path / "data").write_text("test")
            (path / "data").chmod(0o777)
        (private / "linked-directory").symlink_to(outside, target_is_directory=True)
        (private / "linked-file").symlink_to(outside / "data")
        roots = [dict(path=str(private), directory_mode="0750", file_mode="0640",
                      owner=str(os.getuid()), group=str(os.getgid())),
                 dict(path=str(public), directory_mode="0755", file_mode="0644",
                      owner=str(os.getuid()), group=str(os.getgid()))]
        result = self.run_helper(roots)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for path,mode in [(private,0o750), (private / "data",0o640),
                          (public,0o755), (public / "data",0o644), (outside / "data",0o777)]:
            self.assertEqual(path.stat().st_mode & 0o777, mode, str(path))
        result = self.run_helper(roots)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("changed=0", result.stdout)

    def test_symlink_root_is_rejected_before_chmod(self):
        target = self.base / "outside"
        target.mkdir()
        target.chmod(0o777)
        link = self.base / "config"
        link.symlink_to(target, target_is_directory=True)
        result = self.run_helper([dict(path=str(link), directory_mode="0750", file_mode="0640")])
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(target.stat().st_mode & 0o777, 0o777)


if __name__ == "__main__":
    unittest.main()
