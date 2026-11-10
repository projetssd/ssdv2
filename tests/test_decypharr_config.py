"""Render restored Decypharr templates with fictitious settings."""
import json
from pathlib import Path
import unittest

from ansible.plugins.filter.core import to_bool
from jinja2 import Environment, StrictUndefined

ROOT = Path(__file__).resolve().parents[1]


def unique_keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"Duplicate JSON key: {key}")
        result[key] = value
    return result


class DecypharrConfigTest(unittest.TestCase):
    def test_defaults_and_custom_download_limit(self):
        env = Environment(undefined=StrictUndefined)
        env.filters['bool'] = to_bool
        template = env.from_string((ROOT / 'includes/dockerapps/templates/decypharr/config.json.j2').read_text())
        for arr in ('sonarr', 'radarr'):
            for limit in (None, 11):
                for uncached in (True, False):
                    with self.subTest(arr=arr, limit=limit, uncached=uncached):
                        values = dict(
                            decypharr_instance_session_secret='fixture-session',
                            decypharr_instance_strm_secret='fixture-strm',
                            decypharr_instance_provider='alldebrid-' + arr,
                            decypharr_instance_alldebrid_key='fixture-key',
                            decypharr_instance_arr=arr,
                            decypharr_instance_arr_host='http://' + arr,
                            decypharr_instance_arr_token='fixture-arr-token',
                            decypharr_instance_mount='/mnt/alldebrid-' + arr,
                            decypharr_instance_download='/home/fixture/local/' + arr,
                            decypharr_instance_category=arr,
                            decypharr_instance_download_uncached=uncached,
                        )
                        if limit is not None:
                            values['decypharr_instance_max_downloads'] = limit
                        config = json.loads(template.render(**values), object_pairs_hook=unique_keys)
                        self.assertEqual(config['max_active_downloads'], 5 if limit is None else limit)
                        self.assertEqual(config['arrs'][0]['name'], arr)
                        self.assertIs(config['arrs'][0]['download_uncached'], uncached)
                        self.assertTrue(config['use_auth'])


if __name__ == '__main__':
    unittest.main()
