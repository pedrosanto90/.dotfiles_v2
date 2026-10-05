"""Exercise the clipboard UI bridge without changing the real clipboard."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/bin/clipboard-history"


class ClipboardHistoryTest(unittest.TestCase):
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

        program = '''#!/usr/bin/python3
import json, os, sys
from pathlib import Path
name = Path(sys.argv[0]).name
payload = sys.stdin.read() if name in ("cliphist", "wl-copy") and sys.argv[1:] != ["list"] else ""
with open(os.environ["TEST_LOG"], "a") as log:
    log.write(json.dumps({"name": name, "args": sys.argv[1:], "stdin": payload}) + "\\n")
if name == "cliphist" and sys.argv[1:] == ["list"]:
    print("42\\tFirst entry")
    print("41\\tSecond entry")
elif name == "cliphist" and sys.argv[1:] == ["decode"]:
    sys.stdout.write("decoded:" + payload)
elif name == "wofi":
    print("42\\tFirst entry")
elif name == "quickshell" and os.environ.get("QS_FAIL") == "1":
    sys.exit(1)
'''
        for name in ("cliphist", "wl-copy", "wofi", "quickshell"):
            command = bin_dir / name
            command.write_text(program)
            command.chmod(0o755)

        self.env = dict(
            os.environ,
            PATH=f"{bin_dir}:/usr/bin:/bin",
            XDG_CONFIG_HOME=str(root / "config"),
            XDG_RUNTIME_DIR=str(root / "runtime"),
            WAYLAND_DISPLAY="wayland-test",
            TEST_LOG=str(self.log),
        )

    def run_script(self, *args, **env):
        result = subprocess.run(
            [str(SCRIPT), *args],
            env=dict(self.env, **env),
            capture_output=True,
            text=True,
        )
        calls = [json.loads(line) for line in self.log.read_text().splitlines()] \
            if self.log.exists() else []
        return result, calls

    def test_list_returns_raw_cliphist_entries(self):
        result, calls = self.run_script("--list")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.splitlines(), ["42\tFirst entry", "41\tSecond entry"])
        self.assertEqual(calls, [{"name": "cliphist", "args": ["list"], "stdin": ""}])

    def test_restore_decodes_entry_into_wayland_clipboard(self):
        result, calls = self.run_script("--restore", "42")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(calls[0], {"name": "cliphist", "args": ["decode"], "stdin": "42"})
        self.assertEqual(calls[1], {"name": "wl-copy", "args": [], "stdin": "decoded:42"})

    def test_restore_rejects_invalid_entry_id(self):
        result, calls = self.run_script("--restore", "not-an-id")
        self.assertEqual(result.returncode, 2)
        self.assertEqual(calls, [])

    def test_default_action_prefers_quickshell(self):
        result, calls = self.run_script()
        self.assertEqual(result.returncode, 0)
        self.assertEqual(calls[0]["name"], "quickshell")
        self.assertEqual(calls[0]["args"][-3:], ["shell", "toggle", "clipboard"])
        self.assertFalse(any(call["name"] == "wofi" for call in calls))


if __name__ == "__main__":
    unittest.main()
