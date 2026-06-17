# Monitoring & Observability

Logging, metrics, and health monitoring strategies.

---

## 📊 Monitoring Stack

### Current Setup
- **Log Aggregation:** kubectl logs (basic)
- **Metrics:** No Prometheus yet
- **Alerting:** None configured
- **Dashboard:** None configured

### Recommended Setup
- **ELK Stack:** Elasticsearch, Logstash, Kibana
- **Prometheus + Grafana:** Metrics & dashboards
- **AlertManager:** Alert routing
- **Jaeger:** Distributed tracing

---

## 📝 Real-Time Logs

### Follow Application Logs

```bash
# Axric API logs (live)
kubectl logs -f deployment/axric-api -n axric

# Threadly Backend logs (live)
kubectl logs -f deployment/threadly-backend -n threadly-backend

# PostgreSQL logs (live)
kubectl logs -f statefulset/axric-postgres -n axric-db

# Kafka logs (live)
kubectl logs -f statefulset/kafka-prod -n kafka-prod

# Multiple services
kubectl logs -f deployment/axric-api -n axric & \
kubectl logs -f deployment/threadly-backend -n threadly-backend & \
wait
```

### Historical Log Query

```bash
# Last 100 lines with timestamps
kubectl logs deployment/threadly-backend -n threadly-backend \
  --tail=100 \
  --timestamps=true

# Logs from last 1 hour
kubectl logs deployment/threadly-backend -n threadly-backend \
  --since=1h \
  --timestamps=true

# Logs between timestamps
kubectl logs deployment/threadly-backend -n threadly-backend \
  --since-time=2026-06-17T10:00:00Z \
  --until-time=2026-06-17T11:00:00Z

# Search for errors
kubectl logs deployment/threadly-backend -n threadly-backend | grep -i error
```

---

## 💚 Health Check Endpoints

### Application Health Probes

```bash
# Port-forward to service
kubectl port-forward svc/axric-api 3000:3000 -n axric &
kubectl port-forward svc/threadly-backend 1080:1080 -n threadly-backend &

# Test endpoints
curl -i http://localhost:3000/health
curl -i http://localhost:1080/health

# Grep for status
curl -s http://localhost:3000/health | jq '.status'
```

### Kubernetes Probe Status

```bash
# Check probe configuration
kubectl describe pod -l app=threadly-backend -n threadly-backend | grep -A 10 "Probes:"

# Check probe events
kubectl get events -n threadly-backend --sort-by='.lastTimestamp' | grep -i probe

# Monitor probe failures
kubectl get pods -n threadly-backend -w
```

---

## 📈 Metrics Collection

### Resource Metrics (Built-in)

```bash
# Pod memory and CPU usage
kubectl top pods -n axric
kubectl top pods -n threadly-backend
kubectl top pods -n axric-db

# Sort by memory usage
kubectl top pods -n axric --sort-by=memory

# Sort by CPU usage
kubectl top pods -n axric --sort-by=cpu

# Node resource usage
kubectl top nodes
```

### Custom Metrics (with Prometheus)

```yaml
# Example: Pod restart count
kubectl get pods -n threadly-backend \
  -o custom-columns=NAME:.metadata.name,RESTARTS:.status.containerStatuses[0].restartCount
```

---

## 🔍 Pod Inspection

### Describe Pod

```bash
# Full pod information
kubectl describe pod -l app=threadly-backend -n threadly-backend

# Key sections:
# - Containers: Image, ports, resource limits
# - Mounts: ConfigMaps, Secrets
# - Events: Recent pod activity
# - Probes: Startup, liveness, readiness status
```

### Check Environment Variables

```bash
# List all env vars in container
kubectl exec deployment/threadly-backend -n threadly-backend -- env | sort

# Check specific variable
kubectl exec deployment/threadly-backend -n threadly-backend -- \
  sh -c 'echo $PG_HOST'
```

### Access Pod Shell

```bash
# Interactive shell
kubectl exec -it deployment/threadly-backend -n threadly-backend -- /bin/sh

# Inside pod: test connectivity
nc -v axric-postgres.axric-db.svc.cluster.local 5432  # PostgreSQL
nc -v kafka-prod-0.kafka-prod.kafka-prod.svc.cluster.local 9092  # Kafka
```

---

## 🗄️ Database Monitoring

### PostgreSQL Connection Health

```bash
# Test connectivity
kubectl run -it pg-test --image=postgres:16 -n axric-db -- \
  psql -h axric-postgres -U axricuser -d axricdb -c "\l"

# Run inside pod
kubectl exec -it statefulset/axric-postgres-0 -n axric-db -- \
  psql -U axricuser -d axricdb -c "SELECT version();"

# Check active connections
kubectl exec -it statefulset/axric-postgres-0 -n axric-db -- \
  psql -U axricuser -d axricdb -c "SELECT count(*) FROM pg_stat_activity;"

# Check slow queries
kubectl exec -it statefulset/axric-postgres-0 -n axric-db -- \
  psql -U axricuser -d axricdb -c "SELECT query, mean_time FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 10;"
```

### PostgreSQL Data Statistics

```bash
# Database size
kubectl exec -it statefulset/axric-postgres-0 -n axric-db -- \
  psql -U axricuser -d axricdb -c "SELECT pg_size_pretty(pg_database_size('axricdb'));"

# Table sizes
kubectl exec -it statefulset/axric-postgres-0 -n axric-db -- \
  psql -U axricuser -d axricdb -c "\dt+"

# Connection limits
kubectl exec -it statefulset/axric-postgres-0 -n axric-db -- \
  psql -U postgres -c "SHOW max_connections;"
```

---

## 🔗 Kafka Monitoring

### Broker Health

```bash
# Check broker logs
kubectl logs statefulset/kafka-prod -n kafka-prod | head -20

# Connect to broker
kubectl exec -it statefulset/kafka-prod-0 -n kafka-prod -- \
  kafka-broker-api-versions --bootstrap-server localhost:9092

# List topics
kubectl exec -it statefulset/kafka-prod-0 -n kafka-prod -- \
  kafka-topics --bootstrap-server localhost:9092 --list
```

### Consumer Groups

```bash
# List consumer groups
kubectl exec -it statefulset/kafka-prod-0 -n kafka-prod -- \
  kafka-consumer-groups --bootstrap-server localhost:9092 --list

# Describe consumer group
kubectl exec -it statefulset/kafka-prod-0 -n kafka-prod -- \
  kafka-consumer-groups --bootstrap-server localhost:9092 \
  --group axric-group-dev --describe

# Check consumer lag
kubectl exec -it statefulset/kafka-prod-0 -n kafka-prod -- \
  kafka-consumer-groups --bootstrap-server localhost:9092 \
  --group axric-group-dev --describe
```

### Topic Details

```bash
# Describe topic
kubectl exec -it statefulset/kafka-prod-0 -n kafka-prod -- \
  kafka-topics --bootstrap-server localhost:9092 \
  --topic chat --describe

# Topic statistics
kubectl exec -it statefulset/kafka-prod-0 -n kafka-prod -- \
  kafka-log-dirs --bootstrap-server localhost:9092
```

---

## 🚨 Critical Alerts to Monitor

### Pod Health

```bash
# Pod CrashLoopBackOff
kubectl get pods -n axric -o json | jq '.items[] | select(.status.containerStatuses[0].state.waiting.reason=="CrashLoopBackOff")'

# Pod pending
kubectl get pods -n axric -o json | jq '.items[] | select(.status.phase=="Pending")'

# Image pull errors
kubectl get events -n axric | grep -i "pull\|image"
```

### Resource Exhaustion

```bash
# Node memory pressure
kubectl get nodes -o custom-columns=NAME:.metadata.name,MEMORY:.status.conditions[?(@.type=="MemoryPressure")].status

# Node disk pressure
kubectl get nodes -o custom-columns=NAME:.metadata.name,DISK:.status.conditions[?(@.type=="DiskPressure")].status

# Pod out of memory
kubectl get events -n axric | grep -i "outofmemory\|oomkilled"
```

### Network Issues

```bash
# Connection refused errors
kubectl logs deployment/threadly-backend -n threadly-backend | grep -i "refuse\|connect"

# DNS resolution failures
kubectl logs deployment/threadly-backend -n threadly-backend | grep -i "nxdomain\|nameserver"

# Timeout errors
kubectl logs deployment/threadly-backend -n threadly-backend | grep -i "timeout\|deadline"
```

---

## 📊 Recommended Prometheus Queries

### CPU Usage

```promql
# CPU usage by pod
sum by (pod) (rate(container_cpu_usage_seconds_total[5m]))

# CPU usage by namespace
sum by (namespace) (rate(container_cpu_usage_seconds_total[5m]))

# High CPU pods (>80% limit)
(sum by (pod) (rate(container_cpu_usage_seconds_total[5m])) / on(pod) container_spec_cpu_quota) > 0.8
```

### Memory Usage

```promql
# Memory usage by pod
sum by (pod) (container_memory_usage_bytes) / 1024 / 1024

# Memory usage by namespace
sum by (namespace) (container_memory_usage_bytes)

# OOM risk (>80% limit)
(sum by (pod) (container_memory_usage_bytes) / on(pod) container_spec_memory_limit_bytes) > 0.8
```

### Availability

```promql
# Pod restart count increase
rate(kube_pod_container_status_restarts_total[1h])

# Pod availability
count(kube_pod_info{namespace=~"axric"}) / count(kube_pod_info{namespace=~"axric", job="kube-state-metrics"})

# Deployment replica mismatch
kube_deployment_status_replicas{namespace=~"axric"} != kube_deployment_status_replicas_available
```

---

## 🔔 Alert Examples

### Create AlertManager Rules

```yaml
# prometheus-rules.yaml
groups:
- name: kubernetes
  interval: 30s
  rules:
  # Pod CrashLoopBackOff
  - alert: PodCrashLooping
    expr: rate(kube_pod_container_status_restarts_total[1h]) > 5
    for: 10m
    annotations:
      summary: "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} is crash looping"
  
  # High CPU usage
  - alert: HighPodCPU
    expr: (sum by (pod) (rate(container_cpu_usage_seconds_total[5m])) / on(pod) container_spec_cpu_quota) > 0.8
    for: 5m
    annotations:
      summary: "Pod {{ $labels.pod }} CPU usage > 80%"
  
  # High memory usage
  - alert: HighPodMemory
    expr: (sum by (pod) (container_memory_usage_bytes) / on(pod) container_spec_memory_limit_bytes) > 0.8
    for: 5m
    annotations:
      summary: "Pod {{ $labels.pod }} memory usage > 80%"
  
  # Pod not ready
  - alert: PodNotReady
    expr: min by (pod) (kube_pod_status_ready) == 0
    for: 15m
    annotations:
      summary: "Pod {{ $labels.pod }} not ready for 15+ minutes"
```

---

## 📅 Monitoring Schedule

### Daily Checks

```bash
# Morning standup
kubectl get pods -n axric -n threadly-backend -n axric-db
kubectl top pods -n axric
kubectl get events -A --sort-by='.lastTimestamp' | tail -20

# Error scan
kubectl logs deployment/threadly-backend -n threadly-backend | grep -i error | tail -5
```

### Weekly Review

```bash
# Resource trends
kubectl top pods -n axric --sort-by=memory
kubectl top pods -n axric --sort-by=cpu

# Failed pods analysis
kubectl get pods -A --field-selector=status.phase=Failed
kubectl describe events -A | grep Warning
```

### Monthly Deep Dive

```bash
# Capacity planning
kubectl top nodes
kubectl describe nodes | grep -A 5 "Allocated resources"

# Performance analysis
kubectl logs deployment/axric-api -n axric --tail=10000 | grep "ms\|latency"
```

---

## 🔗 References

- [Kubernetes Logging](https://kubernetes.io/docs/concepts/cluster-administration/logging/)
- [Resource Metrics API](https://kubernetes.io/docs/tasks/debug-application-cluster/resource-metrics-pipeline/)
- [Prometheus Kubernetes Integration](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#kubernetes_sd_config)
- [kubectl Debugging](https://kubernetes.io/docs/tasks/debug-application-cluster/debug-application/)

---

**Last Updated:** 2026-06-17  
**Maintained By:** DevOps Team
