# Kubernetes Export Workflow Setup Guide

## Overview

The `export-k8s-resources.yml` workflow automatically exports your Kubernetes cluster resources and packages them as a Helm chart in the `k8s/` directory.

## Prerequisites

1. A working Kubernetes cluster
2. GitHub Actions enabled in your repository
3. Admin access to the repository to add secrets

## Setup Instructions

### Configure Namespaces (Optional)

By default, the workflow exports from these namespaces:
- **axric** (primary application namespace)
- **kube-system** (Kubernetes system components)
- **ingress-nginx** (Ingress controller)
- **argocd** (GitOps)
- **database** (Database services)

To customize which namespaces to export, edit the workflow file:

```yaml
env:
  EXPORT_NAMESPACES: "axric kube-system ingress-nginx argocd database"
```

Change the `EXPORT_NAMESPACES` value to include/exclude namespaces as needed.

### 1. Create Kubernetes Service Account (Recommended for CI/CD)

```bash
# Create a namespace for the CI/CD service account
kubectl create namespace github-actions

# Create service account
kubectl create serviceaccount github-actions -n github-actions

# Create ClusterRole with read permissions
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: github-actions-reader
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
EOF

# Bind ClusterRole to service account
kubectl create clusterrolebinding github-actions-reader \
  --clusterrole=github-actions-reader \
  --serviceaccount=github-actions:github-actions
```

### 2. Generate kubeconfig

```bash
# Get the token
TOKEN=$(kubectl create token github-actions -n github-actions)

# Get cluster info
CLUSTER=$(kubectl cluster-info | grep 'Kubernetes master' | awk '/https/ {print $NF}')
CLUSTER_NAME=$(kubectl config current-context)

# Create kubeconfig
cat > kubeconfig.yaml <<EOF
apiVersion: v1
kind: Config
clusters:
- name: $CLUSTER_NAME
  cluster:
    server: $CLUSTER
    insecure-skip-tls-verify: true  # Only for testing, use proper certs in production
contexts:
- name: default
  context:
    cluster: $CLUSTER_NAME
    user: github-actions
users:
- name: github-actions
  user:
    token: $TOKEN
current-context: default
EOF

# Encode in base64
cat kubeconfig.yaml | base64 -w 0
```

### 3. Add Repository Secret

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Create secret named `KUBE_CONFIG` with the base64-encoded kubeconfig content

### 4. Configure Workflow (Optional)

Edit [.github/workflows/export-k8s-resources.yml](.github/workflows/export-k8s-resources.yml) to customize:

- **Schedule**: Change the cron expression in the `schedule` trigger
- **Namespaces**: Add or remove namespace filtering
- **Resource types**: Add more resource types to export
- **Helm chart**: Customize Chart.yaml metadata

## Triggering the Workflow

### Automatic
- Runs daily at 2 AM UTC (configurable in the workflow file)

### Manual
1. Go to the **Actions** tab in your GitHub repository
2. Select **"Export K8s Resources to Helm"** workflow
3. Click **"Run workflow"** button

## Output Structure

```
k8s/
├── charts/                           # Helm chart with resources
│   ├── Chart.yaml                    # Helm chart metadata
│   ├── values.yaml                   # Helm chart values
│   └── templates/                    # All exported Kubernetes resources
│       ├── _helpers.tpl              # Helm helpers
│       ├── deployments/
│       ├── statefulsets/
│       ├── daemonsets/
│       ├── configmaps/
│       ├── secrets/
│       ├── services/
│       ├── ingresses/
│       ├── pvcs/
│       ├── rbac/
│       └── custom-resources/
├── README.md                         # Documentation
└── INVENTORY.md                      # Resource statistics
```

## Using Exported Resources

### Deploy using Helm

```bash
# Install
helm install k8s-export ./k8s/charts

# Upgrade
helm upgrade k8s-export ./k8s/charts

# With custom values
helm install k8s-export ./k8s/charts -f custom-values.yaml
```

### Deploy specific resources manually

```bash
# Deploy just deployments
kubectl apply -f k8s/exports/deployments/

# Deploy a specific namespace
kubectl apply -f k8s/exports/deployments/default/
```

## Troubleshooting

### Connection Failed

**Error**: `Unable to connect to the server`

**Solution**:
- Verify `KUBE_CONFIG` secret contains valid kubeconfig
- Test locally: `kubectl --kubeconfig=kubeconfig.yaml cluster-info`
- Check cluster is accessible from GitHub Actions runners

### Permission Denied

**Error**: `error: You must be logged in to the server`

**Solution**:
- Verify service account has appropriate permissions
- Check token hasn't expired (tokens expire after 1 hour by default in newer k8s versions)
- Use a kubeconfig with longer-lived credentials for production

### No Resources Exported

**Error**: Files are empty or missing

**Solution**:
- Verify cluster has resources deployed
- Check RBAC permissions: `kubectl auth can-i list deployments --as=system:serviceaccount:github-actions:github-actions`
- Review workflow logs in GitHub Actions tab

### Secret Base64 Encoding Issues

**Solution**:
```bash
# Ensure proper encoding without line breaks
cat kubeconfig.yaml | base64 -w 0 | tr -d '\n'

# On macOS
cat kubeconfig.yaml | base64 | tr -d '\n'
```

## Security Considerations

1. **Service Account Permissions**: The provided ClusterRole only grants read permissions
2. **Secret Management**: Secrets are exported but base64-encoded; consider additional encryption
3. **kubeconfig Rotation**: Regularly rotate tokens by recreating them
4. **Repository Access**: Restrict repository access since it will contain cluster manifests
5. **Branch Protection**: Consider protecting branches and requiring reviews for exports with secrets

## Advanced Customization

### Add Custom Resource Types

Edit the workflow to export additional CRDs:

```yaml
- name: Export Your Custom Resource
  run: |
    mkdir -p k8s/exports/your-resource
    kubectl get your-resource -A -o yaml > k8s/exports/your-resource/all.yaml
```

### Filter by Labels or Annotations

```yaml
- name: Export Labeled Resources
  run: |
    kubectl get deployments -A -l app=myapp -o yaml > k8s/exports/deployments/myapp.yaml
```

### Exclude Certain Resources

Modify the namespace loop to skip namespaces:

```yaml
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v kube-); do
  # export resources
done
```

## Support

For issues or questions:
1. Check GitHub Actions logs
2. Review this setup guide
3. Verify RBAC permissions with `kubectl auth`
