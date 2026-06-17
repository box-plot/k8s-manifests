# Contributing to k8s-manifests

Thank you for contributing! This document outlines guidelines and procedures.

---

## 🌿 Branch Strategy

### Main Branches

- **`main`** - Production deployments
  - Protected branch
  - Requires 1 approval
  - All tests must pass
  - Automatically synced to Kubernetes via ArgoCD

- **`develop`** - Staging & integration
  - Feature branches merge here first
  - Pre-production validation
  - Automated testing required

### Feature Branches

Naming convention: `<type>/<ticket>-<description>`

```
feature/K8S-42-add-monitoring
bugfix/K8S-43-fix-rollout
docs/K8S-44-update-readme
chore/K8S-45-update-dependencies
```

---

## 📝 Commit Messages

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Type

- `feat`: New feature (e.g., new app or service)
- `fix`: Bug fix
- `docs`: Documentation only
- `chore`: Config, dependencies, build scripts
- `refactor`: Code restructure without behavior change
- `perf`: Performance improvement
- `test`: Test updates

### Scope

- `chart`: Helm chart changes
- `templates`: Template files
- `values`: Configuration values
- `ci`: GitHub Actions workflows
- `docs`: Documentation

### Subject (Imperative, Present Tense)

```
✅ feat(templates): add threadly-backend deployment
✅ fix(values): correct kafka broker hostname
✅ chore(chart): bump version to 1.1.0
❌ Updated deployment templates
❌ Fixed bug in chart
```

### Body (Optional)

```
Add detailed explanation of changes, context, and rationale.
Wrap at 72 characters.

- Bullet points for changes
- Reference related issues
```

### Footer (Optional)

```
Fixes #42
Closes #43
Relates-to #44
```

### Complete Example

```
feat(templates): add external-secrets operator support

Implement ExternalSecret templates for Vault and AWS Secrets
Manager integration. This allows credentials to be fetched at
deployment time rather than stored in values.yaml.

- Add SecretStore and ExternalSecret templates
- Support both Vault and AWS Secrets Manager
- Update values schema for externalSecrets configuration
- Document setup procedures in SECRETS.md

Fixes #89
Relates-to #102
```

---

## 🧪 Testing Before Commit

### Pre-Commit Checklist

```bash
# 1. Validate Helm chart
helm lint k8s/charts/

# 2. Check for errors in templates
helm template test k8s/charts > /tmp/manifest.yaml

# 3. Validate YAML syntax
yamllint k8s/charts/templates/

# 4. Check for secrets in code
git secrets --scan

# 5. Test specific values file
helm template test k8s/charts -f k8s/charts/values-dev.yaml
```

### Create Pre-Commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

echo "Running pre-commit checks..."

# Lint
helm lint k8s/charts/ || exit 1

# Template validation
helm template test k8s/charts > /tmp/manifest.yaml || exit 1

# Secret scanning
git secrets --scan || exit 1

echo "✅ Pre-commit checks passed"
```

---

## 📤 Pull Request Process

### Before Opening PR

1. **Create feature branch from `develop`**
   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b feature/K8S-42-description
   ```

2. **Make changes and test**
   ```bash
   vim k8s/charts/values.yaml
   helm lint k8s/charts/
   ```

3. **Commit with proper message**
   ```bash
   git add k8s/charts/
   git commit -m "feat(values): add monitoring sidecar configuration"
   ```

4. **Push to remote**
   ```bash
   git push origin feature/K8S-42-description
   ```

### PR Description Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] New feature
- [ ] Bug fix
- [ ] Documentation update
- [ ] Configuration change
- [ ] Performance improvement

## Changes Made
- Change 1
- Change 2
- Change 3

## Testing
- [ ] Helm lint passes
- [ ] helm template renders without errors
- [ ] Values schema validates
- [ ] Tested in development environment
- [ ] Tested in staging environment

## Checklist
- [ ] CHANGELOG.md updated
- [ ] Documentation updated (if applicable)
- [ ] No hardcoded secrets
- [ ] All tests passing
- [ ] Code reviewed by maintainer
- [ ] Ready for merge to main

## Related Issues
Closes #42
Relates-to #43
```

### PR Requirements

✅ **Must Pass:**
- Helm lint without errors
- helm template renders correctly
- All YAML files valid
- Values schema validates
- No secrets in code
- CHANGELOG.md updated

⚠️ **Recommended:**
- Code reviewed by 1+ maintainers
- Tested in non-production environment
- Documentation updated

---

## 🔄 Merge to Main

After PR approval:

1. **Squash and merge** to main branch
   ```
   Squash and merge: Combines all commits into one
   ```

2. **Delete feature branch**
   - GitHub auto-deletes remote branch
   - Local: `git branch -d feature/K8S-42-description`

3. **ArgoCD auto-syncs**
   - Detects main branch change
   - Applies new configuration to cluster
   - Check sync status: `argocd app get axric-k8s-export`

---

## 📋 Release Process

### Version Bumping

Use Semantic Versioning: `MAJOR.MINOR.PATCH`

```bash
# Feature release (1.0.0 → 1.1.0)
helm version 1.1.0 -f k8s/charts/Chart.yaml

# Patch release (1.1.0 → 1.1.1)
helm version 1.1.1 -f k8s/charts/Chart.yaml

# Major release (1.1.1 → 2.0.0)
# Major version increments for breaking changes
```

### Create Release

1. **Update CHANGELOG.md**
   ```markdown
   ## [1.1.0] - 2026-06-20
   ### Added
   - Feature 1
   - Feature 2
   
   ### Fixed
   - Bug 1
   ```

2. **Create GitHub Release**
   ```bash
   git tag -a v1.1.0 -m "Release 1.1.0: Add monitoring support"
   git push origin v1.1.0
   ```

3. **Create Release Notes**
   - GitHub: Go to Releases → Create Release
   - Tag: v1.1.0
   - Title: Release 1.1.0
   - Description: Copy from CHANGELOG.md

---

## 📞 Code Review Guidelines

### What to Review

✅ **Configuration:**
- Resource limits appropriate
- Security context correct
- RBAC roles minimal and correct

✅ **Templating:**
- Variables correctly referenced
- No hardcoded values
- Proper indentation
- Error handling present

✅ **Documentation:**
- Changes documented
- Examples provided if needed
- README updated if applicable

✅ **Security:**
- No secrets exposed
- Image policies correct
- Network policies defined
- RBAC properly scoped

### Comments

- **Blocking:** `🚫 MUST FIX` - Request changes
- **Warning:** `⚠️ SHOULD FIX` - Strongly suggested
- **Suggestion:** `💡 CONSIDER` - Nice to have
- **Approval:** `✅ LGTM` - Looks good to me

---

## 🐛 Bug Reports

### Create Issue

```markdown
## Description
Brief description of the bug

## Reproduction Steps
1. First step
2. Second step
3. Result

## Expected Behavior
What should happen

## Actual Behavior
What actually happened

## Environment
- Kubernetes: 1.29.15
- Helm: 3.x
- Affected apps: threadly-backend

## Logs
```
kubectl logs deployment/threadly-backend -n threadly-backend
...
```

## Proposed Solution
If you have ideas for fixing this bug
```

---

## 💡 Feature Requests

### Create Issue

```markdown
## Description
What feature would be useful?

## Use Case
Why is this needed?

## Proposed Solution
How might this be implemented?

## Alternatives
Have you considered other approaches?

## Additional Context
Any other information?
```

---

## 🔗 Resources

- [GitHub Flow](https://guides.github.com/introduction/flow/)
- [Semantic Versioning](https://semver.org/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/)

---

## ❓ Questions?

- Check existing issues & PRs
- Review documentation in .docs/
- Contact: jaronthongfoo@gmail.com

---

**Thank you for contributing! 🙏**
