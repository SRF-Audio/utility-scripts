# MQTT Broker (Mosquitto) - OnePassword Setup

## Overview

This directory contains the Kubernetes resources for deploying Mosquitto MQTT broker in the `infra-mqtt` namespace. The broker uses the SINTEF Mosquitto Helm chart and authenticates users via credentials stored in 1Password.

## 1Password Item Configuration

### Item Location
- **Vault**: `HomeLab`
- **Item Name**: `mosquitto-auth`

### Required Fields

The 1Password item must contain a field named **`passwords.conf`** (exact name, case-sensitive) with the following content format:

```
admin:<password-hash>
```

### Generating Password Hashes

Use the `mosquitto_passwd` utility to generate password hashes:

```bash
# Install mosquitto clients (if not already installed)
# On macOS:
brew install mosquitto

# On Debian/Ubuntu:
sudo apt-get install mosquitto

# Generate a password file with a user
mosquitto_passwd -c /tmp/mosquitto_passwd admin
# Enter password when prompted

# View the generated hash
cat /tmp/mosquitto_passwd
```

The output will look like:
```
admin:$7$101$...hash...$...hash...
```

Copy the entire line (including username and hash) into the `passwords.conf` field in 1Password.

### Adding Multiple Users

To add multiple users, run `mosquitto_passwd` without the `-c` flag to append:

```bash
# Add another user to existing file
mosquitto_passwd /tmp/mosquitto_passwd user2

# View all users
cat /tmp/mosquitto_passwd
```

Then copy all lines into the `passwords.conf` field in 1Password:
```
admin:$7$101$...hash1...
user2:$7$101$...hash2...
```

## Deployment

The deployment is managed by ArgoCD:

1. **Sync Wave 10**: `mqtt-broker-secrets` app deploys the OnePasswordItem CRD
   - Creates Kubernetes Secret `mosquitto-auth` in namespace `infra-mqtt`
   - Secret key `passwords.conf` contains the password file content

2. **Sync Wave 20**: `mqtt-broker` app deploys the Mosquitto Helm chart
   - Uses the SINTEF Mosquitto chart from `https://sintef.github.io/mosquitto-helm-chart`
   - References the `mosquitto-auth` secret for user authentication

## ACL Configuration

Access control is configured in the ArgoCD Application values:

```yaml
auth:
  users:
    - username: admin
      acl:
        - topic: "#"
          access: readwrite
```

- The `username` must match a username in the `passwords.conf` secret
- The `password` field in values is ignored when using `usersExistingSecret`
- ACL rules grant the admin user full access to all topics (`#`)

## Service

The MQTT broker is exposed as a ClusterIP service on port 1883:
- **Service Name**: `mosquitto` (managed by Helm)
- **Port**: 1883 (MQTT)
- **Websockets**: Disabled

## Security Notes

- Anonymous access is disabled
- Authentication is required for all connections
- Passwords are stored in 1Password, not in Git
- Password hashes use SHA512-PBKDF2 format (Mosquitto default)
