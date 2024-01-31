#!/bin/bash

# ------------------------------------------------------------------------------
# 
# 
# Stephen's MacOS Setup Script
#
# To use, run:
# curl https://raw.githubusercontent.com/SRF-Audio/utility-scripts/main/macos-setup.sh > macos-setup.sh && chmod +x macos-setup.sh && ./macos-setup.sh
# ------------------------------------------------------------------------------

# Check if Homebrew is installed, if not, install it
if ! command -v brew &> /dev/null
then
    echo "Homebrew could not be found, installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

(echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> $HOME/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"

# Install necessary tools
brew install git xclip

# Install compilers and build tools
brew install gcc

# Install software tools
brew install python
echo "alias python='python3'" >> ~/.zshrc
source ~/.zshrc
python3 -m ensurepip --upgrade
echo "alias pip='pip3'" >> ~/.zshrc
source ~/.zshrc

brew install go kustomize helm kubectl skaffold istioctl derailed/k9s/k9s 
brew install --cask 1password 
brew install --cask 1password-cli 
brew install --cask brave-browser 
brew install --cask iterm2
brew install --cask visual-studio-code
brew install --cask moom
brew install --cask microsoft-teams
brew install --cask slack
brew install --cask discord


