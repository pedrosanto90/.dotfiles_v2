#!/bin/bash

USER_NAME=$(logname 2>/dev/null || echo ${SUDO_USER}) 
HOME_DIR="/home/$USER_NAME" 

cd /home/$USER_NAME

cat << EOF > /etc/apt/sources.list
# Repositórios Debian 13 (Trixie)
deb http://deb.debian.org/debian/ trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ trixie-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security/ trixie-security main contrib non-free non-free-firmware
EOF

apt clean
apt update -y
apt upgrade -y

su - "$USER_NAME" -c "
  cd \"$HOME_DIR\"
  mkdir -p .config scripts Documents Downloads Pictures Music Videos
  mkdir -p Documents/projects
  mkdir -p Documents/work/domatica
"

#core packages
apt install -y \
  xserver-xorg i3 i3status rofi dmenu fzf lightdm tmux nitrogen \
  zsh git curl wget build-essential cmake make ninja-build pkg-config libtool libtool-bin gettext unzip \
  network-manager network-manager-gnome network-manager-openvpn network-manager-openvpn-gnome \
  gvfs-backends blueman chromium x11-xserver-utils maim xclip pulseaudio-utils brightnessctl \
  arandr eza bat \
  npm python3 python3-pip snapd

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
cd noevim
make CMAKE_BUILD_TYPE=RelWithDebInfo
make install
cd

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

#oh my zsh
sh -c "$(wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)"

#nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash

# configure to use node 22
nvm isntall 22
nvm alias default 22

cd ~
rm -rf .zshrc
rm -rf .zprofile
rm -rf .zsh_history

git clone https://pedrosanto90/.dotfiles_v2.git

#create symlinks to dotfiles
# i3, i3status, wezterm, nvim -> ~/.config
ln -s ~/.dotfiles_v2/i3 ~/.config/i3
ln -s ~/.dotfiles_v2/i3status ~/.config/i3status
ln -s ~/.dotfiles_v2/wezterm ~/.config/wezterm
ln -s ~/.dotfiles_v2/nvim ~/.config/nvim

# tmux -> ~
ln -s ~/.dotfiles_v2/tmux/* ~

# scripts -> ~/scripts
ln -s ~/.dotfiles_v2/scripts/* ~/scripts/

# wallpaper -> ~/Pictures
ln -s ~/.dotfiles_v2/wallpaper/* ~/Pictures/

# zsh -> ~
ln -s ~/.dotfiles_v2/zsh/.* ~

# configure git
cd ~
echo "Configuring git..."
echo "-----------------------------------"
echo "Prepare to answer some questions:"
sleep 5
./scripts/configure_git.sh

echo '-----------------------------------'
echo "Installation completed! Please restart your computer with 'sudo shutdown -r now'"
