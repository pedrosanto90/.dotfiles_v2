"""Exercise the searchable keybinding catalog and its Quickshell bridge."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/bin/keybindings"


class KeybindingsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.log = root / "calls.jsonl"
        self.project = root / "project"
        sway = self.project / "configs/sway"
        nvim = self.project / "configs/nvim"
        tmux = self.project / "configs/tmux"
        for directory in (sway, nvim, tmux):
            directory.mkdir(parents=True)
        (sway / "bindings.conf").write_text(
            "# @keybind sway|Windows|Super+Q|Close the focused window\n"
        )
        (tmux / "tmux.conf").write_text(
            "# @keybind tmux|Sessions|Prefix+D|Detach the client\n"
        )
        (nvim / "keys.lua").write_text(
            "-- @keybind neovim|Files|Space F|Find files\n"
        )

        bin_dir = root / "bin"
        bin_dir.mkdir()
        config = root / "config/quickshell/control-center"
        config.mkdir(parents=True)
        (config / "shell.qml").touch()
        program = '''#!/usr/bin/python3
import json, os, sys
from pathlib import Path
name = Path(sys.argv[0]).name
with open(os.environ["TEST_LOG"], "a") as log:
    log.write(json.dumps([name] + sys.argv[1:]) + "\\n")
if name == "quickshell" and os.environ.get("QS_FAIL") == "1":
    sys.exit(1)
sys.stdin.read()
'''
        for name in ("quickshell", "wofi"):
            command = bin_dir / name
            command.write_text(program)
            command.chmod(0o755)

        self.env = dict(
            os.environ,
            HOME=str(root / "home"),
            PATH=f"{bin_dir}:/usr/bin:/bin",
            XDG_CONFIG_HOME=str(root / "config"),
            WAYLAND_DISPLAY="wayland-test",
            TEST_LOG=str(self.log),
        )

    def run_script(self, *args, **env):
        result = subprocess.run(
            [str(SCRIPT), "--root", str(self.project), *args],
            env=dict(self.env, **env), capture_output=True, text=True,
        )
        calls = [json.loads(line) for line in self.log.read_text().splitlines()] \
            if self.log.exists() else []
        return result, calls

    def test_machine_output_contains_structured_records(self):
        result, calls = self.run_script("--machine")
        self.assertEqual(result.returncode, 0)
        self.assertIn("sway\tWindows\tSuper+Q\tClose the focused window", result.stdout)
        self.assertIn("neovim\tFiles\tSpace F\tFind files", result.stdout)
        self.assertEqual(calls, [])

    def test_machine_output_respects_scope(self):
        result, calls = self.run_script("--scope", "tmux", "--machine")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), "tmux\tSessions\tPrefix+D\tDetach the client")
        self.assertEqual(calls, [])

    def test_default_action_opens_quickshell_with_scope(self):
        result, calls = self.run_script("--scope", "sway")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(calls[0][-3:], ["keybindings", "open", "sway"])
        self.assertFalse(any(call[0] == "wofi" for call in calls))

    def test_wofi_remains_the_graphical_fallback(self):
        result, calls = self.run_script(QS_FAIL="1")
        self.assertEqual(result.returncode, 0)
        self.assertEqual([call[0] for call in calls], ["quickshell", "wofi"])


if __name__ == "__main__":
    unittest.main()
