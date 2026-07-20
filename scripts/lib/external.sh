#!/usr/bin/env bash

install_brave() {
  local key_tmp sources_tmp repository_changed=0
  key_tmp=$(mktemp "${CACHE_HOME}/brave-key.XXXXXX")
  sources_tmp=$(mktemp "${CACHE_HOME}/brave-sources.XXXXXX")
  download 'https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg' "${key_tmp}"
  download 'https://brave-browser-apt-release.s3.brave.com/brave-browser.sources' "${sources_tmp}"
  cmp -s "${key_tmp}" /usr/share/keyrings/brave-browser-archive-keyring.gpg || repository_changed=1
  cmp -s "${sources_tmp}" /etc/apt/sources.list.d/brave-browser-release.sources || repository_changed=1
  sudo_install_file "${key_tmp}" /usr/share/keyrings/brave-browser-archive-keyring.gpg
  sudo_install_file "${sources_tmp}" /etc/apt/sources.list.d/brave-browser-release.sources
  if (( repository_changed == 1 )); then
    "${SUDO[@]}" apt-get update
  fi
  if ! dpkg-query -W -f='${db:Status-Abbrev}' brave-browser 2>/dev/null | grep -q '^ii '; then
    "${SUDO[@]}" apt-get install --yes brave-browser
  else
    log_info "Brave is already installed."
  fi
}

dearmor_key() {
  local url=$1 destination=$2 armored fingerprint_suffix=${3:-} fingerprint
  armored=$(mktemp "${CACHE_HOME}/vendor-key.XXXXXX")
  download "${url}" "${armored}"
  if [[ -n ${fingerprint_suffix} ]]; then
    fingerprint=$(gpg --show-keys --with-colons "${armored}" 2>/dev/null |
      awk -F: '$1 == "fpr" {print $10; exit}')
    [[ ${fingerprint} == *"${fingerprint_suffix}" ]] ||
      die "Unexpected signing-key fingerprint from ${url}."
  fi
  gpg --batch --yes --dearmor --output "${destination}" "${armored}"
}

install_bruno_arm64() {
  local release_json tag version asset url digest archive installed=''
  release_json=$(curl --fail --silent --show-error --location \
    -H 'Accept: application/vnd.github+json' \
    'https://api.github.com/repos/usebruno/bruno/releases/latest')
  tag=$(jq -er '.tag_name' <<<"${release_json}")
  version=${tag#v}
  asset="bruno_${version}_arm64_linux.deb"
  url=$(jq -er --arg asset "${asset}" '.assets[] | select(.name == $asset) | .browser_download_url' \
    <<<"${release_json}")
  digest=$(jq -er --arg asset "${asset}" '.assets[] | select(.name == $asset) | .digest' \
    <<<"${release_json}")
  digest=${digest#sha256:}
  installed=$(dpkg-query -W -f='${Version}' bruno 2>/dev/null || true)
  installed=${installed%%-*}
  [[ ${installed} == "${version}" ]] && { log_info "Bruno ${version} is already installed."; return; }
  archive="${CACHE_HOME}/${asset}"
  download "${url}" "${archive}"
  [[ $(sha256sum "${archive}" | awk '{print $1}') == "${digest}" ]] ||
    die "Invalid checksum for the official Bruno arm64 package."
  "${SUDO[@]}" apt-get install --yes "${archive}"
}

install_developer_gui_apps() {
  local microsoft_key dbeaver_key bruno_key repository_changed=0 package
  local -a packages=(code dbeaver-ce)

  log_info "Installing Bruno, Visual Studio Code, and DBeaver from official sources."

  microsoft_key=$(mktemp "${CACHE_HOME}/microsoft-key.XXXXXX.gpg")
  dbeaver_key=$(mktemp "${CACHE_HOME}/dbeaver-key.XXXXXX.gpg")
  dearmor_key 'https://packages.microsoft.com/keys/microsoft.asc' "${microsoft_key}"
  dearmor_key 'https://dbeaver.io/debs/dbeaver.gpg.key' "${dbeaver_key}"

  cmp -s "${microsoft_key}" /usr/share/keyrings/microsoft.gpg || repository_changed=1
  cmp -s "${dbeaver_key}" /usr/share/keyrings/dbeaver.gpg || repository_changed=1
  cmp -s "${PROJECT_ROOT}/assets/apt/vscode.sources" /etc/apt/sources.list.d/vscode.sources || repository_changed=1
  cmp -s "${PROJECT_ROOT}/assets/apt/dbeaver.list" /etc/apt/sources.list.d/dbeaver.list || repository_changed=1

  sudo_deploy_config "${microsoft_key}" /usr/share/keyrings/microsoft.gpg
  sudo_deploy_config "${dbeaver_key}" /usr/share/keyrings/dbeaver.gpg
  sudo_deploy_config "${PROJECT_ROOT}/assets/apt/vscode.sources" /etc/apt/sources.list.d/vscode.sources
  sudo_deploy_config "${PROJECT_ROOT}/assets/apt/dbeaver.list" /etc/apt/sources.list.d/dbeaver.list

  case $(uname -m) in
    x86_64)
      bruno_key=$(mktemp "${CACHE_HOME}/bruno-key.XXXXXX.gpg")
      dearmor_key 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x9FA6017ECABE0266' \
        "${bruno_key}" '9FA6017ECABE0266'
      cmp -s "${bruno_key}" /etc/apt/keyrings/bruno.gpg || repository_changed=1
      cmp -s "${PROJECT_ROOT}/assets/apt/bruno.list" /etc/apt/sources.list.d/bruno.list || repository_changed=1
      sudo_deploy_config "${bruno_key}" /etc/apt/keyrings/bruno.gpg
      sudo_deploy_config "${PROJECT_ROOT}/assets/apt/bruno.list" /etc/apt/sources.list.d/bruno.list
      packages+=(bruno)
      ;;
    aarch64|arm64) ;;
    *) die "Bruno is unsupported on architecture $(uname -m)." ;;
  esac

  if (( repository_changed == 1 )); then
    "${SUDO[@]}" apt-get update
  fi
  for package in "${packages[@]}"; do
    if ! dpkg-query -W -f='${db:Status-Abbrev}' "${package}" 2>/dev/null | grep -q '^ii '; then
      "${SUDO[@]}" apt-get install --yes "${package}"
    else
      log_info "${package} is already installed."
    fi
  done

  case $(uname -m) in
    aarch64|arm64) install_bruno_arm64 ;;
  esac

}

install_starship() {
  local installer
  command -v starship >/dev/null 2>&1 && { log_info "Starship is already installed."; return; }
  installer=$(mktemp "${CACHE_HOME}/starship-install.XXXXXX")
  download 'https://starship.rs/install.sh' "${installer}"
  sh "${installer}" --yes --bin-dir "${HOME}/.local/bin"
}

install_nvm_and_node() {
  local nvm_dir="${NVM_DIR:-${HOME}/.nvm}" tag
  if [[ ! -s ${nvm_dir}/nvm.sh ]]; then
    tag=$(github_latest_tag nvm-sh/nvm)
    log_info "Installing NVM ${tag}."
    git clone --branch "${tag}" --depth 1 https://github.com/nvm-sh/nvm.git "${nvm_dir}"
  fi
  # shellcheck disable=SC1091
  source "${nvm_dir}/nvm.sh"
  nvm install --lts --latest-npm
  nvm alias default 'lts/*'
  corepack enable
  corepack install --global pnpm@latest yarn@stable
}

go_arch() {
  case $(uname -m) in
    x86_64) printf 'amd64' ;;
    aarch64|arm64) printf 'arm64' ;;
    armv6l) printf 'armv6l' ;;
    s390x|ppc64le|riscv64) uname -m ;;
    *) die "Architecture unsupported by official Go builds: $(uname -m)" ;;
  esac
}

install_go() {
  local arch version installed='' archive checksum expected
  arch=$(go_arch)
  version=$(curl --fail --silent --show-error 'https://go.dev/dl/?mode=json' |
    jq -er 'map(select(.stable == true))[0].version')
  [[ -x /usr/local/go/bin/go ]] && installed=$(/usr/local/go/bin/go version | awk '{print $3}')
  [[ ${installed} == "${version}" ]] && { log_info "Go ${version} is already installed."; return; }
  archive="${CACHE_HOME}/${version}.linux-${arch}.tar.gz"
  checksum="${archive}.sha256"
  download "https://go.dev/dl/${version}.linux-${arch}.tar.gz" "${archive}"
  download "https://go.dev/dl/${version}.linux-${arch}.tar.gz.sha256" "${checksum}"
  expected=$(tr -d '[:space:]' <"${checksum}")
  [[ $(sha256sum "${archive}" | awk '{print $1}') == "${expected}" ]] || die "Invalid Go checksum."
  # The upstream installation procedure replaces /usr/local/go as a complete tree.
  if [[ -d /usr/local/go ]]; then
    "${SUDO[@]}" mv /usr/local/go "/usr/local/go.backup.$(date +%Y%m%d-%H%M%S)"
  fi
  "${SUDO[@]}" tar -C /usr/local -xzf "${archive}"
  log_info "Go ${version} installed."
}

install_yazi() {
  local arch tag asset archive temp_dir
  command -v yazi >/dev/null 2>&1 && { log_info "Yazi is already installed."; return; }
  case $(uname -m) in
    x86_64) arch=x86_64-unknown-linux-gnu ;;
    aarch64|arm64) arch=aarch64-unknown-linux-gnu ;;
    *) die "Yazi does not provide a supported official binary for $(uname -m)." ;;
  esac
  tag=$(github_latest_tag sxyazi/yazi)
  asset="yazi-${arch}"
  archive="${CACHE_HOME}/${asset}-${tag}.zip"
  download "https://github.com/sxyazi/yazi/releases/download/${tag}/${asset}.zip" "${archive}"
  temp_dir=$(mktemp -d "${CACHE_HOME}/yazi.XXXXXX")
  unzip -q "${archive}" -d "${temp_dir}"
  install -D -m 0755 "${temp_dir}/${asset}/yazi" "${HOME}/.local/bin/yazi"
  install -D -m 0755 "${temp_dir}/${asset}/ya" "${HOME}/.local/bin/ya"
}

# Neovim is deliberately not installed through APT. Debian Stable generally
# carries an older release, while this configuration targets current Neovim.
# Follow the official upstream build procedure and install into /usr/local.
install_neovim_from_source() {
  local tag current='' build_root source_dir built_version
  local marker="${STATE_HOME}/neovim-source-version"
  tag=$(github_latest_tag neovim/neovim)

  if [[ -x /usr/local/bin/nvim ]]; then
    current=$(/usr/local/bin/nvim --version | awk 'NR == 1 {print $2}')
  fi
  if [[ ${current} == "${tag}" && -f ${marker} ]] && [[ $(<"${marker}") == "${tag}" ]]; then
    log_info "Neovim ${tag} is already installed from source in /usr/local."
    return
  fi

  build_root=$(mktemp -d "${CACHE_HOME}/neovim-build.XXXXXX")
  source_dir="${build_root}/neovim"
  log_info "Cloning the official Neovim ${tag} source release."
  git clone --depth 1 --branch "${tag}" --single-branch \
    https://github.com/neovim/neovim.git "${source_dir}"

  log_info "Building Neovim ${tag} from source with RelWithDebInfo."
  make -C "${source_dir}" CMAKE_BUILD_TYPE=RelWithDebInfo

  built_version=$("${source_dir}/build/bin/nvim" --version | awk 'NR == 1 {print $2}')
  [[ ${built_version} == "${tag}" ]] ||
    die "Built Neovim version ${built_version} does not match requested release ${tag}."

  log_info "Installing the source-built Neovim ${tag} into /usr/local."
  "${SUDO[@]}" make -C "${source_dir}" install
  [[ $(/usr/local/bin/nvim --version | awk 'NR == 1 {print $2}') == "${tag}" ]] ||
    die "Neovim installation verification failed."
  printf '%s\n' "${tag}" >"${marker}"
}

zig_arch() {
  case $(uname -m) in
    x86_64) printf 'x86_64' ;;
    aarch64|arm64) printf 'aarch64' ;;
    *) die "Architecture without a supported official Zig binary: $(uname -m)" ;;
  esac
}

install_ghostty() {
  local tag version source_archive signature source_dir zig_version zarch zig_archive zig_dir build_root current=''
  command -v ghostty >/dev/null 2>&1 && current=$(ghostty +version 2>/dev/null | head -n1 | awk '{print $2}')
  tag=$(github_latest_tag ghostty-org/ghostty)
  version=${tag#v}
  [[ ${current} == "${version}" ]] && { log_info "Ghostty ${version} is already installed."; return; }
  source_archive="${CACHE_HOME}/ghostty-${version}.tar.gz"
  signature="${source_archive}.minisig"
  download "https://release.files.ghostty.org/${version}/ghostty-${version}.tar.gz" "${source_archive}"
  download "https://release.files.ghostty.org/${version}/ghostty-${version}.tar.gz.minisig" "${signature}"
  minisign -Vm "${source_archive}" -x "${signature}" \
    -P 'RWQlAjJC23149WL2sEpT/l0QKy7hMIFhYdQOFy0Z7z7PbneUgvlsnYc' >/dev/null ||
    die "Invalid Ghostty tarball signature."
  build_root=$(mktemp -d "${CACHE_HOME}/ghostty-build.XXXXXX")
  tar -C "${build_root}" -xzf "${source_archive}"
  source_dir="${build_root}/ghostty-${version}"
  [[ -d ${source_dir} ]] || die "Unexpected structure in the Ghostty tarball."
  zig_version=$(awk -F '"' '/minimum_zig_version/ {print $2; exit}' "${source_dir}/build.zig.zon")
  [[ -n ${zig_version} ]] || die "Could not determine the Zig version required by Ghostty."
  zarch=$(zig_arch)
  zig_archive="${CACHE_HOME}/zig-${zarch}-linux-${zig_version}.tar.xz"
  download "https://ziglang.org/download/${zig_version}/zig-${zarch}-linux-${zig_version}.tar.xz" "${zig_archive}"
  tar -C "${build_root}" -xJf "${zig_archive}"
  zig_dir="${build_root}/zig-${zarch}-linux-${zig_version}"
  log_info "Building Ghostty ${version}; this step may take a while."
  (cd "${source_dir}" && "${zig_dir}/zig" build -p "${HOME}/.local" -Doptimize=ReleaseFast)
}

install_nerd_font() {
  local font_dir="${HOME}/.local/share/fonts/JetBrainsMonoNerd" tag archive temp_dir
  if find "${font_dir}" -type f -name '*.ttf' -print -quit 2>/dev/null | grep -q .; then
    log_info "JetBrainsMono Nerd Font is already installed."
    return
  fi
  tag=$(github_latest_tag ryanoasis/nerd-fonts)
  archive="${CACHE_HOME}/JetBrainsMono-${tag}.zip"
  download "https://github.com/ryanoasis/nerd-fonts/releases/download/${tag}/JetBrainsMono.zip" "${archive}"
  temp_dir=$(mktemp -d "${CACHE_HOME}/font.XXXXXX")
  unzip -q "${archive}" -d "${temp_dir}"
  mkdir -p "${font_dir}"
  find "${temp_dir}" -maxdepth 1 -type f -name '*.ttf' -exec install -m 0644 -t "${font_dir}" {} +
  fc-cache -f "${font_dir}"
}
