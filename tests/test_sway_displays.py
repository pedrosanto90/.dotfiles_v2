"""Exercise the monitor/workspace layout planner without touching Sway."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/bin/sway-displays"


def output(name, width=1920, *, active=True):
    return {
        "name": name,
        "active": active,
        "scale": 1,
        "current_mode": {"width": width, "height": 1080, "refresh": 60000},
        "rect": {"x": 0, "y": 0, "width": width, "height": 1080},
    }


def workspace(num, output_name):
    return {"num": num, "name": str(num), "output": output_name,
            "focused": False, "urgent": False}


class SwayDisplaysTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.log = root / "calls.jsonl"
        self.outputs = root / "outputs.json"
        self.workspaces = root / "workspaces.json"
        bin_dir = root / "bin"
        bin_dir.mkdir()
        program = '''#!/usr/bin/python3
import json, os, sys
from pathlib import Path
args = sys.argv[1:]
with open(os.environ["TEST_LOG"], "a") as log:
    log.write(json.dumps(args) + "\\n")
if args == ["-r", "-t", "get_outputs"]:
    print(Path(os.environ["TEST_OUTPUTS"]).read_text()); sys.exit(0)
if args == ["-r", "-t", "get_workspaces"]:
    print(Path(os.environ["TEST_WORKSPACES"]).read_text()); sys.exit(0)
sys.exit(0)
'''
        command = bin_dir / "swaymsg"
        command.write_text(program)
        command.chmod(0o755)
        self.env = dict(os.environ, PATH=f"{bin_dir}:/usr/bin:/bin",
                        TEST_LOG=str(self.log), TEST_OUTPUTS=str(self.outputs),
                        TEST_WORKSPACES=str(self.workspaces))
        self.outputs.write_text("[]")
        self.workspaces.write_text("[]")

    def run_script(self, *args, outputs=(), workspaces=()):
        self.outputs.write_text(json.dumps(list(outputs)))
        self.workspaces.write_text(json.dumps(list(workspaces)))
        if self.log.exists():
            self.log.unlink()
        result = subprocess.run([str(SCRIPT), *args], env=self.env,
                                capture_output=True, text=True)
        calls = [json.loads(line) for line in self.log.read_text().splitlines()] \
            if self.log.exists() else []
        commands = [call[0] for call in calls if len(call) == 1]
        return result, commands

    def test_single_monitor_binds_workspaces_to_internal(self):
        result, commands = self.run_script("apply", outputs=[output("eDP-1")])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(commands, [
            "workspace 1 output eDP-1",
            "workspace 2 output eDP-1",
            "workspace 3 output eDP-1",
            "workspace 4 output eDP-1",
            "workspace 5 output eDP-1",
            "workspace 10 output eDP-1",
        ])

    def test_dual_with_dp_places_external_on_the_right(self):
        result, commands = self.run_script(
            "apply", outputs=[output("eDP-1", 1920), output("DP-1", 2560)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(commands, [
            "output eDP-1 position 0 0",
            "output DP-1 position 1920 0",
            "workspace 1 output DP-1",
            "workspace 2 output DP-1",
            "workspace 3 output DP-1",
            "workspace 4 output DP-1",
            "workspace 5 output DP-1",
            "workspace 10 output eDP-1",
        ])

    def test_dual_with_hdmi_treats_hdmi_as_primary(self):
        result, commands = self.run_script(
            "apply", outputs=[output("eDP-1", 1920), output("HDMI-A-1", 1366)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(commands, [
            "output eDP-1 position 0 0",
            "output HDMI-A-1 position 1920 0",
            "workspace 1 output HDMI-A-1",
            "workspace 2 output HDMI-A-1",
            "workspace 3 output HDMI-A-1",
            "workspace 4 output HDMI-A-1",
            "workspace 5 output HDMI-A-1",
            "workspace 10 output eDP-1",
        ])

    def test_triple_orders_hdmi_dp_internal(self):
        result, commands = self.run_script(
            "apply",
            outputs=[output("eDP-1", 1920), output("DP-1", 2560),
                     output("HDMI-A-1", 1920)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(commands, [
            "output HDMI-A-1 position 0 0",
            "output DP-1 position 1920 0",
            "output eDP-1 position 4480 0",
            "workspace 1 output DP-1",
            "workspace 2 output DP-1",
            "workspace 3 output DP-1",
            "workspace 4 output DP-1",
            "workspace 5 output DP-1",
            "workspace 10 output eDP-1",
        ])

    def test_moves_existing_bound_workspaces_only(self):
        result, commands = self.run_script(
            "apply",
            outputs=[output("eDP-1"), output("DP-1")],
            workspaces=[workspace(3, "eDP-1"), workspace(6, "eDP-1"),
                        workspace(10, "DP-1")])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('[workspace="3"] move workspace to output DP-1', commands)
        self.assertIn('[workspace="10"] move workspace to output eDP-1', commands)
        self.assertNotIn('[workspace="6"] move workspace to output DP-1', commands)
        self.assertFalse(any("workspace 6 output" in command for command in commands))
        self.assertFalse(any("workspace 9 output" in command for command in commands))

    def test_status_reports_the_layout_plan(self):
        result, _ = self.run_script(
            "status",
            outputs=[output("eDP-1"), output("DP-1"), output("HDMI-A-1")])
        self.assertEqual(result.returncode, 0, result.stderr)
        status = json.loads(result.stdout)
        self.assertEqual(status["mode"], "triple")
        self.assertEqual(status["primary"], "DP-1")
        self.assertEqual(status["internal"], "eDP-1")
        self.assertIn("workspace 1 output DP-1", status["bindings"])
        self.assertIn("workspace 10 output eDP-1", status["bindings"])


if __name__ == "__main__":
    unittest.main()
