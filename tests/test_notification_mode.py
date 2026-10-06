"""Exercise the Mako do-not-disturb helper without changing the live daemon."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/bin/notification-mode"


class NotificationModeTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.log = root / "calls"
        command = root / "makoctl"
        command.write_text("""#!/usr/bin/env bash
printf '%s\\n' "$*" >>"${TEST_LOG}"
if [[ $1 == mode && $# == 1 ]]; then
  printf '%s\\n' default
  [[ ${DND_ACTIVE:-0} == 1 ]] && printf '%s\\n' do-not-disturb
fi
""")
        command.chmod(0o755)
        self.env = dict(os.environ, PATH=f"{root}:/usr/bin:/bin", TEST_LOG=str(self.log))

    def run_mode(self, action, **env):
        return subprocess.run(
            [str(SCRIPT), action], env=dict(self.env, **env),
            capture_output=True, text=True, check=False,
        )

    def test_status_reports_active_mode(self):
        result = self.run_mode("status", DND_ACTIVE="1")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(json.loads(result.stdout)["class"], "active")

    def test_status_reports_inactive_mode(self):
        result = self.run_mode("status")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(json.loads(result.stdout)["class"], "inactive")

    def test_toggle_uses_named_mako_mode(self):
        result = self.run_mode("toggle")
        self.assertEqual(result.returncode, 0)
        self.assertIn("mode -t do-not-disturb", self.log.read_text().splitlines())

    def test_unknown_action_fails(self):
        result = self.run_mode("invalid")
        self.assertEqual(result.returncode, 2)


if __name__ == "__main__":
    unittest.main()
