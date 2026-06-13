#!/usr/bin/env bash
# Identify which of Stephen's machines and which environment this session runs in.
set -uo pipefail

os=$(uname -s)
if [[ $os == Darwin ]]; then
  echo "machine: mac-mini"
  echo "env: native macOS $(sw_vers -productVersion 2>/dev/null || true)"
  echo "rules: brew for packages; launchd not systemd; BSD userland (sed/grep/date differ)"
  exit 0
fi

cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ //')
case $cpu in
  *"7700X"*)  machine="desktop" ;;
  *"HX 370"*) machine="laptop" ;;
  *)          machine="unknown" ;;
esac
echo "machine: $machine ($cpu)"
echo "hostname: $(cat /run/host/etc/hostname 2>/dev/null || hostname)"

self=$(grep -m1 '^PRETTY_NAME=' /etc/os-release | cut -d'"' -f2)
if [[ -n ${CONTAINER_ID:-} || -e /run/.containerenv ]]; then
  host_os=$(grep -m1 '^PRETTY_NAME=' /run/host/etc/os-release 2>/dev/null | cut -d'"' -f2)
  echo "env: distrobox '${CONTAINER_ID:-unknown}' ($self) on host: ${host_os:-unknown}"
  if [[ -e /run/host/run/ostree-booted ]]; then
    echo "host: immutable (ostree-booted) — never dnf on host; rpm-ostree (avoid, needs reboot) or flatpak"
  fi
  echo "rules: dnf OK inside this container; host-only tools (op, podman, tailscale, flatpak, rpm-ostree, systemctl) via distrobox-host-exec; /home aliases /var/home on the host"
elif [[ -e /run/ostree-booted ]]; then
  echo "env: native immutable Linux ($self)"
  echo "rules: no dnf install — rpm-ostree/flatpak/distrobox; prefer doing work inside a distrobox"
else
  echo "env: native mutable Linux ($self)"
  echo "rules: dnf and systemd directly; no container indirection"
fi
