# Architecture & System Design

Detailed technical documentation of the multi-app Kubernetes architecture.

---

## 🏗️ System Architecture

### High-Level Topology

```
External World
    │
    ├─────────────────────────────────────────┐
    │                                         │
    ▼                                         ▼
Internet Ingress (nginx)                  External Access
axrique.com:443                           43.229.133.190
    │
    ├─ /api (rewrite to :3000)
    ├─ /api/v1 (rewrite to :1080)
    └─ / (static assets from :80)
    │
┌───┴────────────────────────────────────────┐
│                                            │
▼                                            ▼
axric-api:3000 (Node.js)              axric-fe:80 (React)
Deployment: 3 replicas                Deployment: 1 replica
│                                            │
└────────────────────────┬────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        │               │               │
        ▼               ▼               ▼
    threadly-backend    │          PostgreSQL
    :1080 (Node.js)     │          StatefulSet
    Deployment: 1       │          :5432
                        │
                ┌───────┴───────┐
                │               │
                ▼               ▼
            Kafka Prod      External APIs
            :9092           (LINE, TikTok, Facebook)
            Broker
```

### Namespace Isolation

```
┌──────────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster                       │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────────┐  ┌──────────────────────┐             │
│  │ axric           │  │ threadly-backend     │             │
│  ├─────────────────┤  ├──────────────────────┤             │
│  │ - axric-api:3   │  │ - threadly-backend:1 │             │
│  │ - axric-fe:1    │  │ - ConfigMap          │             │
│  │ - ConfigMap     │  │ - Secret             │             │
│  │ - Secret        │  │ - Service            │             │
│  │ - Service x2    │  │ - Ingress            │             │
│  │ - Ingress       │  │ - ServiceAccount     │             │
│  │ - ServiceAccount│  │                      │             │
│  └─────────────────┘  └──────────────────────┘             │
│                                                              │
│  ┌─────────────────┐  ┌──────────────────────┐             │
│  │ axric-db        │  │ kafka-prod           │             │
│  ├─────────────────┤  ├──────────────────────┤             │
│  │ - axric-postgres│  │ - kafka-prod         │             │
│  │   StatefulSet   │  │   StatefulSet        │             │
│  │ - Service       │  │ - Service            │             │
│  │ - PVC           │  │ - PVC                │             │
│  │ - ConfigMap     │  │ - ConfigMap          │             │
│  └─────────────────┘  └──────────────────────┘             │
│                                                              │
│  ┌─────────────────────────────────────────────┐           │
│  │ kafka-dev                                   │           │
│  ├─────────────────────────────────────────────┤           │
│  │ - kafka-dev StatefulSet                     │           │
│  │ - Service (ClusterIP)                       │           │
│  │ - ExternalService (NodePort :30092)         │           │
│  │ - PVC                                       │           │
│  └─────────────────────────────────────────────┘           │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## 📊 Component Details

### Application Components

#### Axric API (`axric-api`)
- **Type:** Deployment (3 replicas)
- **Image:** `jaron197/axric-api:1.0.41`
- **Container Port:** 3000
- **Service Port:** 3000 (ClusterIP)
- **Namespace:** `axric`
- **Dependencies:**
  - PostgreSQL (axric-db namespace)
  - Kafka (kafka-prod namespace)
  - ConfigMap: `axric-backend-config`
  - Secret: `axric-mail-secret`
- **Health Probes:**
  - Startup: TCP probe, 5s interval, 60 retries (5-minute grace)
  - Liveness: TCP probe, 10s interval, 6 retries
  - Readiness: TCP probe, 5s interval, 20s initial delay

#### Axric Frontend (`axric-fe`)
- **Type:** Deployment (1 replica)
- **Image:** `jaron197/axric-fe:1.0.41`
- **Container Port:** 80
- **Service Port:** 80 (ClusterIP)
- **Namespace:** `axric`
- **Routes:** Served at `axrique.com/`
- **Dependencies:** None (static frontend)

#### Threadly Backend (`threadly-backend`)
- **Type:** Deployment (1 replica)
- **Image:** `jaron197/threadly-backend:1.0.3`
- **Container Port:** 1080
- **Service Port:** 1080 (ClusterIP)
- **Namespace:** `threadly-backend`
- **Dependencies:**
  - PostgreSQL (axric-db namespace)
  - Kafka (kafka-prod namespace)
  - ConfigMap: `threadly-backend-config`
  - Secret: `threadly-backend-secret`
- **Health Probes:**
  - Startup: Node exec probe (localhost:1080), 5s interval, 60 retries
  - Liveness: Node exec probe (localhost:1080), 10s interval, 6 retries
  - Readiness: Node exec probe (localhost:1080), 5s interval, 20s initial delay
- **Service Account:** `threadly-backend` (limited RBAC)

---

### Data Components

#### PostgreSQL (`axric-postgres`)
- **Type:** StatefulSet (1 replica)
- **Image:** `postgres:16.3`
- **Container Port:** 5432
- **Service Port:** 5432 (ClusterIP) + NodePort 30501 (external access)
- **Namespace:** `axric-db`
- **Database:** `axricdb`
- **Credentials:** `axricuser` / `6u9WLtpk5u`
- **Storage:** PVC (optional, ephemeral by default)
- **Access Paths:**
  - Internal (K8s DNS): `axric-postgres.axric-db.svc.cluster.local:5432`
  - External (NodePort): `43.229.133.190:30501`
- **Connection Parameters:**
  - SSL: Disabled (PGSSLMODE=disable, PG_SSL=false)
  - Database: `axricdb`
  - Max connections: 100 (default)

#### Kafka (`kafka-prod`)
- **Type:** StatefulSet (1 replica)
- **Image:** `confluentinc/cp-kafka:8.2.1`
- **Broker Port:** 9092 (plaintext)
- **Internal DNS:** `kafka-prod-0.kafka-prod.kafka-prod.svc.cluster.local:9092`
- **Namespace:** `kafka-prod`
- **Replication Factor:** 1
- **Topics:** `chat`, `chat-topic` (auto-created)
- **Consumer Groups:** `axric-group`, `axric-group-dev`
- **Access:** Internal cluster only

#### Kafka Dev (`kafka-dev`)
- **Type:** StatefulSet (1 replica)
- **Image:** `confluentinc/cp-kafka:8.2.1`
- **Namespace:** `kafka-dev`
- **Internal Port:** 9092
- **External NodePort:** 30092
- **External Access:** `43.229.133.190:30092`
- **Purpose:** Development and testing

---

### Network Components

#### Ingress (`axric-ingress`)
- **Type:** Ingress (nginx controller)
- **Hostname:** `axrique.com`
- **TLS:** Optional (not configured)
- **Routes:**
  - `/api` → `axric-api:3000` (Backend API)
  - `/api/v1` → `threadly-backend:1080` (Threadly API)
  - `/` → `axric-fe:80` (Frontend static)
- **Namespace:** `axric`

#### Threadly Ingress (`threadly-backend-ingress`)
- **Type:** Ingress (nginx controller)
- **Hostname:** `axrique.com`
- **Path:** `/api/v1`
- **Backend:** `threadly-backend:1080`
- **Namespace:** `threadly-backend`

---

### Configuration Components

#### ConfigMaps

**`axric-backend-config`** (namespace: axric)
```yaml
NODE_ENV: production
SERVER_PORT: 3000
KAFKA_ENABLED: true
KAFKA_BROKERS: kafka-prod-0.kafka-prod.kafka-prod.svc.cluster.local:9092
KAFKA_GROUP_ID: axric-group
KAFKA_CHAT_TOPIC: chat-topic
DATABASE_HOST: axric-postgres.axric-db.svc.cluster.local
DATABASE_PORT: 5432
DATABASE_NAME: axricdb
```

**`threadly-backend-config`** (namespace: threadly-backend)
```yaml
NODE_ENV: production
HOST: 0.0.0.0
PORT: 1080
PG_HOST: axric-postgres.axric-db.svc.cluster.local
PG_PORT: 5432
PG_DB_NAME: axricdb
KAFKA_BROKERS: kafka-prod-0.kafka-prod.kafka-prod.svc.cluster.local:9092
KAFKA_GROUP_ID: axric-group-dev
SSL_MODES: false (all disabled)
```

#### Secrets

**`axric-mail-secret`** (namespace: axric)
```yaml
MAIL_USER: <email>
MAIL_PASSWORD: <app-password>
```

**`threadly-backend-secret`** (namespace: threadly-backend)
```yaml
PG_USER: axricuser
PG_PASS: 6u9WLtpk5u
PG_DB_NAME: axricdb
(Plus password key aliases for compatibility)
```

---

## 📡 Communication Paths

### Pod-to-Service Communication

```
axric-api pod → Service axric-api:3000
              → iptables (ClusterIP 10.x.x.x)
              → Pod endpoint (axric-api-xxx)

axric-api pod → Service axric-postgres (external DNS)
              → DNS: axric-postgres.axric-db.svc.cluster.local
              → NodePort 30501 (43.229.133.190)
              → PostgreSQL container port 5432
```

### External-to-Pod Communication

```
External Client (Internet)
            ↓
nginx Ingress Controller (axrique.com)
            ↓
Ingress Routes
  /api      → Service axric-api:3000
  /api/v1   → Service threadly-backend:1080
  /         → Service axric-fe:80
            ↓
Application Pods (across namespaces)
```

### Database Connectivity

```
Internal (within cluster):
  axric-api → DNS: axric-postgres.axric-db.svc.cluster.local:5432
  threadly-backend → Same DNS

External (from outside cluster):
  Client → 43.229.133.190:30501 (NodePort)
         → kubernetes node network
         → Service endpoint
         → PostgreSQL pod:5432
```

### Kafka Message Flow

```
axric-api pod (axric namespace)
    ↓
Kafka Broker (kafka-prod namespace)
    ↓
  Topics: chat, chat-topic
    ↓
Consumer Groups:
  - axric-group (axric-api consumers)
  - axric-group-dev (threadly-backend consumers)
```

---

## 🔄 Data Flow Example: Chat Message

```
1. User sends chat via axric-fe (browser)
        ↓
2. POST /api/chat → nginx ingress
        ↓
3. Route to axric-api:3000 service
        ↓
4. axric-api pod receives message
        ↓
5. Validates user in PostgreSQL
        ↓
6. Publishes to Kafka: kafka-prod-0:9092 (topic: chat)
        ↓
7. Kafka stores message (partition/offset)
        ↓
8. threadly-backend consumer group reads
        ↓
9. threadly-backend pod processes
        ↓
10. Stores in PostgreSQL if needed
        ↓
11. Response sent back through ingress
        ↓
12. axric-fe updates UI
```

---

## 🔌 Connectivity Matrix

| From | To | Protocol | Port | DNS/IP | Status |
|------|-----|----------|------|--------|--------|
| axric-api | PostgreSQL | TCP | 5432 | axric-postgres.axric-db.svc.cluster.local | ✅ |
| axric-api | Kafka | TCP | 9092 | kafka-prod-0.kafka-prod.kafka-prod.svc.cluster.local | ✅ |
| axric-api | External APIs | HTTPS | 443 | Direct internet | ✅ |
| threadly-backend | PostgreSQL | TCP | 5432 | axric-postgres.axric-db.svc.cluster.local | ✅ |
| threadly-backend | Kafka | TCP | 9092 | kafka-prod-0.kafka-prod.kafka-prod.svc.cluster.local | ✅ |
| External | axric-api | HTTPS | 443 | axrique.com/api | ✅ |
| External | threadly-backend | HTTPS | 443 | axrique.com/api/v1 | ✅ |
| External | axric-fe | HTTPS | 443 | axrique.com | ✅ |
| External | PostgreSQL | TCP | 30501 | 43.229.133.190:30501 | ✅ |
| External | Kafka-dev | TCP | 30092 | 43.229.133.190:30092 | ✅ (dev only) |

---

## 📦 Resource Allocation

### CPU & Memory Requests/Limits

```yaml
axric-api:
  Requests: 100m CPU, 256Mi Memory
  Limits:   500m CPU, 512Mi Memory
  
axric-fe:
  Requests: 50m CPU, 128Mi Memory
  Limits:   200m CPU, 256Mi Memory

threadly-backend:
  Requests: 100m CPU, 256Mi Memory
  Limits:   500m CPU, 512Mi Memory

axric-postgres:
  Requests: 100m CPU, 256Mi Memory
  Limits:   1000m CPU, 1Gi Memory

kafka-prod:
  Requests: 200m CPU, 512Mi Memory
  Limits:   1000m CPU, 2Gi Memory
```

**Total Cluster Minimum:** ~1.5 CPU cores, 2.5Gi RAM

---

## 🔐 Security Boundaries

### Network Policies (Recommended)

```yaml
# Only allow traffic specified
- axric-api → PostgreSQL (port 5432)
- axric-api → Kafka (port 9092)
- threadly-backend → PostgreSQL (port 5432)
- threadly-backend → Kafka (port 9092)
- Ingress → axric-api (port 3000)
- Ingress → threadly-backend (port 1080)
- Ingress → axric-fe (port 80)
- Block all other pod-to-pod traffic
```

### RBAC Roles

```yaml
axric-api:
  - Service Account: axric-api (if needed)
  - Permissions: ConfigMap/Secret read in axric namespace

threadly-backend:
  - Service Account: threadly-backend
  - Permissions: ConfigMap/Secret read in threadly-backend namespace

default:
  - No special permissions
```

---

## 📈 Scaling Strategy

### Horizontal Pod Autoscaling (HPA)

```yaml
# Recommended configuration
axric-api:
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

threadly-backend:
  minReplicas: 1
  maxReplicas: 5
  targetCPUUtilizationPercentage: 80
```

### Vertical Pod Autoscaling (VPA)

```yaml
# Monitor and recommend resource adjustments
- Analyze actual usage over 1-2 weeks
- Implement VPA recommendations
- Re-evaluate quarterly
```

---

## 🚀 Disaster Recovery

### Backup Strategy

```yaml
PostgreSQL:
  - Daily backups to external storage
  - Retention: 30 days
  - RPO: 1 day
  - RTO: 2 hours

Kafka:
  - Topics configured with replication factor 3 (future)
  - Consumer group offsets backed up
  - RPO: 5 minutes
  - RTO: 30 minutes
```

### High Availability Setup (Future)

```yaml
PostgreSQL:
  - Current: Single StatefulSet
  - Recommended: Primary-Replica with automated failover
  
Kafka:
  - Current: Single broker
  - Recommended: 3-broker cluster with replication

Applications:
  - Current: 1-3 replicas
  - Recommended: Pod disruption budgets
```

---

## 📚 References

- [Kubernetes Architecture](https://kubernetes.io/docs/concepts/architecture/)
- [PostgreSQL on Kubernetes](https://www.postgresql.org/about/news/postgres-on-kubernetes-best-practices/)
- [Kafka on Kubernetes](https://kafka.apache.org/documentation/#bestpractices)
- [Ingress NGINX](https://kubernetes.github.io/ingress-nginx/)

---

**Last Updated:** 2026-06-17  
**Maintained By:** DevOps Team
