"""Exercise caffeine lifecycle without touching the live idle daemon."""
import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/bin/caffeine-toggle"


class CaffeineToggleTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.runtime = root / "runtime"
        self.runtime.mkdir()
        self.log = root / "calls"
        bin_dir = root / "bin"
        bin_dir.mkdir()

        for name, body in {
            "sway-idle": 'printf "sway-idle %s\\n" "$*" >>"${TEST_LOG}"\n',
            "pkill": 'printf "pkill %s\\n" "$*" >>"${TEST_LOG}"\n',
            "systemd-inhibit": 'exec sleep 30 >/dev/null 2>&1\n',
        }.items():
            command = bin_dir / name
            command.write_text(f"#!/usr/bin/env bash\n{body}")
            command.chmod(0o755)

        self.env = dict(
            os.environ,
            PATH=f"{bin_dir}:/usr/bin:/bin",
            XDG_RUNTIME_DIR=str(self.runtime),
            TEST_LOG=str(self.log),
        )

    def tearDown(self):
        pid_file = self.runtime / "debian-sway-dev-caffeine.pid"
        if pid_file.exists():
            try:
                os.killpg(int(pid_file.read_text()), signal.SIGKILL)
            except (ProcessLookupError, ValueError):
                pass

    def run_toggle(self, action):
        return subprocess.run(
            [str(SCRIPT), action], env=self.env,
            capture_output=True, text=True, check=False,
        )

    def calls(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_enable_stops_idle_daemon(self):
        result = self.run_toggle("toggle")
        self.assertEqual(result.returncode, 0)
        self.assertIn("sway-idle stop", self.calls())
        status = self.run_toggle("status")
        self.assertEqual(json.loads(status.stdout)["class"], "active")

    def test_disable_starts_fresh_idle_daemon(self):
        inhibitor = subprocess.Popen(["setsid", "sleep", "30"])
        self.addCleanup(lambda: inhibitor.poll() is None and inhibitor.kill())
        (self.runtime / "debian-sway-dev-caffeine.pid").write_text(f"{inhibitor.pid}\n")

        result = self.run_toggle("toggle")

        self.assertEqual(result.returncode, 0)
        self.assertIn("sway-idle start", self.calls())
        self.assertFalse((self.runtime / "debian-sway-dev-caffeine.pid").exists())

    def test_inactive_status_recovers_from_stale_pid_file(self):
        (self.runtime / "debian-sway-dev-caffeine.pid").write_text("99999999\n")
        result = self.run_toggle("status")
        self.assertEqual(json.loads(result.stdout)["class"], "inactive")
        self.assertIn("sway-idle start", self.calls())


if __name__ == "__main__":
    unittest.main()
