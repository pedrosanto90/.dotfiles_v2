# Debian Sway Dev

A complete, minimalist, keyboard-first development environment for **Debian 13 Stable (trixie)**. It provides a coherent Wayland session without a full desktop environment and preserves every pre-existing user configuration through automatic backups.

> The installer supports the current Debian Stable release only: Debian 13. Do not run it on Ubuntu, derivatives, Debian testing/unstable, or older Debian releases.

## Features

- Modular Sway configuration with Quickshell, Wofi, Mako, locking, and idle handling
- Illustrated Quickshell tiling selector with seven workspace presets and automatic alternating splits
- Automatic monitor arrangement and workspace binding for laptop, dual, and triple setups
- Native Wayland graphical login through greetd and wlgreet
- Ghostty built from the official release tarball when unavailable in Debian
- Framework-free Zsh with Starship, fzf, zoxide, GitHub CLI, and a small alias set
- Latest stable Neovim built from official source, with modular Tokyo Night and Kanagawa themes
- Docker Engine with CLI, Buildx, and Compose; no Docker Desktop and no `sudo` for daily use
- Node.js LTS through NVM, npm, Corepack, pnpm, and Yarn
- Codex CLI (OpenAI) through npm and opencode through its official installer
- Official stable Go toolchain and Python with venv, pip, pipx, and uv
- PipeWire/WirePlumber, NetworkManager, multi-protocol VPN support, Bluetooth, and PolicyKit
- Wayland portals for screen sharing, Flatpak, and Electron applications
- Brave exclusively from its official repository, launched through Ozone/Wayland
- Brave PWAs for Webex, Excalidraw, WhatsApp, Amália, Notion, Telegram, Spotify, and ChatGPT
- Bruno REST client, Slack, Discord, VSCodium, and DBeaver Community from official distribution channels
- Evolution mail, calendar, contacts, and groupware
- Repository-managed VSCodium settings, keybindings, and extension inventory
- Thunar, Yazi, Gwenview/Zathura image and PDF viewing, persistent clipboard history, screenshots, and USB automounting
- Searchable Sway, tmux, and Neovim keybinding reference
- Tokyo Night and Kanagawa palettes, Papirus icons, and JetBrainsMono Nerd Font
- Synchronized light/dark theme families for GTK, Quickshell, Ghostty, and Neovim
- Pomodoro timer in the Quickshell bar with a GTK4 menu (spinners for the durations), and actionable Mako notifications
- Clipboard history for text and images, available from the Quickshell bar through Wofi

## Requirements

- An updated Debian 13 Stable (`trixie`) installation
- A regular user with `sudo` access
- An Internet connection
- Git installed from the Debian repositories to clone this project
- A working systemd user session
- Approximately 7 GB of free space while Ghostty and Neovim are built
- `amd64` or `arm64` hardware for the complete environment. Go supports more official architectures, but the complete Ghostty/Yazi installation is limited to these two.

On a machine without a display manager, the project installs and configures `greetd` with the graphical `wlgreet` frontend. After reboot, authentication starts the prepared Sway session directly; no TTY command or desktop environment is required. If a different display manager is already selected, such as GNOME's GDM, the installer preserves it and skips the `greetd` and `wlgreet` packages and configuration. Select Sway from the existing login screen when you want to test it.

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
2. Connect your monitors: `sway-displays` arranges them and binds workspaces automatically for the laptop, dual, and triple setups (see [Display modes](#display-modes)). `Super+Shift+M` still opens nwg-displays for ad-hoc tweaks.
3. Zsh is set as your login shell automatically; the change takes effect at the next login.
4. Reboot the machine.
5. Enter your username and password in the Tokyo Night wlgreet screen. If the installer preserved an existing display manager, select Sway from its session menu first.

### Safety and idempotency

Every destination is compared before deployment. Identical files remain untouched. A different existing file is first copied to:

```text
~/.local/state/debian-sway-dev/backups/YYYYmmdd-HHMMSS/
```

Only then is it replaced atomically. The managed-file manifest lives at `~/.local/state/debian-sway-dev/installed-files.tsv`. The installer detects installed packages, current tool versions, and enabled services, so it is safe to run repeatedly.

If no display manager is selected, existing system-level greetd files are backed up under `/var/backups/debian-sway-dev/` before replacement. The installer enables greetd for the next boot instead of starting it immediately. When `display-manager.service` already points to another manager (for example, `gdm3`), that manager is left untouched and greetd/wlgreet are not installed or configured.

An existing Go tree is never deleted. During an upgrade, `/usr/local/go` moves to `/usr/local/go.backup.<timestamp>`.

## Project layout

```text
.
├── install.sh                  # installation orchestrator
├── configs/
│   ├── sway/config.d/          # appearance, bindings, input, output, and autostart
│   ├── waybar/                 # config.jsonc and CSS
│   ├── quickshell/              # control center, OSD, and desktop shell components
│   ├── debian-sway-dev/theme/   # desktop-neutral theme palettes
│   ├── ghostty/                # terminal
│   ├── greetd/                 # graphical Wayland login
│   ├── mako/                   # notifications
│   ├── nvim/                   # editor and plugin configuration
│   ├── starship/               # Tokyo Night shell prompt
│   ├── tmux/                   # multiplexer
│   ├── vscodium/               # settings, keybindings, and extensions
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

Debian packages cover Sway, greetd/wlgreet, Waybar, Wofi, Mako, Zsh, fzf, zoxide, tmux, Git, lazygit, ripgrep, fd (`fdfind`), bat (`batcat`), eza, jq, btop, fastfetch, the C/C++ toolchain, Python, Thunar/GVFS, Evolution, Gwenview, Zathura, wl-clipboard, cliphist, grim/slurp/swappy, PipeWire, WirePlumber, pavucontrol, playerctl, NetworkManager with VPN plugins, Blueman, BlueZ, rfkill, lxpolkit, XDG portals, UPower, power-profiles-daemon, udisks2, udiskie, brightnessctl, Papirus, and nwg-look.

### Image and PDF viewing

Images open in **Gwenview**, a conventional image viewer with broad format support, printing with fit-to-page controls, and direct annotation tools for freehand strokes, lines, arrows, rectangles, ellipses, text, and custom colours. PDF files open in the keyboard-friendly **Zathura** viewer. **Swappy** remains available for annotating screenshots.

The installer defines `fd` and `bat` aliases because Debian names those binaries `fdfind` and `batcat`.

### Neovim is source-only

The `neovim` Debian package is intentionally absent from the APT package list. `install.sh` explicitly calls `install_neovim_from_source`, which resolves the latest stable tag from the official `neovim/neovim` repository, clones that exact tag, builds it with `CMAKE_BUILD_TYPE=RelWithDebInfo`, verifies the resulting version, and runs the upstream `make install` target. The resulting editor is installed under `/usr/local`, which takes precedence over Debian's `/usr/bin` in the standard `PATH`.

The source build is skipped only when `/usr/local/bin/nvim` matches the latest stable tag and `~/.local/state/debian-sway-dev/neovim-source-version` confirms it was installed by this project. An older Debian package may remain on disk, but it is never selected or installed by this project.

Software outside Debian and its source:

| Software | Installation method |
|---|---|
| Brave | Official Brave APT repository |
| Google Chrome | Official stable Google `.deb` package on `amd64` and `arm64`, for Flutter web development |
| Bruno | Official Bruno APT repository on `amd64`; checksummed official release package on `arm64` |
| Slack | Official Slack `.deb` release package on `amd64`; obsolete Jessie PackageCloud source disabled |
| Discord | Official stable Discord `.deb` release package on `amd64` |
| VSCodium | Officially documented VSCodium APT repository |
| DBeaver Community | Official DBeaver APT repository |
| NVM | Latest tag from the official `nvm-sh/nvm` repository |
| Node.js | Latest LTS resolved by NVM |
| Codex CLI | `@openai/codex` globally through npm |
| opencode | Official installer script, binary in `~/.local/bin` |
| Go | Official tarball from `go.dev` |
| Neovim | Latest stable Git tag built locally with the official CMake/Make procedure and installed in `/usr/local` |
| Ghostty | Pinned official `release.files.ghostty.org` tarball, built locally |
| Tokyonight GTK | Pinned commit from `Fausto-Korpsvart/Tokyonight-GTK-Theme`, installed for the current user |
| Kanagawa GTK | Pinned commit from `Fausto-Korpsvart/Kanagawa-GKT-Theme`, installed for the current user |
| Docker | Official Docker APT repository; Engine, CLI, containerd, Buildx, and Compose plugin |
| Yazi | Official `sxyazi/yazi` release binary |
| Starship | Official installer targeting `~/.local/bin` |
| uv | Official Astral installer targeting `~/.local/bin` |
| JetBrainsMono Nerd Font | Official `ryanoasis/nerd-fonts` release |

The installer deploys `/etc/brave/policies/managed/debian-sway-dev-pwas.json` through `scripts/system/install-brave-pwas.sh`. Brave then installs Webex, Excalidraw, WhatsApp Web, Amália, Notion, Telegram Web, Spotify, and ChatGPT as windowed PWAs for each Brave profile. ChatGPT is not installed as a native Debian package. Restart Brave after the first installation so it can process the policy and create the application launchers.

Because these are force-installed browser applications, Brave keeps them synchronized with the policy and does not offer an uninstall button for them. Remove the policy file first if the PWAs should later be removed through Brave.

Google Chrome is also installed so Flutter can detect and launch a supported web-development browser. Brave remains the system default for HTTP, HTTPS, and HTML links.

The installer applies `Tokyonight-Dark` to GTK 3 and GTK 4 applications by default. The theme button in Waybar opens a Wofi selector with Tokyo Night Dark/Light, Kanagawa Wave/Lotus, Rosé Pine, Everforest Dark/Light, Catppuccin Mocha/Latte, Gruvbox Dark/Light, and Nightfox. A selection updates GTK, Papirus icons, Waybar, Ghostty, tmux, VSCodium, and every running Neovim instance. Right-clicking the button quickly toggles light/dark inside families that provide both modes; dark-only families remain dark. Existing `light` or `dark` state files are migrated transparently to Tokyo Night. `nwg-look` remains available for later visual adjustments. The login screen, Sway, Wofi, Mako, and Starship keep their static Tokyo Night palette.

After updating the repository, rerun `./install.sh` to install the added GTK themes, deploy the palettes, and install editor extensions. You can also select the new variants with `theme-toggle catppuccin-light`, `theme-toggle gruvbox-dark`, or `theme-toggle gruvbox-light`.

The theme selector writes the matching theme directly to VSCodium, so family and mode changes remain reliable under Sway even when automatic desktop-theme detection is unavailable. Only Tokyo Night's dark variants enforce a black application background; every other family keeps its original palette. Its user settings and keybindings are deployed from `configs/vscodium`, with the same backup and idempotency guarantees as the other managed files. The installer reads `configs/vscodium/extensions.txt` and installs every missing extension from Open VSX. Extensions unavailable from Open VSX are reported without aborting the rest of the installation. Some proprietary Microsoft extensions can reject non-Microsoft builds at runtime, even when already present locally. The shell aliases `code` to `codium`, so existing terminal habits continue to work without installing Visual Studio Code. No Settings Sync sign-in is required.

Docker Engine starts automatically at boot. The installer adds the current user to the `docker` group and verifies Engine, Buildx, and Compose through that group. The membership is visible to normal applications after the reboot requested at the end of installation. Membership of the `docker` group grants root-level control over the machine; only trusted users should be added to it.

## Languages

- **Node.js/TypeScript:** NVM loads from `.zshrc`; the installer runs `nvm install --lts`, updates npm, enables Corepack, and makes pnpm/Yarn available.
- **Python:** `python3`, development headers, pip, venv, pipx, and uv. uv and uvx are installed in `~/.local/bin`, alongside pipx binaries. Existing uv installations are preserved; update standalone installations with `uv self update`.
- **Go:** `GOROOT=/usr/local/go`, `GOPATH=~/go`, and both binary directories are added to `PATH`.

Global TypeScript packages are intentionally omitted, with the exception of the Codex CLI installed through npm. Prefer `corepack pnpm add -D typescript` inside each project for reproducible builds.

## Sway keybindings

`Super` means the Mod4 key.

| Keybinding | Action |
|---|---|
| `Super + F1` | Open the searchable project keybinding reference |
| `Super + Enter` | Open Ghostty |
| `Super + D` | Open the Quickshell application launcher |
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
| `Super + P` | Open the Pomodoro menu |
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

The tmux prefix is `Ctrl+J`. Follow it with `h/j/k/l` to navigate panes, `r` to reload the configuration, or `f` to open the session selector. Its status bar, messages, selection mode, window states, and pane borders follow the active system palette automatically. From the Zsh prompt, `Ctrl+F` opens the same selector directly.

### Quickshell Control Center

The optional Quickshell Control Center runs alongside Waybar and Mako. Click its
dedicated sliders icon near the power button or press `Super+Ctrl+M` to open it;
close it with the Close button or `Escape` while it has focus. The Waybar volume
module is a read-only indicator: clicking or scrolling it has no effect.

The Control Center starts with compact controls for Wi-Fi, Bluetooth,
notifications, caffeine, battery power profiles, and the default audio output.
Its sound and media section controls the default PipeWire output and microphone,
the laptop backlight, and MPRIS players (including supported browser media
sessions). With multiple players, use the selector to choose which one the panel
and media keys control. Playback and seeking controls follow each player's
reported capabilities. Detailed device management and advanced mixing remain
available through the existing popups and Pavucontrol. Do not disturb hides
normal notifications while leaving urgent notifications visible.

Volume, microphone mute and brightness keys display a short, non-focus-stealing
OSD on the focused Sway monitor. Volume increases are capped at 100%; brightness
decreases keep at least one hardware step. Brightness uses the `backlight` class,
not keyboard LEDs, and does not implement DDC/CI for external displays. Audio and
media events come from PipeWire/MPRIS; brightness is refreshed only while the
panel is open or a brightness OSD is requested. Colours follow the active Waybar
palette, including changes made by `theme-toggle`.

If brightness changes fail with `Permission denied`, check that `brightness-udev`
is installed and your session belongs to the `video` group (`id -nG`). Debian
ships the permissions separately from `brightnessctl`; this project explicitly
installs both because APT recommendations are disabled. To repair an existing
installation without running the full installer:

```bash
sudo apt-get install brightness-udev
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=backlight --action=add
sudo udevadm settle
brightnessctl --class=backlight set +5%
```

If the user is not in `video`, an administrator must add them with
`sudo usermod -aG video "$USER"`, followed by a full logout/login. The udev rule
allows the group to write the brightness attribute and reapplies on boot; no
world-writable sysfs permissions or privileged Quickshell process are needed.

Quickshell is not in this project's Debian 13 APT package list. The separate,
user-local installer below pins Quickshell **0.3.1.db3** and libcpptrace from the
Debian 13 OBS repository linked by the
[upstream installation guide](https://quickshell.org/docs/v0.3.0/guide/install-setup/).
It verifies pinned SHA-256 hashes, extracts packages under
`~/.local/opt/quickshell-0.3.1.db3`, and downloads libdwarf/libunwind through APT.
It supports Debian 13 **amd64**, requires the system Qt 6.8.2 runtime, and neither
uses sudo nor adds an APT repository. Existing machines also need the QtQuick QML
modules listed in `scripts/lib/packages.sh`; the general installer installs those
modules but does not run this separate Quickshell installer.

```bash
python3 scripts/system/install-quickshell-local.py
# After deploying configs/quickshell to ~/.config/quickshell and control-center
# to ~/.local/bin (or after the normal dotfiles deployment):
~/.local/bin/control-center start
~/.local/bin/control-center panel
```

`control-center` keeps hardware keys working through `wpctl`, `brightnessctl` and
`playerctl` when Quickshell is unavailable. Opening the Control Center starts the
shell if needed and falls back to Pavucontrol if startup fails. Sway reloads use
`--no-duplicate` so they do not create extra shell instances.

To stop this shell without affecting the other desktop components:

```bash
quickshell kill -p ~/.config/quickshell/control-center/shell.qml
```

Remove the `control-center start` line from Sway's autostart configuration to keep
it stopped across reloads/logins. Opening the panel explicitly starts it again.

Run the hardware-independent routing and theme-palette checks with
`python3 -B -m unittest discover -s tests`.

The active desktop palette lives at
`~/.config/debian-sway-dev/theme/current.json`. Quickshell watches this neutral
palette directly. `theme-toggle` still maintains the legacy Waybar `colors.css`
files as a compatibility source for tmux and the tiling selector; it does not
start a Waybar process. It also generates a matching `btop` theme and asks any
running `btop` instance to reload when the desktop theme changes.

The Quickshell bar runs at the top of every screen and reserves 30 pixels of
workspace. It includes Sway workspaces, clock, a combined CPU/memory/disk monitor,
calendar, audio, battery, system tray, Pomodoro,
tiling layout, clipboard history, theme, caffeine, Control Center, and power
controls. Audio, network, Bluetooth, and battery icons open click-only popups;
only one popup is shown at a time, and it closes with `Escape` or a click outside.
Advanced network, Bluetooth, and audio configuration remains available from the
corresponding popup. The network popup combines Wi-Fi and VPN management:
configured NetworkManager VPN and WireGuard profiles can be connected,
disconnected, or edited directly, and new profiles can be created or imported
through NetworkManager's connection editor. The battery popup shows the charge
level and remaining time and switches the system power profile (power saver,
balanced, performance) through power-profiles-daemon; the active profile also
appears in the battery tooltip. The bar is visible when the shell starts. Show,
hide, or toggle it through the shell IPC:

The calendar icon at the right edge of the bar, beside the power button, opens a local monthly calendar. Select a day
to add, edit, or remove timed events and choose an alert from the available
reminder intervals. Events are stored only in
`~/.local/share/debian-sway-dev/calendar/events.json`. The
`local-calendar-alerts.timer` user unit checks once per minute and delivers due
reminders through the desktop notification service with an audible alert. The
Control Center also shows up to three events scheduled for today and links to
the full calendar. Clicking the clock itself
continues to switch between the time and full date.

Caffeine stops the idle daemon while active and starts a fresh instance when
disabled. Restarting the daemon resets its timers, so leaving caffeine mode does
not immediately lock or suspend the session because of accumulated idle time.

Hover over the system monitor icon to see current CPU, memory, and root filesystem
usage in a compact informational panel. The panel stays open while the pointer is
over either the icon or the panel and does not take keyboard focus. Click the icon
to open `btop` (or `htop` as a fallback) in a centered floating Ghostty window.

```bash
quickshell ipc -p ~/.config/quickshell/control-center/shell.qml call -- shell showBar
quickshell ipc -p ~/.config/quickshell/control-center/shell.qml call -- shell hideBar
quickshell ipc -p ~/.config/quickshell/control-center/shell.qml call -- shell toggleBar
```

`Super+D` opens the native application launcher. Type to search desktop entries,
use the arrow keys to change selection, and press `Enter` to launch or `Escape`
to close it. If the Quickshell instance is unavailable, the launcher wrapper
falls back to Wofi.

The clipboard icon opens a native searchable history backed by `cliphist`.
Select an entry with the mouse or keyboard to restore it through `wl-copy`.
Running `clipboard-history` opens the same popup and falls back to Wofi when the
Quickshell instance is unavailable.

The theme icon opens a native searchable selector and marks the active palette.
Right-clicking the icon, or using the button in the selector, toggles the current
theme family between light and dark when both variants exist. `theme-toggle menu`
opens the same popup and retains Wofi as a fallback.

The Pomodoro indicator opens a native timer panel with contextual start, pause,
resume, skip, and stop controls, plus editable focus and break durations.
Right-clicking the indicator performs the quick start/pause/resume action.
`Super+P` or `pomodoro menu` opens the same panel and retains the GTK dialog as a
fallback when Quickshell is unavailable.

The power icon opens a native keyboard-accessible menu. Lock and suspend run
immediately; reboot and power-off require a separate confirmation step.
`power-menu` opens the same popup and retains Wofi as a fallback when Quickshell
is unavailable.

### Automatic window tiling

Click the layout icon in the Quickshell bar to open a native two-column picker with live QML previews. Select a preset to immediately arrange the current workspace. Each workspace remembers its own choice across sessions; new windows, closed windows, and windows moved between workspaces update the selected grid automatically. Running `sway-layout menu` opens the same popover and falls back to the illustrated Wofi picker when Quickshell is unavailable.

| Preset (columns × rows) | Reference window count |
| --- | --- |
| 2 × 1 | 2 |
| 3 × 1 | 3 |
| 2 × 2 | 4 |
| 1 + 4: main window on the left, four on the right | 5 |
| 3 × 2 | 6 |
| 2 × 3 | 6 |
| 4 × 2 | 8 |

Window counts are examples, not limits: fewer windows expand to use the available space; additional windows add rows to the selected columns. The main-window preset keeps the first window on the left and distributes the rest vertically on the right. Previews number windows in opening order and follow the active Waybar palette.

The **Alternado** option preserves the original default: the second window opens to the right of the first, the third below the second, the fourth to the right of the third, and so on. Each new window subdivides the last tile, even when another window is focused.

Floating and scratchpad windows are excluded. Manually selected tabbed/stacking layouts are left alone until a preset is chosen again. `sway-autotiling` starts with Sway and prevents duplicate listeners on reload. The layout backend uses Python's `i3ipc` package; Wofi and SVG support remain available only for the fallback picker. Choices are stored in `~/.local/state/debian-sway-dev/tiling.json`.

```bash
sway-layout menu              # illustrated picker
sway-layout apply 2x2         # select and apply to the current workspace
sway-layout apply alternate   # restore alternating splits
sway-layout status            # Waybar JSON status
```

### Searchable keybinding reference

Press `Super + F1` or run `keybindings` to open the complete project-defined
keybinding catalog in a centered Quickshell panel. Search by key, action,
category, or application; use `--scope` to open only Sway, tmux, or Neovim entries.
Selecting an entry never executes it; the panel is reference-only. Wofi remains
available as a fallback when Quickshell is unavailable.

```bash
keybindings                         # Quickshell in Sway, Wofi as fallback
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

### Display modes

`sway-displays watch` starts with the session, positions the connected monitors,
and binds workspaces according to the current setup. It reacts to output
plug/unplug events, so the layout is applied automatically when a monitor is
connected or removed. Three setups are handled:

| Setup | Arrangement | Primary | Workspaces 1–5 | Workspace 10 |
| --- | --- | --- | --- | --- |
| Laptop only | eDP-1 | eDP-1 | eDP-1 | eDP-1 |
| Laptop + one external | eDP-1 left, external right | external (DP-1 or HDMI-A-1) | primary | eDP-1 |
| Laptop + DP-1 + HDMI-A-1 | HDMI-A-1 left, DP-1 center, eDP-1 right | DP-1 | DP-1 | eDP-1 |

Workspaces 6–9 and any others are left unbound: they open on whichever output
is focused. Monitor positions are computed from the actual mode widths, so the
arrangement adapts to different resolutions and scales.

Inspect the plan currently in effect:

```bash
sway-displays status        # JSON: mode, primary, positions, bindings
sway-displays apply         # re-apply the layout now
```

`Super + Shift + M` still opens `nwg-displays` for ad-hoc mode, scale, or
rotation tweaks; the next output event re-asserts the managed layout.

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

VPN connections are managed by NetworkManager. Open the network popup from the Quickshell bar to connect or disconnect a configured VPN; press `Super + Shift + N` to create, import, or edit a connection graphically. The `network-vpn` helper backs the popup: `network-vpn list` prints the VPN and WireGuard profiles as JSON, and `network-vpn up|down|add|import|edit` performs the matching action. The installer adds official Debian plugins and clients for:

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

User-modified files remain in place. Backups, packages, external tools, and VSCodium extensions are also preserved deliberately so they can be reviewed before manual removal.

To remove the main Debian packages, inspect the simulation first and tailor the list to your system:

```bash
sudo apt-get --simulate remove \
  greetd wlgreet sway waybar wofi mako-notifier brave-browser bruno discord codium dbeaver-ce evolution \
  network-manager-openvpn-gnome network-manager-openconnect-gnome \
  network-manager-l2tp-gnome network-manager-strongswan \
  network-manager-vpnc-gnome network-manager-sstp-gnome wireguard-tools
```

The locally built Ghostty is not an APT package; its files are under `~/.local`. Source-built Neovim is installed under `/usr/local/bin/nvim` and `/usr/local/share/nvim`. NVM/Node live under `~/.nvm`, Yazi/Starship under `~/.local/bin`, the Nerd Font under `~/.local/share/fonts/JetBrainsMonoNerd`, and backups under `~/.local/state/debian-sway-dev`. A `Yazi` entry in the applications menu (Wofi) opens a new Ghostty window running Yazi; its desktop file lives at `~/.local/share/applications/yazi.desktop`. The Brave PWA policy remains under `/etc/brave/policies/managed/debian-sway-dev-pwas.json` for separate review and removal.

## Diagnostics

```bash
bash -n install.sh scripts/lib/*.sh scripts/bin/* scripts/system/install-brave-pwas.sh scripts/system/migrate-wlp1s0-to-networkmanager.sh scripts/uninstall.sh
sh -n scripts/system/debian-sway-session
scripts/bin/keybindings --root . --list
sway --validate --config ~/.config/sway/config
jq empty ~/.config/waybar/config.jsonc
python3 -B -m unittest discover -s tests
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
- [Downloading Slack for Linux](https://slack.com/downloads/linux)
- [Downloading Discord for Linux](https://discord.com/download)
- [Installing VSCodium](https://vscodium.com/install)
- [Downloading DBeaver Community](https://dbeaver.io/download/)
- [NVM](https://github.com/nvm-sh/nvm)
- [Official Go installation](https://go.dev/doc/install)
- [Installing uv](https://docs.astral.sh/uv/getting-started/installation/)
- [Building Neovim](https://neovim.io/doc/build/)
- [Building and installing Ghostty](https://ghostty.org/docs/install/build)
- [Installing Yazi](https://yazi-rs.github.io/docs/installation/)
- [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts)
