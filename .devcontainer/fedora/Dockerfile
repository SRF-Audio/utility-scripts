ARG BASE_IMAGE=fedora:42
FROM ${BASE_IMAGE}


# ----- OS + build deps --------------------------------------------------
RUN dnf -y update && \
    dnf -y install \
    sudo git curl ca-certificates openssh awk \
    python3 python3-pip gcc make redhat-rpm-config \
    python3-devel python3-libdnf5 oniguruma-devel libffi-devel \
    openssl-devel procps-ng glibc-langpack-en langpacks-en && \
    dnf clean all

RUN update-ca-trust

ENV LANG=en_US.UTF-8

RUN printf 'LANG=en_US.UTF-8\n' > /etc/locale.conf

RUN python3 -m pip install --no-cache-dir --upgrade pip && \
    pip install ansible ansible-lint ansibug ansible-dev-tools

RUN rpm --import https://downloads.1password.com/linux/keys/1password.asc
RUN sh -c 'echo -e "[1password]\nname=1Password Stable Channel\nbaseurl=https://downloads.1password.com/linux/rpm/stable/\$basearch\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=\"https://downloads.1password.com/linux/keys/1password.asc\"" > /etc/yum.repos.d/1password.repo'
RUN dnf check-update -y 1password-cli && dnf install -y 1password-cli

USER ${USERNAME}

CMD ["zsh"]
