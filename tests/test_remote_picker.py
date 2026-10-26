"""Run isolated Neovim checks; never contact an SSH server or mount a filesystem."""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which("nvim"), "Neovim is required")
class RemotePickerTest(unittest.TestCase):
    def test_remote_explorer(self):
        result = subprocess.run(
            ["nvim", "--headless", "-u", "NONE", "-i", "NONE", "-l",
             str(ROOT / "tests/remote_picker.lua")],
            cwd=ROOT, capture_output=True, text=True, timeout=30,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("remote explorer checks passed", result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
