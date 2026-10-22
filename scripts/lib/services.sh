#!/usr/bin/env bash

readonly WIFI_INTERFACE="wlp1s0"

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

configure_network_manager_wifi() {
  local attempt state=""
  local migration_script="${PROJECT_ROOT}/scripts/system/migrate-wlp1s0-to-networkmanager.sh"

  if [[ ! -d /sys/class/net/${WIFI_INTERFACE} ]]; then
    log_warn "Wi-Fi interface ${WIFI_INTERFACE} was not detected; skipping its NetworkManager migration."
    return
  fi
  [[ -x ${migration_script} ]] || die "Missing executable Wi-Fi migration script: ${migration_script}"

  for attempt in {1..30}; do
    state=$(nmcli -g GENERAL.STATE device show "${WIFI_INTERFACE}" 2>/dev/null || true)
    [[ -n ${state} ]] && break
    sleep 0.5
  done
  [[ -n ${state} ]] || die "NetworkManager did not detect ${WIFI_INTERFACE}."

  if [[ ${state} == *unmanaged* ]]; then
    log_warn "${WIFI_INTERFACE} is unmanaged; starting the guarded ifupdown-to-NetworkManager migration."
    log_warn "The migration creates its own backups and asks for MIGRAR immediately before interrupting Wi-Fi."
    "${SUDO[@]}" "${migration_script}"
    state=$(nmcli -g GENERAL.STATE device show "${WIFI_INTERFACE}" 2>/dev/null || true)
    [[ ${state} != *unmanaged* && -n ${state} ]] ||
      die "${WIFI_INTERFACE} is still unmanaged after the migration."
  else
    log_info "NetworkManager already owns ${WIFI_INTERFACE} (${state}); no migration is needed."
  fi
}

enable_services() {
  systemctl --user daemon-reload || log_warn "Reload user services after starting a graphical session."
  # Keep the global D-Bus supplicant backend available to NetworkManager.
  enable_system_service wpa_supplicant.service
  enable_system_service NetworkManager.service
  configure_network_manager_wifi
  enable_system_service bluetooth.service
  enable_system_service power-profiles-daemon.service
  enable_system_service upower.service
  enable_system_service udisks2.service
  enable_system_service containerd.service
  enable_system_service docker.service
  enable_system_service libvirtd.socket
  enable_user_service pipewire.socket
  enable_user_service pipewire-pulse.socket
  enable_user_service wireplumber.service
  enable_user_service local-calendar-alerts.timer
  enable_user_service local-calendar-sync.timer
}

verify_docker_installation() {
  require_command docker
  require_command sg
  docker compose version >/dev/null
  docker buildx version >/dev/null
  sg docker -c 'docker info --format "Docker Engine {{.ServerVersion}} is ready"'
  log_success "Docker Engine, CLI, Buildx, and Compose work without sudo."
}

verify_libvirt_installation() {
  local command architecture
  for command in virsh virt-manager qemu-img swtpm swtpm_setup sg; do
    require_command "${command}"
  done
  architecture=$(dpkg --print-architecture)
  case ${architecture} in
    amd64) require_command qemu-system-x86_64 ;;
    arm64) require_command qemu-system-aarch64 ;;
    *) die "Unsupported QEMU/KVM host architecture: ${architecture}" ;;
  esac
  if ! sg libvirt -c 'virsh -c qemu:///system list --all'; then
    die "Could not connect to qemu:///system through the libvirt group; check systemctl status libvirtd.socket libvirtd.service and journalctl -b -u libvirtd."
  fi
  if [[ ! -e /dev/kvm ]]; then
    log_warn "/dev/kvm is unavailable; check virtualization support in BIOS/UEFI and hardware (or nested virtualization on a VM host). Guests can use slower QEMU emulation."
  fi
  log_success "QEMU, libvirt, virt-manager, and virtual TPM tools are installed; qemu:///system works without sudo."
}
