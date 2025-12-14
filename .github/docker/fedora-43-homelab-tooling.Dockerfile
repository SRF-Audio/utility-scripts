FROM fedora:43

# Update all packages
RUN dnf -y upgrade

# Install Python and Ansible (system packages)
RUN dnf -y install \
    python3 \
    python3-pip \
    git \
    tree \
    vim \
    curl \
    wget \
    jq \
    net-tools \
    iputils \
    openssh-clients \
    binutils \
    which \
    sudo \
    tmux \
    && dnf -y clean all

RUN $ python3 -m pip install ansible

# Clean up dnf caches to reduce image size
RUN dnf clean all && rm -rf /var/cache/dnf

WORKDIR /workspace