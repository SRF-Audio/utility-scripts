#!/bin/bash

# ------------------------------------------------------------------------------
# 
# Stephen's MacOS Setup Script
#
# To use, run:
# curl https://raw.githubusercontent.com/SRF-Audio/utility-scripts/main/macos-setup.sh > macos-setup.sh && chmod +x macos-setup.sh && ./macos-setup.sh
#
# ------------------------------------------------------------------------------

if ! command -v brew &> /dev/null; then
    echo "Homebrew could not be found, installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "Updating Homebrew..."
    brew update
fi

(echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> $HOME/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"

function brew_install_or_update {
    if brew ls --versions "$1" >/dev/null; then
        echo "$1 is already installed, checking for updates..."
        brew upgrade "$1"
    else
        echo "Installing $1..."
        brew install "$1"
    fi
}

brew_formulae=(
    git
    jq
    xclip
    gcc
    python
    go
    kubectl
    helm
    kustomize
    skaffold
    istioctl
    k9s
)

brew_casks=(
    1password
    1password-cli
    brave-browser
    iterm2
    visual-studio-code
    moom
    microsoft-teams
    slack
    discord
    rancher
)

for formula in "${brew_formulae[@]}"; do
    brew_install_or_update "$formula"
done

for cask in "${brew_casks[@]}"; do
    brew_install_or_update "--cask $cask"
done

if ! grep -q "alias python='python3'" ~/.zshrc; then
    echo "alias python='python3'" >> ~/.zshrc
fi

python3 -m ensurepip --upgrade

if ! grep -q "alias pip='pip3'" ~/.zshrc; then
    echo "alias pip='pip3'" >> ~/.zshrc
fi

source ~/.zshrc

echo "Setup completed!"

