#!/bin/bash

# ------------------------------------------------------------------------------
# Stephen's Fedora Setup Script
#
# To use, run: 
# wget "https://raw.githubusercontent.com/SRF-Audio/utility-scripts/main/fedora-setup.sh" -O setup.sh && chmod +x setup.sh && ./setup.sh
# ------------------------------------------------------------------------------

sudo dnf update -y
sudo dnf upgrade -y


# Git
sudo dnf install git -y

# Homebrew
sudo dnf groupinstall 'Development Tools'
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
(echo; echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"') >> $HOME/.bashrc
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# zsh
sudo dnf install zsh -y
chsh -s $(which zsh)

# oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
echo 'ZSH_THEME="agnoster"' >> ~/.zshrc
source ~/.zshrc
(echo; echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"') >> $HOME/.zshrc
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# 1password
sudo rpm --import https://downloads.1password.com/linux/keys/1password.asc
sudo sh -c 'echo -e "[1password]\nname=1Password Stable Channel\nbaseurl=https://downloads.1password.com/linux/rpm/stable/\$basearch\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=\"https://downloads.1password.com/linux/keys/1password.asc\"" > /etc/yum.repos.d/1password.repo'
sudo dnf install 1password

# VS Code
VS_CODE_URL="https://code.visualstudio.com/sha/download?build=stable&os=linux-rpm-x64"
wget "$VS_CODE_URL" -O vscode.rpm
sudo dnf install ./vscode.rpm -y
rm ./vscode.rpm

# Slack
SLACK_URL="https://downloads.slack-edge.com/releases/linux/4.35.126/prod/x64/slack-4.35.126-0.1.el8.x86_64.rpm"
wget "$SLACK_URL" -O slack.rpm
sudo dnf install ./slack.rpm -y
rm ./slack.rpm

# Brave
sudo dnf install dnf-plugins-core -y
sudo dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
sudo rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
sudo dnf install brave-browser -y

# TigerVNC
sudo dnf install tigervnc -y

read -p "Do you want to install extra developer tools? (y/n) " install_devtools

if [ "$install_devtools" = "y" ]; then
    # Docker
    sudo dnf -y install dnf-plugins-core
    sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    sudo dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl start docker
    sudo usermod -aG docker $USER
    newgrp docker
    
    is_vm() {
        if command -v dmidecode >/dev/null 2>&1; then
            if dmidecode -s system-manufacturer | grep -iqE 'vmware|virtualbox|kvm|xen|qemu|microsoft'; then
                return 0 
            fi
        fi
        return 1
    }
    
    if ! is_vm; then
        echo "Not in a VM, proceeding with Docker Desktop installation..."
        wget -O docker-desktop.rpm "https://desktop.docker.com/linux/main/amd64/docker-desktop-4.25.1-x86_64.rpm"
        sudo dnf install ./docker-desktop.rpm
        rm ./docker-desktop.rpm
    else
        echo "Running in a VM. Skipping Docker Desktop installation."
    fi
    
    # nerd-fonts
    mkdir -p ~/.local/share/fonts
    cd ~/.local/share/fonts && curl -fLO https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/FiraMono/Regular/FiraMonoNerdFontMono-Regular.otf
    
    # Install developer tools
    sudo dnf install jq
    brew install python go kind kubectl helm kustomize skaffold istioctl derailed/k9s/k9s fx yh
    echo "alias python='python3'" >> ~/.bashrc
    echo "alias python='python3'" >> ~/.zshrc
    python3 -m ensurepip --upgrade
    echo "alias pip='pip3'" >> ~/.bashrc
    echo "alias pip='pip3'" >> ~/.zshrc
    source ~/.bashrc
    source ~/.zshrc
fi

fedora_version=$(rpm -E %fedora)

# Check for NVIDIA graphics cards
if lspci | grep -iqE 'nvidia'; then
    echo "NVIDIA graphics card detected. Installing drivers..."

    # Install RPM Fusion repositories (free and nonfree)
    sudo dnf install "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_version}.noarch.rpm"
    sudo dnf install "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_version}.noarch.rpm"

    # Update DNF repositories
    sudo dnf update -y

    # Check if any NVIDIA packages are installed and remove them if found
    if dnf list installed '*nvidia*' &> /dev/null; then
        echo "Removing installed NVIDIA packages..."
        sudo dnf remove '*nvidia*'
    else
        echo "No NVIDIA packages found to remove."
    fi

    sudo dnf install akmod-nvidia xorg-x11-drv-nvidia xorg-x11-drv-nvidia-libs.i686 xorg-x11-drv-nvidia-cuda

    echo "blacklist nouveau" | sudo tee -a /etc/modprobe.d/blacklist.conf
    sudo dracut --force

    sudo dnf update kernel

    # Check for Secure Boot status
    if mokutil --sb-state | grep -qiE 'enabled'; then
        echo -e "\e[33mSecure Boot is enabled. You'll need to disable Secure Boot to finish the NVIDIA drivers installation properly.\e[0m"
    else
        echo "NVIDIA drivers installed successfully."
    fi

else
    echo "No NVIDIA graphics card detected."
fi

sudo reboot
