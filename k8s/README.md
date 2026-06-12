# Kubernetes Resources Export

This directory contains exported Kubernetes resources as a Helm chart.

## Directory Structure

- **charts/**: Helm chart with all Kubernetes resources
  - **Chart.yaml**: Helm chart metadata
  - **values.yaml**: Chart configuration
  - **templates/**: Exported Kubernetes manifests organized by resource type and namespace

### Exported Resource Types

- `deployments/` - Kubernetes Deployments
- `statefulsets/` - StatefulSets
- `daemonsets/` - DaemonSets
- `configmaps/` - ConfigMaps
- `secrets/` - Secrets
- `services/` - Services
- `ingresses/` - Ingress resources
- `pvcs/` - PersistentVolumeClaims
- `rbac/` - RBAC resources (Roles, RoleBindings, etc.)
- `custom-resources/` - Custom Resource Definitions and instances

## Installation

### Using Helm

```bash
# Install the chart
helm install k8s-export ./charts

# Upgrade the chart
helm upgrade k8s-export ./charts

# Install with custom values
helm install k8s-export ./charts -f custom-values.yaml
```

### Manual deployment

```bash
# Apply exported resources directly
kubectl apply -f charts/templates/deployments/
kubectl apply -f charts/templates/services/
# ... and so on
```

## Export Schedule

Resources are automatically exported daily at 2 AM UTC via GitHub Actions workflow.

## Manual Export

To trigger an export manually:

1. Go to Actions tab in GitHub
2. Select "Export K8s Resources to Helm" workflow
3. Click "Run workflow"

## Requirements

- Valid Kubernetes cluster credentials in `KUBE_CONFIG` secret
- GitHub Actions enabled
- Appropriate permissions to read cluster resources

## Notes

- This workflow removes runtime metadata for GitOps-friendly diffs
- Secrets are NOT exported by default (`EXPORT_SECRETS=false`)
- Cluster RBAC and custom resources are disabled by default
- Set workflow env vars to enable additional resource exports

