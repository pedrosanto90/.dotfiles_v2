#!/bin/bash

# Este script instala e configura um ambiente de desenvolvimento completo
# no Debian 13 (Trixie), incluindo i3, Ferramentas de Dev e Node.js.
# Deve ser executado com 'sudo'.

# --- VARIAVEIS ---
# Obtém o nome do utilizador original que invocou o 'sudo'
USER_NAME=$(logname 2>/dev/null || echo ${SUDO_USER}) 
if [ -z "$USER_NAME" ]; then
    echo "Erro: Não foi possível determinar o nome do utilizador não-root. Certifique-se de que executa com 'sudo'."
    exit 1
fi
HOME_DIR="/home/$USER_NAME" # O diretório home real do utilizador
DOTFILES_DIR="$HOME_DIR/.dotfiles_v2" # Diretório base dos dotfiles

SCRIPT_DIR=$(pwd)
NVIM_VERSION="v0.10.1" 
WEZTERM_VERSION="20241118-081016-f36b8e3a" 

DEB_OBSIDIAN_URL="https://github.com/obsidianmd/obsidian-releases/releases/download/v1.6.3/obsidian-1.6.3.deb"
DEB_ONLYOFFICE_URL="https://download.onlyoffice.com/install/desktop/editors/linux/onlyoffice-desktopeditors_amd64.deb"
DEB_WEBEX_URL="https://binaries.webex.com/WebexDesktopApp-linux-webex.deb"
DEB_DBEAVER_URL="https://dbeaver.io/files/dbeaver-ce_latest_amd64.deb"
BITWARDEN_APPIMAGE_URL="https://vault.bitwarden.com/download/?app=desktop&platform=linux&variant=appimage"
POSTMAN_TAR_URL="https://dl.pstmn.io/download/latest/linux_64"
INSOMNIA_DEB_URL="https://insomnia.rest/download/core/debian"

# Garante que o script é executado como root (com a correção do USER_NAME)
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, execute como root (sudo ./install.sh)"
  exit 1
fi

echo "Inicializando o Script de Configuração do Ambiente de Trabalho para o utilizador: $USER_NAME"
echo "---------------------------------------------------------"

# 1. Configurar Repositórios (non-free)
echo "1. Configurando repositórios 'non-free' e atualizando..."
sed -i '/deb http/s/ main/ main contrib non-free non-free-firmware/g' /etc/apt/sources.list
apt update
apt upgrade -y

# 2. Instalar Core System e Ferramentas (apt)
# Inclui i3, rofi, zsh, tmux, git, arandr e utilidades essenciais.
echo "2. Instalando Core System, i3, ZSH e Utilidades essenciais..."
apt install -y \
  xserver-xorg \
  i3 \
  i3status \
  rofi \
  dmenu \
  fzf \
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
  chromium \
  x11-xserver-utils \
  maim \
  xclip \
  pulseaudio-utils \
  brightnessctl \
  arandr

# 3. Configurar Repositórios Externos (VSCode, NordVPN e Docker)
echo "3. Configurando repositórios externos e instalando VS Code e NordVPN..."
# ... (código de configuração de repositórios) ...
# VSCode
echo 'installing VS Code...'
wget -O vscode.deb https://go.microsoft.com/fwlink/?LinkID=760868
sudo apt install -y ./vscode.deb
# NordVPN
echo 'installing NordVPN...'
sh <(curl -sSf https://downloads.nordcdn.com/apps/linux/install.sh)

# Docker
apt install -y ca-certificates gnupg lsb-release
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# Atualiza e instala
apt update
echo "3.4. Instalando Docker Engine e Docker Compose..."
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 3.5 Configurar Permissões do Docker
echo "3.5. Adicionando o utilizador $USER_NAME ao grupo docker (necessário logout/login)..."
usermod -aG docker $USER_NAME

# Instalar pacotes via repositório (VSCode e NordVPN)
echo "3.6. Instalando VS Code e NordVPN via apt..."
apt install -y code nordvpn

# 4. Instalar Neovim a partir do Código Fonte
echo "4. Instalando Neovim ..."
git clone https://github.com/neovim/neovim /opt/neovim-src
cd /opt/neovim-src
make CMAKE_BUILD_TYPE=Release
make install
cd $SCRIPT_DIR

# 5. Instalar WezTerm a partir do Código Fonte (inclui Rust)
echo "5. Instalando Rust e compilando WezTerm a partir do Código Fonte..."
su - $USER_NAME -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"

# Instalação das dependências de build do WezTerm
apt install -y fontconfig libfreetype6-dev libxcb-xfixes0-dev libxkbcommon-dev libssl-dev

git clone https://github.com/wez/wezterm.git /opt/wezterm-src
cd /opt/wezterm-src
git checkout $WEZTERM_VERSION
su - $USER_NAME -c "cd /opt/wezterm-src && PATH=\$HOME/.cargo/bin:\$PATH cargo build --release"
cp target/release/wezterm /usr/local/bin/wezterm
cd $SCRIPT_DIR

# 6. Instalar Outras Aplicações (Pacotes .deb)
echo "6. Instalando Obsidian, OnlyOffice, Webex, Insomnia e DBeaver (.deb)..."
# Obsidian
wget -O /tmp/obsidian.deb "$DEB_OBSIDIAN_URL" && dpkg -i /tmp/obsidian.deb
# OnlyOffice
wget -O /tmp/onlyoffice.deb "$DEB_ONLYOFFICE_URL" && dpkg -i /tmp/onlyoffice.deb
# Webex
wget -O /tmp/webex.deb "$DEB_WEBEX_URL" && dpkg -i /tmp/webex.deb
# Insomnia
wget -O /tmp/insomnia.deb "$INSOMNIA_DEB_URL" && dpkg -i /tmp/insomnia.deb
# DBeaver
wget -O /tmp/dbeaver.deb "$DEB_DBEAVER_URL" && dpkg -i /tmp/dbeaver.deb

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
ln -sf $INSTALL_DIR/Postman/Postman /usr/local/bin/postman
rm /tmp/postman.tar.gz

# 8. Configurar ZSH e Oh-My-ZSH
echo "8. Configurando ZSH e Oh-My-ZSH..."
chsh -s $(which zsh) $USER_NAME # Altera a shell padrão do utilizador
su - $USER_NAME -c "sh -c \"$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh --no-check-certificate)\""

# 9. Configuração de Dotfiles (Criação de Symlinks Automatizada)
echo "9. Automatizando a criação de Symlinks para Dotfiles..."
git clone https://github.com/pedrosanto90/.dotfiles_v2
su - $USER_NAME -c "
  mkdir -p \"\$HOME_DIR/.config\"
  mkdir -p \"\$HOME_DIR/scripts\" # Garante que o diretório scripts existe

  # 9.1 Limpeza ZSH: Remover ficheiros de configuração ZSH existentes antes de criar symlinks
  echo '  -> Limpeza: Removendo ficheiros ZSH existentes (.zshrc, .zprofile, etc)...'
  rm -rf \"\$HOME_DIR/.zshrc\"
  rm -rf \"\$HOME_DIR/.zprofile\"
  rm -rf \"\$HOME_DIR/.zsh_history\"

  # 9.2 Symlinks para ~/.config/
  echo '  -> Criando symlinks em \$HOME_DIR/.config/...'
  ln -sfn \"$DOTFILES_DIR/.config/nvim\" \"\$HOME_DIR/.config/nvim\"
  ln -sfn \"$DOTFILES_DIR/.config/tmux\" \"\$HOME_DIR/.config/tmux\"
  ln -sfn \"$DOTFILES_DIR/.config/i3\" \"\$HOME_DIR/.config/i3\"
  ln -sfn \"$DOTFILES_DIR/.config/i3status\" \"\$HOME_DIR/.config/i3status\"
  ln -sfn \"$DOTFILES_DIR/.config/wezterm\" \"\$HOME_DIR/.config/wezterm\"

  # 9.3 Symlinks para o diretório Home (~)
  echo '  -> Criando symlinks na \$HOME_DIR/ (dotfiles ZSH)...'
  ln -sfn \"$DOTFILES_DIR/zsh/.zshrc\" \"\$HOME_DIR/.zshrc\"

  # 9.4 Symlink para o diretório scripts
  echo '  -> Criando symlink para \$HOME_DIR/scripts...'
  ln -sfn \"$DOTFILES_DIR/scripts\" \"\$HOME_DIR/scripts\"
"

# 10. Configurar Ambiente Node.js (NVM, Node v22, NestJS, Angular)
echo "10. Configurando Ambiente Node.js (NVM, Node v22, NestJS, Angular)..."
# Executa todos os comandos como o utilizador não-root
su - $USER_NAME -c "
  echo '  -> Instalando NVM (v0.39.7)...'
  # 10.1 Instalar NVM
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

  # 10.2 Carregar NVM para o shell atual do subshell
  export NVM_DIR=\"\$HOME/.nvm\"
  [ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\"

  # 10.3 Instalar e Definir Node.js v22 como padrão
  echo '  -> Instalando Node.js v22 e definindo como padrão...'
  nvm install 22
  nvm alias default 22

  # 10.4 Instalar CLIs Globais
  echo '  -> Instalando CLIs Globais: NestJS e Angular...'
  npm install -g @nestjs/cli @angular/cli

  echo '  -> Node.js v22, NestJS CLI e Angular CLI instalados com sucesso.'
"

# 11. Configuração Interativa do Git
echo "11. Configuração Interativa do Git (user.name e user.email)..."
# 11.1 Criar o script de configuração no diretório scripts do utilizador
echo "  -> Criando o script de configuração do Git em $HOME_DIR/scripts/config_git.sh"
su - "$USER_NAME" -c "
cat << 'GIT_CONFIG_EOF' > \"\$HOME_DIR/scripts/config_git.sh\"
#!/bin/bash
echo \"\"
echo \"--- Configuração Global do Git ---\"
echo \"Por favor, introduza a informação para a identificação das suas contribuições.\"

read -r -p \"Introduza o seu Nome Completo: \" GIT_NAME
if [ -z \"\$GIT_NAME\" ]; then
    echo \"Nome não fornecido. A configuração do Git foi cancelada.\"
    exit 1
fi

read -r -p \"Introduza o seu Email: \" GIT_EMAIL
if [ -z \"\$GIT_EMAIL\" ]; then
    echo \"Email não fornecido. A configuração do Git foi cancelada.\"
    exit 1
fi

git config --global user.name \"\$GIT_NAME\"
echo \"✅ Nome de utilizador Git configurado: \$GIT_NAME\"

git config --global user.email \"\$GIT_EMAIL\"
echo \"✅ Email Git configurado: \$GIT_EMAIL\"

git config --global core.editor \"nvim\"
echo \"✅ Editor Git configurado para Neovim.\"

echo \"--- Configuração Git Concluída ---\"
GIT_CONFIG_EOF
chmod +x \"\$HOME_DIR/scripts/config_git.sh\"
"

# 11.2 Executar o script de configuração do Git (interativo - REQUER INPUT)
echo ""
echo "!!! ATENÇÃO: INÍCIO DA CONFIGURAÇÃO INTERATIVA DO GIT !!!"
echo "Por favor, introduza o seu Nome Completo e Email quando solicitado."
echo "----------------------------------------------------------------------------------"
su - "$USER_NAME" -c "$HOME_DIR/scripts/config_git.sh"
echo "----------------------------------------------------------------------------------"

# 12. Finalização
echo "---------------------------------------------------------"
echo "✅ Instalação e Configuração concluída! 🎉"
echo ""
echo "!!! AVISO IMPORTANTE !!!"
echo "Para que as permissões do Docker, o novo ambiente ZSH e o NVM entrem em vigor,"
echo "deve fazer **LOGOUT e LOGIN** ou **REINICIAR** a máquina."
echo ""
echo "Recomendação: Reinicie a máquina (shutdown -r now) para garantir que tudo inicia corretamente."

exit 0
