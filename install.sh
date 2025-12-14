#!/bin/bash

USER_NAME=$(logname 2>/dev/null || echo ${SUDO_USER})
HOME_DIR="/home/$USER_NAME"

cd /home/$USER_NAME

cat <<EOF >/etc/apt/sources.list
# Repositórios Debian 13 (Trixie)
deb http://deb.debian.org/debian/ trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ trixie-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security/ trixie-security main contrib non-free non-free-firmware
EOF

apt clean
apt update -y
apt upgrade -y

mkdir -p .config scripts Documents Downloads Pictures Music Videos
mkdir -p Documents/projects
mkdir -p Documents/work/domatica

#core packages
apt install -y \
    xserver-xorg i3 i3status rofi dmenu fzf lightdm tmux nitrogen \
    zsh git curl wget build-essential cmake make ninja-build pkg-config libtool libtool-bin gettext unzip \
    network-manager network-manager-gnome network-manager-openvpn network-manager-openvpn-gnome \
    gvfs-backends blueman chromium x11-xserver-utils flameshot pulseaudio-utils brightnessctl \
    arandr eza bat \
    npm python3 python3-pip snapd golang nautilus cifs-utils \
    nautilus-share strongswan xl2tpd network-manager-l2tp network-manager-l2tp-gnome flameshot

mkdir -p /home/$USER_NAME/.local/share/fonts
wget -P /home/$USER_NAME/.local/share/fonts https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/JetBrainsMono.zip
cd /home/$USER_NAME/.local/share/fonts
unzip JetBrainsMono.zip
rm JetBrainsMono.zip
chown -R $USER_NAME:$USER_NAME /home/$USER_NAME/.local
fc-cache -fv
cd /home/$USER_NAME

#docker
# Add Docker's official GPG key:
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update -y
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

groupadd docker 2>/dev/null || true
usermod -aG docker "$USER_NAME"

#wezterm
curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list
sudo chmod 644 /usr/share/keyrings/wezterm-fury.gpg
sudo apt update
sudo apt install -y wezterm

#vs code
wget -O /tmp/vscode.deb https://go.microsoft.com/fwlink/?LinkID=760868
apt install -y /tmp/vscode.deb

#nvim
git clone https://github.com/neovim/neovim
cd neovim
make CMAKE_BUILD_TYPE=RelWithDebInfo
make install
cd /home/$USER_NAME

#dbeaver
sudo wget -O /usr/share/keyrings/dbeaver.gpg.key https://dbeaver.io/debs/dbeaver.gpg.key
echo "deb [signed-by=/usr/share/keyrings/dbeaver.gpg.key] https://dbeaver.io/debs/dbeaver-ce /" | sudo tee /etc/apt/sources.list.d/dbeaver.list
sudo apt-get update && sudo apt-get install dbeaver-ce -y

# obsidian
snap install obsidian --classic

# insomnia
snap install insomnia

#onlyoffice
snap install onlyoffice-desktopeditors

#postman
snap install postman

#firefox
snap install firefox

#nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash

#webex
wget -O /tmp/webex.deb https://binaries.webex.com/WebexDesktop-Ubuntu-Official-Package/Webex.deb

sudo apt install -y /tmp/webex.deb

cd /home/$USER_NAME
rm -rf .zshrc
rm -rf .zprofile
rm -rf .zsh_history

#oh my zsh - instalar ANTES dos symlinks para não sobrescrever
echo "Installing oh-my-zsh..."
sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

#p10k
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"

# Remover o .zshrc padrão criado pelo oh-my-zsh
rm -f /home/$USER_NAME/.zshrc

#create symlinks to dotfiles
# i3, i3status, wezterm, nvim -> ~/.config
ln -s /home/$USER_NAME/.dotfiles_v2/i3 /home/$USER_NAME/.config/i3
ln -s /home/$USER_NAME/.dotfiles_v2/i3status /home/$USER_NAME/.config/i3status
ln -s /home/$USER_NAME/.dotfiles_v2/wezterm /home/$USER_NAME/.config/wezterm
ln -s /home/$USER_NAME/.dotfiles_v2/nvim /home/$USER_NAME/.config/nvim

# tmux -> ~
ln -s /home/$USER_NAME/.dotfiles_v2/tmux /home/$USER_NAME/.config/tmux

# scripts -> ~/scripts
ln -s /home/$USER_NAME/.dotfiles_v2/scripts/* /home/$USER_NAME/scripts/

# wallpaper -> ~/Pictures
ln -s /home/$USER_NAME/.dotfiles_v2/wallpaper /home/$USER_NAME/Pictures/wallpaper

# zsh -> ~ (agora com oh-my-zsh já instalado)
ln -s /home/$USER_NAME/.dotfiles_v2/zsh/.zshrc /home/$USER_NAME/.zshrc
ln -s /home/$USER_NAME/.dotfiles_v2/zsh/.p10k.zsh /home/$USER_NAME/.p10k.zsh

chsh -s "$(command -v zsh)" "$USER_NAME"
cd /home/$USER_NAME
source /home/$USER_NAME/.zshrc

# configure to use node 22
nvm install 22
nvm alias default 22

# install angular cli
npm install -g @angular/cli

# install nestjs cli
npm i -g @nestjs/cli

cd /home/$USER_NAME
source /home/$USER_NAME/.zshrc

# configure git
cd /home/$USER_NAME
echo "Configuring git..."
echo "-----------------------------------"
echo "Prepare to answer some questions:"
sleep 5
echo "--- Configuração Global do Git ---"
echo "Esta informação será usada para identificar as suas contribuições."

# Pede o nome de utilizador
read -r -p "Introduza o seu Nome Completo (ex: Pedro Almeida): " GIT_NAME
if [ -z "$GIT_NAME" ]; then
    echo "Nome não fornecido. A configuração do Git foi cancelada."
    exit 1
fi

# Pede o email
read -r -p "Introduza o seu Email (ex: pedro.almeida@exemplo.com): " GIT_EMAIL
if [ -z "$GIT_EMAIL" ]; then
    echo "Email não fornecido. A configuração do Git foi cancelada."
    exit 1
fi

# 1. Configurar o nome global
git config --global user.name "$GIT_NAME"
echo "✅ Nome de utilizador Git configurado: $GIT_NAME"

# 2. Configurar o email global
git config --global user.email "$GIT_EMAIL"
echo "✅ Email Git configurado: $GIT_EMAIL"

# 3. Opcional: Configurar o editor padrão (nvim)
# Assumimos que o Neovim será o editor padrão.
git config --global core.editor "nvim"
echo "✅ Editor Git configurado para Neovim."

echo "--- Configuração Git Concluída ---"

echo '-----------------------------------'
echo "Installation completed! Please restart your computer with 'sudo shutdown -r now'"
