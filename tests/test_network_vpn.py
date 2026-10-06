"""Exercise NetworkManager VPN discovery and actions without changing the network."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/bin/network-vpn"
VPN_UUID = "11111111-2222-3333-4444-555555555555"
WG_UUID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"


class NetworkVpnTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.log = root / "calls.jsonl"
        bin_dir = root / "bin"
        bin_dir.mkdir()
        program = f'''#!/usr/bin/python3
import json, os, sys
from pathlib import Path
name = Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["TEST_LOG"], "a") as log:
    log.write(json.dumps([name] + args) + "\\n")
if name == "nmcli":
    if args == ["--terse", "--fields", "UUID,TYPE", "connection", "show", "--active"]:
        print("{VPN_UUID}:vpn")
    elif args == ["--terse", "--fields", "UUID,TYPE", "connection", "show"]:
        print("{WG_UUID}:wireguard")
        print("{VPN_UUID}:vpn")
        print("99999999-8888-7777-6666-555555555555:802-11-wireless")
    elif args[:4] == ["--get-values", "connection.id", "connection", "show"]:
        print("Office WireGuard" if args[-1] == "{WG_UUID}" else "Company VPN")
    elif args[:4] == ["--get-values", "vpn.service-type", "connection", "show"]:
        print("org.freedesktop.NetworkManager.openvpn")
'''
        for name in ("nmcli", "nm-connection-editor"):
            command = bin_dir / name
            command.write_text(program)
            command.chmod(0o755)
        self.env = dict(os.environ, PATH=f"{bin_dir}:/usr/bin:/bin", TEST_LOG=str(self.log))

    def run_script(self, *args):
        result = subprocess.run([str(SCRIPT), *args], env=self.env,
                                capture_output=True, text=True)
        calls = [json.loads(line) for line in self.log.read_text().splitlines()] \
            if self.log.exists() else []
        return result, calls

    def test_list_returns_only_vpn_profiles_and_active_state(self):
        result, calls = self.run_script("list")
        self.assertEqual(result.returncode, 0, result.stderr)
        profiles = json.loads(result.stdout)
        self.assertEqual([profile["name"] for profile in profiles],
                         ["Company VPN", "Office WireGuard"])
        self.assertTrue(profiles[0]["active"])
        self.assertEqual(profiles[0]["type"], "openvpn")
        self.assertFalse(profiles[1]["active"])
        self.assertEqual(profiles[1]["type"], "WireGuard")

    def test_up_and_down_use_connection_uuid(self):
        result, calls = self.run_script("up", WG_UUID)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(calls[-1], ["nmcli", "connection", "up", "uuid", WG_UUID])

        self.log.unlink()
        result, calls = self.run_script("down", VPN_UUID)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(calls[-1], ["nmcli", "connection", "down", "uuid", VPN_UUID])

    def test_invalid_uuid_is_rejected(self):
        result, calls = self.run_script("up", "not-a-uuid")
        self.assertEqual(result.returncode, 2)
        self.assertEqual(calls, [])

    def test_add_import_and_edit_use_connection_editor(self):
        result, calls = self.run_script("add")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(calls[-1], ["nm-connection-editor", "--create", "--type=vpn"])

        self.log.unlink()
        result, calls = self.run_script("import")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(calls[-1], ["nm-connection-editor", "--import"])

        self.log.unlink()
        result, calls = self.run_script("edit", VPN_UUID)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(calls[-1], ["nm-connection-editor", f"--edit={VPN_UUID}"])


if __name__ == "__main__":
    unittest.main()
