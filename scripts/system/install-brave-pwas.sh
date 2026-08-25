#!/usr/bin/env bash
set -euo pipefail

readonly PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly POLICY_SOURCE="${PROJECT_ROOT}/assets/brave-pwas-policy.json"
readonly POLICY_DESTINATION="/etc/brave/policies/managed/debian-sway-dev-pwas.json"
readonly BACKUP_ROOT="/var/backups/debian-sway-dev"
SUDO=()

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

if ((EUID != 0)); then
  command -v sudo >/dev/null 2>&1 || die "sudo is required to install the Brave PWA policy."
  SUDO=(sudo)
fi

command -v jq >/dev/null 2>&1 || die "jq is required to validate the Brave PWA policy."
[[ -f ${POLICY_SOURCE} ]] || die "Policy file not found: ${POLICY_SOURCE}"

jq -e '
  (.WebAppInstallForceList | type == "array" and length > 0) and
  all(.WebAppInstallForceList[];
    (.url | type == "string" and startswith("https://")) and
    .default_launch_container == "window" and
    .create_desktop_shortcut == true and
    (.custom_name | type == "string" and length > 0)
  )
' "${POLICY_SOURCE}" >/dev/null || die "Invalid Brave PWA policy: ${POLICY_SOURCE}"

for policy in /etc/brave/policies/managed/*.json; do
  [[ -e ${policy} && ${policy} != "${POLICY_DESTINATION}" ]] || continue
  if "${SUDO[@]}" grep -q '"WebAppInstallForceList"' "${policy}"; then
    die "Another Brave policy already defines WebAppInstallForceList: ${policy}"
  fi
done

if "${SUDO[@]}" test -f "${POLICY_DESTINATION}" &&
  "${SUDO[@]}" cmp -s "${POLICY_SOURCE}" "${POLICY_DESTINATION}"; then
  printf 'Brave PWA policy is already up to date.\n'
  exit 0
fi

if "${SUDO[@]}" test -e "${POLICY_DESTINATION}"; then
  timestamp=$(date +%Y%m%d-%H%M%S-%N)
  backup="${BACKUP_ROOT}/${timestamp}${POLICY_DESTINATION}"
  "${SUDO[@]}" install -d -m 0700 "$(dirname -- "${backup}")"
  "${SUDO[@]}" cp -a -- "${POLICY_DESTINATION}" "${backup}"
  printf 'Backup created: %s\n' "${backup}"
fi

"${SUDO[@]}" install -D -m 0644 "${POLICY_SOURCE}" "${POLICY_DESTINATION}"
printf 'Installed Brave PWA policy: %s\n' "${POLICY_DESTINATION}"
printf 'Brave installs or refreshes the configured PWAs when it next processes policies.\n'
