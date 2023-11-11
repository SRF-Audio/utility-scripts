#!/bin/bash

# ------------------------------------------------------------------------------
# Stephen's Ubuntu Setup Script
#
# Prior to running this script, ensure the following commands have been run:
# touch stephen-setup.sh
# vim stephen-setup.sh
# <paste this script into vim, and save/exit>
# chmod +x stephen-setup.sh && ./stephen-setup.sh
# ------------------------------------------------------------------------------

# Get email for ssh key generation from the user
read -p "Please enter your email for ssh key generation: " email_address

# Get passphrase for ssh key securely
read -sp "Enter passphrase for the ssh key (press enter for no passphrase): " ssh_passphrase
echo # Insert a new line after the passphrase input for cleaner output

# Update & Upgrade
sudo apt update -y && sudo apt upgrade -y

# Install necessary tools
sudo apt install -y wget zsh git-all fonts-powerline xclip

# Set zsh as default shell
chsh -s $(which zsh)

# Install oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Update .zshrc with theme and settings
echo 'ZSH_THEME="agnoster"' >> ~/.zshrc

# Source .zshrc to apply changes
source ~/.zshrc

# install HomeBrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
(echo; echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"') >> $HOME/.zshrc
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
sudo apt-get install build-essential
brew install gcc

# Install nerd fonts
git clone https://github.com/ryanoasis/nerd-fonts.git
cd nerd-fonts && ./install.sh FiraMono
cd .. && rm -rf nerd-fonts

# Generate SSH key using provided email and passphrase
ssh-keygen -t ed25519 -C "$email_address" -N "$ssh_passphrase"

# Create directory
mkdir -p ~/GitLab

# Set default directory in .zshrc to GitLab
echo 'cd ~/GitLab' >> ~/.zshrc

# Install software tools
brew install python
sudo apt install python3-pip -y
echo "alias python='python3'" >> ~/.zshrc
source ~/.zshrc

brew install go

brew install kustomize

brew install skaffold

brew install derailed/k9s/k9s

# Copy SSH key to clipboard
xclip -sel clip < ~/.ssh/id_ed25519.pub

# Notification
echo "The GitLab ssh key has been copied to the clipboard. Please add it to your GitLab account."
