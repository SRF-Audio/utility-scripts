# Proxmox K3s HA Cluster Role

This Ansible role sets up a highly available K3s cluster on Proxmox VE with Fedora CoreOS (FCOS) nodes.

## Features

- **HA Control Plane**: 3 control plane nodes with etcd clustering
- **Dynamic Worker Nodes**: Configurable worker nodes with different specifications
- **Static IP Addressing**: Sequential IP assignment starting from configurable base
- **Static MAC Addresses**: Unique MAC addresses for each node
- **Tailscale Integration**: Built-in Tailscale VPN setup
- **Automated VM Creation**: Full automation of VM provisioning

## Prerequisites

### 1Password Setup

You need to create a secure item in 1Password with the following fields:

- **Item Name**: `Coachlight K3s Cluster`
- **Vault**: `HomeLab`
- **Field**: `cluster token`

The cluster token should be a secure, random string that will be used for node authentication. You can generate one using:

```bash
# Generate a secure cluster token
openssl rand -hex 32
# or
head -c 32 /dev/urandom | base64
```

**Important**: This token is different from the kubeconfig token you'll use to access the cluster. The cluster token is used during cluster formation and node joining.

### Cluster Token Requirements

- **Length**: At least 32 characters (recommended: 64+ characters)
- **Characters**: Alphanumeric and special characters are allowed
- **Security**: Must be kept secret and consistent across all nodes
- **Persistence**: This token doesn't expire and is used for the lifetime of the cluster

## Configuration

### Control Plane Nodes

- **Count**: 3 nodes (configurable via `proxmox_k3s_control_plane_count`)
- **Specifications**: 2 vCPU, 4 GiB RAM, 60 GiB disk
- **IP Range**: Starts at `proxmox_k3s_control_plane_start_ip` (default: 192.168.226.93)
- **Clustering**: First node initializes cluster, others join as HA members

### Worker Nodes

Two types of worker nodes are supported:

#### Standard Worker
- **Count**: 2 nodes (configurable)
- **Specifications**: 4 vCPU, 4 GiB RAM, 150 GiB disk
- **Use Case**: General workloads, applications

#### Media Worker
- **Count**: 1 node (configurable)
- **Specifications**: 8 vCPU, 8 GiB RAM, 240 GiB disk
- **Use Case**: Media processing, high-performance workloads

### Network Configuration

- **Subnet**: 192.168.226.0/24 (configurable)
- **Gateway**: 192.168.226.1 (configurable)
- **MAC Addresses**: Sequential assignment with prefix `52:54:00:12:34:XX`
- **DNS**: 1.1.1.1, 8.8.8.8

## Variables

### Required Variables

```yaml
# Proxmox connection
pve_admin_user: "root@pam"
pve_admin_password: "your-password"

# Network configuration
proxmox_k3s_control_plane_start_ip: "192.168.226.93"
proxmox_k3s_control_plane_gateway: "192.168.226.1"

# Storage configuration
proxmox_storage: "local-lvm"
proxmox_bridge: "vmbr0"

# 1Password cluster token (required)
proxmox_k3s_cluster_token: "{{ lookup('community.general.onepassword', 'Coachlight K3s Cluster', field='cluster_token', vault='HomeLab') }}"
```

### Optional Variables

```yaml
# Control plane configuration
proxmox_k3s_control_plane_count: 3
proxmox_k3s_control_plane_cpu: 2
proxmox_k3s_control_plane_memory: 4096
proxmox_k3s_control_plane_disk: 60

# Worker configuration
proxmox_k3s_worker_config:
  worker:
    count: 2
    cpu: 4
    memory: 4096
    disk: 150
  media_worker:
    count: 1
    cpu: 8
    memory: 8192
    disk: 240

# MAC address prefix
proxmox_k3s_mac_prefix: "52:54:00:12:34:"
```

## Usage

### 1. Prerequisites

- Proxmox VE cluster with at least one node
- Fedora CoreOS template VM named `fcos-template`
- Ansible with `community.general.proxmox_kvm` module
- 1Password CLI configured with access to `HomeLab` vault
- 1Password item `Coachlight K3s Cluster` with `cluster_token` field

### 2. Inventory Setup

```ini
[proxmox]
pve1 ansible_host=192.168.1.10
pve2 ansible_host=192.168.1.11
pve3 ansible_host=192.168.1.12

[proxmox_primary]
pve1

[proxmox_secondaries]
pve2
pve3
```

### 3. Playbook Execution

```bash
ansible-playbook -i inventory/hosts.ini playbooks/k3s-cluster.yml
```

## VM Naming Convention

- **Control Plane**: `k3s-cp-1`, `k3s-cp-2`, `k3s-cp-3`
- **Standard Workers**: `k3s-worker-1`, `k3s-worker-2`
- **Media Workers**: `k3s-media-worker-1`

## IP Address Assignment

- **Control Plane**: 192.168.226.93, 192.168.226.94, 192.168.226.95
- **Workers**: 192.168.226.96, 192.168.226.97, 192.168.226.98

## Security Features

- **SSH Key Authentication**: Uses 1Password-stored SSH keys
- **Tailscale VPN**: Secure remote access to cluster nodes
- **Static MAC Addresses**: Prevents MAC address conflicts
- **Network Isolation**: Dedicated network configuration
- **Secure Cluster Token**: Stored in 1Password, not in playbooks

## Troubleshooting

### Common Issues

1. **VM Creation Fails**: Check Proxmox API credentials and storage availability
2. **Network Issues**: Verify bridge configuration and IP address conflicts
3. **Template Missing**: Ensure `fcos-template` exists and is accessible
4. **Cluster Token Issues**: Verify 1Password item exists and field name is correct

### Debug Commands

```bash
# Check VM status
qm list

# View VM configuration
qm config <vm-id>

# Check network configuration
ip addr show vmbr0

# View cluster status (after setup)
kubectl get nodes

# Verify cluster token on first control plane
cat /var/lib/rancher/k3s/server/token
```

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   k3s-cp-1     │    │   k3s-cp-2     │    │   k3s-cp-3     │
│  (Cluster      │    │  (HA Member)    │    │  (HA Member)    │
│   Init)        │    │                 │    │                 │
│ 192.168.226.93 │    │ 192.168.226.94 │    │ 192.168.226.95 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────┴─────────────┐
                    │                           │
            ┌─────────────┐           ┌─────────────┐
            │k3s-worker-1 │           │k3s-worker-2 │
            │192.168.226.96│           │192.168.226.97│
            └─────────────┘           └─────────────┘
                    │                           │
                    └─────────────┬─────────────┘
                                  │
                           ┌─────────────┐
                           │k3s-media-   │
                           │worker-1     │
                           │192.168.226.98│
                           └─────────────┘
```

## Contributing

When modifying this role:

1. Update the documentation
2. Test with different node counts
3. Verify IP address calculations
4. Test HA failover scenarios
5. Ensure cluster token security is maintained
