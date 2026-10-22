"""Check installer virtualization paths without changing packages or services."""
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class VirtualizationInstallTest(unittest.TestCase):
    def run_bash(self, script, services=None):
        return subprocess.run(
            ["bash", "-c", 'set -euo pipefail\n'
             f'source "{ROOT}/scripts/lib/common.sh"\n'
             f'source "{ROOT}/scripts/lib/packages.sh"\n'
             f'source "{ROOT}/scripts/lib/configure.sh"\n'
             f'source "{services or ROOT / "scripts/lib/services.sh"}"\n' + script],
            capture_output=True, text=True,
        )

    def test_architecture_and_only_missing_packages(self):
        for arch, packages, excluded in (
            ("amd64", ("qemu-system-x86", "ovmf"), "qemu-system-arm"),
            ("arm64", ("qemu-system-arm", "qemu-efi-aarch64"), "qemu-system-x86"),
        ):
            with self.subTest(architecture=arch):
                result = self.run_bash(f'''
dpkg() {{ printf '%s\\n' {arch}; }}
dpkg-query() {{ [[ $* == *qemu-utils* ]] && printf 'ii ' || return 1; }}
apt-cache() {{ return 0; }}
apt-get() {{ printf 'APT'; printf ' <%s>' "$@"; printf '\\n'; }}
install_debian_packages
''')
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("APT <install> <--no-install-recommends> <--yes>", result.stdout)
                for package in (*packages, "libvirt-daemon-system", "virt-manager",
                                "swtpm", "swtpm-tools", "qemu-system-modules-spice",
                                "gir1.2-spiceclientgtk-3.0"):
                    self.assertIn(f"<{package}>", result.stdout)
                self.assertNotIn(f"<{excluded}>", result.stdout)
                self.assertNotIn("<qemu-utils>", result.stdout)

    def test_repeat_install_skips_apt_install(self):
        result = self.run_bash('''
dpkg() { printf 'amd64\n'; }
dpkg-query() { printf 'ii '; }
apt-get() { [[ $1 == update ]]; }
install_debian_packages
install_debian_packages
''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.count("already installed"), 2)

    def test_unsupported_architecture_fails_before_apt(self):
        result = self.run_bash('''
dpkg() { printf 'riscv64\n'; }
apt-get() { printf 'UNEXPECTED APT'; }
install_debian_packages
''')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Unsupported QEMU/KVM host architecture", result.stderr)
        self.assertNotIn("UNEXPECTED APT", result.stdout)

    def test_access_is_idempotent_and_keeps_other_groups(self):
        result = self.run_bash('''
member=0
id() {
  if [[ $1 == -un ]]; then printf 'tester\n';
  elif (( member )); then printf 'tester docker libvirt\n';
  else printf 'tester docker\n'; fi
}
getent() { [[ $* == 'group libvirt' ]]; }
usermod() { printf 'USERMOD <%s> <%s> <%s> <%s>\n' "$@"; member=1; }
configure_libvirt_access
configure_libvirt_access
''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.count("USERMOD"), 1)
        self.assertIn("USERMOD <--append> <--groups> <libvirt> <tester>", result.stdout)
        self.assertIn("log out and back in", result.stdout)
        self.assertIn("already belongs", result.stdout)

    def test_missing_debian_group_fails_without_usermod(self):
        result = self.run_bash('''
getent() { return 2; }
usermod() { printf 'UNEXPECTED USERMOD'; }
configure_libvirt_access
''')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Debian libvirt group is missing", result.stderr)
        self.assertNotIn("UNEXPECTED USERMOD", result.stdout)

    def test_connection_commands_and_kvm_warning(self):
        # Substitute only the device path to exercise both branches on any host.
        with tempfile.TemporaryDirectory() as directory:
            device = Path(directory) / "kvm"
            services = Path(directory) / "services.sh"
            services.write_text((ROOT / "scripts/lib/services.sh").read_text()
                                .replace("/dev/kvm", str(device)))
            for arch, emulator in (("amd64", "qemu-system-x86_64"),
                                   ("arm64", "qemu-system-aarch64")):
                for available in (False, True):
                    with self.subTest(architecture=arch, kvm=available):
                        if available:
                            device.touch()
                        elif device.exists():
                            device.unlink()
                        result = self.run_bash(f'''
require_command() {{ printf 'REQUIRE <%s>\\n' "$1"; }}
dpkg() {{ printf '{arch}\\n'; }}
sg() {{
  [[ $# == 3 && $1 == libvirt && $2 == -c && $3 == 'virsh -c qemu:///system list --all' ]]
}}
verify_libvirt_installation
''', services=services)
                        self.assertEqual(result.returncode, 0, result.stderr)
                        for command in ("virsh", "virt-manager", "qemu-img",
                                        "swtpm", "swtpm_setup", "sg", emulator):
                            self.assertIn(f"REQUIRE <{command}>", result.stdout)
                        self.assertEqual("unavailable" in result.stderr, not available)

    def test_connection_failure_aborts(self):
        result = self.run_bash('''
require_command() { return 0; }
dpkg() { printf 'amd64\n'; }
sg() { return 1; }
verify_libvirt_installation
printf 'UNEXPECTED SUCCESS'
''')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Could not connect to qemu:///system", result.stderr)
        self.assertNotIn("UNEXPECTED SUCCESS", result.stdout)

    def test_socket_enabled_without_network_or_vm_mutation(self):
        result = self.run_bash('''
systemctl() {
  if [[ $1 == list-unit-files ]]; then printf '%s enabled\n' "$2";
  else printf 'SYSTEMCTL'; printf ' <%s>' "$@"; printf '\n'; fi
}
configure_network_manager_wifi() { return 0; }
virsh() { printf 'UNEXPECTED VIRSH'; return 1; }
enable_services
''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("SYSTEMCTL <enable> <--now> <libvirtd.socket>", result.stdout)
        self.assertNotIn("UNEXPECTED VIRSH", result.stdout)


if __name__ == "__main__":
    unittest.main()
