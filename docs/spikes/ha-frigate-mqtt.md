# Spike: HA + Frigate + MQTT “Just Works”

## Constants (chosen LAN endpoints)

- MQTT_LAN_HOST: 192.168.226.94
- FRIGATE_LAN_HOST: 192.168.226.94
- MQTT endpoint: 192.168.226.94:1883
- Frigate API endpoint: [http://192.168.226.94:8971](http://192.168.226.94:8971)

## Preconditions

- Argo CD apps synced for mqtt-broker, mqtt-rbac, mqtt-rbac-secrets, and frigate.
- 1Password Operator is installed and healthy.
- The following 1Password items exist:
  - mosquitto-auth (field: passwords.conf)
  - frigate-mqtt-credentials (fields: FRIGATE_MQTT_USER, FRIGATE_MQTT_PASSWORD)

## Step 1 — Lock the endpoints

- Use the constants above in all configs and HA UI inputs.
- Do not use any other VIPs for this spike.

## Step 2 — MQTT broker baseline

- Auth is enforced via mosquitto-auth and the mosquitto.conf configmap.
- Persistence is enabled via mosquitto.conf and the PVC in the Helm values.
- Logging is enabled to stdout for the spike.

Expected 1Password mosquitto-auth content (passwords.conf field):

- Include at least these users with hashed passwords:
   - frigate
   - homeassistant
   - admin (optional for debug)

## Step 3 — Configure Frigate → MQTT

- Frigate config enables MQTT and points to 192.168.226.94:1883.
- Frigate uses FRIGATE_MQTT_USER and FRIGATE_MQTT_PASSWORD from 1Password.
- The topic prefix is frigate.

## Step 4 — Configure Home Assistant → MQTT integration

- Add MQTT integration in HA UI.
- Broker: 192.168.226.94
- Port: 1883
- Username/password: use the homeassistant user from mosquitto-auth.

## Step 5 — Configure Home Assistant ↔ Frigate integration

- Add Frigate integration in HA UI.
- Frigate URL: [http://192.168.226.94:8971](http://192.168.226.94:8971)
- Provide credentials if Frigate auth is enabled.

## Step 6 — Proof automation

Create a minimal HA automation:

- Trigger: Frigate person detection for the chosen camera.
- Action: toggle a helper boolean or send a notification.

## Verification checks

- MQTT broker reachable from HA and LAN clients at 192.168.226.94:1883.
- Frigate API reachable at [http://192.168.226.94:8971](http://192.168.226.94:8971).
- Frigate publishes MQTT topics under frigate/#.
- HA MQTT integration shows connected.
- HA Frigate integration shows entities and updates on detections.
- Automation fires repeatedly.

## Restart tests

Run these in any order and re-check verification:

- Restart mqtt-broker pod.
- Restart Frigate pod.
- Restart HA.

## Debug runbook

1. Addressing
   - Confirm HA uses 192.168.226.94 for MQTT and Frigate, not other VIPs.
2. Ports
   - 1883/TCP reachable from HA to MQTT.
   - 8971/TCP reachable from HA to Frigate.
3. Auth
   - Check mosquitto logs for auth failures.
   - Confirm mosquitto-auth has the expected users.
4. Frigate publishes
   - Subscribe to frigate/# briefly and confirm updates.
5. HA integrations
   - MQTT integration connected.
   - Frigate integration connected.
6. Time drift
   - If events are delayed, confirm NTP is in sync.
