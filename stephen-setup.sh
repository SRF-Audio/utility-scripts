#!/bin/bash

# ------------------------------------------------------------------------------
# Stephen's Ubuntu Setup Script
#
# Prior to running this script, ensure the following commands have been run:
# git clone https://github.com/SRF-Audio/ubuntu-setup.git && cd ubuntu-setup && chmod +x stephen_setup.sh && ./stephen-setup.sh
# ------------------------------------------------------------------------------

# Get email for ssh key generation from the user
read -p "Please enter your email for ssh key generation: " email_address

# Update & Upgrade
sudo apt update -y && sudo apt upgrade -y

# Install necessary tools
sudo apt install -y wget zsh git-all fonts-powerline xclip

# Set zsh as default shell
chsh -s $(which zsh)

# Install oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Install nerd fonts
curl -OL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraMono.tar.xz
git clone https://github.com/ryanoasis/nerd-fonts.git
cd nerd-fonts && ./install.sh FiraMono
cd .. && rm -rf nerd-fonts

# Update .zshrc with theme and settings
echo 'ZSH_THEME="agnoster"' >> ~/.zshrc

# Source .zshrc to apply changes
source ~/.zshrc

# Generate SSH key using provided email
ssh-keygen -t ed25519 -C "$email_address" -N ""

# Create directory
mkdir -p ~/GitLab

# Set default directory in .zshrc to GitLab
echo 'cd ~/GitLab' >> ~/.zshrc

# Copy SSH key to clipboard
xclip -sel clip < ~/.ssh/id_ed25519.pub

# Notification
echo "The GitLab ssh key has been copied to the clipboard. Please add it to your GitLab account."

