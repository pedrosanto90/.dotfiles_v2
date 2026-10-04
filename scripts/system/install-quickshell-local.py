#!/usr/bin/env python3
"""Install the pinned Debian 13 amd64 Quickshell runtime without root.

Uses the Debian 13 OBS packages linked by the upstream installation guide.
Debian dependencies are downloaded through the configured APT sources; no
repositories, system packages, or desktop configuration are changed.
"""

import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import urllib.request


VERSION = "0.3.1.db3"
BASE = "https://download.opensuse.org/repositories/home:/AvengeMedia:/danklinux/Debian_13/amd64/"
PACKAGES = {
    "quickshell_0.3.1.db3_amd64.deb": "0ce8c9ac0035d35bcc877fe3169d2b27802981f5b34fbcc123e38e40c71a4956",
    "libcpptrace_1.0.4.db10_amd64.deb": "23f3cb784f2e81bf446ebcf0d9a361ec82c718145ff51a213b13c40c6f6b71f0",
}


def main():
    release = dict(line.split("=", 1) for line in Path("/etc/os-release").read_text().splitlines() if "=" in line)
    arch = subprocess.check_output(["dpkg", "--print-architecture"], text=True).strip()
    if release.get("ID", "").strip('"') != "debian" or release.get("VERSION_ID", "").strip('"') != "13" or arch != "amd64":
        raise SystemExit("This pinned runtime supports Debian 13 amd64 only.")

    destination = Path.home() / ".local/opt" / f"quickshell-{VERSION}"
    launcher = Path.home() / ".local/bin/quickshell"
    launcher_text = f'''#!/bin/sh
runtime="${{HOME}}/.local/opt/quickshell-{VERSION}"
export LD_LIBRARY_PATH="${{runtime}}/usr/lib/x86_64-linux-gnu${{LD_LIBRARY_PATH:+:${{LD_LIBRARY_PATH}}}}"
exec "${{runtime}}/usr/bin/quickshell" "$@"
'''
    if launcher.is_symlink() or (launcher.exists() and launcher.read_bytes() != launcher_text.encode()):
        raise SystemExit(f"Refusing to replace an existing launcher: {launcher}")

    if not destination.exists():
        with tempfile.TemporaryDirectory(prefix="quickshell-install-") as work:
            work = Path(work)
            for filename, checksum in PACKAGES.items():
                print(f"Downloading {filename}", flush=True)
                with urllib.request.urlopen(BASE + filename, timeout=60) as response:
                    data = response.read()
                if hashlib.sha256(data).hexdigest() != checksum:
                    raise SystemExit(f"Checksum mismatch: {filename}")
                (work / filename).write_bytes(data)

            subprocess.run(["apt-get", "download", "libdwarf1", "libunwind8"], cwd=work, check=True)
            root = work / "root"
            for package in work.glob("*.deb"):
                subprocess.run(["dpkg-deb", "--extract", str(package), str(root)], check=True)
            env = dict(os.environ, LD_LIBRARY_PATH=str(root / "usr/lib/x86_64-linux-gnu"))
            subprocess.run([str(root / "usr/bin/quickshell"), "--version"], env=env, check=True)
            destination.parent.mkdir(parents=True, exist_ok=True)
            # Move within the destination filesystem only after the copy completes.
            with tempfile.TemporaryDirectory(prefix=".quickshell-", dir=destination.parent) as stage:
                staged = Path(stage) / "runtime"
                shutil.copytree(root, staged, symlinks=True)
                staged.rename(destination)

    launcher.parent.mkdir(parents=True, exist_ok=True)
    launcher.write_text(launcher_text)
    launcher.chmod(0o755)
    subprocess.run([str(launcher), "--version"], check=True)
    print(f"Installed user-local runtime: {destination}")


if __name__ == "__main__":
    main()
