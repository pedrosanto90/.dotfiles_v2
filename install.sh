#!/usr/bin/env bash
set -euo pipefail

readonly PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly LIB_DIR="${PROJECT_ROOT}/scripts/lib"

# shellcheck source=scripts/lib/common.sh
source "${LIB_DIR}/common.sh"
# shellcheck source=scripts/lib/packages.sh
source "${LIB_DIR}/packages.sh"
# shellcheck source=scripts/lib/external.sh
source "${LIB_DIR}/external.sh"
# shellcheck source=scripts/lib/configure.sh
source "${LIB_DIR}/configure.sh"
# shellcheck source=scripts/lib/services.sh
source "${LIB_DIR}/services.sh"

main() {
  require_debian_stable
  require_regular_user
  init_runtime
  acquire_lock

  log_step "Update package indexes and install Debian packages"
  install_debian_packages
  require_command curl
  require_command jq

  log_step "Install software from official upstream sources"
  install_docker_engine
  install_brave
  install_developer_gui_apps
  install_starship
  install_nvm_and_node
  install_go
  install_yazi
  # Neovim is intentionally built from the latest stable upstream source.
  # The Debian neovim package must never be used by this project.
  install_neovim_from_source
  install_ghostty
  install_tokyonight_gtk_theme
  install_nerd_font

  log_step "Deploy configurations with backups"
  deploy_configs
  configure_login_manager
  configure_browser
  configure_shell
  configure_gtk_theme
  configure_vscode_theme
  configure_docker_access

  log_step "Enable services"
  enable_services
  verify_docker_installation

  log_success "Installation complete"
  printf '\nReboot, then sign in through the graphical wlgreet screen. Backups: %s\n' "${BACKUP_ROOT}"
  printf 'Before doing so, review ~/.config/sway/config.d/output.conf and input.conf.\n'
}

main "$@"
