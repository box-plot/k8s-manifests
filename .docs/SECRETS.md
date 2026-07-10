# Secrets Management

Best practices for managing sensitive credentials in Kubernetes.

---

## ⚠️ Current State (Development)

### Existing Credentials in values.yaml

Currently storing secrets directly in `values.yaml` is **NOT SECURE** for production:

```yaml
# ❌ NOT FOR PRODUCTION
apps:
  rekakimBackend:
    secret:
      stringData:
        PG_USER: "axricuser"
        PG_PASS: "6u9WLtpk5u"           # Exposed!
        PG_DB_NAME: "axricdb"
```

### Credentials Currently Exposed

| Service | Username | Password | Notes |
|---------|----------|----------|-------|
| PostgreSQL | axricuser | 6u9WLtpk5u | Used by Rekakim & Axric |
| Docker Hub | jaronthongfoo | [via env] | If private repos needed |
| LINE API | [in configMap] | [test token] | External service |
| TikTok API | [in configMap] | [test token] | External service |
| Facebook API | [in configMap] | [test token] | External service |

---

## 🔒 Production-Grade Solutions

### Option 1: Sealed Secrets (Recommended)

Encrypted secrets stored safely in git.

#### Installation

```bash
# Install sealed-secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.27.0/controller.yaml -n kube-system

# Verify installation
kubectl get pods -n kube-system | grep sealed
```

#### Usage

```bash
# 1. Create secret normally
kubectl create secret generic rekakim-backend-secret \
  --from-literal=PG_USER=axricuser \
  --from-literal=PG_PASS=NEW_SECURE_PASSWORD \
  -n rekakim-backend \
  --dry-run=client -o yaml > secret.yaml

# 2. Seal it
kubeseal -f secret.yaml -w sealed-secret.yaml

# 3. Commit sealed-secret.yaml safely to git
git add sealed-secret.yaml
git commit -m "chore: Add encrypted database secret"

# 4. Deploy sealed secret
kubectl apply -f sealed-secret.yaml
```

#### In Helm Chart

```yaml
# k8s/charts/templates/secrets/rekakim-backend-secret.yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: rekakim-backend-secret
  namespace: {{ .Values.apps.rekakimBackend.namespace }}
spec:
  encryptedData:
    PG_USER: AgBvB3McZ1v...  # Encrypted value
    PG_PASS: AgCqK9Zad2m...  # Encrypted value
  template:
    metadata:
      name: rekakim-backend-secret
      namespace: {{ .Values.apps.rekakimBackend.namespace }}
    type: Opaque
```

---

### Option 2: External Secrets Operator (ESO)

Fetch secrets from external vault at deploy time.

#### Installation

```bash
# Add helm repo
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# Install ESO
helm install external-secrets \
  external-secrets/external-secrets \
  -n external-secrets-system \
  --create-namespace
```

#### Configuration with HashiCorp Vault

```yaml
# k8s/charts/templates/secrets/vault-secretstore.yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-secret-store
  namespace: rekakim-backend
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "rekakim-backend"
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: rekakim-backend-secret
  namespace: rekakim-backend
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-secret-store
    kind: SecretStore
  target:
    name: rekakim-backend-secret
    creationPolicy: Owner
  data:
  - secretKey: PG_USER
    remoteRef:
      key: database/postgres/username
  - secretKey: PG_PASS
    remoteRef:
      key: database/postgres/password
```

---

### Option 3: AWS Secrets Manager

For clusters in AWS (EKS).

```yaml
# k8s/charts/templates/secrets/aws-secret.yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets
  namespace: rekakim-backend
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: rekakim-backend-secret
  namespace: rekakim-backend
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets
    kind: SecretStore
  target:
    name: rekakim-backend-secret
    creationPolicy: Owner
  data:
  - secretKey: PG_USER
    remoteRef:
      key: rds/postgres/username
  - secretKey: PG_PASS
    remoteRef:
      key: rds/postgres/password
```

---

### Option 4: HashiCorp Vault

Enterprise secret management.

#### Installation

```bash
# Add Vault helm repo
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Install Vault
helm install vault hashicorp/vault \
  -n vault \
  --create-namespace \
  --values vault-values.yaml
```

#### Store Secrets in Vault

```bash
# Login to Vault
vault login

# Store database secret
vault kv put secret/database/postgres \
  username=axricuser \
  password=SECURE_PASSWORD

# Store API tokens
vault kv put secret/external-apis \
  line_channel_id=xxx \
  line_channel_secret=yyy
```

#### Kubernetes Authentication

```bash
# Enable Kubernetes auth method
vault auth enable kubernetes

# Configure Kubernetes auth
vault write auth/kubernetes/config \
  kubernetes_host="$KUBERNETES_HOST:$KUBERNETES_PORT_443_TCP_PORT" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token

# Create policy
vault policy write rekakim-secret - <<EOF
path "secret/data/database/postgres" {
  capabilities = ["read"]
}
EOF

# Create Kubernetes role
vault write auth/kubernetes/role/rekakim-backend \
  bound_service_account_names=rekakim-backend \
  bound_service_account_namespaces=rekakim-backend \
  policies=rekakim-secret \
  ttl=24h
```

---

## 🔐 Credential Rotation

### PostgreSQL Password Rotation

```bash
#!/bin/bash
# 1. Generate new password
NEW_PASSWORD=$(openssl rand -base64 32)

# 2. Update in secret manager (Vault/Sealed Secrets)
vault kv put secret/database/postgres password=$NEW_PASSWORD

# 3. Update in database
kubectl exec -it statefulset/axric-postgres-0 -n axric-db -- \
  psql -U postgres -c "ALTER USER axricuser WITH PASSWORD '$NEW_PASSWORD';"

# 4. Force pods to restart (pickup new secret)
kubectl rollout restart deployment/rekakim-backend -n rekakim-backend
kubectl rollout restart deployment/axric-api -n axric

# 5. Verify connectivity
kubectl logs deployment/rekakim-backend -n rekakim-backend | grep "PostgreSQL connected"
```

### API Token Rotation

```bash
# Update tokens in Vault
vault kv put secret/external-apis \
  line_channel_secret=NEW_TOKEN \
  tiktok_secret=NEW_TOKEN

# Restart applications to pickup new values
kubectl rollout restart deployment/rekakim-backend -n rekakim-backend
kubectl rollout restart deployment/axric-api -n axric
```

### Automated Rotation (Optional)

```bash
# Consider using tools like:
# - Vault: Built-in password rotation policies
# - cert-manager: Automatic certificate renewal
# - External operators: Custom rotation controllers
```

---

## 🛡️ Security Best Practices

### 1. Access Control

```bash
# Limit who can view secrets
kubectl create rolebinding secret-reader \
  --clusterrole=secret-reader \
  --serviceaccount=rekakim-backend:rekakim-backend \
  -n rekakim-backend

# Audit secret access
kubectl get events -n rekakim-backend | grep Secret
```

### 2. Encryption at Rest

```bash
# Verify etcd encryption is enabled
kubectl get secrets -n rekakim-backend -o json | \
  jq '.items[0].metadata.managedFields[].manager'

# Check encryption configuration
cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep encryption-provider-config
```

### 3. Network Policies

```yaml
# k8s/charts/templates/networkpolicies/rekakim-network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: rekakim-backend-network-policy
  namespace: rekakim-backend
spec:
  podSelector:
    matchLabels:
      app: rekakim-backend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: axric  # Only from axric namespace
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: axric-db  # Database only
    ports:
    - protocol: TCP
      port: 5432
  - to:
    - namespaceSelector:
        matchLabels:
          name: kafka-prod
    ports:
    - protocol: TCP
      port: 9092
```

### 4. RBAC Restrictions

```yaml
# k8s/charts/templates/rbac/rekakim-role.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: rekakim-backend-role
  namespace: rekakim-backend
rules:
# Only allow reading ConfigMaps and Secrets in same namespace
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["rekakim-backend-secret"]
  verbs: ["get"]
```

### 5. Secret Scanning in CI/CD

```bash
# Install git-secrets
brew install git-secrets

# Configure patterns
git secrets --add 'password.*=.*'
git secrets --add 'secret.*=.*'
git secrets --add '[0-9a-zA-Z]{40,}'  # API keys pattern

# Test before commit
git secrets --scan
```

---

## 📋 Credential Inventory

### Maintain Central Registry

```markdown
# Credential Inventory (DO NOT COMMIT)

| Service | Location | Rotation Schedule | Owner | Status |
|---------|----------|-------------------|-------|--------|
| PostgreSQL | Vault/rds/postgres | Quarterly | DBA | Active |
| LINE API | Vault/external-apis/line | Annually | Dev Lead | Active |
| TikTok API | Vault/external-apis/tiktok | Annually | Dev Lead | Active |
| Docker Hub | GitHub Secrets | As needed | DevOps | Active |
| ArgoCD | k8s-manifests secret | Quarterly | DevOps | Active |
```

---

## 🚀 Migration Path

### Week 1: Preparation
- [ ] Choose secret management solution (Sealed Secrets recommended)
- [ ] Generate new, strong passwords
- [ ] Audit current secret usage

### Week 2: Implementation
- [ ] Install chosen secret management tool
- [ ] Migrate credentials
- [ ] Test with non-production first

### Week 3: Deployment
- [ ] Update Helm chart templates
- [ ] Deploy to staging
- [ ] Verify connectivity
- [ ] Deploy to production

### Week 4: Cleanup
- [ ] Remove plaintext secrets from values.yaml
- [ ] Update .gitignore
- [ ] Document procedures
- [ ] Schedule rotation policy

---

## ⚙️ Configuration Examples

### values.yaml (Development - Current)

```yaml
# ❌ DO NOT USE IN PRODUCTION
apps:
  rekakimBackend:
    secret:
      enabled: true
      stringData:
        PG_USER: "axricuser"
        PG_PASS: "6u9WLtpk5u"
```

### values-prod.yaml (Production - Sealed Secrets)

```yaml
# ✅ PRODUCTION READY
apps:
  rekakimBackend:
    secret:
      enabled: false  # Use external secret instead
externalSecrets:
  enabled: true
  backend: sealed-secrets
```

---

## 📚 References

- [Sealed Secrets Documentation](https://github.com/bitnami-labs/sealed-secrets)
- [External Secrets Operator](https://external-secrets.io/)
- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)
- [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)

---

**Last Updated:** 2026-06-17  
**Maintained By:** DevOps Team

