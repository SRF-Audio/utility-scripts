# utility-scripts

To use, run `git clone https://github.com/SRF-Audio/utility-scripts.git && cd utility-scripts && ./bootstrap.sh`

This repo is a list of useful setup scripts for different Linux Distros, and various cloud/kubernetes tools that I use. These allow me to spin up a new VM or container, and quickly bring it back to my preferred configuration.

## Contributing

If you find these useful, but see a way to make them better, or more efficient, feel free to open an issue. I appreciate the contribution.

## Notes

### Playbook high level strategy

Below is a pattern I’ve had good luck with on mixed-environment homelabs.  It follows the directory layout and role-centric workflow the Ansible docs call “sample-setup”, adding only enough structure to keep your desktop, hypervisor, VM, k3s and add-on services cleanly separated. ([docs.ansible.com][1])

---

## 1  Inventory: model the *hardware & OS* first

```
inventories/
└── homelab/
    ├── hosts.ini
    └── group_vars/
        ├── all.yml
        ├── desktops.yml          # KDE Fedora workstations & laptops
        ├── proxmox.yml          # Bare-metal hypervisors
        ├── vms_fedora.yml       # CoreOS / Server VMs
        ├── k3s_control.yml
        └── k3s_worker.yml
```

* **Hosts go in the most specific group only**; use Ansible’s built-in group inheritance (`children=` blocks) if something truly belongs to several groups.
* Put *behaviour* in `group_vars`, secrets in `vault.yml` (or call the 1Password lookup plug-in there).  This keeps secrets out of playbooks and roles.  ([docs.ansible.com][2], [docs.ansible.com][3])

---

## 2  Roles: one concern per role

Roles are how you make the codebase composable and testable.  Each role owns exactly one slice of configuration and can be reused on any host that needs it.  ([docs.ansible.com][4])

| Role name         | What it does                                                             | Typical tags |
| ----------------- | ------------------------------------------------------------------------ | ------------ |
| `common`          | Users, base packages, 1Password CLI, Tailscale client                    | `base`       |
| `updates`         | DNF/Yum/Apt upgrade or `rpm-ostree upgrade` with autoreboot guard        | `updates`    |
| `workstation_kde` | KDE settings, Plasma look-and-feel, Flatpak/pkg install                  | `gui`        |
| `proxmox_host`    | `/etc/hosts`, cluster join, pve-no-subscription repo, zfs tune           | `hypervisor` |
| `coreos_base`     | Ignition tweaks, rpm-ostree layers, podman                               | `vm`         |
| `ssh_keys`        | Generate ED25519 keys, sync public key from 1Password item, distribute   | `ssh`        |
| `k3s_control`     | Install k3s server, configure etcd-external, set node-labels             | `k3s`        |
| `k3s_worker`      | Join worker, taints, GPU runtime, kube-proxy flags                       | `k3s`        |
| `k8s_deploy`      | `k8s` / `helm` module calls that stand up Home-Assistant, InfluxDB, etc. | `apps`       |

*Anything* that may be useful on more than one host belongs in its own role; resist the urge to combine “desktop tweaks” with “OS updates”.

---

## 3  Playbooks: orchestration entry points

Keep playbooks thin—just “which hosts, which roles, in what order”.  Example:

```yaml
# playbooks/site.yml  ← run for the full stack
- name: Workstations
  hosts: desktops
  roles:
    - common
    - workstation_kde
    - ssh_keys
    - updates

- name: Proxmox hypervisors
  hosts: proxmox
  gather_facts: false           # PVE shell is fast; facts optional
  roles:
    - common
    - proxmox_host
    - ssh_keys
    - updates

- name: Fedora / CoreOS VMs
  hosts: vms_fedora
  roles:
    - common
    - coreos_base
    - updates

- name: k3s control plane
  hosts: k3s_control
  roles:
    - k3s_control
    - k8s_deploy            # if you want apps immediately

- name: k3s workers
  hosts: k3s_worker
  roles:
    - k3s_worker
```

### Useful siblings

```
playbooks/
├── site.yml           # full convergence
├── maintenance.yml    # just updates & reboots
└── k8s.yml            # (re)deploy apps only
```

---

## 4  Granularity & tagging rules of thumb

| Question to ask                                                 | Answer                                                                                  |
| --------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| **“Could this role ever target a *different* host type?”**      | If *yes*, keep it separate (ex: `ssh_keys`, `updates`).                                 |
| **“Does this task get skipped 90 % of the time?”**              | Give it a tag (`gui`, `apps`) so you can `--tags gui` or `--skip-tags gui`.             |
| **“Do I have >200 lines in a single role’s `tasks/main.yml`?”** | Split into `tasks/update.yml`, `tasks/firewall.yml`, etc. and call with `import_tasks`. |
| **“Is this only called from another role?”**                    | Put it in that role’s `meta/` as a dependency instead of its own top-level playbook.    |

---

## 5  Running it day-to-day

| High-level job                          | Command                                                           |
| --------------------------------------- | ----------------------------------------------------------------- |
| One-shot full converge                  | `ansible-navigator run playbooks/site.yml -i inventories/homelab` |
| Desktop GUI tweaks only                 | `ansible-playbook playbooks/site.yml --tags gui --limit desktops` |
| Patch Tuesday                           | `ansible-playbook playbooks/maintenance.yml --tags updates`       |
| Redeploy apps after editing Helm values | `ansible-playbook playbooks/k8s.yml --tags apps`                  |

Because roles carry their own tags, you stay flexible without bloating the playbooks.

---

### Why this tends to scale

* **Separation of concerns** – inventory = *where*, roles = *what*, playbooks = *when/which*.
* **Predictable overrides** – `group_vars` hierarchy means a workstation can inherit `common` defaults but override `dnf_automatic: true`.
* **Idempotence tests** – each role is unit-testable with Molecule (Docker or Vagrant driver) before it ever touches the homelab.
* **Secrets-aware** – 1Password lookup lives only in `group_vars/all/vault.yml`; roles stay secrets-agnostic.

Adopt or drop pieces to taste, but sticking to this pattern will keep “desktop tweaks” from leaking into your hypervisor config and vice-versa—no more *sauce* mixing.

[1]: https://docs.ansible.com/ansible/latest/tips_tricks/sample_setup.html?utm_source=chatgpt.com "Sample Ansible setup"
[2]: https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html?utm_source=chatgpt.com "How to build your inventory - Ansible Documentation"
[3]: https://docs.ansible.com/ansible/2.9/user_guide/playbooks_best_practices.html?utm_source=chatgpt.com "Best Practices - Ansible Documentation"
[4]: https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse_roles.html?utm_source=chatgpt.com "Roles — Ansible Community Documentation"
