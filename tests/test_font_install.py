"""Exercise font installation without touching the user's fonts or network."""
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class FontInstallTest(unittest.TestCase):
    def run_installer(self, directory, script):
        return subprocess.run(
            ["bash", "-c", f'''
set -euo pipefail
export HOME="{directory}"
source "{ROOT}/scripts/lib/common.sh"
source "{ROOT}/scripts/lib/external.sh"
mkdir -p "${{CACHE_HOME}}"
download() {{ printf 'download %s\\n' "$1"; printf 'font' >"$2"; }}
fc-scan() {{ printf 'Courier Prime'; }}
fc-cache() {{ :; }}
{script}
'''], capture_output=True, text=True,
        )

    def test_install_repeat_and_repair_missing_style(self):
        with tempfile.TemporaryDirectory() as directory:
            result = self.run_installer(directory, '''
install_courier_prime_font
install_courier_prime_font
rm "${HOME}/.local/share/fonts/CourierPrime/CourierPrime-Italic.ttf"
install_courier_prime_font
''')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.count("download "), 6)
            fonts = Path(directory) / ".local/share/fonts/CourierPrime"
            self.assertEqual({p.name for p in fonts.iterdir()}, {
                "CourierPrime-Regular.ttf", "CourierPrime-Bold.ttf",
                "CourierPrime-Italic.ttf", "CourierPrime-BoldItalic.ttf", "OFL.txt",
            })

    def test_invalid_font_is_not_installed(self):
        with tempfile.TemporaryDirectory() as directory:
            result = self.run_installer(directory, '''
fc-scan() { printf 'Unexpected font'; }
install_courier_prime_font
''')
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Invalid Courier Prime font", result.stderr)
            self.assertFalse(list(Path(directory).rglob("*.ttf")))
