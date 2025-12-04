FROM fedora:43

# Update all packages
RUN dnf -y upgrade

# Install Python and Ansible (system packages)
RUN dnf -y install \
    python3 \
    python3-pip \
    ansible

# Clean up dnf caches to reduce image size
RUN dnf clean all && rm -rf /var/cache/dnf

WORKDIR /workspace
