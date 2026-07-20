#!/usr/bin/env bash

readonly STATE_HOME="${XDG_STATE_HOME:-${HOME}/.local/state}/debian-sway-dev"
readonly CACHE_HOME="${XDG_CACHE_HOME:-${HOME}/.cache}/debian-sway-dev"
readonly BACKUP_ROOT="${STATE_HOME}/backups"
readonly MANIFEST="${STATE_HOME}/installed-files.tsv"
readonly LOCK_FILE="${STATE_HOME}/install.lock"
SUDO=()
APT_UPDATED=0

log_info() { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
log_step() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
log_warn() { printf '\033[1;33m[WARNING]\033[0m %s\n' "$*" >&2; }
log_error() { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; }
log_success() { printf '\033[1;32m[OK]\033[0m %s\n' "$*"; }
die() { log_error "$*"; exit 1; }

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

require_regular_user() {
  [[ ${EUID} -ne 0 ]] || die "Run this script as a regular user; it calls sudo only when required."
  [[ -n ${HOME:-} && -d ${HOME} ]] || die "Invalid HOME directory."
}

require_debian_stable() {
  [[ -r /etc/os-release ]] || die "Unable to identify the distribution."
  # shellcheck disable=SC1091
  source /etc/os-release
  [[ ${ID:-} == debian ]] || die "This project supports Debian only."
  [[ ${VERSION_CODENAME:-} == trixie && ${VERSION_ID%%.*} == 13 ]] ||
    die "Debian Stable 13 (trixie) is required; detected ${PRETTY_NAME:-unknown}."
}

init_runtime() {
  umask 022
  mkdir -p "${STATE_HOME}" "${CACHE_HOME}" "${BACKUP_ROOT}" "${HOME}/.local/bin"
  require_command sudo
  SUDO=(sudo)
}

acquire_lock() {
  require_command flock
  exec 9>"${LOCK_FILE}"
  flock -n 9 || die "Another installation is already running."
}

sudo_install_file() {
  local source=$1 destination=$2 mode=${3:-0644}
  if [[ -f ${destination} ]] && cmp -s "${source}" "${destination}"; then
    return
  fi
  "${SUDO[@]}" install -D -m "${mode}" "${source}" "${destination}"
}

sudo_deploy_config() {
  local source=$1 destination=$2 mode=${3:-0644}
  local timestamp relative backup_root backup
  if [[ -f ${destination} ]] && cmp -s "${source}" "${destination}"; then
    return
  fi
  if [[ -e ${destination} || -L ${destination} ]]; then
    timestamp=$(date +%Y%m%d-%H%M%S-%N)
    relative=${destination#/}
    backup_root="/var/backups/debian-sway-dev/${timestamp}"
    backup="${backup_root}/${relative}"
    "${SUDO[@]}" install -d -m 0700 "$(dirname -- "${backup}")"
    "${SUDO[@]}" cp -a -- "${destination}" "${backup}"
    log_warn "System configuration backup created: ${backup}"
  fi
  "${SUDO[@]}" install -D -m "${mode}" "${source}" "${destination}"
  log_info "Installed system configuration: ${destination}"
}

download() {
  local url=$1 destination=$2
  curl --fail --location --retry 3 --connect-timeout 15 --output "${destination}" "${url}"
}

github_latest_tag() {
  local repository=$1
  curl --fail --silent --show-error --location \
    -H 'Accept: application/vnd.github+json' \
    "https://api.github.com/repos/${repository}/releases/latest" |
    jq -er '.tag_name'
}

backup_file() {
  local destination=$1 relative timestamp backup
  [[ -e ${destination} || -L ${destination} ]] || return 0
  relative=${destination#"${HOME}"/}
  timestamp=$(date +%Y%m%d-%H%M%S-%N)
  backup="${BACKUP_ROOT}/${timestamp}/${relative}"
  mkdir -p "$(dirname -- "${backup}")"
  cp -a -- "${destination}" "${backup}"
  log_warn "Backup created: ${backup}"
}

deploy_file() {
  local source=$1 destination=$2 mode=${3:-0644} temporary
  [[ -f ${source} ]] || die "Missing project file: ${source}"
  mkdir -p "$(dirname -- "${destination}")"
  if [[ -f ${destination} ]] && cmp -s "${source}" "${destination}"; then
    record_file "${destination}"
    return
  fi
  backup_file "${destination}"
  temporary=$(mktemp "$(dirname -- "${destination}")/.debian-sway-dev.XXXXXX")
  cp -- "${source}" "${temporary}"
  chmod "${mode}" "${temporary}"
  mv -f -- "${temporary}" "${destination}"
  record_file "${destination}"
  log_info "Installed: ${destination}"
}

record_file() {
  local destination=$1 temporary
  temporary=$(mktemp "${STATE_HOME}/manifest.XXXXXX")
  { [[ ! -f ${MANIFEST} ]] || awk -F '\t' -v path="${destination}" '$1 != path' "${MANIFEST}"; printf '%s\t%s\n' "${destination}" "${PROJECT_ROOT}"; } >"${temporary}"
  mv -f -- "${temporary}" "${MANIFEST}"
}

version_gt() {
  [[ $(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n1) == "$1" && $1 != "$2" ]]
}
