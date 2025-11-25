#!/bin/bash

# --- VARIAVEIS ---
USER_NAME=$(whoami)
SCRIPT_DIR=$(pwd)
NVIM_VERSION="v0.10.1" # Versão estável mais recente do Neovim
WEZTERM_VERSION="20240203-094136-22a941a3" # Exemplo de tag estável, verifique a última no GitHub
DEB_OBSIDIAN_URL="https://github.com/obsidianmd/obsidian-releases/releases/download/v1.6.3/obsidian-1.6.3.deb" # URL do último DEB (Atualizar se necessário)
DEB_ONLYOFFICE_URL="https://download.onlyoffice.com/install/desktop/editors/linux/onlyoffice-desktopeditors_amd64.deb" # URL OnlyOffice
DEB_WEBEX_URL="https://binaries.webex.com/WebexDesktopApp-linux-webex.deb" # URL genérica da Webex (Pode requerer URL específica)
BITWARDEN_APPIMAGE_URL="https://vault.bitwarden.com/download/?app=desktop&platform=linux&variant=appimage"
POSTMAN_TAR_URL="https://dl.pstmn.io/download/latest/linux_64"
INSOMNIA_DEB_URL="https://insomnia.rest/download/core/debian" # Link de redirecionamento, mais fiável

# Garante que o script é executado como root
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, execute como root (sudo ./setup_desktop.sh)"
  exit 1
fi

echo "Iniciando a instalação minimalista do Debian 13 (Trixie) + i3."
echo "---------------------------------------------------------"

# 1. Configurar Repositórios (non-free)
# Adiciona os componentes contrib e non-free essenciais para firmware/drivers
echo "1. Configurando repositórios 'non-free' e atualizando..."
sed -i '/deb http/s/ main/ main contrib non-free non-free-firmware/g' /etc/apt/sources.list
apt update
apt upgrade -y

# 2. Instalar Core System e Ferramentas (apt)
echo "2. Instalando Core System (i3, zsh, tmux, git) e Utilidades..."
apt install -y \
  xserver-xorg \
  i3 \
  lightdm \
  tmux \
  nitrogen \
  zsh \
  git \
  curl \
  wget \
  build-essential \
  cmake \
  ninja-build \
  pkg-config \
  libtool \
  libtool-bin \
  gettext \
  unzip \
  network-manager \
  network-manager-gnome \
  network-manager-openvpn \
  network-manager-openvpn-gnome \
  thunar \
  gvfs-backends \
  gvfs-smb \
  blueman \
  chromium

# 3. Configurar Repositórios Externos (VSCode e NordVPN)

# VSCode
echo "3.1. Adicionando repositório do Visual Studio Code..."
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
rm packages.microsoft.gpg
echo "deb [arch=amd64] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list

# NordVPN
echo "3.2. Adicionando repositório e instalando NordVPN..."
wget -qO- https://repo.nordvpn.com/gpg/nordvpn_public.asc | gpg --dearmor > nordvpn.gpg
install -o root -g root -m 644 nordvpn.gpg /etc/apt/trusted.gpg.d/
rm nordvpn.gpg
echo "deb [arch=amd64] https://repo.nordvpn.com/debian stable main" > /etc/apt/sources.list.d/nordvpn.list

# Atualiza novamente com os novos repositórios
apt update

# Instalar pacotes via repositório
echo "3.3. Instalando VS Code e NordVPN via apt..."
apt install -y code nordvpn

# 4. Instalar Neovim a partir do Código Fonte
echo "4. Instalando Neovim ($NVIM_VERSION) a partir do Código Fonte..."
# Dependências para Neovim: já incluídas no passo 2
git clone https://github.com/neovim/neovim /opt/neovim-src
cd /opt/neovim-src
git checkout $NVIM_VERSION
make CMAKE_BUILD_TYPE=Release
make install
cd $SCRIPT_DIR # Voltar para o diretório original

# 5. Instalar WezTerm a partir do Código Fonte (inclui Rust)
echo "5. Instalando Rust e compilando WezTerm a partir do Código Fonte..."
# Instala rustup - AVISO: isto deve ser feito como o USER_NAME para instalar no $HOME
su - $USER_NAME -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"
# Adiciona Rust ao PATH para o resto do script (só funciona no subshell)
export PATH="$HOME/.cargo/bin:$PATH"

# Instalação das dependências de build do WezTerm
apt install -y fontconfig libfreetype6-dev libxcb-xfixes0-dev libxkbcommon-dev libssl-dev

git clone https://github.com/wez/wezterm.git /opt/wezterm-src
cd /opt/wezterm-src
git checkout $WEZTERM_VERSION
# O comando de build do WezTerm é complexo e deve usar o rustup instalado
su - $USER_NAME -c "cd /opt/wezterm-src && PATH=\$HOME/.cargo/bin:\$PATH cargo build --release"
cp target/release/wezterm /usr/local/bin/wezterm
cd $SCRIPT_DIR

# 6. Instalar Outras Aplicações (Pacotes .deb)
echo "6. Instalando Obsidian, OnlyOffice, Webex e Insomnia (.deb)..."
# Obsidian
wget -O /tmp/obsidian.deb "$DEB_OBSIDIAN_URL" && dpkg -i /tmp/obsidian.deb

# OnlyOffice
wget -O /tmp/onlyoffice.deb "$DEB_ONLYOFFICE_URL" && dpkg -i /tmp/onlyoffice.deb

# Webex
wget -O /tmp/webex.deb "$DEB_WEBEX_URL" && dpkg -i /tmp/webex.deb

# Insomnia
wget -O /tmp/insomnia.deb "$INSOMNIA_DEB_URL" && dpkg -i /tmp/insomnia.deb

# Tenta corrigir quaisquer dependências não resolvidas
apt --fix-broken install -y

# 7. Instalar Aplicações (Binários/AppImages)
echo "7. Instalando Bitwarden e Postman (AppImage/Binary)..."
INSTALL_DIR="/opt/binaries"
mkdir -p $INSTALL_DIR

# Bitwarden (AppImage)
wget -O $INSTALL_DIR/Bitwarden.AppImage "$BITWARDEN_APPIMAGE_URL"
chmod +x $INSTALL_DIR/Bitwarden.AppImage

# Postman (Binary)
wget -O /tmp/postman.tar.gz "$POSTMAN_TAR_URL"
tar -xzf /tmp/postman.tar.gz -C $INSTALL_DIR
# Cria symlink para o executável principal
ln -sf $INSTALL_DIR/Postman/Postman /usr/local/bin/postman
rm /tmp/postman.tar.gz

# 8. Configurar ZSH e Oh-My-ZSH
echo "8. Configurando ZSH e Oh-My-ZSH..."
chsh -s $(which zsh) $USER_NAME # Altera a shell padrão do utilizador
su - $USER_NAME -c "sh -c \"$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh --no-check-certificate)\""

# 9. Configuração de Dotfiles (Symlinks)
echo "9. Preparação para Dotfiles (Symlinks)..."
echo "O script terminou a instalação dos pacotes. Por favor, coloque os seus dotfiles na sua home ($HOME)."
echo "Exemplo de como criar os symlinks MANUAIS:"
echo "su - $USER_NAME"
echo "ln -s ~/dotfiles/.config/i3/config ~/.config/i3/config"
echo "ln -s ~/dotfiles/.zshrc ~/.zshrc"
echo "..."

# 10. Finalização
echo "---------------------------------------------------------"
echo "Instalação concluída! Pode agora iniciar o seu ambiente:"
echo "systemctl start lightdm"
echo "Recomendação: Reinicie a máquina para garantir que todos os serviços (NetworkManager, etc.) iniciam corretamente."

# systemctl enable lightdm # O instalador do LightDM já deve ter feito isto

exit 0
