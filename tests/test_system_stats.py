"""Validate the lightweight system resource status command."""
import json
from pathlib import Path
import subprocess
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/bin/system-stats"


class SystemStatsTest(unittest.TestCase):
    def test_status_contains_sensible_resource_values(self):
        result = subprocess.run([str(SCRIPT)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        status = json.loads(result.stdout)
        self.assertEqual(status["class"], "system")
        for key in ("cpu", "memory", "disk"):
            self.assertGreaterEqual(status[key], 0)
            self.assertLessEqual(status[key], 100)
        self.assertGreater(status["memoryTotal"], 0)
        self.assertGreater(status["diskTotal"], 0)
        self.assertLessEqual(status["memoryUsed"], status["memoryTotal"])
        self.assertLessEqual(status["diskUsed"], status["diskTotal"])


if __name__ == "__main__":
    unittest.main()
