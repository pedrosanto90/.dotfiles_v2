"""Check native OBS installation without changing system packages."""
from pathlib import Path
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]


class ObsInstallTest(unittest.TestCase):
    def run_installer(self, installed):
        return subprocess.run(
            ["bash", "-c", 'set -euo pipefail\n'
             f'source "{ROOT}/scripts/lib/common.sh"\n'
             f'source "{ROOT}/scripts/lib/packages.sh"\n'
             'dpkg() { printf "amd64\\n"; }\n'
             'dpkg-query() {\n'
             f'  if [[ ${{*: -1}} == obs-studio || ${{*: -1}} == obs-plugins ]]; then {installed};\n'
             '  else printf "ii "; fi\n'
             '}\n'
             'apt-cache() { [[ $* == "show obs-studio" || $* == "show obs-plugins" ]]; }\n'
             'apt-get() { printf "APT"; printf " <%s>" "$@"; printf "\\n"; }\n'
             'install_debian_packages\n'],
            capture_output=True, text=True,
        )

    def test_missing_obs_is_installed_from_debian(self):
        result = self.run_installer("return 1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(
            "APT <install> <--no-install-recommends> <--yes> <obs-studio> <obs-plugins>",
            result.stdout,
        )

    def test_existing_obs_is_preserved(self):
        result = self.run_installer('printf "ii "')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("APT <install>", result.stdout)
        self.assertIn("already installed", result.stdout)


if __name__ == "__main__":
    unittest.main()
