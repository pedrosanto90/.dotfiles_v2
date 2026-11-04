"""Exercise the tray's QML JavaScript handler with mock StatusNotifier items."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]


class TrayMenuRuntimeTest(unittest.TestCase):
    def test_platform_menus_use_qapplication(self):
        source = (ROOT / "configs/quickshell/control-center/shell.qml").read_text()
        self.assertTrue(source.startswith("//@ pragma UseQApplication\n"))


@unittest.skipUnless(shutil.which("node"), "Node.js is required")
class TrayClicksTest(unittest.TestCase):
    def test_click_dispatch(self):
        source = (ROOT / "configs/quickshell/control-center/Bar.qml").read_text()
        handler = source.split("onClicked: mouse => {", 1)[1].split("onWheel:", 1)[0]
        handler = handler.rsplit("}", 1)[0]
        cases = [
            (1, True, False, ["activate"]),
            (1, False, False, ["activate"]),
            (2, True, False, ["menu"]),
            (2, False, False, []),
            (4, True, False, ["secondary"]),
            (1, True, True, ["menu"]),
            (1, False, True, []),
        ]
        for button, has_menu, only_menu, expected in cases:
            with self.subTest(button=button, has_menu=has_menu, only_menu=only_menu):
                script = f"""
const calls = [];
const Qt = {{LeftButton: 1, RightButton: 2, MiddleButton: 4}};
const mouse = {{button: {button}}};
const trayButton = {{
  modelData: {{
    hasMenu: {json.dumps(has_menu)}, onlyMenu: {json.dumps(only_menu)},
    activate() {{ calls.push('activate'); }},
    secondaryActivate() {{ calls.push('secondary'); }}
  }},
  showMenu() {{ calls.push('menu'); }}
}};
{handler}
console.log(JSON.stringify(calls));
"""
                result = subprocess.run(["node", "-e", script], capture_output=True,
                                        text=True, timeout=10)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(json.loads(result.stdout), expected)


if __name__ == "__main__":
    unittest.main()
