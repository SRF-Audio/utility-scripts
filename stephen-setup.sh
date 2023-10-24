#!/bin/bash

# Update & Upgrade
sudo apt update -y && sudo apt upgrade -y

# Install necessary tools
sudo apt install -y wget zsh git-all fonts-powerline xclip

# Set zsh as default shell
chsh -s $(which zsh)

# Install oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Install nerd fonts
git clone https://github.com/ryanoasis/nerd-fonts.git
cd nerd-fonts && ./install.sh
cd .. && rm -rf nerd-fonts

# Update .zshrc with theme and settings
echo 'ZSH_THEME="agnoster"' >> ~/.zshrc

# Source .zshrc to apply changes
source ~/.zshrc

# Generate SSH key
ssh-keygen -t ed25519 -C "sfroeber@applied-insight.com" -N ""

# Create directory
mkdir -p ~/GitLab

# Set default directory in .zshrc to GitLab
echo 'cd ~/GitLab' >> ~/.zshrc

# Copy SSH key to clipboard
xclip -sel clip < ~/.ssh/id_ed25519.pub

# Notification
echo "The GitLab ssh key has been copied to the clipboard. Please add it to your GitLab account."

