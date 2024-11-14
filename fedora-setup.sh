#!/bin/bash

# ------------------------------------------------------------------------------
# Stephen's Fedora Setup Script
#
# To use, run: 
# wget "https://raw.githubusercontent.com/SRF-Audio/utility-scripts/main/fedora-setup.sh" -O setup.sh && chmod +x setup.sh && ./setup.sh
# ------------------------------------------------------------------------------

sudo dnf install ansible git -y
mkdir -p GitHub && cd GitHub
git clone https://github.com/SRF-Audio/utility-scripts.git
cd utility-scripts/ansible
ansible-playbook fedora.yml

rm ~/setup.sh