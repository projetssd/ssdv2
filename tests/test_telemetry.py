"""Tests hors-ligne : aucune connexion réseau ou Docker requise."""
from __future__ import annotations

import importlib.util
import os
import tempfile
import time
import json
import urllib.error
import unittest
from pathlib import Path
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "includes/config/scripts/telemetry.py"
spec = importlib.util.spec_from_file_location("ssdv2_telemetry", SCRIPT)
assert spec and spec.loader
telemetry = importlib.util.module_from_spec(spec)
spec.loader.exec_module(telemetry)


class TelemetryTests(unittest.TestCase):
    def test_image_tag_never_exposes_registry(self):
        self.assertEqual(telemetry.image_tag("ghcr.io/user/private/myapp:1.2.3"), "1.2.3")
        self.assertEqual(telemetry.image_tag("registry.example:443/private:latest"), "latest")
        self.assertEqual(telemetry.image_tag("private@sha256:deadbeef"), "unknown")
        self.assertEqual(telemetry.image_tag("private:tag with spaces"), "unknown")

    def test_snapshot_only_uses_allowlisted_apps_and_tags(self):
        with patch.object(telemetry, "database_apps", return_value={"plex", "secret", "jellyfin"}), \
             patch.object(telemetry, "docker_apps", return_value={"jellyfin": "10.9.0", "secret": "private", "sonarr": "4.0"}), \
             patch.object(telemetry, "catalogue_apps", return_value={"plex", "jellyfin", "sonarr"}), \
             patch.object(telemetry, "project_version", return_value=("master", "abcd1234")), \
             patch.object(telemetry, "installation_id", return_value="de164f30-4b69-4a4a-a847-3111a9c80a38"):
            result = telemetry.snapshot()
        self.assertEqual(set(result), {"schema", "installation_id", "branch", "core_version", "apps"})
        self.assertEqual(result["apps"], [
            {"name": "jellyfin", "version": "10.9.0"},
            {"name": "plex", "version": "unknown"},
            {"name": "sonarr", "version": "4.0"}
        ])
        for key in ("ip", "mac", "hostname", "domain", "image", "container", "email", "env"):
            self.assertNotIn(key, str(result).lower())

    def test_docker_failure_never_reports_empty_inventory(self):
        with patch.object(telemetry, "database_apps", return_value={"plex"}), \
             patch.object(telemetry, "docker_apps", return_value=None), \
             patch.object(telemetry, "catalogue_apps", return_value={"plex"}):
            self.assertIsNone(telemetry.snapshot())

    def test_disable_prevents_network(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            with patch.object(telemetry, "DISABLED_FILE", base / "disabled"), \
                 patch.object(telemetry, "CONFIG", base), \
                 patch.object(telemetry, "endpoint", return_value="https://metrics.example.org/api/v1/snapshot"), \
                 patch.object(telemetry, "send") as sender:
                (base / "disabled").touch()
                telemetry.sync()
                sender.assert_not_called()

    def test_url_validation_rejects_downgrades_and_credentials(self):
        with tempfile.TemporaryDirectory() as temp:
            location = Path(temp) / "endpoint"
            with patch.object(telemetry, "ENDPOINT_FILE", location), \
                 patch.dict(os.environ, {}, clear=False):
                os.environ.pop("SSDV2_TELEMETRY_ENDPOINT", None)
                for value in ("http://metrics.example.org/api/v1/snapshot",
                              "https://user:pass@metrics.example.org/api/v1/snapshot",
                              "https://metrics.example.org/api/v1/snapshot?token=x",
                              "https://metrics.example.org/anything"):
                    location.write_text(value)
                    self.assertIsNone(telemetry.endpoint())
                location.write_text("https://metrics.example.org/api/v1/snapshot")
                self.assertEqual(telemetry.endpoint(), location.read_text())

    def test_git_revision_change_bypasses_cooldown(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            old = {"schema": 1, "branch": "master", "core_version": "old123456789", "apps": []}
            new = {**old, "core_version": "new123456789"}
            with (
                patch.object(telemetry, "CONFIG", base),
                patch.object(telemetry, "LOCK_FILE", base / "lock"),
                patch.object(telemetry, "LAST_SEND_FILE", base / "last-send"),
                patch.object(telemetry, "LAST_FINGERPRINT_FILE", base / "last-fingerprint"),
                patch.object(telemetry, "LAST_RESULT_FILE", base / "last-result"),
                patch.object(telemetry, "enabled", return_value=True),
                patch.object(telemetry, "endpoint", return_value="https://example.org/api/v1/snapshot"),
                patch.object(telemetry, "snapshot", return_value=new),
                patch.object(telemetry, "send") as sender,
            ):
                telemetry.LAST_SEND_FILE.write_text(str(time.time()))
                telemetry.LAST_FINGERPRINT_FILE.write_text(telemetry.payload_fingerprint(old))
                telemetry.sync()
                sender.assert_called_once()
                self.assertEqual(telemetry.LAST_FINGERPRINT_FILE.read_text().strip(),
                                 telemetry.payload_fingerprint(new))
                self.assertEqual(json.loads(telemetry.LAST_RESULT_FILE.read_text())["state"], "ok")

    def test_unchanged_snapshot_does_not_send_again_within_day(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            current = {"schema": 1, "branch": "master", "core_version": "abc123456789",
                       "apps": [{"name": "jellyfin", "version": "10.9"}]}
            with (
                patch.object(telemetry, "CONFIG", base),
                patch.object(telemetry, "LOCK_FILE", base / "lock"),
                patch.object(telemetry, "LAST_SEND_FILE", base / "last-send"),
                patch.object(telemetry, "LAST_FINGERPRINT_FILE", base / "last-fingerprint"),
                patch.object(telemetry, "enabled", return_value=True),
                patch.object(telemetry, "endpoint", return_value="https://example.org/api/v1/snapshot"),
                patch.object(telemetry, "snapshot", return_value=current),
                patch.object(telemetry, "send") as sender,
            ):
                telemetry.LAST_SEND_FILE.write_text(str(time.time()))
                telemetry.LAST_FINGERPRINT_FILE.write_text(telemetry.payload_fingerprint(current))
                telemetry.sync()
                sender.assert_not_called()

    def test_failed_http_delivery_records_only_safe_status(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            installation_id = "de164f30-4b69-4a4a-a847-3111a9c80a38"
            current = {"schema": 1, "installation_id": installation_id,
                       "branch": "master", "core_version": "abc123456789", "apps": []}
            http_error = urllib.error.HTTPError("https://example.org/api/v1/snapshot", 403,
                                               "Forbidden", None, None)
            with (
                patch.object(telemetry, "CONFIG", base),
                patch.object(telemetry, "LOCK_FILE", base / "lock"),
                patch.object(telemetry, "LAST_SEND_FILE", base / "last-send"),
                patch.object(telemetry, "LAST_FINGERPRINT_FILE", base / "last-fingerprint"),
                patch.object(telemetry, "LAST_RESULT_FILE", base / "last-result"),
                patch.object(telemetry, "enabled", return_value=True),
                patch.object(telemetry, "endpoint", return_value="https://example.org/api/v1/snapshot"),
                patch.object(telemetry, "snapshot", return_value=current),
                patch.object(telemetry, "send", side_effect=http_error),
            ):
                telemetry.sync()
                status = json.loads(telemetry.LAST_RESULT_FILE.read_text())
                self.assertEqual(status["state"], "http_403")
                self.assertNotIn(installation_id, str(status))
                self.assertFalse(telemetry.LAST_SEND_FILE.exists())
                self.assertFalse(telemetry.LAST_FINGERPRINT_FILE.exists())

    def test_app_version_change_is_detected_independently_from_git(self):
        old = {"branch": "master", "core_version": "abc123456789",
               "apps": [{"name": "jellyfin", "version": "10.9"}]}
        new = {"branch": "master", "core_version": "abc123456789",
               "apps": [{"name": "jellyfin", "version": "10.10"}]}
        self.assertNotEqual(telemetry.payload_fingerprint(old), telemetry.payload_fingerprint(new))


if __name__ == "__main__":
    unittest.main()
