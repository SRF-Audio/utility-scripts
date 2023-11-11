#!/bin/bash

# ------------------------------------------------------------------------------
# Stephen's Fedora Setup Script
#
# To use, run: 
# wget "https://github.com/SRF-Audio/utility-scripts/blob/main/fedora-setup.sh" -O setup.sh && chmod +x setup.sh && ./setup.sh
# ------------------------------------------------------------------------------

sudo dnf update -y

# Git
sudo dnf install git -y

# 1password
sudo rpm --import https://downloads.1password.com/linux/keys/1password.asc
sudo sh -c 'echo -e "[1password]\nname=1Password Stable Channel\nbaseurl=https://downloads.1password.com/linux/rpm/stable/\$basearch\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=\"https://downloads.1password.com/linux/keys/1password.asc\"" > /etc/yum.repos.d/1password.repo'
sudo dnf install 1password

# VS Code
VS_CODE_URL="https://code.visualstudio.com/sha/download?build=stable&os=linux-rpm-x64"
wget "$VS_CODE_URL" -O vscode.rpm
sudo dnf install ./vscode.rpm -y
rm ./vscode.rpm


SLACK_URL="https://downloads.slack-edge.com/releases/linux/4.35.126/prod/x64/slack-4.35.126-0.1.el8.x86_64.rpm"
wget "$SLACK_URL" -O slack.rpm
sudo dnf install ./slack.rpm -y
rm ./slack.rpm
