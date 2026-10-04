"""Exercise key routing without changing audio, brightness, or playback."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/bin/control-center"


class ControlCenterTest(unittest.TestCase):
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
        for name in ("quickshell", "wpctl", "brightnessctl", "playerctl", "pavucontrol"):
            command = bin_dir / name
            command.write_text('''#!/usr/bin/python3
import json, os, sys
from pathlib import Path
name = Path(sys.argv[0]).name
with open(os.environ["TEST_LOG"], "a") as log:
    log.write(json.dumps([name] + sys.argv[1:]) + "\\n")
if name == "quickshell":
    if os.environ.get("QS_FAIL") == "1": sys.exit(1)
    if "transport" in sys.argv: print("true")
''')
            command.chmod(0o755)
        self.env = dict(os.environ, PATH=f"{bin_dir}:/usr/bin:/bin",
                        XDG_CONFIG_HOME=str(root / "config"), TEST_LOG=str(self.log))

    def run_control(self, action, **env):
        result = subprocess.run([str(SCRIPT), action], env=dict(self.env, **env), capture_output=True, text=True)
        calls = [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []
        return result, calls

    def test_volume_succeeds_when_osd_is_unavailable(self):
        result, calls = self.run_control("volume-up", QS_FAIL="1")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(calls[0], ["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", "5%+"])
        self.assertEqual(calls[1][-3:], ["media", "show", "volume"])

    def test_brightness_targets_backlight_and_preserves_nonzero_minimum(self):
        result, calls = self.run_control("brightness-down")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(calls[0], ["brightnessctl", "--class=backlight", "--min-value=1", "set", "5%-"])

    def test_media_uses_selected_quickshell_player_only(self):
        result, calls = self.run_control("play-pause")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0][-3:], ["media", "transport", "play-pause"])

    def test_media_falls_back_to_playerctl(self):
        result, calls = self.run_control("next", QS_FAIL="1")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(calls[-1], ["playerctl", "next"])

    def test_panel_falls_back_to_existing_mixer(self):
        result, calls = self.run_control("panel", QS_FAIL="1")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(calls[-1], ["pavucontrol"])

    def test_unknown_action_runs_nothing(self):
        result, calls = self.run_control("invalid-action")
        self.assertEqual(result.returncode, 2)
        self.assertEqual(calls, [])


if __name__ == "__main__":
    unittest.main()
