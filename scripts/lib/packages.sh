#!/usr/bin/env bash

readonly DEBIAN_PACKAGES=(
  sway swaybg swayidle swaylock waybar wofi nwg-displays mako-notifier greetd wlgreet
  zsh fzf zoxide tmux
  git lazygit curl wget unzip zip jq ripgrep fd-find bat eza tree htop btop file fastfetch
  openssh-client build-essential pkg-config cmake make ninja-build gettext xz-utils
  python3 python3-pip python3-venv python3-dev pipx
  thunar thunar-archive-plugin gvfs gvfs-backends evolution
  wl-clipboard cliphist grim slurp swappy
  pipewire pipewire-pulse wireplumber libspa-0.2-bluetooth pavucontrol playerctl
  network-manager network-manager-gnome nm-connection-editor
  wpasupplicant iw iproute2 iputils-ping
  network-manager-openvpn-gnome openvpn
  network-manager-openconnect-gnome openconnect
  network-manager-l2tp-gnome network-manager-strongswan
  network-manager-vpnc-gnome network-manager-sstp-gnome wireguard-tools
  bluez blueman
  polkitd pkexec lxpolkit
  xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk xdg-utils desktop-file-utils
  upower power-profiles-daemon udisks2 udiskie brightnessctl
  papirus-icon-theme nwg-look fontconfig libnotify-bin
  sassc gtk2-engines-murrine gnome-themes-extra
  libgtk-4-dev libgtk4-layer-shell-dev libadwaita-1-dev libxml2-utils
  ca-certificates gnupg util-linux procps dbus-user-session libpam-systemd
  tree-sitter-cli
)

apt_update_once() {
  (( APT_UPDATED == 1 )) && return
  "${SUDO[@]}" apt-get update
  APT_UPDATED=1
}

install_debian_packages() {
  local package
  local -a missing=()
  apt_update_once
  for package in "${DEBIAN_PACKAGES[@]}"; do
    if dpkg-query -W -f='${db:Status-Abbrev}' "${package}" 2>/dev/null | grep -q '^ii '; then
      continue
    fi
    if apt-cache show "${package}" >/dev/null 2>&1; then
      missing+=("${package}")
    else
      die "Required package is missing from Debian Stable repositories: ${package}"
    fi
  done
  if ((${#missing[@]})); then
    log_info "Installing ${#missing[@]} missing Debian packages."
    "${SUDO[@]}" apt-get install --no-install-recommends --yes "${missing[@]}"
  else
    log_info "All Debian packages are already installed."
  fi
}
