ARG BASE_IMAGE=fedora:42
FROM ${BASE_IMAGE}


# ----- OS + build deps --------------------------------------------------
RUN dnf -y update && \
    dnf -y install \
    sudo git curl ca-certificates openssh-clients shadow-utils awk \
    which gnupg tree vim htop net-tools bind-utils wget jq openssl unzip \
    python3 python3-pip gcc make redhat-rpm-config \
    python3-devel python3-libdnf5 oniguruma-devel libffi-devel \
    openssl-devel procps-ng glibc-langpack-en langpacks-en zsh && \
    dnf clean all

RUN update-ca-trust

ENV LANG=en_US.UTF-8

RUN printf 'LANG=en_US.UTF-8\n' > /etc/locale.conf

RUN python3 -m pip install --no-cache-dir --upgrade pip && \
    pip install ansible ansible-lint ansibug ansible-dev-tools

# 1Password CLI
RUN rpm --import https://downloads.1password.com/linux/keys/1password.asc
RUN sh -c 'echo -e "[1password]\nname=1Password Stable Channel\nbaseurl=https://downloads.1password.com/linux/rpm/stable/\$basearch\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=\"https://downloads.1password.com/linux/keys/1password.asc\"" > /etc/yum.repos.d/1password.repo'
RUN dnf check-update -y 1password-cli && dnf install -y 1password-cli

# kubectl
ARG KUBECTL_VERSION=v1.33.5
RUN echo -e "[kubernetes]\nname=Kubernetes\nbaseurl=https://pkgs.k8s.io/core:/stable:/${KUBECTL_VERSION}/rpm/\nenabled=1\ngpgcheck=0" > /etc/yum.repos.d/kubernetes.repo \
    && dnf install -y kubectl

# k9s
ARG K9S_VERSION=v0.50.18
RUN ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/') \
    && curl -Lo /tmp/k9s.rpm "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_linux_${ARCH}.rpm" \
    && dnf install -y /tmp/k9s.rpm \
    && rm -f /tmp/k9s.rpm

# Helm
# Docs: https://helm.sh/docs/intro/install/
RUN curl -fsSL -o /tmp/get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4 \
    && chmod 700 /tmp/get_helm.sh \
    && /tmp/get_helm.sh \
    && rm /tmp/get_helm.sh

# Kustomize
# Docs: https://kubectl.docs.kubernetes.io/installation/kustomize/
ARG KUSTOMIZE_VERSION=5.8.1
RUN ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/') \
    && curl -Lo /tmp/kustomize.tar.gz "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_${ARCH}.tar.gz" \
    && tar -xzf /tmp/kustomize.tar.gz -C /tmp/ \
    && mv /tmp/kustomize /usr/local/bin/ \
    && rm /tmp/kustomize.tar.gz

# Terraform
# Docs: https://developer.hashicorp.com/terraform/install
RUN dnf install -y dnf-plugins-core \
    && dnf config-manager addrepo --from-repofile=https://rpm.releases.hashicorp.com/fedora/hashicorp.repo \
    && dnf install -y terraform

# AWS CLI v2
# Docs: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
RUN ARCH=$(uname -m) \
    && curl "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH}.zip" -o /tmp/awscliv2.zip \
    && unzip /tmp/awscliv2.zip -d /tmp/aws-installer \
    && /tmp/aws-installer/aws/install \
    && rm -rf /tmp/awscliv2.zip /tmp/aws-installer

# hcloud CLI (Hetzner Cloud)
# Docs: https://github.com/hetznercloud/cli
# Version: check https://github.com/hetznercloud/cli/releases/latest
ARG HCLOUD_VERSION=1.46.0
RUN ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/') \
    && curl -Lo /tmp/hcloud.tar.gz "https://github.com/hetznercloud/cli/releases/download/v${HCLOUD_VERSION}/hcloud-linux-${ARCH}.tar.gz" \
    && tar -xzf /tmp/hcloud.tar.gz -C /tmp/ \
    && mv /tmp/hcloud /usr/local/bin/ \
    && rm /tmp/hcloud.tar.gz

# Node.js + Claude Code CLI (required for anthropic.claude-code VSCode extension)
# Docs: https://docs.anthropic.com/en/docs/claude-code/getting-started
RUN dnf install -y nodejs npm \
    && npm install -g @anthropic-ai/claude-code

# ----- User setup -------------------------------------------------------
ARG USER_UID=1000
ARG USER_GID=1000
ARG USERNAME=vscode

RUN getent group ${USER_GID} || groupadd --gid ${USER_GID} ${USERNAME} \
    && id -u ${USER_UID} &>/dev/null || useradd --uid ${USER_UID} --gid ${USER_GID} -m --shell /bin/zsh ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# oh-my-zsh with plugins and agnoster theme
# RUNZSH=no and CHSH=no prevent the installer from trying to launch zsh or change the shell (both fail in Docker builds)
USER ${USERNAME}
RUN RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    && git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions \
    && git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting \
    && sed -i 's/^ZSH_THEME=.*/ZSH_THEME="agnoster"/' ~/.zshrc \
    && sed -i 's/^plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc \
    && mkdir -p ~/.ssh && chmod 700 ~/.ssh
USER root

WORKDIR /workspace

CMD ["sleep", "infinity"]
