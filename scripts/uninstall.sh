#!/usr/bin/env bash
set -euo pipefail

readonly STATE_HOME="${XDG_STATE_HOME:-${HOME}/.local/state}/debian-sway-dev"
readonly MANIFEST="${STATE_HOME}/installed-files.tsv"

[[ ${EUID} -ne 0 ]] || { printf 'Run this script as a regular user.\n' >&2; exit 1; }
[[ -f ${MANIFEST} ]] || { printf 'Manifest not found; there is nothing to remove.\n'; exit 0; }

while IFS=$'\t' read -r destination project_root; do
  [[ -n ${destination} ]] || continue
  relative=''
  case ${destination} in
    "${HOME}/.config/starship.toml") relative='configs/starship/starship.toml' ;;
    "${HOME}/.config/code-flags.conf") relative='configs/code-flags.conf' ;;
    "${HOME}/.config/"*) relative="configs/${destination#"${HOME}/.config/"}" ;;
    "${HOME}/.local/bin/"*) relative="scripts/bin/${destination#"${HOME}/.local/bin/"}" ;;
    "${HOME}/.local/share/wallpapers/debian-sway-dev/"*) relative="wallpapers/${destination#"${HOME}/.local/share/wallpapers/debian-sway-dev/"}" ;;
    "${HOME}/.local/share/applications/brave-browser.desktop") relative='assets/brave-browser.desktop' ;;
    "${HOME}/.tmux.conf") relative='configs/tmux/tmux.conf' ;;
    "${HOME}/.zshrc") relative='configs/zsh/zshrc' ;;
    "${HOME}/.zprofile") relative='configs/zsh/zprofile' ;;
  esac
  if [[ -n ${relative} && -f ${project_root}/${relative} && -f ${destination} ]] && cmp -s "${project_root}/${relative}" "${destination}"; then
    rm -- "${destination}"
    printf 'Removed: %s\n' "${destination}"
  elif [[ -e ${destination} ]]; then
    printf 'Kept (modified by the user): %s\n' "${destination}"
  fi
done <"${MANIFEST}"

printf '\nPackages, external software, and backups were not removed. See the README.\n'
