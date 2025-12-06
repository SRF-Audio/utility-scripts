# omada_netbox_sync

Ansible role that queries the Omada SDN Controller API for connected and known
clients, normalizes the device data, and pushes it into NetBox using its REST
API. Supports idempotent updates to keep NetBox aligned with the real network
state.

## Requirements

- Ansible 2.9 or higher
- `community.general` collection (for 1Password lookup if used)
- Access to Omada SDN Controller API
- Access to NetBox API with write permissions

## Dependencies

This role depends on:
- `omada_api_auth` - for Omada Controller authentication
- `role_artifacts` - for persisting artifacts

## Role Variables

### Required Variables

| Variable | Description |
|----------|-------------|
| `omada_netbox_sync_omada_api_base_url` | Base URL for Omada controller (e.g., `https://192.168.1.1:8043`) |
| `omada_netbox_sync_omada_api_username` | Username for Omada API authentication |
| `omada_netbox_sync_omada_api_password` | Password for Omada API authentication |
| `omada_netbox_sync_netbox_url` | Base URL for NetBox API (e.g., `https://netbox.example.com`) |
| `omada_netbox_sync_netbox_token` | API token for NetBox authentication |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `omada_netbox_sync_omada_api_validate_certs` | `false` | Validate TLS certificates for Omada API |
| `omada_netbox_sync_omada_site` | `"Default"` | Omada site name to query clients from |
| `omada_netbox_sync_netbox_validate_certs` | `true` | Validate TLS certificates for NetBox API |
| `omada_netbox_sync_netbox_site` | `""` | NetBox site slug to assign devices to |
| `omada_netbox_sync_default_device_role` | `"unknown"` | Default device role slug |
| `omada_netbox_sync_device_role_mappings` | `{}` | Mapping of device name patterns to roles |
| `omada_netbox_sync_device_type_slug` | `"generic-network-client"` | Default device type slug |
| `omada_netbox_sync_manufacturer_slug` | `"unknown"` | Default manufacturer slug |
| `omada_netbox_sync_artifacts_path` | `{{ artifacts_path }}` | Path to store artifacts |
| `omada_netbox_sync_dry_run` | `false` | Skip NetBox updates, only fetch/normalize |
| `omada_netbox_sync_page_size` | `1000` | Number of clients to fetch per page |

## Example Playbook

```yaml
- name: Sync Omada Devices to NetBox
  hosts: localhost
  gather_facts: false
  vars:
    omada_netbox_sync_omada_api_base_url: "https://192.168.226.6:8043"
    omada_netbox_sync_omada_api_username: "admin"
    omada_netbox_sync_omada_api_password: "secret"
    omada_netbox_sync_omada_site: "Default"
    omada_netbox_sync_netbox_url: "https://netbox.example.com"
    omada_netbox_sync_netbox_token: "your-netbox-api-token"
    omada_netbox_sync_netbox_site: "home"
    omada_netbox_sync_default_device_role: "client"
    omada_netbox_sync_dry_run: false

  tasks:
    - name: Sync Omada devices to NetBox
      ansible.builtin.include_role:
        name: omada_netbox_sync

    - name: Display sync results
      ansible.builtin.debug:
        var: omada_netbox_sync_artifacts
```

## Artifacts

The role produces an artifact named `omada_netbox_sync_artifacts` containing:

| Field | Description |
|-------|-------------|
| `omada_site` | The Omada site that was queried |
| `netbox_site` | The NetBox site devices were assigned to |
| `dry_run` | Whether dry run mode was enabled |
| `total_clients_fetched` | Number of clients fetched from Omada |
| `devices_created` | Count of devices created in NetBox |
| `devices_updated` | Count of devices updated in NetBox |
| `devices_skipped` | Count of devices skipped |
| `devices_failed` | Count of devices that failed to sync |
| `raw_clients` | Raw client data from Omada API |
| `normalized_devices` | Normalized device data |
| `created_devices` | List of created device names |
| `updated_devices` | List of updated device names |
| `skipped_devices` | List of skipped device names |
| `failed_devices` | List of failed device names with errors |

Artifacts are also written to disk at
`{{ omada_netbox_sync_artifacts_path }}/omada_netbox_sync/omada_netbox_sync_artifacts.yml`

## NetBox Custom Fields

This role uses custom fields in NetBox to store Omada-specific data:

- `mac_address` - Device MAC address
- `omada_hostname` - Hostname from Omada
- `omada_vendor` - Vendor/OUI information
- `omada_ssid` - SSID (for wireless devices)
- `omada_network` - Network/VLAN name
- `omada_device_type` - Device type (wireless/wired)
- `omada_first_seen` - Timestamp when first seen
- `omada_last_seen` - Timestamp when last seen

**Note:** You must create these custom fields in NetBox before running this
role, or modify the role to use only built-in NetBox fields.

## License

See repository LICENSE file.
