# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-06-17

### Added
- Threadly backend format standardization (single image string format)
- Environment-specific values files (dev, staging, prod)
- Comprehensive documentation structure (.docs/)
- Values schema validation (values.schema.json)
- CONTRIBUTING.md with branch and commit standards
- revisionHistoryLimit consistency (3 across all apps)
- GitHub Actions workflow documentation

### Changed
- Refactored threadlyBackend structure to match axric apps format
- `port` renamed to `containerPort` for consistency
- Helm Chart metadata enhanced
- Improved secret ordering with sync-wave annotations

### Fixed
- ArgoCD OutOfSync state after image format standardization
- Nil-pointer template errors with hasKey safety checks
- Health probe startup time alignment

### Security
- Secret sync-wave=-1 ensures Secret before Deployment
- PGSSLMODE=disable for internal cluster communication only
- Documented secrets management best practices

## [1.0.3] - 2026-06-16

### Fixed
- Database connection failures via external node IP routing (43.229.133.190:30501)
- Kafka broker DNS configuration (kafka-prod-0.kafka-prod.kafka-prod.svc.cluster.local:9092)
- Missing SSL-disable flags for PostgreSQL connections
- Pod startup probe connection refused errors

### Added
- HOST: 0.0.0.0 binding for app interfaces
- Comprehensive SSL-disable environment variables
- Dedicated threadly-backend deployment template

## [1.0.2] - 2026-06-15

### Fixed
- Duplicate threadly-backend deployments in ArgoCD
- Image pull failures (removed non-existent imagePullSecret)
- Missing secret keys for database passwords

### Added
- Generic template safety guards (hasKey checks)
- Template exclusion for threadlyBackend from generic loop

## [1.0.1] - 2026-06-14

### Fixed
- ArgoCD namespace sync errors (removed stale threadly-backend-uat override)
- Ingress template structure reorganization

## [1.0.0] - 2026-06-13

### Added
- Initial Helm chart structure for multi-app Kubernetes deployment
- Support for Axric API, Axric FE, Threadly Backend, PostgreSQL, Kafka
- ArgoCD integration with auto-sync
- GitHub Actions CI/CD pipeline for image updates
- Multi-namespace architecture (axric, threadly-backend, kafka-prod, axric-db)
- RBAC and service account configuration
