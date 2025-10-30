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

USER ${USERNAME}

CMD ["zsh"]
