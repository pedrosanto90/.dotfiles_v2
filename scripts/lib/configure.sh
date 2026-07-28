#!/usr/bin/env bash

deploy_tree() {
  local source_root=$1 destination_root=$2 source relative mode
  while IFS= read -r -d '' source; do
    relative=${source#"${source_root}"/}
    mode=0644
    [[ -x ${source} ]] && mode=0755
    deploy_file "${source}" "${destination_root}/${relative}" "${mode}"
  done < <(find "${source_root}" -type f -print0 | sort -z)
}

deploy_configs() {
  local directory
  for directory in sway waybar mako ghostty wofi nvim gtk-3.0 gtk-4.0; do
    deploy_tree "${PROJECT_ROOT}/configs/${directory}" "${HOME}/.config/${directory}"
  done
  deploy_file "${PROJECT_ROOT}/configs/tmux/tmux.conf" "${HOME}/.tmux.conf"
  deploy_file "${PROJECT_ROOT}/configs/starship/starship.toml" "${HOME}/.config/starship.toml"
  deploy_file "${PROJECT_ROOT}/configs/code-flags.conf" "${HOME}/.config/code-flags.conf"
  deploy_file "${PROJECT_ROOT}/configs/zsh/zshrc" "${HOME}/.zshrc"
  deploy_file "${PROJECT_ROOT}/configs/zsh/zprofile" "${HOME}/.zprofile"
  deploy_tree "${PROJECT_ROOT}/scripts/bin" "${HOME}/.local/bin"
  deploy_tree "${PROJECT_ROOT}/wallpapers" "${HOME}/.local/share/wallpapers/debian-sway-dev"
  deploy_file "${PROJECT_ROOT}/assets/brave-browser.desktop" "${HOME}/.local/share/applications/brave-browser.desktop"
}

configure_login_manager() {
  log_info "Configuring the native Wayland graphical login manager (greetd + wlgreet)."
  sudo_deploy_config "${PROJECT_ROOT}/configs/greetd/config.toml" /etc/greetd/config.toml
  sudo_deploy_config "${PROJECT_ROOT}/configs/greetd/sway-config" /etc/greetd/sway-config
  sudo_deploy_config "${PROJECT_ROOT}/configs/greetd/wlgreet.toml" /etc/greetd/wlgreet.toml
  sudo_deploy_config "${PROJECT_ROOT}/scripts/system/debian-sway-session" \
    /usr/local/bin/debian-sway-session 0755

  # Do not start a second display manager inside the current graphical session.
  # --force updates display-manager.service if another manager owned the alias.
  "${SUDO[@]}" systemctl enable --force greetd.service
  "${SUDO[@]}" systemctl set-default graphical.target
}

configure_browser() {
  if command -v xdg-settings >/dev/null 2>&1; then
    xdg-settings set default-web-browser brave-browser.desktop ||
      log_warn "Could not set the browser outside a graphical session; run: xdg-settings set default-web-browser brave-browser.desktop"
  fi
  xdg-mime default brave-browser.desktop x-scheme-handler/http
  xdg-mime default brave-browser.desktop x-scheme-handler/https
  xdg-mime default brave-browser.desktop text/html
}

configure_shell() {
  local current_user current_shell zsh_path
  mkdir -p "${HOME}/.local/bin" "${HOME}/.local/share" "${HOME}/go/bin"
  if command -v pipx >/dev/null 2>&1; then
    PIPX_BIN_DIR="${HOME}/.local/bin" pipx ensurepath >/dev/null || true
  fi
  require_command getent
  require_command zsh
  current_user=$(id -un)
  current_shell=$(getent passwd "${current_user}" | cut -d: -f7)
  zsh_path=$(command -v zsh)
  if [[ ${current_shell} != "${zsh_path}" ]]; then
    "${SUDO[@]}" usermod --shell "${zsh_path}" "${current_user}"
    [[ $(getent passwd "${current_user}" | cut -d: -f7) == "${zsh_path}" ]] ||
      die "Could not set ${zsh_path} as the login shell for ${current_user}."
    log_info "Set ${zsh_path} as the login shell for ${current_user}."
  fi
}

configure_gtk_theme() {
  if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' ||
      log_warn "Could not set the desktop dark color preference through GSettings."
    gsettings set org.gnome.desktop.interface gtk-theme 'Tokyonight-Dark' ||
      log_warn "Could not set the GTK theme through GSettings."
    gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' ||
      log_warn "Could not set the icon theme through GSettings."
  else
    log_warn "gsettings is unavailable; GTK settings.ini files will still request the dark theme."
  fi
}

configure_vscode_theme() {
  local settings="${HOME}/.config/Code/User/settings.json" temporary mode=0644
  temporary=$(mktemp "${CACHE_HOME}/vscode-settings.XXXXXX")
  node "${PROJECT_ROOT}/scripts/lib/vscode-theme-settings.mjs" "${settings}" "${temporary}"
  if [[ -f ${settings} ]] && cmp -s "${temporary}" "${settings}"; then
    log_info "VS Code already follows the system light/dark theme."
    return
  fi

  [[ ! -e ${settings} ]] || mode=$(stat -c '%a' "${settings}")
  backup_file "${settings}"
  mkdir -p "$(dirname -- "${settings}")"
  chmod "${mode}" "${temporary}"
  mv -f -- "${temporary}" "${settings}"
  log_info "Configured only VS Code's system theme preferences; Settings Sync owns all other settings."
}

configure_docker_access() {
  local current_user
  current_user=$(id -un)
  if ! getent group docker >/dev/null 2>&1; then
    "${SUDO[@]}" groupadd --system docker
  fi
  if ! id -nG "${current_user}" | tr ' ' '\n' | grep -qx docker; then
    "${SUDO[@]}" usermod --append --groups docker "${current_user}"
    log_info "Added ${current_user} to the docker group; the new membership applies after the next login."
  else
    log_info "${current_user} already belongs to the docker group."
  fi
}
