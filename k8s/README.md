# Kubernetes Resources Export

This directory contains GitOps-ready Kubernetes resources packaged as a Helm chart for Argo CD.

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

## Argo CD Deployment (Recommended)

1. Update `repoURL` in `k8s/argocd/application.yaml` to your repository URL.
2. Apply the Argo CD application:

```bash
kubectl apply -f k8s/argocd/application.yaml
```

3. Argo CD will sync and continuously reconcile the chart from `k8s/charts`.

## Helm Deployment (Manual)

### Using Helm

```bash
# Install the chart
helm install k8s-export ./charts

# Upgrade the chart
helm upgrade k8s-export ./charts

# Install with custom values
helm install k8s-export ./charts -f custom-values.yaml
```

### Manual kubectl deployment

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

- Templates are refactored to remove cluster-generated runtime metadata (UIDs, resourceVersions, bind annotations).
- Cluster-managed resources such as `kube-root-ca.crt` are excluded from GitOps templates.
- Secrets are optional and disabled by default (`secrets.enabled=false`) to support External Secrets / sealed workflows.
- ServiceAccounts and PVCs are optional and fully values-driven.

