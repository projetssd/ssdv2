"""Vérification hors ligne du lancement discret de la télémétrie Bash."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class ProfileTests(unittest.TestCase):
    def test_telemetry_finishes_without_remaining_in_shell_jobs(self):
        profile = (Path(__file__).resolve().parents[1] / "profile.sh").read_text()
        start = profile.index("  _ssdv2_telemetry_resume() {")
        end = profile.index("\n  _ssdv2_autoreload()", start)
        function = profile[start:end]
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory)
            worker = source / "includes/config/scripts/telemetry.py"
            worker.parent.mkdir(parents=True)
            worker.write_text(
                "import os, sys, time\n"
                "from pathlib import Path\n"
                "time.sleep(0.2)\n"
                "Path(os.environ['SETTINGS_SOURCE'], 'done').write_text(sys.argv[1])\n"
            )
            script = function + '\n' + '''
_ssdv2_telemetry_resume
jobs -p > "$SETTINGS_SOURCE/jobs"
for attempt in {1..100}; do
  [ -f "$SETTINGS_SOURCE/done" ] && break
  sleep 0.05
done
'''
            result = subprocess.run(
                ["bash", "--noprofile", "--norc", "-ic", script],
                env={**os.environ, "SETTINGS_SOURCE": directory},
                capture_output=True, text=True, timeout=10,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((source / "jobs").read_text(), "")
            self.assertEqual((source / "done").read_text(), "sync")
            self.assertNotIn("Done", result.stderr)


if __name__ == "__main__":
    unittest.main()
