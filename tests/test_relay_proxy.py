"""Contrôles Ansible ciblés sur fixtures, sans Docker ni accès réseau."""
import json
import re
import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch

import yaml

ROOT = Path(__file__).resolve().parents[1]
ANSIBLE = Path(os.environ.get("ANSIBLE_PLAYBOOK") or shutil.which("ansible-playbook")
               or ROOT / "venv/bin/ansible-playbook")


@unittest.skipUnless(ANSIBLE.is_file(), "Ansible requis")
class ProxyLoggingTest(unittest.TestCase):
    """Le déploiement générique masque les paramètres Docker par défaut.

    `~/.ansible.cfg` définit `log_path`, donc toute valeur non masquée est écrite
    dans un journal persistant, pas seulement affichée en verbosité.
    """

    def run_deployment(self, tmp, docker_no_log="absent"):
        generic = yaml.safe_load((ROOT / "includes/dockerapps/vars/generique.yml").read_text())[0]
        start = next(i for i, t in enumerate(generic["tasks"]) if t["name"] == "Prepare docker info")
        tasks = generic["tasks"][start:start + 4]
        selected = json.loads(json.dumps(tasks))
        deployment = selected[-1]
        del deployment["community.docker.docker_container"]
        # Échec réaliste : le message ne contient pas le secret. Ce qui doit
        # rester masqué, c'est `docker_info.env` reconstruit par les tâches
        # précédentes (et donc le journal persistant), pas le texte de l'erreur.
        deployment["ansible.builtin.fail"] = {"msg": "fixture: échec de déploiement"}
        # Une erreur du module peut contenir les arguments Docker : provoquer ce
        # cas sur une valeur fictive, avec verbosité.
        marker = "fixture-pass-relay-proxy-845731"
        variables = dict(pgrole="test-app", image="fixture:local",
                         docker_deploy_enabled=True, pg_labels={},
                         pg_env={"AUTH_PASS": marker},
                         specific_docker_info={"security_opts": "no-new-privileges:true"})
        if docker_no_log != "absent":
            variables["docker_no_log"] = docker_no_log
        play = [{"hosts": "localhost", "gather_facts": False,
                 "vars": variables, "tasks": selected}]
        path = Path(tmp) / "play.json"
        path.write_text(json.dumps(play))
        result = subprocess.run([str(ANSIBLE), "-i", "localhost,", "-c", "local", str(path), "-vv"],
                                capture_output=True, text=True, timeout=60)
        self.assertNotEqual(result.returncode, 0)
        return marker, result.stdout + result.stderr

    def test_default_masks_secrets_including_on_error(self):
        with tempfile.TemporaryDirectory() as tmp:
            marker, output = self.run_deployment(tmp)
            self.assertNotIn(marker, output)

    def test_explicit_opt_out_restores_verbose_output(self):
        # Le comportement historique reste accessible, explicitement.
        with tempfile.TemporaryDirectory() as tmp:
            marker, output = self.run_deployment(tmp, docker_no_log=False)
            self.assertIn(marker, output)

    def test_explicit_opt_in_still_masks(self):
        with tempfile.TemporaryDirectory() as tmp:
            marker, output = self.run_deployment(tmp, docker_no_log=True)
            self.assertNotIn(marker, output)

    def test_apps_that_opted_in_keep_the_option(self):
        for name in ("ssdv2proxy", "ssdv2-relay"):
            app = yaml.safe_load((ROOT / f"includes/dockerapps/vars/{name}.yml").read_text())
            self.assertIs(app["docker_no_log"], True, name)


@unittest.skipUnless(ANSIBLE.is_file(), "Ansible requis")
class RelayConfigurationTest(unittest.TestCase):
    def run_play(self, tasks, variables, directory):
        play = [{'hosts':'localhost','gather_facts':False,'vars':variables,'tasks':tasks}]
        path = directory / 'play.json'
        path.write_text(json.dumps(play))
        return subprocess.run([str(ANSIBLE),'-i','localhost,','-c','local',str(path),'-vv'],
                              capture_output=True,text=True,timeout=90)

    def test_configuration_lifecycle_and_legacy_import(self):
        url1, url2 = 'https://fixture-one.invalid', 'https://fixture-two.invalid'
        token1, token2 = 'a' * 64, 'b' * 64
        cases = [
            ('first', {}, {}, {'worker_url':url1+'/', 'token':token1}, (url1,token1)),
            ('legacy', {}, {'RELAY_WORKER_URL':url1,'RELAY_TOKEN':token1},
             {'keep_config':'o'}, (url1,token1)),
            ('keep', {'RELAY_WORKER_URL':url2,'RELAY_TOKEN':token2},
             {'RELAY_WORKER_URL':url1,'RELAY_TOKEN':token1}, {'keep_config':'o'}, (url2,token2)),
            ('change', {'RELAY_WORKER_URL':url1,'RELAY_TOKEN':token1}, {},
             {'keep_config':'n','worker_url':url2,'token':token2}, (url2,token2)),
            ('partial-new', {'RELAY_WORKER_URL':url2},
             {'RELAY_WORKER_URL':url1,'RELAY_TOKEN':token1},
             {'worker_url':url2,'token':token2}, (url2,token2)),
            ('partial-legacy', {}, {'RELAY_WORKER_URL':url1},
             {'worker_url':url2,'token':token2}, (url2,token2)),
            ('noninteractive-keep', {'RELAY_WORKER_URL':url1,'RELAY_TOKEN':token1}, {},
             {'keep_config':None}, (url1,token1)),
            ('noninteractive-first', {}, {}, {'worker_url':None,'token':None}, None),
        ]
        original = yaml.safe_load((ROOT/'includes/dockerapps/pretasks/ssdv2-relay.yml').read_text())
        start = next(i for i,t in enumerate(original) if t['name']=='Définir le dossier des secrets SSD Relay')
        end = next(i for i,t in enumerate(original) if 'ansible.builtin.uri' in t)
        for name,current,legacy,answers,expected in cases:
            with self.subTest(case=name), tempfile.TemporaryDirectory() as tmp:
                directory=Path(tmp)
                base=directory/'docker'/os.environ.get('USER','')
                dest=base/'ssdv2-relay/secrets'
                old=base/'ssdv2-relay-secrets'
                for folder,data in [(dest,current),(old,legacy)]:
                    folder.mkdir(parents=True)
                    for filename,content in data.items(): (folder/filename).write_text(content+'\n')
                tasks=json.loads(json.dumps(original[start:end]))
                for task in tasks:
                    if 'ansible.builtin.pause' not in task: continue
                    marker=task.pop('ansible.builtin.pause')['prompt'].splitlines()[0]
                    key=json.loads(marker.split('SSDV2_PROMPT ',1)[1])['id'].split('.')[-1]
                    register=task.pop('register')
                    if key not in answers:
                        task['ansible.builtin.fail']={'msg':'Unexpected prompt: '+key}
                    else:
                        task['ansible.builtin.set_fact']={register: {} if answers[key] is None else {'user_input':answers[key]}}
                result=self.run_play(tasks,dict(settings={'storage':tmp},pgrole='ssdv2-relay'),directory)
                output=result.stdout+result.stderr
                self.assertNotIn(token1,output)
                self.assertNotIn(token2,output)
                if expected is None:
                    self.assertNotEqual(result.returncode,0)
                    self.assertFalse((dest/'RELAY_TOKEN').exists())
                else:
                    self.assertEqual(result.returncode,0,output)
                    for filename,content in zip(['RELAY_WORKER_URL','RELAY_TOKEN'],expected):
                        self.assertEqual((dest/filename).read_text().strip(),content)
                        self.assertEqual((dest/filename).stat().st_mode & 0o777,0o600)
                for filename,content in legacy.items(): self.assertEqual((old/filename).read_text(),content+'\n')

    def test_migration_selection_and_noninteractive_confirmation(self):
        original=yaml.safe_load((ROOT/'includes/dockerapps/posttasks/ssdv2-relay.yml').read_text())
        names={'Déterminer la migration nécessaire','Déterminer si une migration est nécessaire',
               'Détecter une exécution non interactive','Définir la réponse de migration',
               'Migrer stream-fusion vers SSD Relay','Migrer taskiq-worker vers SSD Relay'}
        tasks=json.loads(json.dumps([t for t in original if t['name'] in names]))
        for task in tasks:
            if 'ansible.builtin.shell' in task:
                name='stream-fusion' if 'stream-fusion' in task['name'] else 'taskiq-worker'
                del task['ansible.builtin.shell']
                task.pop('register')
                task['ansible.builtin.set_fact']={'migration_calls':"{{ migration_calls + ['"+name+"'] }}"}
        cases=[(True,False,{'user_input':' o '},['stream-fusion']),
               (False,True,{'user_input':'oui'},['taskiq-worker']),
               (True,True,{},[]), (True,True,{'user_input':'n'},[]),
               (False,False,{},[])]
        for sf,tw,answer,expected in cases:
            with self.subTest(sf=sf,tw=tw,answer=answer),tempfile.TemporaryDirectory() as tmp:
                variables=dict(ssdv2_relay_ping={'rc':0},migration_calls=[],expected=expected,
                    ssdv2_relay_sf_state={'rc':0,'stdout':'false'},
                    ssdv2_relay_tw_state={'rc':0,'stdout':'true'},
                    ssdv2_relay_sf_env={'stdout':'PROXY_URL=http://warp:1080' if sf else 'AD_BASE_URL=http://ssdv2-relay:1080'},
                    ssdv2_relay_tw_env={'stdout':'PROXY_URL=http://warp:1080' if tw else 'AD_BASE_URL=http://ssdv2-relay:1080'},
                    ssdv2_relay_migrate_answer=answer)
                check={'name':'Check selected containers','ansible.builtin.assert':{'that':'migration_calls == expected'}}
                result=self.run_play(tasks+[check],variables,Path(tmp))
                self.assertEqual(result.returncode,0,result.stdout+result.stderr)

    def test_relay_opts_in_to_masking(self):
        relay=yaml.safe_load((ROOT/'includes/dockerapps/vars/ssdv2-relay.yml').read_text())
        self.assertIs(relay['docker_no_log'],True)


class RelayContainerStateTest(unittest.TestCase):
    def test_recreation_keeps_stopped_state_and_never_removes_volumes(self):
        spec=importlib.util.spec_from_file_location('relay_recreate',ROOT/'includes/config/scripts/recreate_app_container.py')
        helper=importlib.util.module_from_spec(spec)
        spec.loader.exec_module(helper)
        for running in [True,False]:
            with self.subTest(running=running):
                container=Mock()
                container.name='stream-fusion'
                container.status='running' if running else 'exited'
                container.attrs={'HostConfig':{'Binds':['fixture-data:/data:rw']}}
                client=Mock()
                with patch.object(helper,'_create_container',return_value='new-id') as create:
                    helper.recreate_container(client,container,pull=False,
                        env_overrides={'AD_BASE_URL':'http://ssdv2-relay:1080','PROXY_URL':''})
                self.assertIs(create.call_args.args[1],container.attrs)
                container.remove.assert_called_once_with()
                self.assertEqual(container.stop.called,running)
                self.assertEqual(client.api.start.called,running)
                client.images.pull.assert_not_called()




@unittest.skipUnless(ANSIBLE.is_file(), "Ansible requis")
class HookRedeployLoggingTest(unittest.TestCase):
    """Les hooks qui redéploient `docker_info` doivent masquer les paramètres."""

    def test_all_docker_info_redeploys_are_masked(self):
        import glob
        unmasked = []
        for path in glob.glob(str(ROOT / "includes/dockerapps/**/*.yml"), recursive=True):
            if path.endswith("stremio_base.yml"):
                continue
            try:
                document = yaml.safe_load(Path(path).read_text())
            except yaml.YAMLError:
                continue
            stack = [(document, False)]
            while stack:
                node, inherited = stack.pop()
                if isinstance(node, list):
                    for item in node:
                        stack.append((item, inherited))
                    continue
                if not isinstance(node, dict):
                    continue
                raw_no_log = node.get("no_log")
                if raw_no_log is True:
                    local_protected = True
                elif isinstance(raw_no_log, str) and re.search(r"default\(\s*false\s*\)", raw_no_log):
                    local_protected = False
                elif raw_no_log is not None:
                    local_protected = str(raw_no_log).strip().lower() not in ("false", "no")
                else:
                    local_protected = False
                protected = inherited or local_protected
                for key, value in node.items():
                    if str(key).split(".")[-1] == "docker_container" and \
                            str(value).strip() in ("{{ docker_info }}", "{{docker_info}}"):
                        if not protected:
                            unmasked.append(f"{Path(path).relative_to(ROOT)}: {node.get('name')}")
                for child in node.values():
                    if isinstance(child, (list, dict)):
                        stack.append((child, protected))
        self.assertEqual(unmasked, [])

    def run_task(self, tmp, task, variables):
        play = [{"hosts": "localhost", "gather_facts": False,
                 "vars": variables, "tasks": [task]}]
        path = Path(tmp) / "play.json"
        path.write_text(json.dumps(play))
        return subprocess.run(
            [str(ANSIBLE), "-i", "localhost,", "-c", "local", str(path), "-vv"],
            capture_output=True, text=True, timeout=60,
        )

    def test_masked_redeploy_keeps_progress_and_hides_secret(self):
        marker = "fixture-docker-info-secret-7712"
        task = {
            "name": "Deploying test-app",
            "no_log": True,
            "community.docker.docker_container": {"name": "test-app", "state": "started"},
        }
        # Le module est remplacé par un échec statique : ce qui doit rester
        # masqué, c'est le contenu de docker_info (donc env).
        task.pop("community.docker.docker_container")
        task["ansible.builtin.fail"] = {"msg": "échec simulé"}
        with tempfile.TemporaryDirectory() as tmp:
            result = self.run_task(tmp, task, {
                "docker_info": {"name": "test-app", "env": {"SECRET": marker}},
            })
        output = result.stdout + result.stderr
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn(marker, output)
        self.assertIn("Deploying test-app", output)

    def test_module_error_message_is_not_masked(self):
        # Comportement constaté, à requalifier si Ansible change : no_log masque
        # le résultat de tâche, pas un message d'erreur produit par un module.
        marker = "fixture-module-error-secret-9913"
        task = {
            "name": "Échec avec message",
            "no_log": True,
            "ansible.builtin.fail": {"msg": "échec : " + marker},
        }
        with tempfile.TemporaryDirectory() as tmp:
            result = self.run_task(tmp, task, {})
        output = result.stdout + result.stderr
        version = subprocess.run([str(ANSIBLE), "--version"], capture_output=True, text=True)
        version = " ".join(version.stdout.split()[:3])
        self.assertIn(marker, output, f"comportement Ansible modifié ({version})")
        self.assertIn("censored", output, version)


if __name__ == '__main__':
    unittest.main()
