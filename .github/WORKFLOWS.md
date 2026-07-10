# GitHub Actions Workflows

Documentation for automated CI/CD pipelines.

---

## 📋 Workflow Overview

| Workflow | Trigger | Purpose | Files |
|----------|---------|---------|-------|
| gitops-k8s-resources.yml | repository_dispatch | Update image versions from app repos | values.yaml |
| deploy-helm.yml | Manual trigger | Deploy/update cluster configuration | All templates |

---

## 🚀 gitops-k8s-resources.yml

### Purpose

Automatically update Kubernetes deployments when application images are published.

**Flow:**
```
App Repo (axric-api, rekakim-backend)
  ↓ publishes image
  ↓ sends repository_dispatch
GitHub Actions (k8s-manifests repo)
  ↓ receives dispatch event
  ↓ extracts version from payload
  ↓ updates values.yaml with yq
  ↓ commits and pushes
ArgoCD
  ↓ detects change
  ↓ auto-syncs cluster
Kubernetes Cluster
  ↓ pulls new image
  ↓ updates running pods
```

### Trigger

Repository dispatch from application repositories.

**Event Type:** `deployment-app`

**Payload Format:**

```json
{
  "event_type": "deployment-app",
  "client_payload": {
    "version": "1.0.4",
    "sourceRepo": "deployment-backend"
  }
}
```

### Workflow Steps

#### 1. Receive Dispatch

```yaml
on:
  repository_dispatch:
    types: [deployment-app]
```

#### 2. Extract Version

```bash
NEW_VERSION="${{ github.event.client_payload.version }}"
SOURCE_REPO="${{ github.event.client_payload.sourceRepo }}"
```

#### 3. Detect Target App

```bash
if [[ "$SOURCE_REPO" == *"deployment-backend"* ]] || \
   [[ "$SOURCE_REPO" == *"rekakim"* ]]; then
  TARGET_APP="rekakim"
elif [[ "$SOURCE_REPO" == *"deployment-frontend"* ]] || \
     [[ "$SOURCE_REPO" == *"axric"* ]]; then
  TARGET_APP="axric"
fi
```

**Pattern Matching:**
- `deployment-backend`, `Deployment-Backend`, `rekakim` → `rekakim`
- `deployment-frontend`, `Deployment-Frontend`, `axric-api`, `axric-fe` → `axric`

#### 4. Update values.yaml

```bash
# For Rekakim
yq eval ".apps.rekakimBackend.image = \"jaron197/rekakim-backend:$VERSION\"" -i values.yaml

# For Axric
yq eval ".apps.axric-api.image = \"jaron197/axric-api:$VERSION\"" -i values.yaml
yq eval ".apps.axric-fe.image = \"jaron197/axric-fe:$VERSION\"" -i values.yaml
```

#### 5. Commit & Push

```bash
git config --local user.email "github-actions[bot]@users.noreply.github.com"
git config --local user.name "github-actions[bot]"
git add k8s/charts/values.yaml
git commit -m "chore: Update $TARGET_APP image version to $VERSION"
git push origin main
```

#### 6. Generate Summary

Output to GitHub step summary:
```
✅ Deployment Updated
App: rekakim-backend
Version: 1.0.4
Source: deployment-backend
Time: 2026-06-17 14:23:15
```

### Usage from App Repository

**Using curl:**

```bash
curl -X POST \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/OWNER/k8s-manifests/dispatches \
  -d '{"event_type":"deployment-app","client_payload":{"version":"1.0.4","sourceRepo":"deployment-backend"}}'
```

**Using GitHub CLI:**

```bash
gh repo dispatch OWNER/k8s-manifests \
  --event deployment-app \
  --client-payload "{\"version\":\"1.0.4\",\"sourceRepo\":\"deployment-backend\"}"
```

**From GitHub Actions:**

```yaml
# In app repository workflow
- name: Trigger k8s-manifests deployment
  run: |
    gh repo dispatch OWNER/k8s-manifests \
      --event deployment-app \
      --client-payload "{\"version\":\"${{ github.sha }}\",\"sourceRepo\":\"${{ github.repository }}\"}"
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Secrets Required

- `DOCKERHUB_USERNAME`: Optional, used in image path construction

### Troubleshooting

**Workflow not triggered:**
```bash
# Check dispatch was sent
gh api -X POST repos/OWNER/k8s-manifests/dispatches \
  -f event_type=deployment-app \
  -f client_payload='{"version":"test","sourceRepo":"test-repo"}'

# Check workflow logs
gh run list --repo OWNER/k8s-manifests --limit 5
gh run view <run-id> --log
```

**Image not updating:**
```bash
# Verify values.yaml was updated
git log --oneline -5 -- k8s/charts/values.yaml

# Check ArgoCD sync
argocd app get axric-k8s-export --refresh
```

---

## 🔧 deploy-helm.yml

### Purpose

Manual deployment/update to Kubernetes cluster.

### Trigger

- Manual (via GitHub Actions UI)
- Scheduled (optional)

### Workflow Steps

1. **Checkout code**
2. **Lint Helm chart**
   ```bash
   helm lint k8s/charts/
   ```

3. **Template validation**
   ```bash
   helm template axric-deployment k8s/charts -f k8s/charts/values.yaml
   ```

4. **Deploy to cluster**
   ```bash
   helm upgrade --install axric-deployment k8s/charts \
     --namespace axric \
     --create-namespace
   ```

5. **Wait for rollout**
   ```bash
   kubectl rollout status deployment/axric-api -n axric
   ```

### Usage

1. Go to **Actions** tab
2. Select **Deploy Helm Chart**
3. Click **Run workflow**
4. Select branch (main/develop)
5. Click **Run workflow**
6. Monitor deployment in Actions logs

---

## 📊 Monitoring Workflows

### View Workflow History

```bash
# List recent runs
gh run list --repo OWNER/k8s-manifests --limit 10

# View specific run
gh run view <run-id> --log

# Watch live
gh run watch <run-id>
```

### Check Workflow Status

```bash
# From workflow status badge
https://github.com/OWNER/k8s-manifests/actions/workflows/gitops-k8s-resources.yml/badge.svg

# Current status
gh api repos/OWNER/k8s-manifests/actions/runs --limit 1
```

---

## 🔑 Setting Up Secrets

### GitHub Actions Secrets

Required secrets for workflows:

```bash
# Set secret
gh secret set SECRET_NAME --body "secret_value"

# List secrets
gh secret list

# Update secret
gh secret set EXISTING_SECRET --body "new_value"
```

**Required Secrets:**

| Secret | Value | Used By |
|--------|-------|---------|
| DOCKERHUB_USERNAME | Docker Hub username | gitops-k8s-resources.yml (optional) |
| GITHUB_TOKEN | Auto-provided by GitHub | All workflows |

---

## 🚀 Creating New Workflows

### Template

```yaml
name: New Workflow

on:
  push:
    branches: [main]
    paths:
      - 'k8s/charts/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install Helm
        uses: azure/setup-helm@v3
        with:
          version: '3.x'
      
      - name: Validate Chart
        run: helm lint k8s/charts/
      
      - name: Deploy
        run: |
          helm upgrade --install deployment k8s/charts \
            --namespace default \
            --create-namespace
```

---

## 📝 Workflow Examples

### Example 1: Image Build and Deploy

**In app repository:**

```yaml
# .github/workflows/build-and-deploy.yml
name: Build and Deploy

on:
  push:
    tags: ['v*']

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Build image
        run: docker build -t jaron197/rekakim-backend:${{ github.ref_name }} .
      
      - name: Push image
        run: |
          echo "${{ secrets.DOCKERHUB_TOKEN }}" | docker login -u "${{ secrets.DOCKERHUB_USERNAME }}" --password-stdin
          docker push jaron197/rekakim-backend:${{ github.ref_name }}
      
      - name: Trigger k8s deployment
        run: |
          curl -X POST \
            -H "Accept: application/vnd.github.v3+json" \
            -H "Authorization: token ${{ secrets.GITHUB_TOKEN }}" \
            https://api.github.com/repos/OWNER/k8s-manifests/dispatches \
            -d "{\"event_type\":\"deployment-app\",\"client_payload\":{\"version\":\"${{ github.ref_name }}\",\"sourceRepo\":\"${{ github.repository }}\"}}"
```

### Example 2: Scheduled Health Check

```yaml
name: Cluster Health Check

on:
  schedule:
    - cron: '0 8 * * *'  # Daily at 8 AM UTC

jobs:
  health-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up kubectl
        uses: azure/setup-kubectl@v3
        with:
          version: 'v1.29.15'
      
      - name: Configure kubectl
        run: |
          mkdir -p $HOME/.kube
          echo "${{ secrets.KUBECONFIG }}" | base64 -d > $HOME/.kube/config
      
      - name: Check pod status
        run: |
          kubectl get pods -n axric -n rekakim-backend
          kubectl get events -A --sort-by='.lastTimestamp' | tail -20
```

---

## 📚 References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Repository Dispatch Event](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#repository_dispatch)
- [Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)

---

**Last Updated:** 2026-06-17  
**Maintained By:** DevOps Team

