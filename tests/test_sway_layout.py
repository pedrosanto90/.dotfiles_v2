"""Exercise the native tiling-selector bridge and machine-readable preset data."""
from contextlib import redirect_stdout
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/bin/sway-layout"
BACKEND = ROOT / "configs/sway/tiling.py"


def load_backend():
    spec = importlib.util.spec_from_file_location("dotfiles_tiling", BACKEND)
    module = importlib.util.module_from_spec(spec)
    with mock.patch.dict("sys.modules", {"i3ipc": mock.Mock()}):
        spec.loader.exec_module(module)
    return module


class SwayLayoutTest(unittest.TestCase):
    def test_active_workspace_falls_back_to_sway_workspace_focus(self):
        backend = load_backend()
        workspace = type("Workspace", (), {"name": "3"})()
        tree = mock.Mock()
        tree.find_focused.return_value = None
        tree.workspaces.return_value = [workspace]
        ipc = mock.Mock()
        ipc.get_tree.return_value = tree
        ipc.get_workspaces.return_value = [
            type("WorkspaceReply", (), {"name": "3", "focused": True})()
        ]

        self.assertIs(backend.active_workspace(ipc), workspace)

    def test_preset_list_is_machine_readable(self):
        backend = load_backend()
        workspace = type("Workspace", (), {"name": "4"})()
        output = io.StringIO()
        with mock.patch.object(backend, "active_workspace", return_value=workspace), \
                mock.patch.object(backend, "choice", return_value="2x2"), \
                redirect_stdout(output):
            backend.list_presets(None)

        data = json.loads(output.getvalue())
        self.assertEqual(data["workspace"], "4")
        self.assertEqual(data["selected"], "2x2")
        self.assertEqual(len(data["presets"]), 8)
        self.assertEqual(data["presets"][0]["id"], "2x1")
        self.assertEqual(data["presets"][-1]["id"], "alternate")

    def test_menu_prefers_quickshell_popup(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            log = root / "calls.jsonl"
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
            env = dict(
                os.environ,
                HOME=str(root / "home"),
                PATH=f"{bin_dir}:/usr/bin:/bin",
                XDG_CONFIG_HOME=str(root / "config"),
                TEST_LOG=str(log),
            )
            result = subprocess.run([str(SCRIPT), "menu"], env=env,
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0)
            calls = [json.loads(line) for line in log.read_text().splitlines()]
            self.assertEqual(calls[0][-3:], ["shell", "toggle", "tiling"])


if __name__ == "__main__":
    unittest.main()
