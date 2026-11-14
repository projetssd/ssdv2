"""Configuration StreamFusion : fixtures Ansible et Docker simulé, sans serveur réel."""
import contextlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

import yaml

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'includes/config/scripts'
sys.path.insert(0, str(SCRIPTS))
import streamfusion_proxy as proxy

ANSIBLE = Path(os.environ.get('ANSIBLE_PLAYBOOK') or shutil.which('ansible-playbook')
               or ROOT / 'venv/bin/ansible-playbook')
KEYS = ['TMDB_API_KEY', 'ADMIN_SECRET_KEY', 'AD_BASE_URL', 'PROXY_URL']
BASE = dict(zip(KEYS, ['fixture-tmdb-5261', 'fixture-admin-' + 'x' * 32,
                       'https://api.alldebrid.com', '']))


@unittest.skipUnless(ANSIBLE.is_file(), 'Ansible requis')
class ConfigurationTest(unittest.TestCase):
    def run_case(self, stored=None, runtime=None, answers=None, variables=None, expected=None, real_prompts=False):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            dest = directory / 'docker' / os.environ.get('USER', '') / 'streamfusion-secrets'
            dest.mkdir(parents=True)
            for key, value in (stored or {}).items():
                (dest / key).write_text(value + '\n')
            tasks = yaml.safe_load((ROOT / 'includes/dockerapps/pretasks/streamfusion.yml').read_text())
            end = next(i for i, task in enumerate(tasks)
                       if task['name'] == 'Generate persistent StreamFusion internal secrets')
            tasks = tasks[:end]
            # Assertions inside the play check that only the expected prompts run.
            for task in tasks:
                if 'ansible.builtin.command' in task:
                    task.pop('ansible.builtin.command')
                    register = task.pop('register')
                    task['ansible.builtin.set_fact'] = {register: {
                        'rc': 0 if runtime is not None else 1,
                        'stdout': json.dumps([f'{k}={v}' for k, v in (runtime or {}).items()])}}
                if 'ansible.builtin.pause' not in task or real_prompts:
                    continue
                marker = task.pop('ansible.builtin.pause')['prompt'].splitlines()[0]
                key = json.loads(marker.split('SSDV2_PROMPT ', 1)[1])['id'].split('.')[-1]
                register = task.pop('register')
                if key not in (answers or {}):
                    task['ansible.builtin.fail'] = {'msg': 'Unexpected prompt: ' + key}
                else:
                    answer = answers[key]
                    task['ansible.builtin.set_fact'] = {
                        register: {} if answer is None else {'user_input': answer}}
            play = [{'hosts': 'localhost', 'gather_facts': False,
                     'vars': {'settings': {'storage': tmp}, **(variables or {})}, 'tasks': tasks}]
            playpath = directory / 'play.json'
            playpath.write_text(json.dumps(play))
            logpath = directory / 'ansible.log'
            environment = {**os.environ, 'ANSIBLE_LOG_PATH': str(logpath),
                           'ANSIBLE_LOCAL_TEMP': str(directory / 'ansible-tmp')}
            result = subprocess.run([str(ANSIBLE), '-i', 'localhost,', '-c', 'local',
                                     str(playpath), '-vv'], capture_output=True, text=True,
                                    timeout=60, env=environment, input='')
            output = result.stdout + result.stderr
            log = logpath.read_text() if logpath.exists() else ''
            for secret in [BASE['TMDB_API_KEY'], BASE['ADMIN_SECRET_KEY'], 'fixture-password-123']:
                self.assertNotIn(secret, output + log)
            if expected is None:
                self.assertNotEqual(result.returncode, 0, output)
                self.assertIn('TASK [Validate provided StreamFusion secret facts]', output)
                self.assertIn('Configuration incomplète ou invalide', output)
                self.assertFalse((dest / 'TMDB_API_KEY').exists())
            else:
                self.assertEqual(result.returncode, 0, output)
                self.assertEqual(dest.stat().st_mode & 0o777, 0o700)
                for key in KEYS:
                    self.assertEqual((dest / key).read_text(), expected[key] + '\n')
                    self.assertEqual((dest / key).stat().st_mode & 0o777, 0o600)

    def test_first_install_default_url_without_proxy(self):
        self.run_case(answers=dict(tmdb_key=BASE['TMDB_API_KEY'], admin_key=BASE['ADMIN_SECRET_KEY'],
                                   ad_base_url='', proxy_url=''), expected=BASE)

    def test_import_existing_container(self):
        self.run_case(runtime={**BASE, 'UNRELATED': 'ignored'},
                      answers={'reconfigure': 'n'}, expected=BASE)

    def test_files_win_including_empty_proxy(self):
        self.run_case(stored=BASE, runtime={**BASE, 'PROXY_URL': 'http://obsolete:1080'},
                      answers={'reconfigure': ''}, expected=BASE)

    def test_noninteractive_keep(self):
        self.run_case(stored=BASE, answers={'reconfigure': None}, expected=BASE)

    def test_change_and_keep_blank_secrets(self):
        expected = {**BASE, 'AD_BASE_URL': 'http://relay:1080',
                    'PROXY_URL': 'http://user:fixture-password-123@proxy:1080/?x=1&y=2'}
        self.run_case(stored=BASE, answers=dict(reconfigure='o', tmdb_key='', admin_key='',
                      ad_base_url=expected['AD_BASE_URL'], proxy_url=expected['PROXY_URL']),
                      expected=expected)

    def test_disable_proxy(self):
        self.run_case(stored={**BASE, 'PROXY_URL': 'http://proxy:1080'},
                      answers=dict(reconfigure='oui', tmdb_key='', admin_key='',
                                   ad_base_url='', proxy_url='-'), expected=BASE)

    def test_real_noninteractive_pause_keeps_values_or_fails_clearly(self):
        self.run_case(stored=BASE, real_prompts=True, expected=BASE)
        self.run_case(real_prompts=True)

    def test_partial_configuration(self):
        self.run_case(stored={'ADMIN_SECRET_KEY': BASE['ADMIN_SECRET_KEY']},
                      answers=dict(reconfigure='n', tmdb_key=BASE['TMDB_API_KEY'],
                                   ad_base_url='', proxy_url=''), expected=BASE)

    def test_automated_overrides(self):
        values = dict(zip(['streamfusion_tmdb_api_key', 'streamfusion_admin_secret_key',
                           'streamfusion_ad_base_url', 'streamfusion_proxy_url'], BASE.values()))
        self.run_case(variables={**values, 'streamfusion_reconfigure': False}, expected=BASE)

    def test_missing_noninteractive_secrets_and_invalid_admin_fail(self):
        for admin in [None, 'short']:
            with self.subTest(admin=admin):
                self.run_case(answers=dict(tmdb_key=None if admin is None else BASE['TMDB_API_KEY'], admin_key=admin,
                                           ad_base_url=None, proxy_url=None))

    def test_public_app_and_worker_share_routing(self):
        app = yaml.safe_load((ROOT / 'includes/dockerapps/vars/streamfusion.yml').read_text())
        self.assertEqual(app['pg_env']['AD_BASE_URL'], '{{ AD_BASE_URL }}')
        self.assertEqual(app['pg_env']['PROXY_URL'], '{{ PROXY_URL }}')
        tasks = yaml.safe_load((ROOT / 'includes/dockerapps/pretasks/streamfusion.yml').read_text())
        worker = next(t['community.docker.docker_container'] for block in tasks
                      for t in block.get('block', [])
                      if t.get('community.docker.docker_container', {}).get('name') == 'taskiq-worker')
        self.assertEqual(worker['env']['AD_BASE_URL'], '{{ pg_env.AD_BASE_URL }}')
        self.assertIn('pg_env.PROXY_URL', worker['env']['PROXY_URL'])


class ProxyTest(unittest.TestCase):
    def setUp(self):
        self.client = Mock()
        self.containers = [Mock(), Mock()]
        for container, name in zip(self.containers, ['stream-fusion', 'taskiq-worker']):
            container.name = name
        self.client.containers.get.side_effect = self.containers

    def test_proxy_and_disable_only_override_proxy_without_pull(self):
        for value in ['http://user:fixture-password-123@proxy:1080/?x=1&y=2', '']:
            with self.subTest(value=bool(value)), tempfile.TemporaryDirectory() as tmp:
                self.client.containers.get.side_effect = self.containers
                with patch.object(proxy, 'recreate_container') as recreate:
                    self.assertTrue(proxy.configure_proxy(self.client, Path(tmp), value))
                    for call, container in zip(recreate.call_args_list, self.containers):
                        self.assertEqual(call.args, (self.client, container))
                        self.assertEqual(call.kwargs, {'env_overrides': {'PROXY_URL': value}, 'pull': False})
                    self.assertEqual(recreate.call_count, 2)
                path = Path(tmp) / 'PROXY_URL'
                self.assertEqual(path.read_text(), value + '\n')
                self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_failure_masks_secret_and_persists_for_retry(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(proxy, 'recreate_container') as recreate:
            recreate.side_effect = [RuntimeError('fixture-password-123'), None]
            output = io.StringIO()
            with contextlib.redirect_stderr(output):
                self.assertFalse(proxy.configure_proxy(self.client, Path(tmp), 'http://proxy:1080'))
            self.assertNotIn('fixture-password-123', output.getvalue())
            self.assertIn('stream-fusion', output.getvalue())
            self.assertEqual((Path(tmp) / 'PROXY_URL').read_text(), 'http://proxy:1080\n')
            self.assertEqual(recreate.call_count, 2)

    def test_missing_container_or_invalid_url_does_not_save(self):
        for value, missing in [('bad-url', False), ('http://proxy:1080', True), ('http://proxy\ninjected', False)]:
            with self.subTest(value=value), tempfile.TemporaryDirectory() as tmp:
                self.client.containers.get.side_effect = [self.containers[0], RuntimeError()] if missing else self.containers
                with patch.object(proxy, 'recreate_container') as recreate:
                    self.assertFalse(proxy.configure_proxy(self.client, Path(tmp), value))
                    recreate.assert_not_called()
                    self.assertFalse((Path(tmp) / 'PROXY_URL').exists())

    def test_shell_command_uses_masked_stdin_and_disable(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            (directory / 'venv/bin').mkdir(parents=True)
            wrapper = directory / 'venv/bin/python'
            wrapper.write_text('#!/bin/bash\ncat > "$SETTINGS_STORAGE/value"\nprintf "%s\\n" "$@" > "$SETTINGS_STORAGE/args"\n')
            wrapper.chmod(0o700)
            command = f'source "{ROOT}/includes/functions.sh"; streamfusion_proxy'
            env = {**os.environ, 'SETTINGS_SOURCE': tmp, 'SETTINGS_STORAGE': tmp}
            for arguments, data, expected in [('', 'http://proxy:1080\n', 'http://proxy:1080'),
                                               (' --disable', '', ''), (' "http://proxy:1080"', '', 'http://proxy:1080')]:
                result = subprocess.run(['bash', '-c', command + arguments], input=data,
                                        text=True, capture_output=True, env=env)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual((directory / 'value').read_text(), expected)
                self.assertNotIn('http://proxy:1080', (directory / 'args').read_text())
                if not arguments:
                    self.assertIn('SSDV2_PROMPT', result.stderr)


if __name__ == '__main__':
    unittest.main()
