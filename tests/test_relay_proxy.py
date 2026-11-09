"""Contrôles Ansible ciblés sur fixtures, sans Docker ni accès réseau."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[1]
ANSIBLE = Path(os.environ.get("ANSIBLE_PLAYBOOK") or shutil.which("ansible-playbook")
               or ROOT / "venv/bin/ansible-playbook")


@unittest.skipUnless(ANSIBLE.is_file(), "Ansible requis")
class ProxyLoggingTest(unittest.TestCase):
    def test_generic_deployment_masks_opted_in_app_and_preserves_default(self):
        generic = yaml.safe_load((ROOT / "includes/dockerapps/vars/generique.yml").read_text())[0]
        start = next(i for i,t in enumerate(generic['tasks']) if t['name']=='Prepare docker info')
        tasks = generic['tasks'][start:start+4]
        for opted_in in [True, False]:
            with self.subTest(opted_in=opted_in), tempfile.TemporaryDirectory() as tmp:
                selected = json.loads(json.dumps(tasks))
                deployment = selected[-1]
                del deployment['community.docker.docker_container']
                deployment['ansible.builtin.fail'] = {'msg': '{{ docker_info.env.AUTH_PASS }}'}
                # Une erreur du module peut contenir les arguments Docker :
                # provoquer ce cas sur une valeur fictive, avec verbosité.
                marker = 'fixture-pass-relay-proxy-845731'
                variables = dict(pgrole='test-app', image='fixture:local',
                                 docker_deploy_enabled=True, pg_labels={},
                                 pg_env={'AUTH_PASS': marker},
                                 specific_docker_info={'security_opts': 'no-new-privileges:true'})
                if opted_in:
                    variables['docker_no_log'] = True
                play = [{'hosts':'localhost', 'gather_facts':False, 'vars':variables,'tasks':selected}]
                path = Path(tmp) / 'play.json'
                path.write_text(json.dumps(play))
                result = subprocess.run([str(ANSIBLE),'-i','localhost,','-c','local',str(path),'-vv'],
                                        capture_output=True,text=True,timeout=60)
                self.assertNotEqual(result.returncode, 0)
                output = result.stdout + result.stderr
                self.assertEqual(marker in output, not opted_in, output)
        proxy = yaml.safe_load((ROOT/'includes/dockerapps/vars/ssdv2proxy.yml').read_text())
        self.assertIs(proxy['docker_no_log'], True)


if __name__ == '__main__':
    unittest.main()
