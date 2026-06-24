# Aurora-DX ASUS Hardware Inventory — 2026-06-24

Host: `sfroeber-amd-aurora-laptop` (ASUS ROG Zephyrus G16 GA605WI, Ryzen AI 9 HX 370 + NVIDIA dGPU)
Image: `ghcr.io/ublue-os/aurora-dx-nvidia-open:stable`, version 44.20260623.1, base Kinoite/Fedora 44
Investigated from inside the `fedora` distrobox via `flatpak-spawn --host` (read-only recon, nothing changed).

## Image Identity

- Image: `ghcr.io/ublue-os/aurora-dx-nvidia-open:stable`
- Version: 44.20260623.1 (2026-06-23), base Kinoite, Fedora 44
- User-layered packages: `1password`, `1password-cli` (only)
- `nvidia-open` flavor is correct, not a mismatch — fwupd identifies the model as the GA605WI (the "WI" suffix is the NVIDIA dGPU variant), confirmed by active `nvidia_drm`/`nvidia_modeset`/`nvidia_uvm` modules and `nvidia-powerd.service`.

## ASUS Tooling

| Package | Version | Source |
|---|---|---|
| supergfxctl | 5.2.7-8.fc44 | base image (installed binary + active service) |
| asusctl | absent | not installed — no binary, no package |
| asusd | absent | not installed — no binary, no systemd unit file, yet `/etc/asusd/*.ron` config survives from a prior install (dated Dec 2025, with `.ron-old` backups from Apr 2025) |
| rog-control-center | absent | not installed |

## Services

| Service | State |
|---|---|
| supergfxd.service | active, enabled |
| nvidia-powerd.service | active |
| systemd-backlight@leds:asus::kbd_backlight.service | active (exited — one-shot brightness restore) |
| tuned.service | active |
| tuned-ppd.service | active — shims `power-profiles-daemon`'s D-Bus API via TuneD |
| upower.service | active |
| asusd | inactive/absent |
| power-profiles-daemon | not installed (package absent; tuned-ppd substitutes) |
| tlp | inactive/absent |
| fwupd | inactive (present, on-demand) |

## Kernel Modules (ASUS-relevant)

- Loaded natively, no DKMS: `asus_wmi`, `asus_nb_wmi`, `asus_armoury`, `hid_asus`, `firmware_attributes_class`, `platform_profile`, `sparse_keymap`
- GPU stack: `amdgpu`, `i915` alongside `nvidia`/`nvidia_drm`/`nvidia_modeset`/`nvidia_uvm`/`nvidia_wmi_ec_backlight` — confirms hybrid AMD APU + NVIDIA dGPU (Optimus-style)
- Notable journal entries (`journalctl -k -b`, raw `dmesg` was permission-blocked):
  - `asus_wmi: ASUS WMI generic driver loaded`, `asus-nb-wmi: Detected ATK, not ASUSWMI, use DSTS`
  - `Using throttle_thermal_policy for platform_profile support` — native kernel-level platform profile support, no asusd required for this baseline function
  - `ACPI: battery: new hook: ASUS Battery Extension`
  - Cirrus Logic `cs35l56-hda` speaker amp DSP firmware loaded for model `GA605W`
  - Benign HID handshake oddity: `Asus handshake 5e failed to receive ack: -32` (commonly seen on this chassis, cosmetic)

## Configuration Files

- asusd config: **present but orphaned** — `/etc/asusd/asusd.ron`, `aura_19b6.ron` (RGB/Aura), `fan_curves.ron`, `slash.ron` (AniMe Matrix/Slash lightbar), each with `-old` backups. Key settings in `asusd.ron`: AC/battery platform-profile switching (`Performance` on AC, `Quiet` on battery), charge limit 100%, `disable_nvidia_powerd_on_battery: true`. Leftovers from a previously-installed-then-removed `asusd` — no service consumes them now.
- udev rules: none ASUS-specific in `/usr/lib/udev/rules.d/` or `/etc/udev/rules.d/`. Device matching relies entirely on in-kernel WMI/HID drivers, not udev.

## Firmware

- fwupd devices: full ASUS UEFI/BIOS/EC chain visible (PK/KEK/db certs, AMD PSP microcontroller, NVMe drive) — standard fwupd/UEFI capability, not ASUS-Linux-specific tooling.
- Firmware files: only generic `amdgpu` blobs under `/usr/lib/firmware/`; no dedicated `asus/` firmware directory (none needed — WMI/HID is driver-only).

## Trackpad / Input

- Only one ASUS-vendor input device visible through the container's restricted permissions: `ITE Tech. Inc. ITE Device(8910)` (usb:0b05:19b6 — `0b05` is ASUSTeK's USB vendor ID), enumerated by libinput as keyboard+pointer.
- `/usr/share/libinput/50-system-asus.quirks` is present, but this is a **stock upstream libinput file** shipped generically with libinput on Fedora — not an Aurora-specific addition.
- **Resolved 2026-06-24, from a real host terminal (not through the distrobox):** the touchpad is `ASUF1209:00 2808:0219 Touchpad`, an **i2c-HID multitouch device** (`hid-multitouch` driver over `i2c_hid_acpi`, kernel node `event7`) — not a PS/2 `ETPS/2 Elantech` device, which is what every touchpad-matching stanza in `50-system-asus.quirks` targets (`Asus X555LAB`, `UX21E`, `UX302LA`). None of those `MatchName=*ETPS/2 Elantech Touchpad*` rules apply to this hardware, and there is no G16/Zephyrus/GA605-specific stanza anywhere in the file. The only G-series entries present are *keyboard* quirks (`Asus ROG Zephyrus G15 2021`, `Strix G15 2021`, `Flow Z13 2025` — all matching by USB VID `0x0B05`/PID, for disable-while-typing pairing), and none match this G16's keyboard VID/PID either.
- `libinput list-devices` (sudo) shows `dwt-on dwtp-on` (disable-while-typing / disable-while-trackpointing both active) — but this comes from libinput's **built-in** same-chassis pairing heuristic, not from a quirks-file match, since no quirks stanza applies here.
- `rpm -qi libinput`: version `1.31.3-1.fc44`, **Vendor: Fedora Project**, built on `buildhw-x86-09.rdu3.fedoraproject.org` — the literal upstream Fedora package, not an Aurora-patched build.
- **Conclusion: no Aurora-specific touchpad tweaking exists.** The `50-system-asus.quirks` file is the stock one shipped by upstream libinput on any Fedora install; it's present but inert for this exact hardware. Tap-to-click disabled / two-finger-edge scroll / etc. are either kernel-reported device defaults or KDE Plasma's own touchpad settings (System Settings → Touchpad), not anything Aurora layered in.

## Third-Party Repos

- `_copr:ublue-os:packages` and `_copr:ublue-os:staging` — present, disabled by default (`enabled=0`); upstream source for `supergfxctl` et al. when ublue layers them.
- No `asus-linux`/`lukenukem` COPR present anywhere — confirms asusctl/asusd absence is a deliberate gap, not a repo issue.
- Other notable repos: `linux-surface`, `negativo17-fedora-nvidia(-lts)`, `nvidia-container-toolkit`, `docker-ce`, `tailscale`, `1password`, `howdy`, `nextdns`, `vscode` — none ASUS-specific.

## Gap Analysis — Workstation Replication

To reach parity with this Aurora-DX configuration on stock Fedora Workstation:

1. Kernel ≥ Fedora's current stock kernel already ships `asus_wmi`/`asus_armoury`/`hid_asus` upstream — no Aurora-exclusive patches needed here.
2. Add the `lukenukem/asus-linux` (or current `asus-linux.org`) COPR to install `supergfxctl`. Aurora itself doesn't have `asusctl`/`asusd` installed either, so no extra step is needed to match *current* state — though the orphaned `/etc/asusd/*.ron` files suggest reinstalling `asusd` from that same repo to restore the previous fan-curve/Aura/Slash config, if desired.
3. Install `tuned`+`tuned-ppd` (or just `power-profiles-daemon` directly) for the `org.freedesktop.UPower.PowerProfiles` D-Bus interface GNOME/KDE power settings expect.
4. Enable `systemd-backlight@leds:asus::kbd_backlight.service` — template unit, auto-instantiates once the kernel driver creates the `leds:asus::kbd_backlight` sysfs node, should work automatically.
5. Install the NVIDIA driver stack with `nvidia-powerd` equivalent, plus `supergfxctl` for GPU mode switching.
6. No udev rules or firmware files need to be manually added — none exist beyond stock kernel/libinput behavior.
7. For feature parity with the orphaned config (RGB/Aura lighting, fan curves, Slash lightbar): install `asusd`/`asusctl` from the asus-linux COPR and manually recreate those `.ron` settings (charge limit 100%, AC=Performance/Battery=Quiet, `disable_nvidia_powerd_on_battery`).

## Verdict

The day-to-day ASUS hardware advantage Aurora provides here is thin — `asusctl`/`asusd` aren't even installed, core ASUS support (WMI, HID, platform-profile, battery hook, keyboard backlight) comes from the upstream kernel and is identical on stock Workstation, and the only meaningfully pre-wired pieces are `supergfxctl` plus the disabled-by-default ublue COPRs — all replicable on Workstation in a single COPR-add + package-install step. The trackpad question is now fully resolved (see Trackpad/Input section): Aurora does **no** ASUS-specific touchpad tweaking — it ships the same stock upstream libinput package and quirks file Workstation would, and that quirks file doesn't even match this G16's i2c-HID touchpad hardware.
