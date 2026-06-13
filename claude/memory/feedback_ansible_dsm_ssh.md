---
name: feedback-ansible-dsm-ssh
description: How to connect Ansible (and direct SSH) to a Synology NAS — the specific workarounds required
metadata:
  type: feedback
---

# Ansible SSH to Synology DSM

Use `ansible_password` from 1Password + `ansible_become: true` with passwordless sudo. Do NOT use the ssh connection plugin's default behavior with DSM.

**Why:** DSM's SSH daemon uses PAM-based pubkey auth. Ansible hardcodes `-o KbdInteractiveAuthentication=no` which breaks it. Password auth from 1Password sidesteps the entire problem.

**How to apply:**
- `ansible_password: "{{ lookup('community.general.onepassword', '<item-id>', field='password', vault='HomeLab') }}"`
- User must have passwordless sudo: `echo "username ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/username`
- `ansible_connection: paramiko` does NOT work — it can't use the SSH agent
- DSM has no `crontab` binary — use `ansible.builtin.blockinfile` on `/etc/crontab` (system crontab format with username column)
- DSM has no `ssh-keyscan` — pre-populate known_hosts from control host
- 1Password SSH Key items return PKCS#8 format by default; use `op read "op://vault/item/field?ssh-format=openssh"` for OpenSSH format
- **Direct SSH (non-Ansible):** The 1Password SSH agent (`~/.1password/agent.sock`) does NOT reliably serve the NAS key from the control host. Use the key file directly: `ssh -i ~/.ssh/coachlight-homelab.pem stephenfroeber@192.168.226.6`
- Internal IP (`192.168.226.6`) is more reliable than Tailscale hostname for direct SSH; hostname `srfaudio.rohu-shark.ts.net` also works
