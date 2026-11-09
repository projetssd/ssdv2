"""Tests isolés du transport privé WireGuard ; aucun accès au démon Docker."""
import base64
import importlib.machinery
import importlib.util
import io
import pathlib
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch

ROOT = pathlib.Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader("ctl_peer_test", str(ROOT / "ssdv2ctl"))
spec = importlib.util.spec_from_loader(loader.name, loader)
ctl = importlib.util.module_from_spec(spec)
loader.exec_module(ctl)
PNG = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aP1sAAAAASUVORK5CYII=")


def archive(name="peer1.png", data=PNG, symlink=False):
    result = io.BytesIO()
    with tarfile.open(fileobj=result, mode="w") as tar:
        info = tarfile.TarInfo(name)
        if symlink:
            info.type = tarfile.SYMTYPE
            info.linkname = "/etc/shadow"
            tar.addfile(info)
        else:
            info.size = len(data)
            tar.addfile(info, io.BytesIO(data))
    return result.getvalue()


class PeerQrTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.source = pathlib.Path(self.temp.name)
        catalogue = self.source / ctl.CATALOGUE_RELATIVE
        catalogue.parent.mkdir(parents=True)
        catalogue.write_text("wireguard - VPN\nsonarr - Series\n")

    def tearDown(self):
        self.temp.cleanup()

    def test_reads_only_known_png_in_memory(self):
        with patch.object(ctl, "_read_peer_archive", return_value=archive()) as read:
            result = ctl.command_peer_qr(self.source, "wireguard")
        self.assertEqual(base64.b64decode(result["png_base64"]), PNG)
        read.assert_called_once_with(["docker", "cp", "wireguard:/config/peer1/peer1.png", "-"])

    def test_refuses_other_apps_and_arbitrary_paths(self):
        for app in ["sonarr", "../wireguard", "wireguard;id"]:
            with self.subTest(app=app), patch.object(ctl, "_read_peer_archive") as read:
                with self.assertRaises(ctl.CtlError):
                    ctl.command_peer_qr(self.source, app)
                read.assert_not_called()

    def test_rejects_paths_links_invalid_png_and_large_files(self):
        for content in [archive("../peer1.png"), archive(symlink=True),
                        archive(data=b"private-key"), archive(data=b"x" * (512 * 1024 + 1))]:
            with patch.object(ctl, "_read_peer_archive", return_value=content):
                with self.assertRaises(ctl.CtlError) as error:
                    ctl.command_peer_qr(self.source, "wireguard")
                self.assertNotIn("private-key", str(error.exception))

    def test_transport_timeout_and_size_limit(self):
        for code,timeout in [("import time;time.sleep(5)", .05),
                             ("import sys;sys.stdout.buffer.write(b'x'*1100000)", 2)]:
            with self.assertRaises(ctl.CtlError):
                ctl._read_peer_archive([sys.executable, "-c", code], timeout=timeout)


if __name__ == "__main__":
    unittest.main()
