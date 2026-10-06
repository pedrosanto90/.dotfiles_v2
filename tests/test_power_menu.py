"""Exercise power-menu routing without changing the real system state."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/bin/power-menu"


class PowerMenuTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.log = root / "calls.jsonl"
        bin_dir = root / "bin"
        bin_dir.mkdir()
        local_bin = root / "home/.local/bin"
        local_bin.mkdir(parents=True)
        config = root / "config/quickshell/control-center"
        config.mkdir(parents=True)
        (config / "shell.qml").touch()

        program = '''#!/usr/bin/python3
import json, os, sys
from pathlib import Path
with open(os.environ["TEST_LOG"], "a") as log:
    log.write(json.dumps([Path(sys.argv[0]).name] + sys.argv[1:]) + "\\n")
'''
        for command in (bin_dir / "quickshell", bin_dir / "systemctl",
                        local_bin / "sway-lock"):
            command.write_text(program)
            command.chmod(0o755)

        self.env = dict(
            os.environ,
            HOME=str(root / "home"),
            PATH=f"{bin_dir}:/usr/bin:/bin",
            XDG_CONFIG_HOME=str(root / "config"),
            TEST_LOG=str(self.log),
        )

    def run_script(self, *args):
        result = subprocess.run(
            [str(SCRIPT), *args], env=self.env, capture_output=True, text=True
        )
        calls = [json.loads(line) for line in self.log.read_text().splitlines()] \
            if self.log.exists() else []
        return result, calls

    def test_menu_prefers_quickshell_popup(self):
        result, calls = self.run_script("menu")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(calls[0][-3:], ["shell", "toggle", "power"])

    def test_lock_uses_project_lock_command(self):
        result, calls = self.run_script("execute", "lock")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(calls, [["sway-lock"]])

    def test_suspend_locks_before_systemctl(self):
        result, calls = self.run_script("execute", "suspend")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(calls, [["sway-lock"], ["systemctl", "suspend"]])

    def test_reboot_and_poweroff_route_to_systemctl(self):
        result, calls = self.run_script("execute", "reboot")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(calls, [["systemctl", "reboot"]])

        self.log.unlink()
        result, calls = self.run_script("execute", "poweroff")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(calls, [["systemctl", "poweroff"]])

    def test_unknown_action_is_rejected(self):
        result, calls = self.run_script("execute", "hibernate")
        self.assertEqual(result.returncode, 2)
        self.assertEqual(calls, [])


if __name__ == "__main__":
    unittest.main()
