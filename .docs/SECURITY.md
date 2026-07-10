# Security Checklist & Guidelines

Security hardening checklist and best practices.

---

## 🔐 Cluster Security

### Access Control

- [ ] RBAC roles configured for service accounts
- [ ] Network policies restrict pod-to-pod traffic
- [ ] API server audit logging enabled
- [ ] ABAC (Attribute-Based Access Control) policies defined
- [ ] kubectl access restricted to authorized users
- [ ] Kubeconfig files not shared/committed to git

### Cluster Hardening

- [ ] Kubernetes version up-to-date (1.29.15+)
- [ ] Kubelet authentication enabled
- [ ] Anonymous API access disabled
- [ ] Admission controllers enabled (PodSecurityPolicy)
- [ ] etcd encryption at rest enabled
- [ ] API server TLS configured
- [ ] Kubelet TLS configured

---

## 🛡️ Container Security

### Image Security

- [ ] Images scanned for vulnerabilities before deployment
- [ ] Images pulled from trusted registries only
- [ ] Private registry credentials stored as Kubernetes secrets
- [ ] Image pull policies set correctly:
  - `IfNotPresent` for stable releases
  - `Always` for latest/dev tags
- [ ] No hardcoded credentials in images
- [ ] Distroless or minimal base images used
- [ ] Images signed and verification enabled (if available)

### Container Policies

- [ ] Containers run as non-root user
- [ ] Read-only root filesystem (readOnlyRootFilesystem: true)
- [ ] Drop unnecessary capabilities
- [ ] Security context configured per pod/container
- [ ] No privileged containers (privileged: false)
- [ ] No host network access (hostNetwork: false)
- [ ] No host PID access (hostPID: false)
- [ ] Resource limits set (CPU, memory)

**Current Container Configuration:**

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: false  # TODO: Enable where possible
```

---

## 🔑 Secret Management

### Current Implementation

- ⚠️ Secrets stored in values.yaml (DEVELOPMENT ONLY)
- ⚠️ Sensitive data visible in git history
- ✅ Secrets excluded from .gitignore

### Production Requirements (TODO)

- [ ] Secrets encrypted at rest
- [ ] Implement Sealed Secrets or External Secrets
- [ ] Secrets rotated quarterly
- [ ] Credentials never appear in logs
- [ ] Secret access audited
- [ ] Secret versions tracked
- [ ] Credential rotation alerts configured

**See [.docs/SECRETS.md](.docs/SECRETS.md) for detailed instructions.**

---

## 🔗 Network Security

### Network Policies

- [ ] Ingress network policies defined
- [ ] Egress network policies defined
- [ ] Default deny-all policy enforced
- [ ] Only required traffic allowed

**Recommended NetworkPolicy:**

```yaml
# TODO: Implement
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-rekakim-backend-traffic
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
          name: axric  # Only from Axric namespace
    ports:
    - protocol: TCP
      port: 1080
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: axric-db
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

### Ingress Security

- [ ] TLS enabled on ingress (HTTPS)
- [ ] Certificate valid and not expired
- [ ] Strong TLS version (1.2+)
- [ ] Secure cipher suites configured
- [ ] HTTP traffic redirected to HTTPS

**Current Status:** ❌ TLS not yet enabled

---

## 📋 RBAC (Role-Based Access Control)

### Service Account Permissions

- [ ] Service accounts created per application
- [ ] Minimal permissions granted (least privilege)
- [ ] No cluster-admin roles for applications
- [ ] Read-only access where possible

**Current Implementation:**

```yaml
# TODO: Create minimal roles for each app
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: rekakim-backend
  namespace: rekakim-backend
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: rekakim-backend-role
  namespace: rekakim-backend
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  resourceNames: ["rekakim-backend-config"]
  verbs: ["get"]
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["rekakim-backend-secret"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: rekakim-backend-rolebinding
  namespace: rekakim-backend
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: rekakim-backend-role
subjects:
- kind: ServiceAccount
  name: rekakim-backend
  namespace: rekakim-backend
```

---

## 📊 Monitoring & Audit

### Logging

- [ ] Audit logging enabled
- [ ] Logs retained for 90+ days
- [ ] Logs backed up off-cluster
- [ ] Log analysis for security events
- [ ] Alerts on suspicious activity

**Enable API Audit Logging:**

```bash
# Check if audit is enabled
kubectl logs -n kube-system pod/kube-apiserver-* | grep audit

# Configure audit policy
kubectl get cm -n kube-system audit-policy-yaml
```

### Monitoring

- [ ] Pod security alerts configured
- [ ] Privilege escalation attempts logged
- [ ] Unauthorized access attempts logged
- [ ] Configuration change audits enabled
- [ ] Secret access audited

---

## 🚨 Incident Response

### Security Incident Procedures

1. **Detection:** Alert received for suspicious activity
2. **Containment:** Isolate affected pod/node
3. **Investigation:** Analyze logs and metrics
4. **Remediation:** Apply fix or patch
5. **Recovery:** Restore service
6. **Review:** Post-incident analysis

### Emergency Procedures

**Compromise Detected:**

```bash
# 1. Isolate pod
kubectl delete pod <pod-name> -n <namespace>

# 2. Cordon node
kubectl cordon <node-name>

# 3. Check other pods on node
kubectl get pods -n <namespace> -o wide | grep <node-name>

# 4. Collect evidence
kubectl logs <pod-name> > evidence.log
kubectl describe pod <pod-name> > evidence.txt

# 5. Contact security team
# ... escalate incident ...

# 6. Restart pod (if isolated issue)
kubectl delete pod <pod-name> -n <namespace>
```

---

## 🔍 Compliance & Standards

### Compliance Checklist

- [ ] CIS Kubernetes Benchmark reviewed
- [ ] NIST Cybersecurity Framework implemented
- [ ] SOC2 requirements met (if applicable)
- [ ] Data residency requirements followed
- [ ] PII data properly protected
- [ ] Data retention policies enforced

### External Audits

- [ ] Cluster penetration test scheduled
- [ ] Vulnerability scanning conducted
- [ ] Code review completed
- [ ] Security audit trail maintained

---

## 📝 Security Documentation

### To Create

1. **Security Policy** - Define security requirements
2. **Incident Response Plan** - Procedures for incidents
3. **Access Control Policy** - Who can access what
4. **Data Protection Policy** - How sensitive data is handled
5. **Compliance Matrix** - Map to standards (CIS, SOC2, etc.)

---

## 🔗 Security Tools

### Recommended

| Tool | Purpose | Status |
|------|---------|--------|
| Sealed Secrets | Encrypt secrets in git | TODO |
| Pod Security Policy | Enforce pod constraints | TODO |
| NetworkPolicy | Network access control | TODO |
| Falco | Runtime security monitoring | TODO |
| Trivy | Image vulnerability scanning | TODO |
| OWASP ZAP | Security testing | TODO |

---

## 📚 References

- [CIS Kubernetes Benchmark](https://www.cisecurity.org/cis-benchmarks#kubernetes)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)

---

## 🎯 Security Roadmap

### Q3 2026
- [ ] Implement Sealed Secrets
- [ ] Enable TLS on ingress
- [ ] Create NetworkPolicies
- [ ] Document RBAC roles

### Q4 2026
- [ ] Implement vulnerability scanning
- [ ] Set up audit logging
- [ ] Conduct security audit
- [ ] Create incident response runbook

### Q1 2027
- [ ] Implement runtime security monitoring
- [ ] Annual penetration test
- [ ] Update compliance documentation
- [ ] Review and update security policies

---

**Last Updated:** 2026-06-17  
**Maintained By:** DevOps Team  
**Next Review:** 2026-09-17

