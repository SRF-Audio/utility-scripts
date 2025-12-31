# Observability Stack

This directory contains Argo CD applications for the observability stack, including log collection, metrics, and tracing components.

## Components

### Grafana Alloy

**File**: `alloy.yml`

Grafana Alloy is deployed as a DaemonSet to collect logs from all Kubernetes pods and nodes.

**Key Features**:
- **DaemonSet Deployment**: Runs on every node to collect logs locally
- **Kubernetes Log Discovery**: Automatically discovers pods and collects their logs
- **Log Forwarding**: Sends logs to Loki (when deployed)
- **OTLP Support**: Optional OpenTelemetry receiver for traces and metrics (currently commented out)

**Configuration**:
- Namespace: `observability-alloy`
- Helm Chart: `grafana/alloy` (v1.5.1)
- Project: `coachlight-k3s-observability`

**Current State**:
- ✅ Alloy is configured to collect Kubernetes pod logs
- ⏳ Loki endpoint is configured but Loki is not yet deployed (deployment will succeed but logs won't be persisted until Loki is available)
- 💡 OTLP receiver is included but commented out - uncomment when you need trace/metric collection

**Next Steps**:

1. **Deploy Loki** to persist logs:
   - Create `loki.yml` in this directory
   - Use namespace `observability-loki`
   - Expose service at `http://loki.observability-loki.svc.cluster.local:3100`
   - Alloy is already configured to send logs to this endpoint

2. **Deploy Prometheus** (optional) for metrics:
   - Create `prometheus.yml` in this directory
   - Use namespace `observability-prometheus`
   - Configure remote_write or scraping endpoint
   - Uncomment the OTLP receiver section in Alloy config

3. **Deploy Tempo** (optional) for traces:
   - Create `tempo.yml` in this directory
   - Use namespace `observability-tempo`
   - Expose OTLP endpoint at `http://tempo.observability-tempo.svc.cluster.local:4317`
   - Uncomment the OTLP receiver section in Alloy config

4. **Deploy Grafana** for visualization:
   - Create `grafana.yml` in this directory
   - Configure data sources for Loki, Prometheus, and Tempo
   - Access dashboards to view logs, metrics, and traces

## Troubleshooting

### Check Alloy Status

```bash
# Check if Alloy pods are running
kubectl get pods -n observability-alloy

# View Alloy logs
kubectl logs -n observability-alloy -l app.kubernetes.io/name=alloy --tail=100

# Check Alloy configuration
kubectl get configmap -n observability-alloy
```

### Verify Log Collection

Once Loki is deployed:

```bash
# Check if logs are being sent
kubectl logs -n observability-alloy -l app.kubernetes.io/name=alloy | grep "loki.write"

# Query Loki directly
kubectl port-forward -n observability-loki svc/loki 3100:3100
# Then visit http://localhost:3100/ready
```

### Enable OTLP Receiver

To enable the OTLP receiver in Alloy:

1. Edit `alloy.yml`
2. Uncomment the OTLP receiver section (lines with `otelcol.receiver.otlp`)
3. Ensure Prometheus and Tempo endpoints are correct
4. Commit and push - ArgoCD will auto-sync

## Resource Requirements

**Alloy**:
- CPU: 100m (request), unlimited (limit)
- Memory: 128Mi (request), 512Mi (limit)
- Runs on every node as DaemonSet

**Estimated Total** (per node):
- ~100-200m CPU
- ~256-512Mi Memory

Adjust resource limits in `alloy.yml` under `resources:` section if needed.

## Security

- Alloy runs as root (UID 0) to read logs from `/var/log` and `/var/lib/docker/containers`
- RBAC is configured with minimal permissions for Kubernetes discovery and log reading
- No secrets are currently required
- When adding authentication for Loki/Prometheus/Tempo, use Kubernetes secrets

## References

- [Grafana Alloy Documentation](https://grafana.com/docs/alloy/latest/)
- [Grafana Alloy Helm Chart](https://github.com/grafana/alloy/tree/main/operations/helm/charts/alloy)
- [Alloy Configuration Syntax](https://grafana.com/docs/alloy/latest/reference/config-blocks/)
