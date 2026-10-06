"""Validate the detailed system monitor terminal launcher."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/bin/system-monitor"


class SystemMonitorTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.bin_dir = root / "bin"
        self.bin_dir.mkdir()
        (self.bin_dir / "bash").symlink_to("/usr/bin/bash")
        self.log = root / "calls.jsonl"
        program = '''#!/usr/bin/python3
import json, os, sys
from pathlib import Path
with open(os.environ["TEST_LOG"], "a") as log:
    log.write(json.dumps([Path(sys.argv[0]).name] + sys.argv[1:]) + "\\n")
'''
        ghostty = self.bin_dir / "ghostty"
        ghostty.write_text(program)
        ghostty.chmod(0o755)
        self.env = dict(os.environ, HOME=str(root / "home"),
                        PATH=str(self.bin_dir), TEST_LOG=str(self.log),
                        SYSTEM_MONITOR_FOREGROUND="1")

    def add_command(self, name):
        command = self.bin_dir / name
        command.write_text("#!/usr/bin/python3\n")
        command.chmod(0o755)

    def run_script(self):
        result = subprocess.run([str(SCRIPT)], env=self.env,
                                capture_output=True, text=True)
        calls = [json.loads(line) for line in self.log.read_text().splitlines()] \
            if self.log.exists() else []
        return result, calls

    def test_prefers_btop_in_a_dedicated_ghostty_window(self):
        self.add_command("btop")
        self.add_command("htop")
        result, calls = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls[0][0], "ghostty")
        self.assertIn("--class=dev.debianswaydev.system-monitor", calls[0])
        self.assertEqual(calls[0][-2:], ["-e", str(self.bin_dir / "btop")])

    def test_uses_htop_when_btop_is_unavailable(self):
        self.add_command("htop")
        result, calls = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls[0][-2:], ["-e", str(self.bin_dir / "htop")])

    def test_reports_when_no_monitor_is_installed(self):
        result, calls = self.run_script()
        self.assertEqual(result.returncode, 1)
        self.assertIn("neither btop nor htop", result.stderr)
        self.assertEqual(calls, [])


if __name__ == "__main__":
    unittest.main()
