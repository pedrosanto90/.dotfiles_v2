#!/usr/bin/env bash

enable_system_service() {
  local unit=$1
  if systemctl list-unit-files "${unit}" --no-legend 2>/dev/null | grep -q "${unit}"; then
    "${SUDO[@]}" systemctl enable --now "${unit}"
  else
    log_warn "Service not found: ${unit}"
  fi
}

enable_user_service() {
  local unit=$1
  if systemctl --user list-unit-files "${unit}" --no-legend 2>/dev/null | grep -q "${unit}"; then
    systemctl --user enable --now "${unit}" || log_warn "Enable ${unit} after starting a graphical session."
  fi
}

enable_services() {
  enable_system_service NetworkManager.service
  enable_system_service bluetooth.service
  enable_system_service power-profiles-daemon.service
  enable_system_service upower.service
  enable_system_service udisks2.service
  enable_system_service containerd.service
  enable_system_service docker.service
  enable_user_service pipewire.socket
  enable_user_service pipewire-pulse.socket
  enable_user_service wireplumber.service
}

verify_docker_installation() {
  require_command docker
  require_command sg
  docker compose version >/dev/null
  docker buildx version >/dev/null
  sg docker -c 'docker info --format "Docker Engine {{.ServerVersion}} is ready"'
  log_success "Docker Engine, CLI, Buildx, and Compose work without sudo."
}
