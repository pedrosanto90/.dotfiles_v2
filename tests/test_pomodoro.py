"""Exercise the Pomodoro state API and native menu bridge."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/bin/pomodoro"


class PomodoroTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.log = root / "calls.jsonl"
        self.state_home = root / "state/debian-sway-dev"
        self.runtime = root / "runtime"
        self.state_home.mkdir(parents=True)
        self.runtime.mkdir()
        bin_dir = root / "bin"
        bin_dir.mkdir()
        config = root / "config/quickshell/control-center"
        config.mkdir(parents=True)
        (config / "shell.qml").touch()

        quickshell = bin_dir / "quickshell"
        quickshell.write_text('''#!/usr/bin/python3
import json, os, sys
with open(os.environ["TEST_LOG"], "a") as log:
    log.write(json.dumps(sys.argv[1:]) + "\\n")
''')
        quickshell.chmod(0o755)

        self.env = dict(
            os.environ,
            HOME=str(root / "home"),
            PATH=f"{bin_dir}:/usr/bin:/bin",
            XDG_CONFIG_HOME=str(root / "config"),
            XDG_RUNTIME_DIR=str(self.runtime),
            XDG_STATE_HOME=str(root / "state"),
            TEST_LOG=str(self.log),
        )

    def run_script(self, *args):
        return subprocess.run(
            [str(SCRIPT), *args],
            env=self.env,
            capture_output=True,
            text=True,
        )

    def test_details_reports_idle_defaults(self):
        result = self.run_script("details")
        self.assertEqual(result.returncode, 0)
        data = json.loads(result.stdout)
        self.assertEqual(data["state"], "idle")
        self.assertEqual(data["phase"], "idle")
        self.assertEqual(data["remaining"], 0)
        self.assertEqual(data["duration"], 50 * 60)
        self.assertEqual(data["focusDuration"], 50)
        self.assertEqual(data["shortDuration"], 10)
        self.assertEqual(data["longDuration"], 15)

    def test_details_reports_paused_state_and_saved_durations(self):
        (self.state_home / "pomodoro.conf").write_text(
            "focus=25\nshort=5\nlong=20\n"
        )
        (self.runtime / "debian-sway-dev-pomodoro.state").write_text(
            "phase=focus\nends_at=0\nremaining=42\nsessions=2\n"
        )
        result = self.run_script("details")
        self.assertEqual(result.returncode, 0)
        data = json.loads(result.stdout)
        self.assertEqual(data["state"], "paused")
        self.assertEqual(data["phase"], "focus")
        self.assertEqual(data["remaining"], 42)
        self.assertEqual(data["duration"], 25 * 60)
        self.assertEqual(data["sessions"], 2)

    def test_menu_prefers_quickshell_popup(self):
        result = self.run_script("menu")
        self.assertEqual(result.returncode, 0)
        calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        self.assertEqual(calls[0][-3:], ["shell", "toggle", "pomodoro"])


if __name__ == "__main__":
    unittest.main()
