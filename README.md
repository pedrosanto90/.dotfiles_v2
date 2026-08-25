# Debian Sway Dev

A complete, minimalist, keyboard-first development environment for **Debian 13 Stable (trixie)**. It provides a coherent Wayland session without a full desktop environment and preserves every pre-existing user configuration through automatic backups.

> The installer supports the current Debian Stable release only: Debian 13. Do not run it on Ubuntu, derivatives, Debian testing/unstable, or older Debian releases.

## Features

- Modular Sway configuration with Waybar, Wofi, Mako, locking, and idle handling
- Native Wayland graphical login through greetd and wlgreet
- Ghostty built from the official release tarball when unavailable in Debian
- Framework-free Zsh with Starship, fzf, zoxide, and a small alias set
- Latest stable Neovim built from official source, with modular Tokyo Night and Kanagawa themes
- Docker Engine with CLI, Buildx, and Compose; no Docker Desktop and no `sudo` for daily use
- Node.js LTS through NVM, npm, Corepack, pnpm, and Yarn
- Official stable Go toolchain and Python with venv, pip, and pipx
- PipeWire/WirePlumber, NetworkManager, multi-protocol VPN support, Bluetooth, and PolicyKit
- Wayland portals for screen sharing, Flatpak, and Electron applications
- Brave exclusively from its official repository, launched through Ozone/Wayland
- Bruno REST client, Visual Studio Code, and DBeaver Community from official distribution channels
- Repository-managed VS Code settings, keybindings, and extension inventory
- Thunar, Yazi, persistent clipboard history, screenshots, and USB automounting
- Searchable Sway, tmux, and Neovim keybinding reference
- Tokyo Night and Kanagawa palettes, Papirus icons, and JetBrainsMono Nerd Font
- Synchronized light/dark theme families for GTK, Waybar, Ghostty, and Neovim
- Clipboard history for text and images, available from Waybar through Wofi

## Requirements

- An updated Debian 13 Stable (`trixie`) installation
- A regular user with `sudo` access
- An Internet connection
- Git installed from the Debian repositories to clone this project
- A working systemd user session
- Approximately 7 GB of free space while Ghostty and Neovim are built
- `amd64` or `arm64` hardware for the complete environment. Go supports more official architectures, but the complete Ghostty/Yazi installation is limited to these two.

The project installs and configures `greetd` with the graphical `wlgreet` frontend. After reboot, authentication starts the prepared Sway session directly; no TTY command or desktop environment is required.

## Installation

```bash
sudo apt update
sudo apt install git
git clone <THIS-REPOSITORY-URL> debian-sway-dev
cd debian-sway-dev
./install.sh
```

Do not run the installer with `sudo`. It requests elevated privileges only for APT, `/usr/local`, the Brave repository, greetd configuration, and system services. Ghostty compilation, NVM, Node, Yazi, fonts, and user configuration run without elevation.

After installation:

1. Review `~/.config/sway/config.d/input.conf`. Keyboards default to US and can switch to Brazilian ABNT2.
2. Press `Super+Shift+M` to arrange monitors graphically with nwg-displays. Saved layouts and workspace assignments are restored automatically on login.
3. Zsh is set as your login shell automatically; the change takes effect at the next login.
4. Reboot the machine.
5. Enter your username and password in the Tokyo Night wlgreet screen. Sway starts automatically after authentication.

### Safety and idempotency

Every destination is compared before deployment. Identical files remain untouched. A different existing file is first copied to:

```text
~/.local/state/debian-sway-dev/backups/YYYYmmdd-HHMMSS/
```

Only then is it replaced atomically. The managed-file manifest lives at `~/.local/state/debian-sway-dev/installed-files.tsv`. The installer detects installed packages, current tool versions, and enabled services, so it is safe to run repeatedly.

Existing system-level greetd files are backed up under `/var/backups/debian-sway-dev/` before replacement. The installer enables greetd for the next boot instead of starting it immediately, preventing a second display manager from disrupting the current graphical session.

An existing Go tree is never deleted. During an upgrade, `/usr/local/go` moves to `/usr/local/go.backup.<timestamp>`.

## Project layout

```text
.
├── install.sh                  # installation orchestrator
├── configs/
│   ├── sway/config.d/          # appearance, bindings, input, output, and autostart
│   ├── waybar/                 # config.jsonc and CSS
│   ├── ghostty/                # terminal
│   ├── greetd/                 # graphical Wayland login
│   ├── mako/                   # notifications
│   ├── nvim/                   # editor and plugin configuration
│   ├── starship/               # Tokyo Night shell prompt
│   ├── tmux/                   # multiplexer
│   ├── vscode/                 # settings, keybindings, and extensions
│   ├── wofi/                   # launcher
│   └── zsh/                    # zshrc and zprofile
├── scripts/
│   ├── lib/                    # reusable installer modules
│   ├── bin/                    # helpers deployed to ~/.local/bin
│   ├── system/                 # system-level Sway session wrapper
│   └── uninstall.sh            # conservative configuration removal
├── wallpapers/                 # included Tokyo Night background
└── assets/                     # desktop integration and official APT repository definitions
```

## Installed software

Debian packages cover Sway, greetd/wlgreet, Waybar, Wofi, Mako, Zsh, fzf, zoxide, tmux, Git, lazygit, ripgrep, fd (`fdfind`), bat (`batcat`), eza, jq, btop, fastfetch, the C/C++ toolchain, Python, Thunar/GVFS, wl-clipboard, cliphist, grim/slurp/swappy, PipeWire, WirePlumber, pavucontrol, playerctl, NetworkManager with VPN plugins, Blueman, BlueZ, lxpolkit, XDG portals, UPower, power-profiles-daemon, udisks2, udiskie, brightnessctl, Papirus, and nwg-look.

The installer defines `fd` and `bat` aliases because Debian names those binaries `fdfind` and `batcat`.

### Neovim is source-only

The `neovim` Debian package is intentionally absent from the APT package list. `install.sh` explicitly calls `install_neovim_from_source`, which resolves the latest stable tag from the official `neovim/neovim` repository, clones that exact tag, builds it with `CMAKE_BUILD_TYPE=RelWithDebInfo`, verifies the resulting version, and runs the upstream `make install` target. The resulting editor is installed under `/usr/local`, which takes precedence over Debian's `/usr/bin` in the standard `PATH`.

The source build is skipped only when `/usr/local/bin/nvim` matches the latest stable tag and `~/.local/state/debian-sway-dev/neovim-source-version` confirms it was installed by this project. An older Debian package may remain on disk, but it is never selected or installed by this project.

Software outside Debian and its source:

| Software | Installation method |
|---|---|
| Brave | Official Brave APT repository |
| Bruno | Official Bruno APT repository on `amd64`; checksummed official release package on `arm64` |
| Visual Studio Code | Official Microsoft APT repository |
| DBeaver Community | Official DBeaver APT repository |
| NVM | Latest tag from the official `nvm-sh/nvm` repository |
| Node.js | Latest LTS resolved by NVM |
| Go | Official tarball from `go.dev` |
| Neovim | Latest stable Git tag built locally with the official CMake/Make procedure and installed in `/usr/local` |
| Ghostty | Pinned official `release.files.ghostty.org` tarball, built locally |
| Tokyonight GTK | Pinned commit from `Fausto-Korpsvart/Tokyonight-GTK-Theme`, installed for the current user |
| Kanagawa GTK | Pinned commit from `Fausto-Korpsvart/Kanagawa-GKT-Theme`, installed for the current user |
| Docker | Official Docker APT repository; Engine, CLI, containerd, Buildx, and Compose plugin |
| Yazi | Official `sxyazi/yazi` release binary |
| Starship | Official installer targeting `~/.local/bin` |
| JetBrainsMono Nerd Font | Official `ryanoasis/nerd-fonts` release |

The installer applies `Tokyonight-Dark` to GTK 3 and GTK 4 applications by default. The theme button in Waybar opens a Wofi selector with Tokyo Night Dark/Light and Kanagawa Wave/Lotus. A selection updates GTK, Papirus icons, Waybar, Ghostty, and every running Neovim instance; right-clicking the button quickly toggles light/dark inside the active family. Existing `light` or `dark` state files are migrated transparently to Tokyo Night. `nwg-look` remains available for later visual adjustments. The login screen, Sway, Wofi, Mako, Starship, and tmux keep their static Tokyo Night palette.

VS Code follows the system preference with `Tokyo Night Light` and `Tokyo Night Storm`. Its complete user settings and keybindings are deployed from `configs/vscode`, with the same backup and idempotency guarantees as the other managed files. The installer also reads `configs/vscode/extensions.txt` and installs every missing extension from the Visual Studio Marketplace. Existing extensions remain under VS Code's own update policy, and no Settings Sync sign-in is required.

Docker Engine starts automatically at boot. The installer adds the current user to the `docker` group and verifies Engine, Buildx, and Compose through that group. The membership is visible to normal applications after the reboot requested at the end of installation. Membership of the `docker` group grants root-level control over the machine; only trusted users should be added to it.

## Languages

- **Node.js/TypeScript:** NVM loads from `.zshrc`; the installer runs `nvm install --lts`, updates npm, enables Corepack, and makes pnpm/Yarn available.
- **Python:** `python3`, development headers, pip, venv, and pipx. pipx binaries live in `~/.local/bin`.
- **Go:** `GOROOT=/usr/local/go`, `GOPATH=~/go`, and both binary directories are added to `PATH`.

Global TypeScript packages are intentionally omitted. Prefer `corepack pnpm add -D typescript` inside each project for reproducible builds.

## Sway keybindings

`Super` means the Mod4 key.

| Keybinding | Action |
|---|---|
| `Super + F1` | Open the searchable project keybinding reference |
| `Super + Enter` | Open Ghostty |
| `Super + D` | Open Wofi |
| `Super + B` | Open Brave on Wayland |
| `Super + E` | Open Thunar |
| `Super + Shift + N` | Open the network and VPN connection editor |
| `Super + Shift + M` | Open the graphical monitor manager |
| `Super + Ctrl + arrows` | Focus the monitor in that direction |
| `Super + Ctrl + Shift + arrows` | Move the current workspace to another monitor |
| `Super + Shift + Q` | Close the focused window |
| `Super + Shift + C` | Reload Sway |
| `Super + Shift + E` | Confirm and end the session |
| `Super + Ctrl + L` | Lock the session |
| `Super + H/J/K/L` | Move focus |
| `Super + Shift + H/J/K/L` | Move the focused window |
| `Super + 1…0` | Switch to workspace 1…10 |
| `Super + Shift + 1…0` | Move a window to a workspace |
| `Super + F` | Toggle fullscreen |
| `Super + Shift + Space` | Toggle floating |
| `Super + Space` | Switch keyboard layouts on all keyboards |
| `Super + Ctrl + Space` | Switch tiled/floating focus |
| `Super + Shift + -` | Send a window to the scratchpad |
| `Super + -` | Show the scratchpad |
| `Super + R` | Enter resize mode; `Esc` exits |
| `Print` | Capture an area and copy it to the clipboard |
| `Shift + Print` | Capture the active output |
| `Super + Print` | Capture an area in Swappy |
| Media keys | Volume, mute, microphone, and playback controls |
| Brightness keys | Increase or decrease brightness by 5% |

The tmux prefix is `Ctrl+J`. Follow it with `h/j/k/l` to navigate panes, `r` to reload the configuration, or `f` to open the session selector. From the Zsh prompt, `Ctrl+F` opens the same selector directly.

### Searchable keybinding reference

Press `Super + F1` or run `keybindings` to open the complete project-defined keybinding catalog in Wofi. Search by key, action, category, or application. Selecting an entry never executes it; the menu is reference-only.

```bash
keybindings                         # Wofi in Sway, fzf in a terminal
keybindings --terminal              # force the fzf interface
keybindings --list                  # print a non-interactive list
keybindings --scope sway            # sway, tmux, or neovim only
```

The utility reads the active files under `~/.config/sway`, `~/.config/nvim`, and `~/.tmux.conf`. During project development, inspect the repository copies directly with:

```bash
scripts/bin/keybindings --root . --list
```

The catalog is generated from structured `@keybind` comments stored next to the real mappings. This keeps the documentation local to each configuration instead of maintaining a second keybinding database. Add new entries using four pipe-separated fields, with all user-facing text in English:

```text
# @keybind sway|Category|Super+Key|Action description
```

Only mappings explicitly defined by this project are included. Built-in application shortcuts and plugin defaults remain in their respective application documentation.

### Per-device keyboard layouts

The built-in `AT Translated Set 2 keyboard` starts in US, while `splitkb.com Elora` and `splitkb.com Elora Keyboard` start in Brazilian ABNT2. Both devices retain US and Brazilian ABNT2 as selectable layouts, so `Super + Space` switches them while preserving their opposite defaults.

`sway-keyboard-layout watch` starts with the session, configures keyboards already connected, and listens for Sway input events so an Elora connected later is configured automatically. It matches the human-readable device name instead of a vendor/product identifier, which can vary with firmware. Inspect the names detected by Sway with:

```bash
swaymsg -t get_inputs | jq '.[] | select(.type == "keyboard") | {identifier, name}'
```

If the reported Elora name differs, update `ELORA_KEYBOARD_NAME` in `~/.local/bin/sway-keyboard-layout` and its source file under `scripts/bin/`.

## Wi-Fi ownership

The installer explicitly installs the NetworkManager Wi-Fi backend and its diagnostic tools, then starts the global `wpa_supplicant.service` before NetworkManager. If `wlp1s0` is already managed by NetworkManager, no network configuration is changed.

If Debian's existing `ifupdown` configuration leaves `wlp1s0` as `unmanaged`, the installer runs the guarded migration script at the end of installation, after all downloads have completed. The migration:

- inspects the effective configuration without displaying passwords or PSKs;
- creates metadata-preserving backups under `/var/backups`;
- stops before any network interruption and requires the explicit confirmation `MIGRAR`;
- removes only `wlp1s0` from `ifupdown`, preserving loopback and unrelated interfaces;
- keeps the global `wpa_supplicant.service` and lets NetworkManager provide Wi-Fi, DHCP, routes, and DNS;
- uses `nmcli --ask` if a Wi-Fi password must be entered again;
- automatically rolls back if NetworkManager cannot take ownership of the interface.

The migration refuses to run while the `Domatica` VPN is active. It never modifies that VPN profile and verifies its file checksum and metadata before and after the operation.

To inspect the migration independently without changing the system:

```bash
sudo ./scripts/system/migrate-wlp1s0-to-networkmanager.sh --inspect
```

## VPN support

VPN connections are managed by NetworkManager and appear in `nm-applet` in the Waybar tray. Press `Super + Shift + N` to create, import, or edit a connection graphically. The installer adds official Debian plugins and clients for:

| VPN type | NetworkManager support |
|---|---|
| OpenVPN | OpenVPN plugin and `.ovpn` import |
| Cisco AnyConnect / Meraki AnyConnect | OpenConnect plugin |
| Meraki Client VPN | L2TP over IPsec and IKEv2/IPsec plugins |
| WireGuard | Native NetworkManager support and `wireguard-tools` |
| Cisco IPsec/XAuth | VPNC plugin |
| Microsoft SSTP | SSTP plugin |

Import OpenVPN and WireGuard profiles from the terminal with:

```bash
nmcli connection import type openvpn file company.ovpn
nmcli connection import type wireguard file company.conf
```

List, connect, and disconnect configured VPNs without exposing credentials on the command line:

```bash
nmcli connection show
nmcli connection up id "Company VPN" --ask
nmcli connection down id "Company VPN"
```

For a traditional Meraki Client VPN, create an L2TP connection and enter the gateway, user credentials, and IPsec pre-shared key supplied by the administrator. For a Meraki AnyConnect endpoint, create an OpenConnect connection using the AnyConnect protocol and the provided hostname. Some corporate deployments that require Cisco posture or proprietary modules may still require the licensed Cisco Secure Client supplied by the organization.

No VPN profile, certificate, password, or pre-shared key is included in this repository. NetworkManager stores imported profiles outside the project and requests secrets through its authentication agent.

## Updating

```bash
git pull --ff-only
./install.sh
```

This reapplies the current project configuration, installs missing external tools, and rebuilds Neovim when a newer stable upstream release is available. Update Debian packages separately:

```bash
sudo apt update
sudo apt full-upgrade
```

The installer deliberately does not run `full-upgrade`, leaving that system-level decision under user control.

## Removal

Remove only managed files that still match the project copies:

```bash
./scripts/uninstall.sh
```

User-modified files remain in place. Backups, packages, external tools, and VS Code extensions are also preserved deliberately so they can be reviewed before manual removal.

To remove the main Debian packages, inspect the simulation first and tailor the list to your system:

```bash
sudo apt-get --simulate remove \
  greetd wlgreet sway waybar wofi mako-notifier brave-browser bruno code dbeaver-ce \
  network-manager-openvpn-gnome network-manager-openconnect-gnome \
  network-manager-l2tp-gnome network-manager-strongswan \
  network-manager-vpnc-gnome network-manager-sstp-gnome wireguard-tools
```

The locally built Ghostty is not an APT package; its files are under `~/.local`. Source-built Neovim is installed under `/usr/local/bin/nvim` and `/usr/local/share/nvim`. NVM/Node live under `~/.nvm`, Yazi/Starship under `~/.local/bin`, the Nerd Font under `~/.local/share/fonts/JetBrainsMonoNerd`, and backups under `~/.local/state/debian-sway-dev`.

## Diagnostics

```bash
bash -n install.sh scripts/lib/*.sh scripts/bin/* scripts/system/migrate-wlp1s0-to-networkmanager.sh scripts/uninstall.sh
sh -n scripts/system/debian-sway-session
scripts/bin/keybindings --root . --list
sway --validate --config ~/.config/sway/config
jq empty ~/.config/waybar/config.jsonc
command -v nvim                    # expected: /usr/local/bin/nvim
nvim --version | head -n 1
journalctl --user -b --unit pipewire --unit wireplumber
systemctl status NetworkManager bluetooth power-profiles-daemon
nmcli connection show
systemctl status greetd
```

If screen sharing does not appear in an application, fully close that application after starting Sway and verify the portal with `systemctl --user status xdg-desktop-portal-wlr`.

## Official references

- [Debian 13 trixie](https://www.debian.org/releases/trixie/)
- [greetd manual](https://manpages.debian.org/trixie/greetd/greetd.1.en.html)
- [Debian wlgreet package](https://packages.debian.org/trixie/wlgreet)
- [Debian NetworkManager OpenVPN plugin](https://packages.debian.org/trixie/network-manager-openvpn-gnome)
- [Debian NetworkManager OpenConnect plugin](https://packages.debian.org/trixie/network-manager-openconnect-gnome)
- [Debian NetworkManager L2TP plugin](https://packages.debian.org/trixie/network-manager-l2tp-gnome)
- [Cisco Meraki Client VPN overview](https://documentation.meraki.com/SASE_and_SD-WAN/MX/Design_and_Configure/Configuration_Guides/Client_VPN/Client_VPN_Overview)
- [Installing Brave on Linux](https://brave.com/linux/)
- [Installing Bruno](https://docs.usebruno.com/v2/get-started/bruno-basics/download)
- [Installing Visual Studio Code on Linux](https://code.visualstudio.com/docs/setup/linux)
- [Downloading DBeaver Community](https://dbeaver.io/download/)
- [NVM](https://github.com/nvm-sh/nvm)
- [Official Go installation](https://go.dev/doc/install)
- [Building Neovim](https://neovim.io/doc/build/)
- [Building and installing Ghostty](https://ghostty.org/docs/install/build)
- [Installing Yazi](https://yazi-rs.github.io/docs/installation/)
- [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts)
