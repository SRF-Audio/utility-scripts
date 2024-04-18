#!/bin/bash

# ------------------------------------------------------------------------------
# Stephen's Debian/Ubuntu Setup Script
#
# To run this script use:
# sudo apt install -y wget && wget "https://raw.githubusercontent.com/SRF-Audio/utility-scripts/main/debian-setup.sh" -O setup.sh && chmod +x setup.sh && ./setup.sh
# ------------------------------------------------------------------------------

# Ask the user for their choice of Git platform
echo "Select your preferred Git hosting service:"
echo "1) GitHub"
echo "2) GitLab"

while true; do
    read -p "Enter your choice (1 or 2): " git_choice

    case $git_choice in
        1)
            git_service="GitHub"
            break
            ;;
        2)
            git_service="GitLab"
            break
            ;;
        *)
            echo "Invalid input. Please enter 1 for GitHub or 2 for GitLab."
            ;;
    esac
done

# Get email for ssh key generation from the user
read -p "Please enter your email for ssh key generation: " email_address

# Get passphrase for ssh key securely
read -sp "Enter passphrase for the ssh key (press enter for no passphrase): " ssh_passphrase
echo # Insert a new line after the passphrase input for cleaner output

# Update & Upgrade
sudo apt update -y && sudo apt upgrade -y

# Install necessary tools
sudo apt install -y zsh git-all fonts-powerline xclip net-tools

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

ssh-keygen -t ed25519 -C "$email_address" -N "$ssh_passphrase"

# Create directory based on user choice
mkdir -p ~/"$git_service"

# Set default directory in .zshrc to the chosen platform
echo "cd ~/$git_service" >> ~/.zshrc

echo "Default directory set to $git_service in .zshrc."


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
echo "Setup complete, and the $git_service ssh key has been copied to the clipboard. Please add it to your account now."
