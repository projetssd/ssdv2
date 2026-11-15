"""Régression des suffixes de protocole lors des recréations Docker."""
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import Mock
from docker.types import ContainerConfig

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('recreate', ROOT / 'includes/config/scripts/recreate_app_container.py')
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class PortProtocolsTest(unittest.TestCase):
    def test_recreation_repairs_ports_and_stays_stable(self):
        ports = {'8080/tcp': {}, '8080/tcp/tcp': {}, '8080/tcp/tcp/tcp': {}, '53/udp/udp': {}}
        for _ in range(3):
            client = Mock()
            client.api.create_container.return_value = {"Id": "fixture"}
            helper._create_container(client, {'Config': {'ExposedPorts': ports}, 'HostConfig': {}}, 'fixture')
            kwargs = client.api.create_container.call_args.kwargs
            ports = ContainerConfig('1.45', 'fixture', command=None, ports=kwargs['ports'])['ExposedPorts']
            self.assertEqual(set(ports), {'8080/tcp', '53/udp'})

    def test_ambiguous_protocol_is_rejected(self):
        with self.assertRaises(ValueError):
            helper._normalize_exposed_ports(['53/udp/tcp'])


if __name__ == '__main__':
    unittest.main()
