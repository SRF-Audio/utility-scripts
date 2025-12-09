# Legacy Ansible Roles Catalog

This document catalogs all legacy roles under `ansible/old_roles` and tracks where they are referenced from `ansible/roles` and `ansible/playbooks`. These roles are candidates for refactoring into smaller, atomic, best-practice roles.

## Best Practice References

This analysis compares legacy roles against:
- Existing roles in `ansible/roles` (the "good" examples)
- [Red Hat Communities of Practice - Ansible Automation Good Practices](https://redhat-cop.github.io/automation-good-practices/)
- [Ansible Best Practices (official documentation)](https://docs.ansible.com/ansible/2.8/user_guide/playbooks_best_practices.html)

## Table of Contents

- [audio_tools_install](#audio_tools_install)
- [fedora](#fedora)
- [git_repo_setup](#git_repo_setup)
- [proxmox](#proxmox)
- [proxmox_cluster_prep](#proxmox_cluster_prep)
- [workstation_prep](#workstation_prep)

---

## audio_tools_install

**Path:** `ansible/old_roles/audio_tools_install`

### Structure

**Directories:**
- `tasks/`

**Task Files:**
- `ansible/old_roles/audio_tools_install/tasks/main.yml`

### Task File Responsibilities

#### `tasks/main.yml`
- Installs core audio stack for Fedora (PipeWire, WirePlumber, ALSA utilities, etc.)
- Installs audio production applications via Flatpak (Bitwig Studio)
- Installs MuseScore via dnf

### References

**Playbooks:**
- `ansible/playbooks/audio-production.yml:7` - Listed in `roles:` section

**Roles:**
- No references found in other roles

### Notes / Refactor Hints

**Divergences from Best Practices:**
- **No argument_specs.yml**: Role lacks meta/argument_specs.yml to declare supported variables
- **No defaults/main.yml**: No default variable configuration file
- **Hard-coded OS check**: Uses inline `when: ansible_facts['os_family'] == "RedHat"` instead of parameterized approach
- **No variable prefixing**: Should prefix any variables with role name (e.g., `audio_tools_install_*`)
- **Mixed package managers**: Combines dnf and flatpak in single role without clear separation
- **No artifacts**: Does not expose any outputs via role_artifacts pattern

**Atomic Role Split Candidates:**
1. **audio_stack_install** - Dedicated to installing system audio infrastructure (PipeWire, ALSA, etc.)
   - Could be OS-agnostic with proper conditionals
   - Follow pattern in `ansible/roles/cli_tester` for OS detection
2. **flatpak_apps_installer** - Generic role for installing flatpak applications
   - Takes list of flatpak packages as input
   - Similar to how `control_host_dependencies` handles package installation
3. **music_production_tools** - Higher-level role that orchestrates audio_stack_install and flatpak_apps_installer
   - Takes application list as parameter
   - Uses argument_specs.yml for variable declaration

**Best Practice Alignment:**
- Study `ansible/roles/cli_tester` for proper OS detection and conditional package installation
- Study `ansible/roles/op_install` for clean argument_specs.yml structure
- Follow role_artifacts pattern from existing roles (e.g., `cli_tester`)

---

## fedora

**Path:** `ansible/old_roles/fedora`

### Structure

**Directories:**
- `tasks/`

**Task Files:**
- `ansible/old_roles/fedora/tasks/main.yml`

### Task File Responsibilities

#### `tasks/main.yml`
- Empty file (no tasks defined)

### References

**Playbooks:**
- No references found

**Roles:**
- No references found

### Notes / Refactor Hints

**Divergences from Best Practices:**
- **Completely empty**: Role contains no functionality
- **No purpose**: Unclear why this role exists

**Atomic Role Split Candidates:**
- **Consider deletion**: This role appears to be unused and empty
- If it was meant for Fedora-specific setup, that functionality should be incorporated into OS-specific conditionals in other roles

**Best Practice Alignment:**
- Empty roles should be removed to reduce confusion
- If Fedora-specific logic is needed, follow conditional patterns in existing roles

---

## git_repo_setup

**Path:** `ansible/old_roles/git_repo_setup`

### Structure

**Directories:**
- `tasks/`
- `files/`

**Task Files:**
- `ansible/old_roles/git_repo_setup/tasks/main.yml`

**Template/Files:**
- `ansible/old_roles/git_repo_setup/files/gitconfig-github.tpl`
- `ansible/old_roles/git_repo_setup/files/gitconfig-gitlab.tpl`
- `ansible/old_roles/git_repo_setup/files/gitconfig.tpl`

### Task File Responsibilities

#### `tasks/main.yml`
- Creates directory structure for Git repositories (~/GitLab/personal, ~/GitLab/work, ~/GitHub)
- Sets directory permissions to 0755

### References

**Playbooks:**
- No references found

**Roles:**
- No references found

### Notes / Refactor Hints

**Divergences from Best Practices:**
- **No argument_specs.yml**: Missing variable declarations
- **No defaults/main.yml**: No default variables defined
- **Hard-coded paths**: Directory paths are hard-coded (~/GitLab/personal, etc.) rather than parameterized
- **Unused templates**: Has gitconfig template files that are never referenced in tasks
- **No variable prefixing**: Should prefix variables with role name
- **Single concern violation**: Mixes directory creation with (presumably) git configuration setup
- **No idempotency guards**: While directory creation is idempotent, should document expected state

**Atomic Role Split Candidates:**
1. **directory_structure_creator** - Generic role for creating directory structures
   - Takes a list of directories with permissions as input
   - More reusable than git-specific implementation
   - Similar pattern to `file_copier` role
2. **git_config_manager** - Dedicated to git configuration management
   - Would actually use the gitconfig templates
   - Takes user preferences as parameters
   - Follows argument_specs pattern

**Best Practice Alignment:**
- Study `ansible/roles/file_copier` for how to handle file/directory operations
- Parameterize all paths using argument_specs.yml
- Either use or remove the template files
- Consider if this functionality belongs in a workstation setup role

---

## proxmox

**Path:** `ansible/old_roles/proxmox`

### Structure

**Directories:**
- `tasks/`
- `defaults/`
- `files/`

**Task Files:**
- `ansible/old_roles/proxmox/tasks/main.yml`
- `ansible/old_roles/proxmox/tasks/users.yml`
- `ansible/old_roles/proxmox/tasks/storage.yml`
- `ansible/old_roles/proxmox/tasks/proxmox-module-prereqs.yml`
- `ansible/old_roles/proxmox/tasks/coreos-download.yml`
- `ansible/old_roles/proxmox/tasks/coreos-vm-templating.yml`
- `ansible/old_roles/proxmox/tasks/control-plane-1-create.yml`
- `ansible/old_roles/proxmox/tasks/control-planes-2-3-create-join.yml`
- `ansible/old_roles/proxmox/tasks/workers-create.yml`

**Template/Files:**
- `ansible/old_roles/proxmox/files/coredns-config.yaml`
- `ansible/old_roles/proxmox/files/fcos-k3s-ha-control-join.bu.j2`
- `ansible/old_roles/proxmox/files/fcos-k3s-ha-control.bu.j2`
- `ansible/old_roles/proxmox/files/fcos-k3s-worker.bu.j2`

### Task File Responsibilities

#### `tasks/main.yml`
- Imports users.yml, storage.yml, and proxmox-module-prereqs.yml task files
- Orchestrates Proxmox node configuration

#### `tasks/users.yml`
- Creates PVE administrators group using `pveum group add`
- Assigns Administrator role at root path `/`
- Creates sfroeber@pam user account
- Adds user to administrators group
- Creates kubernetes pool for VM/CT organization
- Uses inventory group checks (`inventory_hostname in groups['proxmox_primary']`)

#### `tasks/storage.yml`
- Retrieves Synology NAS IP from 1Password
- Adds NFS storage mounts from Synology to Proxmox cluster
- Creates local directory storage for CoreOS images
- Configures storage for multiple nodes using `pvesm` commands

#### `tasks/proxmox-module-prereqs.yml`
- Installs Python packages: proxmoxer, requests, requests_toolbelt
- Uses pip3 directly without checking if already installed

#### `tasks/coreos-download.yml`
- (Not viewed but appears to handle Fedora CoreOS downloads)

#### `tasks/coreos-vm-templating.yml`
- (Not viewed but appears to create VM templates)

#### `tasks/control-plane-1-create.yml`
- (Not viewed but appears to create first K3s control plane)

#### `tasks/control-planes-2-3-create-join.yml`
- (Not viewed but appears to create additional control plane nodes)

#### `tasks/workers-create.yml`
- (Not viewed but appears to create K3s worker nodes)

### References

**Playbooks:**
- `ansible/playbooks/proxmox.yml:99` - Listed in `roles:` section for "Coachlight Homelab Proxmox Cluster Config" play

**Roles:**
- No references found in other roles

### Notes / Refactor Hints

**Divergences from Best Practices:**
- **Massive scope**: Single role handles users, storage, VM creation, K3s cluster setup, and more
- **No argument_specs.yml**: Missing meta/argument_specs.yml despite having extensive defaults
- **Inventory group coupling**: Heavy reliance on specific inventory groups (`proxmox_primary`, `proxmox`)
- **No variable prefixing**: Uses unprefixed variables like `pve_admin_group` instead of `proxmox_pve_admin_group`
- **1Password hardcoding**: Direct calls to 1Password lookups in tasks instead of using dedicated roles
- **Direct command usage**: Heavy use of `pveum` and `pvesm` commands instead of Ansible modules where available
- **No artifacts pattern**: Does not expose outputs via role_artifacts
- **Poor idempotency**: Some command tasks lack proper `changed_when` or `creates` guards
- **Mixed responsibilities**: Combines infrastructure management with application deployment (K3s)

**Atomic Role Split Candidates:**
1. **proxmox_user_manager** - Dedicated to PVE user/group/ACL management
   - Takes user/group definitions as parameters
   - Uses argument_specs for inputs
   - Returns artifacts about created users/groups
   - Similar to how `k8s_object_manager` handles k8s resources
   
2. **proxmox_storage_manager** - Dedicated to storage configuration
   - Takes storage definitions as parameters
   - Handles NFS, directory, and other storage types
   - Uses existing patterns from `proxmox_vm_disk_manager` as reference
   
3. **proxmox_python_dependencies** - Dedicated to installing Proxmox Python libraries
   - Simple, focused role similar to `op_install`
   - Checks if already installed before installing
   - Could use cli_tester pattern for validation
   
4. **coreos_image_manager** - Dedicated to downloading and managing CoreOS images
   - Note: `coreos_image_fetch` and `coreos_cli_install` already exist in ansible/roles
   - This functionality should likely be removed and use existing roles
   
5. **proxmox_vm_creator** - Dedicated to creating VMs (without K3s specifics)
   - Takes VM specifications as parameters
   - Uses existing `proxmox_kvm_manager` as reference
   
6. **k3s_cluster_proxmox_scaffolder** - Dedicated to K3s-specific VM deployment
   - Should be separate from general Proxmox management
   - Note: `proxmox_k3s_vm_scaffolder` already exists in ansible/roles
   - This functionality should be removed and existing role used

**Best Practice Alignment:**
- Study `ansible/roles/proxmox_kvm_manager` for proper Proxmox VM management
- Study `ansible/roles/proxmox_k3s_vm_scaffolder` for K3s-specific scaffolding
- Use `ansible/roles/op_read` instead of direct 1Password lookups
- Follow role_artifacts pattern to expose created resources
- Split into single-concern roles following the pattern of existing new roles
- Add proper argument_specs.yml for all inputs
- Prefix all variables with role name
- Use inventory-agnostic patterns (pass host lists as variables)

---

## proxmox_cluster_prep

**Path:** `ansible/old_roles/proxmox_cluster_prep`

### Structure

**Directories:**
- `tasks/`
- `defaults/`
- `files/`
- `handlers/`

**Task Files:**
- `ansible/old_roles/proxmox_cluster_prep/tasks/main.yml`
- `ansible/old_roles/proxmox_cluster_prep/tasks/repo-setup.yml`
- `ansible/old_roles/proxmox_cluster_prep/tasks/package-install.yml`
- `ansible/old_roles/proxmox_cluster_prep/tasks/hosts-mod.yml`
- `ansible/old_roles/proxmox_cluster_prep/tasks/ssh-trust.yml`
- `ansible/old_roles/proxmox_cluster_prep/tasks/create-sfroeber.yml`
- `ansible/old_roles/proxmox_cluster_prep/tasks/cluster-setup.yml`

**Handlers:**
- `ansible/old_roles/proxmox_cluster_prep/handlers/main.yml`

**Template/Files:**
- `ansible/old_roles/proxmox_cluster_prep/files/hosts.j2`

### Task File Responsibilities

#### `tasks/main.yml`
- Orchestrates cluster preparation by importing all subtask files in sequence
- Imports: repo-setup, package-install, hosts-mod, ssh-trust, create-sfroeber, cluster-setup

#### `tasks/repo-setup.yml`
- Disables Proxmox Enterprise repository
- Enables Proxmox no-subscription repository
- Disables Ceph Enterprise repository
- Enables Ceph no-subscription repository
- Notifies handler to update apt cache

#### `tasks/package-install.yml`
- Installs management tools from `proxmox_extra_packages` variable
- Uses apt with update_cache

#### `tasks/hosts-mod.yml`
- Templates `/etc/hosts` file from `hosts.j2`
- Sets proper ownership and permissions
- Notifies handler to restart networking

#### `tasks/ssh-trust.yml`
- Retrieves cluster SSH keypair from 1Password
- Writes private key to local ~/.ssh/coachlight-homelab.pem
- Distributes private key to all cluster nodes as /root/.ssh/id_ed25519
- Configures SSH config for root user to use cluster identity

#### `tasks/create-sfroeber.yml`
- Retrieves public key from 1Password
- Creates sfroeber user with sudo privileges
- Sets password from 1Password
- Authorizes cluster SSH key for sfroeber
- Configures passwordless sudo for admin group

#### `tasks/cluster-setup.yml`
- Detects if cluster already exists by checking /etc/pve/corosync.conf
- Creates Proxmox cluster on primary node using `pvecm create`
- Has proper idempotency guards

### References

**Playbooks:**
- `ansible/playbooks/proxmox.yml:37` - Listed in `roles:` section for "Bootstrap the nodes that failed the probe" play

**Roles:**
- No references found in other roles

### Notes / Refactor Hints

**Divergences from Best Practices:**
- **Massive mixed concerns**: Single role handles repos, packages, networking, SSH, users, and cluster setup
- **No argument_specs.yml**: Missing variable declarations despite using variables
- **1Password hardcoding**: Direct 1Password lookups instead of using op_read role
- **User-specific logic**: Hard-coded to create "sfroeber" user instead of parameterized approach
- **No variable prefixing**: Uses unprefixed variables like `proxmox_cluster_name`
- **Inventory coupling**: Relies on inventory group names like `proxmox`, `proxmox_primary`
- **No artifacts**: Does not expose cluster information as artifacts
- **Template location**: Jinja2 template (hosts.j2) is in files/ directory; Ansible best practice is to use templates/ directory for .j2 files
- **Hard-coded credentials**: Password and SSH key locations are hard-coded
- **Security concerns**: Stores private keys on multiple systems without clear lifecycle management

**Atomic Role Split Candidates:**
1. **proxmox_repo_configurator** - Dedicated to repository management
   - Takes repository definitions as parameters
   - Handles enterprise vs. no-subscription repos
   - Parameterize which repos to enable/disable
   - Similar pattern to package manager setup in workstation roles
   
2. **package_installer** - Generic package installation role
   - Takes package list as parameter
   - OS-agnostic where possible
   - Similar to `control_host_dependencies`
   
3. **hosts_file_manager** - Dedicated to /etc/hosts management
   - Takes host entries as parameters
   - Generic, not Proxmox-specific
   - Could be reusable across different contexts
   
4. **ssh_key_distributor** - Dedicated to distributing SSH keys
   - Takes key source and target hosts as parameters
   - Uses op_read instead of direct lookups
   - More generic than cluster-specific
   
5. **linux_user_creator** - Dedicated to creating Linux users
   - Takes user specifications as parameters
   - Handles SSH keys, sudo config, passwords
   - Generic across different use cases
   - Already exists as pattern in existing roles
   
6. **proxmox_cluster_creator** - Dedicated to Proxmox cluster initialization
   - Takes cluster name and node list as parameters
   - Focused only on `pvecm create` logic
   - Could incorporate join logic from playbook
   - Use existing `proxmox_maintenance` role as reference

**Best Practice Alignment:**
- Split into 6+ focused, single-concern roles
- Use `ansible/roles/op_read` for 1Password access instead of direct lookups
- Add argument_specs.yml to all new roles
- Prefix all variables with role names
- Make roles inventory-agnostic (pass host lists as variables)
- Use role_artifacts pattern to expose created resources
- Move template to templates/ directory in new roles
- Study `ansible/roles/proxmox_maintenance` for Proxmox-specific patterns
- Consider security implications of SSH key distribution

---

## workstation_prep

**Path:** `ansible/old_roles/workstation_prep`

### Structure

**Directories:**
- `tasks/`
- `vars/`

**Task Files:**
- `ansible/old_roles/workstation_prep/tasks/main.yml`
- `ansible/old_roles/workstation_prep/tasks/standard-distros.yml`
- `ansible/old_roles/workstation_prep/tasks/immutable-distros.yml`
- `ansible/old_roles/workstation_prep/tasks/1password.yml`
- `ansible/old_roles/workstation_prep/tasks/flatpak.yml`
- `ansible/old_roles/workstation_prep/tasks/kde-setup.yml`
- `ansible/old_roles/workstation_prep/tasks/productivity-apps.yml`
- `ansible/old_roles/workstation_prep/tasks/vs-code.yml`

**Vars:**
- `ansible/old_roles/workstation_prep/vars/1password.yml` (Ansible Vault encrypted)

### Task File Responsibilities

#### `tasks/main.yml`
- Detects OS ID from /etc/os-release
- Sets immutable distro fact for Aurora Linux
- Conditionally includes standard-distros.yml or immutable-distros.yml
- Adds Python and pip aliases to .bashrc and .zshrc
- Upgrades pip for Python 3

#### `tasks/standard-distros.yml`
- Updates all packages to latest
- Installs common packages (zsh, python3, tmux, git, jq, etc.)
- Installs Python packages (paramiko, ansibug) via pip
- Installs OS-specific packages for Fedora/RHEL (Development Tools, golang, etc.)
- Installs OS-specific packages for Debian/Ubuntu (build-essential, golang-go, etc.)
- Changes default shell to zsh
- Includes oh-my-zsh tasks (reference to non-existent file)
- Includes 1password, vs-code, flatpak, and productivity-apps tasks

#### `tasks/immutable-distros.yml`
- Contains only a debug placeholder message
- No actual functionality implemented

#### `tasks/1password.yml`
- Installs 1Password desktop client for Fedora/RHEL
- Installs 1Password CLI for Fedora/RHEL
- Installs 1Password desktop client for Debian/Ubuntu
- Installs 1Password CLI for Debian/Ubuntu
- Adds repositories, GPG keys, and debsig policies
- Significant duplication between desktop and CLI installation blocks

#### `tasks/flatpak.yml`
- Installs flatpak via dnf
- Adds Fedora and Flathub flatpak remotes
- Installs flatpak applications (Discord, Signal, Slack, Brave, Obsidian, etc.)

#### `tasks/kde-setup.yml`
- Creates KDE Activities (Work, Homelab) using qdbus
- Only runs when desktop environment is KDE

#### `tasks/productivity-apps.yml`
- Installs productivity applications via dnf (inkscape, steam, musescore, krita, etc.)

#### `tasks/vs-code.yml`
- Installs Visual Studio Code for Fedora/RHEL
- Installs Visual Studio Code for Debian/Ubuntu
- Adds Microsoft repositories and GPG keys

### References

**Playbooks:**
- No references found in current playbooks
- (Previously may have been used, but `workstations.yml` currently only uses `oh_my_zsh_install`)

**Roles:**
- No references found in other roles

### Notes / Refactor Hints

**Divergences from Best Practices:**
- **Monolithic scope**: Single role handles package management, shell setup, application installation, desktop configuration, and more
- **No argument_specs.yml**: Missing variable declarations
- **No defaults/main.yml**: No default variables defined
- **Broken reference**: Includes non-existent `oh-my-zsh.yml` file (should reference existing `oh_my_zsh_install` role)
- **No variable prefixing**: Should prefix variables with role name
- **Hard-coded paths**: .bashrc and .zshrc paths are hard-coded
- **Shell anti-pattern**: Uses `ansible.builtin.shell` for pip upgrade instead of pip module
- **Massive duplication**: 1Password installation has significant duplication between desktop and CLI
- **Package manager mixing**: Uses dnf, apt, pip, flatpak all in same role
- **Incomplete implementation**: immutable-distros.yml is just a placeholder
- **No idempotency**: pip upgrade runs every time without guards
- **Deprecated modules**: Uses `apt_key` module which is deprecated
- **Security risk**: Uses `state: latest` for all packages (non-deterministic)
- **No artifacts**: Does not expose any outputs

**Atomic Role Split Candidates:**
1. **shell_configurator** - Dedicated to shell setup and aliases
   - Takes shell type and aliases as parameters
   - Handles .bashrc, .zshrc configuration
   - Generic, reusable pattern
   
2. **package_manager_base** - Dedicated to base system packages
   - Takes package list as parameter
   - OS-detection similar to `cli_tester`
   - Installs only essential system tools
   - Similar to `control_host_dependencies`
   
3. **1password_installer** - Dedicated to 1Password installation
   - Note: `op_install` already exists in ansible/roles for CLI
   - Should leverage existing role and create new desktop client role
   - Eliminate duplication between Fedora/Debian code paths
   
4. **flatpak_manager** - Dedicated to flatpak setup and apps
   - Takes list of flatpak applications as parameter
   - Manages remotes and packages
   - Reusable for any flatpak needs
   
5. **vscode_installer** - Dedicated to VS Code installation
   - Takes optional extensions list as parameter
   - OS-agnostic implementation
   - Could be part of dev tools role
   
6. **kde_configurator** - Dedicated to KDE desktop setup
   - Takes KDE preferences as parameters
   - Only runs on KDE systems
   - More comprehensive than current placeholder
   
7. **development_tools_installer** - Higher-level role for dev environments
   - Orchestrates shell_configurator, package_manager_base, vscode_installer
   - Takes dev tool preferences as parameters
   
8. **productivity_apps_installer** - Dedicated to productivity applications
   - Takes application list as parameter
   - OS-agnostic where possible
   - Could merge with flatpak_manager for unified app management

**Best Practice Alignment:**
- Split into 8+ focused, single-concern roles
- Use existing `op_install` role instead of custom 1Password CLI installation
- Study `ansible/roles/control_host_dependencies` for package management patterns
- Study `ansible/roles/cli_tester` for OS detection patterns
- Add argument_specs.yml to all new roles with proper variable declarations
- Prefix all variables with role names
- Replace deprecated `apt_key` with proper apt keyring management
- Use specific package versions instead of `state: latest` for reproducibility
- Use Ansible pip module instead of shell commands
- Implement immutable distro support or remove placeholder
- Add proper changed_when and creates guards for idempotency
- Consider using role_artifacts pattern where appropriate
- Fix oh-my-zsh reference to use existing `oh_my_zsh_install` role

---

## Summary

All legacy roles share common anti-patterns:
- Missing `meta/argument_specs.yml` for variable declarations
- No variable prefixing with role names
- Missing or incomplete role_artifacts implementation
- Direct 1Password lookups instead of using dedicated roles
- Mixed concerns and monolithic design
- Hard-coded values that should be parameterized
- Inventory group coupling instead of parameter-based design

The new roles in `ansible/roles/` demonstrate the target patterns:
- Single, atomic concerns
- Proper argument_specs.yml with all variables declared
- Variable prefixing with role name
- role_artifacts pattern for outputs
- Use of specialized roles (op_read, cli_tester) for common operations
- Inventory-agnostic design
- Clear defaults/main.yml files

### Recommended Refactoring Priority

1. **High Priority** (actively used, high complexity):
   - `proxmox` - Split into 6+ atomic roles, leverage existing proxmox_* roles
   - `proxmox_cluster_prep` - Split into 6+ atomic roles, critical infrastructure
   - `workstation_prep` - Split into 8+ atomic roles, leverage existing oh_my_zsh_install and op_install

2. **Medium Priority** (simple or partially used):
   - `audio_tools_install` - Split into 2-3 atomic roles
   - `git_repo_setup` - Simplify or merge into workstation setup roles

3. **Low Priority** (unused):
   - `fedora` - Delete (empty and unused)

### Next Steps

After this catalog, follow-up issues should:
1. Create atomic role designs for each split candidate
2. Implement new roles following `ansible/roles` patterns
3. Update playbooks to use new atomic roles
4. Deprecate and eventually remove old_roles
5. Update documentation and examples
