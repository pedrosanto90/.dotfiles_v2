#!/bin/bash

# this scipt installs the necessary tools for a debian based system
# it requires sudo privileges

DEB_OBSIDIAN_URL="https://github.com/obsidianmd/obsidian-releases/releases/download/v1.6.3/obsidian-1.6.3.deb"
DEB_ONLYOFFICE_URL="https://download.onlyoffice.com/install/desktop/editors/linux/onlyoffice-desktopeditors_amd64.deb"
DEB_WEBEX_URL="https://binaries.webex.com/WebexDesktopApp-linux-webex.deb"
DEB_DBEAVER_URL="https://dbeaver.io/files/dbeaver-ce_latest_amd64.deb"
BITWARDEN_APPIMAGE_URL="https://vault.bitwarden.com/download/?app=desktop&platform=linux&variant=appimage"
POSTMAN_TAR_URL="https://dl.pstmn.io/download/latest/linux_64"
INSOMNIA_DEB_URL="https://insomnia.rest/download/core/debian"

cd ~

mkdir -p ~/.config
mkdir -p ~/scripts
mkdir -p ~/Documents
mkdir -p ~/Downloads
mkdir -p ~/Documents/projects
mkdir -p ~/Documents/work/domatica
mkdir -p ~/Pictures
mkdir -p ~/Music
mkdir -p ~/Videos

# first we update the package list and then upgrade existing packages
sudo apt update -y
sudo apt upgrade -y

# replace sources.list with debian 13 (trixie) repositories

cat << EOF > /etc/apt/sources.list
# Repositórios Debian 13 (Trixie) gerados pelo script
deb http://deb.debian.org/debian/ trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ trixie-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security/ trixie-security main contrib non-free non-free-firmware
EOF

# update and upgrade again
apt clean
apt update -y
apt upgrade -y
# install necessary packages
apt install -y xserver-xorg i3 i3status rofi dmenu fzf lightdm tmux nitrogen zsh git curl wget build-essential cmake make ninja-build pkg-config libtool libtool-bin gettext unzip network-manager network-manager-gnome network-manager-openvpn network-manager-openvpn-gnome thunar gvfs-backends gvfs-smb blueman chromium x11-xserver-utils maim xclip pulseaudio-utils brightnessctl arandr

# enable lightdm
systemctl enable lightdm

#install ohmyzsh
sh -c "$(wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)"

# set zsh as default shell
chsh -s $(which zsh)

# install wezterm
curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list
sudo chmod 644 /usr/share/keyrings/wezterm-fury.gpg

sudo apt update -y
sudo apt install -y wezterm

#install docker
sudo apt remove $(dpkg --get-selections docker.io docker-compose docker-doc podman-docker containerd runc | cut -f1)

# Add Docker's official GPG key:
sudo apt update -y
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
sudo systemctl start docker.service
sudo systemctl enable docker.service
# add user to docker group
sudo groupadd docker
sudo usermod -aG docker $USER

# install neovim from source
cd ~
git clone https://github.com/neovim/neovim
cd neovim
make CMAKE_BUILD_TYPE=Release
make install


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

# install node, python, npm, pip and nvm
sudo apt install -y npm python3 python3-pip
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm

nvm install 22
nvm default alias 22

# Clone dotfiles
git clone https://github.com/pedrosanto90/.dotfiles_v2.git

#create symlinks for config files
ln -s ~/.dotfiles_v2/i3/config ~/.config/i3
ln -s ~/.dotfiles_v2/i3status/config ~/.config/i3status
ln -s ~/.dotfiles_v2/wezterm/wezterm.lua ~/.config/wezterm
ln -s ~/.dotfiles_v2/nvim ~/.config/nvim
ln -s ~/.dotfiles_v2/tmux/.tmux.conf ~/.tmux.conf
ln -s ~/.dotfiles_v2/zsh/.zshrc ~/.zshrc
ln -s ~/.dotfiles_v2/zsh/.zshprofile ~/.zshprofile
ln -s ~/.dotfiles_v2/scripts ~/scripts
ln -s ~/.dotfiles_v2/wallpapper/lofi-bart.jpg ~/Pictures/lofi-bart.jpg

# configure git
echo "Configure git..."
./scripts/git_config.sh

echo "Installation completed! Please restart your computer."

