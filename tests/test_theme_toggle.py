"""Exercise the native theme-selector bridge without applying a real theme."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/bin/theme-toggle"


class ThemeToggleTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.log = root / "calls.jsonl"
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
            XDG_RUNTIME_DIR=str(root / "runtime"),
            TEST_LOG=str(self.log),
        )

    def run_script(self, *args):
        return subprocess.run(
            [str(SCRIPT), *args],
            env=self.env,
            capture_output=True,
            text=True,
        )

    def test_machine_list_contains_ids_labels_and_modes(self):
        result = self.run_script("list-machine")
        self.assertEqual(result.returncode, 0)
        records = [line.split("\t") for line in result.stdout.splitlines()]
        self.assertEqual(len(records), 12)
        self.assertEqual(records[0], ["tokyonight-dark", "Tokyo Night — Dark", "dark"])
        self.assertEqual(records[-1], ["nightfox-dark", "Nightfox — Dark", "dark"])

    def test_menu_prefers_quickshell_popup(self):
        result = self.run_script("menu")
        self.assertEqual(result.returncode, 0)
        calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        self.assertEqual(calls[0][-3:], ["shell", "toggle", "theme"])


if __name__ == "__main__":
    unittest.main()
