# Deployment Runbook

Complete procedures for deploying, managing, and troubleshooting Kubernetes infrastructure.

---

## 📋 Table of Contents

1. [First-Time Setup](#first-time-setup)
2. [Deployment Procedures](#deployment-procedures)
3. [Verification Checklist](#verification-checklist)
4. [Troubleshooting](#troubleshooting)
5. [Rollback Procedures](#rollback-procedures)
6. [Monitoring & Health Checks](#monitoring--health-checks)

---

## 🔧 First-Time Setup

### Prerequisites Checklist

```bash
# Verify Kubernetes cluster
kubectl cluster-info
kubectl version

# Verify Helm 3.x+
helm version

# Verify kubectl context
kubectl config current-context
kubectl get nodes
```

### Step 1: Create Required Namespaces

```bash
# ArgoCD namespace (if not already created)
kubectl create namespace argocd

# Application namespaces
kubectl create namespace axric
kubectl create namespace rekakim-backend
kubectl create namespace axric-db
kubectl create namespace kafka-prod
kubectl create namespace kafka-dev
```

### Step 2: Install ArgoCD (Optional, for GitOps)

```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl rollout status deployment/argocd-server -n argocd

# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open https://localhost:8080
```

### Step 3: Configure Repository Access

```bash
# Add k8s-manifests repo to ArgoCD
argocd repo add https://github.com/OWNER/k8s-manifests.git \
  --username git-user \
  --password git-token \
  --insecure-skip-server-verification

# Or via UI: Settings → Repositories → Connect Repo
```

### Step 4: Create PostgreSQL Persistent Data (if needed)

```bash
# Optionally create persistent storage
kubectl apply -f k8s/charts/templates/pvcs/

# For local development, create local-path storage class
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
EOF
```

---

## 🚀 Deployment Procedures

### Option A: ArgoCD (Recommended for Production)

#### Deploy via ArgoCD

```bash
# 1. Update application.yaml with your repository URL
cat k8s/argocd/application.yaml

# 2. Apply the ArgoCD Application
kubectl apply -f k8s/argocd/application.yaml

# 3. Monitor sync progress
argocd app get axric-k8s-export
watch -n 2 'argocd app get axric-k8s-export | grep -A 5 Status'

# 4. Verify all pods are running
kubectl get pods -n axric
kubectl get pods -n rekakim-backend
kubectl get pods -n axric-db
kubectl get pods -n kafka-prod
```

#### Troubleshoot ArgoCD Deployment

```bash
# Check Application status
kubectl get application -n argocd axric-k8s-export

# Describe for details
kubectl describe application axric-k8s-export -n argocd

# Check ArgoCD server logs
kubectl logs -n argocd deployment/argocd-server | tail -50

# Sync with verbose output
argocd app sync axric-k8s-export --v

# Hard refresh (clears cache)
argocd app sync axric-k8s-export --hard-refresh
```

### Option B: Helm (Manual Deployment)

#### Development Environment

```bash
# Install with development values (1 replica, low resources)
helm install axric-deployment k8s/charts \
  -n axric \
  --create-namespace \
  -f k8s/charts/values-dev.yaml

# Verify installation
helm status axric-deployment -n axric
kubectl get pods -n axric
```

#### Staging Environment

```bash
# Install with staging values (2 replicas, medium resources)
helm install axric-deployment k8s/charts \
  -n axric \
  --create-namespace \
  -f k8s/charts/values-staging.yaml
```

#### Production Environment

```bash
# Install with production values (3 replicas, full resources)
helm install axric-deployment k8s/charts \
  -n axric \
  --create-namespace \
  -f k8s/charts/values-prod.yaml

# Verify production requirements
kubectl get pv
kubectl top nodes
kubectl top pods -n axric
```

#### Upgrade Existing Deployment

```bash
# Update values
vim k8s/charts/values.yaml

# Validate changes
helm lint k8s/charts/
helm template axric-deployment k8s/charts | less

# Perform upgrade
helm upgrade axric-deployment k8s/charts -n axric

# Monitor upgrade
kubectl rollout status deployment/axric-api -n axric
kubectl rollout status deployment/axric-fe -n axric
```

---

## ✅ Verification Checklist

### Post-Deployment Validation

```bash
# 1. All pods running
echo "=== Pod Status ==="
kubectl get pods -n axric
kubectl get pods -n rekakim-backend
kubectl get pods -n axric-db
kubectl get pods -n kafka-prod

# 2. Services available
echo "=== Service Status ==="
kubectl get svc -n axric
kubectl get svc -n rekakim-backend

# 3. Ingress configured
echo "=== Ingress Status ==="
kubectl get ingress -n axric
kubectl get ingress -n rekakim-backend

# 4. ConfigMaps and Secrets loaded
echo "=== ConfigMap Status ==="
kubectl get configmap -n axric
kubectl get configmap -n rekakim-backend

echo "=== Secret Status ==="
kubectl get secret -n axric
kubectl get secret -n rekakim-backend

# 5. No pod errors
echo "=== Pod Logs Check ==="
kubectl logs deployment/axric-api -n axric --tail=5
kubectl logs deployment/rekakim-backend -n rekakim-backend --tail=5
```

### Health Check Script

```bash
#!/bin/bash

echo "📋 Deployment Health Check"
echo "=========================="

# Namespace check
for ns in axric rekakim-backend axric-db kafka-prod; do
  echo "Checking namespace: $ns"
  kubectl get pods -n $ns -o wide
  
  # Failed pods?
  failed=$(kubectl get pods -n $ns -o jsonpath='{.items[?(@.status.phase!="Running")].metadata.name}')
  if [ -n "$failed" ]; then
    echo "⚠️  Failed pods in $ns: $failed"
  fi
done

echo ""
echo "✅ Health check complete"
```

---

## 🔄 Update Procedures

### Update Application Image

#### Via GitHub Actions (Automatic)

1. App repository pushes new image: `jaron197/rekakim-backend:1.0.4`
2. App sends repository_dispatch to this repo
3. GitHub Actions workflow auto-updates values.yaml
4. ArgoCD detects change and auto-syncs

See [.github/WORKFLOWS.md] for dispatch format.

#### Manual Update

```bash
# Edit values.yaml
vim k8s/charts/values.yaml

# Update image:
# apps.rekakimBackend.image: jaron197/rekakim-backend:1.0.4
# apps.axric-api.image: jaron197/axric-api:1.0.42

# Validate
helm lint k8s/charts/

# Deploy
helm upgrade axric-deployment k8s/charts -n axric

# Monitor rollout
kubectl rollout status deployment/rekakim-backend -n rekakim-backend
kubectl rollout status deployment/axric-api -n axric
```

### Scale Replicas

```bash
# Update values.yaml
vim k8s/charts/values.yaml
# Change: apps.axric-api.replicaCount: 5

# Apply
helm upgrade axric-deployment k8s/charts -n axric

# Or via kubectl
kubectl scale deployment axric-api --replicas=5 -n axric

# Monitor scaling
kubectl get pods -n axric -w
```

### Update Configuration

```bash
# Edit ConfigMap values
vim k8s/charts/values.yaml
# Modify: configMaps.axric-backend-config.data.KAFKA_BROKERS

# Update chart
helm upgrade axric-deployment k8s/charts -n axric

# Verify ConfigMap updated
kubectl get configmap axric-backend-config -n axric -o yaml | grep KAFKA

# Restart pods to pick up new config
kubectl rollout restart deployment/axric-api -n axric
```

---

## 🔙 Rollback Procedures

### Helm Rollback

```bash
# List release history
helm history axric-deployment -n axric

# Rollback to previous release
helm rollback axric-deployment -n axric

# Rollback to specific revision
helm rollback axric-deployment 2 -n axric

# Verify rollback
helm status axric-deployment -n axric
kubectl rollout status deployment/axric-api -n axric
```

### Kubernetes Deployment Rollback

```bash
# Check rollout history
kubectl rollout history deployment/axric-api -n axric

# Undo last rollout
kubectl rollout undo deployment/axric-api -n axric

# Undo to specific revision
kubectl rollout undo deployment/axric-api -n axric --to-revision=3

# Monitor rollback
kubectl rollout status deployment/axric-api -n axric
```

### Database Rollback (if needed)

```bash
# PostgreSQL has snapshot functionality
# Check available backups
kubectl get pvc -n axric-db

# For manual backup/restore
# Backup: kubectl exec -it postgres-0 -n axric-db -- pg_dump -U axricuser > backup.sql
# Restore: kubectl exec -it postgres-0 -n axric-db -- psql -U axricuser < backup.sql
```

---

## 📊 Monitoring & Health Checks

### Real-Time Logs

```bash
# Follow Axric API logs
kubectl logs -f deployment/axric-api -n axric

# Follow Rekakim backend logs
kubectl logs -f deployment/rekakim-backend -n rekakim-backend

# Follow PostgreSQL logs
kubectl logs -f statefulset/axric-postgres -n axric-db

# Follow Kafka logs
kubectl logs -f statefulset/kafka-prod -n kafka-prod

# Stream all pod logs across namespaces
kubectl logs -f deployment/axric-api -n axric deployment/rekakim-backend -n rekakim-backend
```

### Pod Inspection

```bash
# Describe pod for events
kubectl describe pod -l app=axric-api -n axric

# Check resource usage
kubectl top pods -n axric
kubectl top nodes

# Check environment variables in pod
kubectl exec deployment/axric-api -n axric -- env | sort

# Access pod shell
kubectl exec -it deployment/rekakim-backend -n rekakim-backend -- /bin/sh
```

### Health Endpoints

```bash
# Port-forward to service
kubectl port-forward svc/axric-api 3000:3000 -n axric

# Test health endpoint
curl http://localhost:3000/health

# Test Rekakim endpoint
kubectl port-forward svc/rekakim-backend 1080:1080 -n rekakim-backend
curl http://localhost:1080/health
```

### Database Connectivity Tests

```bash
# Test PostgreSQL from pod
kubectl exec -it deployment/axric-api -n axric -- \
  sh -c 'pg_isready -h axric-postgres.axric-db -p 5432'

# Run psql client
kubectl run -it psql --image=postgres:16 -n axric-db -- \
  psql -h axric-postgres -U axricuser -d axricdb -c "SELECT version();"

# Check Kafka brokers
kubectl exec -it statefulset/kafka-prod-0 -n kafka-prod -- \
  kafka-broker-api-versions --bootstrap-server localhost:9092
```

### Prometheus Metrics (if installed)

```bash
# Query pod memory usage
kubectl exec -it deployment/prometheus -n monitoring -- \
  promtool query range 'sum(container_memory_usage_bytes) by (pod_name)' 1h

# Port-forward to Prometheus
kubectl port-forward svc/prometheus 9090:9090 -n monitoring
# Open http://localhost:9090
```

---

## 🚨 Common Issues & Solutions

### Issue: ImagePullBackOff

```bash
# Check image availability
kubectl describe pod -l app=axric-api -n axric | grep "image:"

# Verify imagePullSecret
kubectl get secret -n axric

# Verify Docker Hub credentials
kubectl get secret dockercfg -n axric -o jsonpath='{.data}'
```

### Issue: CrashLoopBackOff

```bash
# Check pod logs
kubectl logs deployment/rekakim-backend -n rekakim-backend --previous

# Get detailed pod info
kubectl describe pod -l app=rekakim-backend -n rekakim-backend

# Common causes:
# 1. Missing environment variables
kubectl get secret rekakim-backend-secret -n rekakim-backend -o yaml
# 2. Database connection refused
kubectl exec -it deployment/rekakim-backend -n rekakim-backend -- \
  sh -c 'nc -v axric-postgres.axric-db 5432'
# 3. Port already in use
kubectl port-forward svc/rekakim-backend 1080:1080 -n rekakim-backend
```

### Issue: OutOfMemory (OOMKilled)

```bash
# Check resource limits
kubectl describe node
kubectl top pods -n axric --sort-by=memory

# Increase limits
helm upgrade axric-deployment k8s/charts \
  -n axric \
  --set apps.axric-api.resources.limits.memory=1Gi
```

### Issue: PVC Pending

```bash
# Check PVC status
kubectl get pvc -n axric-db

# Check available storage classes
kubectl get storageclass

# Describe PVC for events
kubectl describe pvc postgres-pvc -n axric-db
```

---

## 📝 Incident Response

### Create Incident Log

```bash
# Collect diagnostic info
kubectl cluster-info dump --all-namespaces --output-directory=/tmp/cluster-dump

# Export all resources
kubectl get all -A -o yaml > /tmp/cluster-state.yaml

# Check recent events
kubectl get events -n axric --sort-by='.lastTimestamp' | tail -20
```

### Graceful Shutdown

```bash
# Drain node before maintenance
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Cordon node to prevent new pods
kubectl cordon <node-name>

# Restore node
kubectl uncordon <node-name>
```

### Emergency Delete

```bash
# Force delete stuck pod
kubectl delete pod <pod-name> -n axric --grace-period=0 --force

# Clean up failed jobs
kubectl delete job --field-selector status.successful=0 -n axric
```

---

## 📞 Support & Escalation

**Primary Contact:** jaronthongfoo@gmail.com  
**Repository:** https://github.com/OWNER/k8s-manifests  
**Documentation:** See [README.md](../README.md)

