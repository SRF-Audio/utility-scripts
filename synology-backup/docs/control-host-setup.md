# Control-Host Prerequisites

This document describes everything that must be true on the machine you run `ansible-playbook` from before the playbook will succeed.

---

## 1. Ansible

Install Ansible and the required collection:

```bash
pip install ansible
ansible-galaxy collection install -r ansible/requirements.yml
```

Verify:

```bash
ansible --version          # >= 2.14 recommended
ansible-galaxy collection list | grep community.general   # must appear
```

---

## 2. 1Password CLI (`op`)

All secrets are fetched at playbook runtime via the `community.general.onepassword` lookup plugin, which shells out to `op`. The CLI must be installed **and** authenticated before running the playbook.

### Install

```bash
# macOS
brew install 1password-cli

# Linux (Debian/Ubuntu)
curl -sS https://downloads.1password.com/linux/keys/1password.asc \
  | sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] \
  https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" \
  | sudo tee /etc/apt/sources.list.d/1password.list
sudo apt update && sudo apt install 1password-cli
```

### Authenticate

Interactive session (personal account):

```bash
op signin
```

Service account (CI / unattended runs):

```bash
export OP_SERVICE_ACCOUNT_TOKEN=<token>
```

Verify:

```bash
op account list     # must return at least one account
op vault list       # HomeLab vault must appear
```

---

## 3. Required 1Password Items

All items must exist in the **HomeLab** vault before the playbook is run.

| Item title | Type | Fields required |
|---|---|---|
| `Synology Restic Repository` | Login or Secure Note | `password` — restic repo encryption password |
| `Hetzner Storage Box SSH Key` | SSH Key | `private key` — ed25519 private key (OpenSSH format) |
| `Hetzner` | Login | Section `add more`: `storagebox_host`, `storagebox_username`, `storagebox_host_key` |

### Capturing the Storage Box host key (one-time)

Run this from any machine that can reach the Storage Box on port 23:

```bash
ssh-keyscan -p 23 u579903.your-storagebox.de
```

Copy the **ed25519** line (starts with `ssh-ed25519 AAAA...`) and store the portion after the hostname — i.e., `ssh-ed25519 AAAA...` — as the `storagebox_host_key` field value in the `Hetzner` 1Password item.

> The `ansible.builtin.known_hosts` task formats the entry as
> `[host]:port key-type key-data`, so store only the `key-type key-data`
> portion (e.g. `ssh-ed25519 AAAAC3Nza...`).

---

## 4. SSH Access to the Synology NAS

The control-host user's public key must be in `/var/services/homes/admin/.ssh/authorized_keys` on the NAS.

On the NAS (one-time, via DSM web UI or direct SSH):

```bash
mkdir -p /var/services/homes/admin/.ssh
chmod 700 /var/services/homes/admin/.ssh
echo "<your-control-host-pubkey>" >> /var/services/homes/admin/.ssh/authorized_keys
chmod 600 /var/services/homes/admin/.ssh/authorized_keys
```

Verify connectivity:

```bash
ssh -p 22 admin@<nas-tailscale-ip> 'echo ok'
```

---

## 5. Synology NAS One-Time Manual Setup

In the DSM web UI:

1. **Control Panel → Terminal & SNMP** → Enable SSH service (port 22)
2. **Package Center** → Install **Python 3.x** (required by Ansible's raw connection)

---

## 6. Running the Playbook

```bash
cd synology-backup/ansible
ansible-playbook -i inventories/hosts.yml playbooks/synology-backup.yml
```

The playbook is idempotent — safe to re-run.

---

## 7. Failure Alerting Configuration

The wrapper scripts support an optional alert command injected via the
`synology_restic_backup_alert_command` role variable (default: empty — no alerts).

The command receives the alert message on stdin. Examples:

```yaml
# Email via msmtp (if configured on the NAS)
synology_restic_backup_alert_command: "msmtp you@example.com"

# healthchecks.io ping-fail endpoint
synology_restic_backup_alert_command: >-
  curl -fsS -m 10 --retry 3
  -o /dev/null
  --data-binary @-
  https://hc-ping.com/<uuid>/fail
```

Set this in the playbook `vars:` block or in `inventories/group_vars/synology_nas.yml`.
