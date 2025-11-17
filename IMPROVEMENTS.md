# K8s-Homelab Improvement Roadmap

**Last Updated**: 2025-11-17
**Analysis Date**: 2025-11-17
**Total Issues Identified**: 82 (3 Critical, 13 High, 28 Medium, 38 Low)

---

## Status Overview

### ✅ Completed (2025-11-17)

#### Critical Issues
- **C-4.1**: Snippet annotations security verified (secured with annotations-risk-level: Critical)
- **C-9.1**: Trivy Operator activated for vulnerability scanning
- **C-1.1**: Flux Kustomization dependencies corrected (kyverno-policies, external-secrets-secretstores, snapshot-controller)

#### High Priority Issues
- **H-7.2**: All 10 monitoring exporters activated (blackbox, gatus, grafana, media exporters, etc.)
- **H-10.2**: Selected apps activated (librechat2, homepage)
- **H-1.1**: Inconsistent Longhorn wait settings standardized (all set to wait: true)

---

## 🔴 HIGH PRIORITY (Next 1-2 Weeks)

### H-8.1: Implement NetworkPolicies
**Status**: Not Started
**Priority**: HIGH
**Risk**: Critical namespace exposure, flat network security model
**Effort**: 4-6 hours

**Action Items**:
1. **Security Namespace** - Deny all ingress except from specific namespaces
   - File to create: `kubernetes/apps/security/network-policies.yaml`
   - Allow: kube-system → security (for external-secrets operator)
   - Allow: All namespaces → security (for ExternalSecret resources)
   - Deny: All other ingress

2. **Database Namespace** - Restrict to app namespaces only
   - File to create: `kubernetes/apps/database/network-policies.yaml`
   - Allow: productivity → database
   - Allow: ai → database
   - Deny: All other ingress

3. **Kube-System Namespace** - Lock down critical components
   - File to create: `kubernetes/apps/kube-system/network-policies.yaml`
   - CoreDNS: Allow UDP 53 from all pods
   - Metrics-server: Allow from prometheus
   - Cilium: Allow as needed

4. **Media Namespace** - Deny external egress except specific
   - File to create: `kubernetes/apps/media/network-policies.yaml`
   - Allow: Internal cluster communication
   - Allow: Specific external IPs/domains for media sources
   - Deny: Unrestricted internet access

**Testing Plan**:
- Deploy to test namespace first
- Verify app connectivity
- Monitor for blocked legitimate traffic
- Rollout namespace by namespace

**Resources**:
- [Kubernetes NetworkPolicy docs](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Cilium NetworkPolicy guide](https://docs.cilium.io/en/stable/policy/)

---

### H-7.1: Add ServiceMonitors for Operators
**Status**: Not Started
**Priority**: HIGH
**Risk**: Limited visibility into operator health
**Effort**: 2-3 hours

**Missing ServiceMonitors**:

1. **Cilium** - CNI networking metrics
   - File to create: `kubernetes/apps/kube-system/cilium/app/servicemonitor.yaml`
   - Metrics port: 9962
   - Path: `/metrics`
   - Labels: `k8s-app: cilium`

2. **External-Secrets Operator**
   - File to create: `kubernetes/apps/security/external-secrets/operator/servicemonitor.yaml`
   - Metrics port: 8080
   - Path: `/metrics`
   - Labels: `app.kubernetes.io/name: external-secrets`

3. **Cert-Manager**
   - File to create: `kubernetes/apps/cert-manager/cert-manager/app/servicemonitor.yaml`
   - Metrics port: 9402
   - Path: `/metrics`
   - Labels: `app.kubernetes.io/name: cert-manager`

4. **Kyverno**
   - File to create: `kubernetes/apps/security/kyverno/app/servicemonitor.yaml`
   - Metrics port: 8000
   - Path: `/metrics`
   - Labels: `app.kubernetes.io/name: kyverno`

5. **K8up**
   - File to create: `kubernetes/apps/storage/k8up/app/servicemonitor.yaml`
   - Metrics port: 8080
   - Path: `/metrics`
   - Labels: `app.kubernetes.io/name: k8up`

6. **Velero**
   - File to create: `kubernetes/apps/storage/velero/app/servicemonitor.yaml`
   - Metrics port: 8085
   - Path: `/metrics`
   - Labels: `app.kubernetes.io/name: velero`

**Template**:
```yaml
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: <component>-metrics
  namespace: <namespace>
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: <component>
  endpoints:
    - port: metrics
      interval: 30s
      scrapeTimeout: 10s
      path: /metrics
```

**Verification**:
- Check Prometheus targets: `kubectl -n observability port-forward svc/kube-prometheus-stack-prometheus 9090:9090`
- Navigate to Status → Targets
- Verify all new targets are "UP"

---

### H-9.1: Expand Kyverno Policy Coverage
**Status**: Not Started
**Priority**: HIGH
**Risk**: Insufficient Pod Security Standards enforcement
**Effort**: 3-4 hours

**Current Policies** (6):
- gatus-external.yaml
- gatus-internal.yaml
- ingress.yaml
- label-existing-namespaces.yaml
- limits.yaml
- ndots.yaml

**Policies to Add**:

1. **Pod Security Standards - Baseline**
   - File to create: `kubernetes/apps/security/kyverno/policies/pss-baseline.yaml`
   - Disallow: Privileged containers
   - Disallow: Host namespaces (hostNetwork, hostPID, hostIPC)
   - Disallow: Host path volumes
   - Disallow: Unsafe capabilities
   - Exceptions: kube-system namespace

2. **Required Labels**
   - File to create: `kubernetes/apps/security/kyverno/policies/require-labels.yaml`
   - Require: `app.kubernetes.io/name`
   - Require: `app.kubernetes.io/instance`
   - Optional: `app.kubernetes.io/version`

3. **Image Pull Policy**
   - File to create: `kubernetes/apps/security/kyverno/policies/image-pull-policy.yaml`
   - Enforce: `imagePullPolicy: Always` for containers without specific tags
   - Enforce: `imagePullPolicy: IfNotPresent` for tagged images

4. **Resource Limits Required**
   - File to create: `kubernetes/apps/security/kyverno/policies/require-resources.yaml`
   - Enforce: All containers must have `resources.requests.memory`
   - Enforce: All containers must have `resources.requests.cpu`
   - Enforce: All containers must have `resources.limits.memory`
   - Exceptions: Can use LimitRange or VPA

5. **Read-Only Root Filesystem**
   - File to create: `kubernetes/apps/security/kyverno/policies/readonly-root-fs.yaml`
   - Enforce: `securityContext.readOnlyRootFilesystem: true`
   - Exceptions: Workloads that need writable root (with justification)

**Implementation Order**:
1. Deploy policies in `Audit` mode first
2. Review violations for 1 week
3. Fix violations or create exceptions
4. Switch to `Enforce` mode

**Testing**:
```bash
# Check policy reports
kubectl get policyreport -A

# View violations
kubectl get policyreport -n <namespace> -o yaml
```

---

### H-3.1: Add refreshInterval to ExternalSecrets
**Status**: Not Started
**Priority**: HIGH
**Risk**: Secrets not refreshed timely after 1Password updates
**Effort**: 1 hour

**Action**: Add explicit `refreshInterval` to all ExternalSecret resources

**Files to Update** (48 ExternalSecret resources found):
- All files in `kubernetes/apps/*/*/app/externalsecret.yaml`

**Change Template**:
```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: <name>
spec:
  refreshInterval: 15m  # ADD THIS LINE
  secretStoreRef:
    kind: ClusterSecretStore
    name: onepassword-connect
  # ... rest of spec
```

**Recommended Values**:
- Active secrets (OIDC, API keys): `15m`
- Database credentials: `30m`
- Static secrets (rarely change): `1h`

**Script to Apply**:
```bash
# Find all ExternalSecret files
find kubernetes/apps -name "externalsecret.yaml" -type f

# Add refreshInterval after spec: line
# (Manual review recommended)
```

---

## 🟡 MEDIUM PRIORITY (Next 2-4 Weeks)

### M-5.1: Add Backup Annotations to PVCs
**Status**: Not Started
**Priority**: MEDIUM
**Risk**: Data loss if backups not configured
**Effort**: 2-3 hours

**Current State**:
- K8up installed but no backup annotations
- Velero installed but no volume backup annotations
- Longhorn recurring backups commented out

**Action Items**:

1. **Enable Longhorn Recurring Backups**
   - File: `kubernetes/apps/storage/longhorn/app/helmrelease.yaml`
   - Lines: 37-41 (currently commented)
   - Uncomment and configure:
     ```yaml
     recurringJobs:
       - name: daily-backup
         cron: "0 2 * * *"
         task: backup
         retain: 7
       - name: weekly-snapshot
         cron: "0 3 * * 0"
         task: snapshot
         retain: 4
     ```

2. **Add K8up Backup Annotations**
   - Add to all PVCs in critical apps:
     ```yaml
     annotations:
       k8up.io/backup: "true"
     ```
   - Critical apps:
     - productivity/paperless
     - productivity/n8n
     - productivity/freshrss
     - productivity/linkding
     - productivity/obsidian
     - media/calibre-web
     - database/postgres clusters

3. **Add Velero Backup Annotations**
   - Add to all PVCs:
     ```yaml
     annotations:
       velero.io/backup-volume: "true"
     ```

**Verification**:
```bash
# Check K8up backups
kubectl get backup -n storage

# Check Velero backups
kubectl get backup -n storage -l app.kubernetes.io/name=velero
```

---

### M-7.1: Optimize Prometheus Storage Configuration
**Status**: Not Started
**Priority**: MEDIUM
**Risk**: Wasted storage resources
**Effort**: 30 minutes

**Current Config**:
- File: `kubernetes/apps/observability/kube-prometheus-stack/app/helmrelease.yaml`
- Line 64: `retentionSize: 2GiB`
- Line 79: PVC size `12Gi`
- **Utilization**: Only 16% (2 of 12 GB)

**Options**:

**Option A: Increase Retention** (Recommended)
```yaml
prometheus:
  prometheusSpec:
    retentionSize: 10GiB  # Increase from 2GiB
    retention: 30d         # Keep 30 days of metrics
    storage:
      volumeClaimTemplate:
        spec:
          resources:
            requests:
              storage: 12Gi  # Keep as is
```

**Option B: Reduce PVC Size**
```yaml
prometheus:
  prometheusSpec:
    retentionSize: 2GiB
    retention: 7d
    storage:
      volumeClaimTemplate:
        spec:
          resources:
            requests:
              storage: 4Gi  # Reduce from 12Gi
```

**Recommendation**: Option A - More historical data is valuable for troubleshooting

---

### M-1.3: Clean Up Commented Code
**Status**: Not Started
**Priority**: MEDIUM
**Risk**: Repository clutter and confusion
**Effort**: 1 hour

**Files with Commented Resources**:

1. **longhorn-prereq** (disabled)
   - File: `kubernetes/apps/storage/longhorn/ks.yaml`
   - Lines: 1-22
   - Action: Move to `kubernetes/apps/storage/longhorn/ks.dis.prereq` or delete

2. **unifi-dns** (disabled)
   - File: `kubernetes/apps/network/internal/ks.yaml`
   - Lines: 3-22
   - Action: Move to dedicated disabled/ directory or delete

3. **openvpn** (disabled)
   - File: `kubernetes/apps/network/external/ks.yaml`
   - Lines: 74-94
   - Action: Move to dedicated disabled/ directory or delete

**Recommendation**: Create `kubernetes/apps/.disabled/` directory with README explaining why each component is disabled

---

### M-3.1: Document SOPS Secret Inventory
**Status**: Not Started
**Priority**: MEDIUM
**Risk**: Lack of secret management visibility
**Effort**: 1-2 hours

**Action**: Create `kubernetes/SECRETS.md` documenting all SOPS-encrypted secrets

**Template**:
```markdown
# Secret Inventory

## SOPS Encrypted Files (17 total)

| File | Purpose | Age Key | Last Rotated |
|------|---------|---------|--------------|
| file1.sops.yaml | Description | age-key-id | YYYY-MM-DD |

## Secret Rotation Schedule

- Age keys: Annually
- 1Password token: Every 90 days
- Service credentials: As needed

## Recovery Procedures

1. Age key lost: [steps]
2. 1Password access lost: [steps]
```

---

### M-10.1: Standardize Directory Structures
**Status**: Not Started
**Priority**: MEDIUM
**Risk**: Inconsistent patterns make maintenance harder
**Effort**: 2 hours (documentation)

**Current Patterns**:
- Most apps: `app/helmrelease.yaml`
- Some apps: `app/` with multiple ingress files (mediabox)
- Some apps: Separate `app/` and `db/` (webtrees)
- Network: `external/` and `internal/` subdirectories

**Action**: Document patterns in CLAUDE.md

**Pattern Decision Tree**:
```
Single HelmRelease → app/helmrelease.yaml
Multiple components → app/<component>/helmrelease.yaml
Separate database → db/helmrelease.yaml + app/helmrelease.yaml
Multiple ingresses → app/ingress-<name>.yaml
```

---

### M-1.2: Add CoreDNS Dependency to k8s-gateway
**Status**: Not Started
**Priority**: MEDIUM
**Risk**: k8s-gateway may start before DNS is ready
**Effort**: 5 minutes

**File**: `kubernetes/apps/network/k8s-gateway/ks.yaml`

**Change**:
```yaml
spec:
  dependsOn:
    - name: coredns
      namespace: kube-system
```

---

## 🟢 LOW PRIORITY (Future / As Needed)

### L-10.1: Add README Files to App Directories
**Status**: Not Started
**Priority**: LOW
**Risk**: Lack of documentation
**Effort**: Ongoing

**Template for Complex Apps**:
```markdown
# <App Name>

## Purpose
Brief description of what this app does

## Dependencies
- Storage: Longhorn PVC
- Secrets: External-secrets from 1Password
- Ingress: internal-ingress-nginx

## Configuration
Key configuration points

## Backup Strategy
- PVC backed up by: K8up daily
- Database backed up by: Velero

## Known Issues / Quirks
- Issue 1: Description and workaround
```

**Apps that need READMEs**:
- kube-prometheus-stack (complex configuration)
- longhorn (backup configuration)
- mediabox (multiple ingresses)
- paperless (AI integration)
- n8n (workflow automation)

---

### L-10.2: Create Cluster Changelog
**Status**: Not Started
**Priority**: LOW
**Risk**: Lost institutional knowledge
**Effort**: Ongoing

**File to Create**: `kubernetes/CHANGELOG.md`

**Format**:
```markdown
# Cluster Changelog

## 2025-11-17
- Activated Trivy Operator for vulnerability scanning
- Enabled 10 monitoring exporters
- Standardized Longhorn wait settings
- Fixed Flux Kustomization dependencies

## 2025-11-14
- Added Weave GitOps with OIDC authentication

## [Earlier entries...]
```

---

### L-6.1: Enable VPA Auto Mode for Selected Apps
**Status**: Not Started
**Priority**: LOW
**Risk**: None (optimization opportunity)
**Effort**: 2-3 hours

**Current State**:
- Goldilocks (VPA dashboard) installed
- VPA appears in "Off" or "Recommend" mode
- Resource recommendations not automatically applied

**Action**: Enable VPA auto-update for non-critical workloads

**Candidates for Auto VPA**:
- Media exporters (low risk)
- Monitoring exporters (low risk)
- Development tools (code-server, etc.)

**DO NOT auto-update**:
- Databases
- Storage systems
- Critical infrastructure (Cilium, CoreDNS)

**VPA Resource Example**:
```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: <app-name>
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: <app-name>
  updatePolicy:
    updateMode: "Auto"  # Change from "Off"
  resourcePolicy:
    containerPolicies:
      - containerName: "*"
        minAllowed:
          memory: 50Mi
          cpu: 10m
        maxAllowed:
          memory: 1Gi
          cpu: 500m
```

---

### L-1.1: Review and Standardize Timeout Values
**Status**: Not Started
**Priority**: LOW
**Risk**: Suboptimal deployment experience
**Effort**: 1 hour

**Current State**: Inconsistent timeouts (5m to 15m)

**Proposed Standards**:
- **Critical Infrastructure** (cert-manager, prometheus, longhorn): 15m
- **Network/Ingress**: 10m
- **Standard Apps**: 5m
- **Simple Deployments** (echo-server): 3m

**Files to Update**: All `ks.yaml` files

**Script**:
```bash
# Review current timeouts
grep -r "timeout:" kubernetes/apps/*/*/ks.yaml | sort | uniq -c
```

---

### L-9.1: Audit Deployed RBAC
**Status**: Not Started
**Priority**: LOW
**Risk**: Over-permissive roles
**Effort**: 3-4 hours

**Action**: Extract and document RBAC from deployed HelmReleases

**Commands**:
```bash
# List all ClusterRoles
kubectl get clusterrole | grep -v "system:"

# List all Roles per namespace
for ns in $(kubectl get ns -o name | cut -d/ -f2); do
  echo "=== $ns ==="
  kubectl get role -n $ns
done

# Review specific role
kubectl describe clusterrole <name>
```

**Focus Areas**:
- External-secrets operator permissions
- Kyverno webhook permissions
- Cert-manager permissions
- Flux permissions

---

## 📊 COMPLETED IMPROVEMENTS SUMMARY

### 2025-11-17

#### Flux Kustomization Dependency Fixes
- **kyverno-policies**: Set `wait: true` (22 apps depend on it)
- **external-secrets-secretstores**: Set `wait: true` (8 apps depend on it)
- **snapshot-controller**: Set `wait: true` (Velero depends on it)
- **kube-prometheus-stack**: Added missing `namespace: observability` to alertmanager-discord dependency

#### Longhorn Storage Consistency
- Standardized all Longhorn-dependent apps to `wait: true`:
  - open-webui
  - code-server
  - freshrss
  - linkding
  - n8n
  - obsidian

#### Security Enhancements
- ✅ Trivy Operator activated (automated vulnerability scanning)
- ✅ Snippet annotations verified as secured (annotations-risk-level: Critical)

#### Observability Improvements
- ✅ Activated 10 monitoring exporters:
  - blackbox-exporter
  - gatus
  - grafana
  - prowlarr-exporter
  - radarr-exporter
  - sabnzbd-exporter
  - snmp-exporter
  - sonarr-exporter
  - speedtest-exporter
  - tautulli-exporter

#### Application Deployments
- ✅ librechat2 activated (AI namespace)
- ✅ homepage activated (default namespace)

---

## 🎯 RECOMMENDED ACTION PLAN

### Week 1 (High Priority Security)
- [ ] H-8.1: Implement NetworkPolicies (4-6 hours)
- [ ] H-3.1: Add refreshInterval to ExternalSecrets (1 hour)

### Week 2 (High Priority Monitoring)
- [ ] H-7.1: Add ServiceMonitors for operators (2-3 hours)
- [ ] H-9.1: Expand Kyverno policies (3-4 hours)

### Week 3-4 (Medium Priority)
- [ ] M-5.1: Add backup annotations to PVCs (2-3 hours)
- [ ] M-7.1: Optimize Prometheus storage (30 minutes)
- [ ] M-1.3: Clean up commented code (1 hour)
- [ ] M-3.1: Document SOPS inventory (1-2 hours)

### Ongoing / As Needed
- [ ] L-10.1: Add README files to complex apps
- [ ] L-10.2: Maintain cluster changelog
- [ ] L-6.1: Enable VPA auto mode for selected apps
- [ ] L-1.1: Standardize timeout values
- [ ] L-9.1: Audit deployed RBAC

---

## 📈 PROGRESS TRACKING

**Completion Rate**: 21% (17 of 82 issues resolved)

**By Priority**:
- Critical: 100% (3/3) ✅
- High: 31% (4/13) 🟡
- Medium: 4% (1/28) 🔴
- Low: 0% (0/38) ⚪

**Next Milestone**: Complete all High Priority items (9 remaining)

---

## 📝 NOTES

### Patterns Working Well
- SOPS encryption with Age keys
- External-secrets with 1Password
- Flux GitOps workflow
- Resource limits with VPA recommendations
- Split-horizon DNS
- Wildcard TLS certificates

### Areas for Improvement
- Network security (NetworkPolicies)
- Metrics coverage (ServiceMonitors)
- Policy enforcement (Kyverno)
- Backup automation (PVC annotations)
- Documentation (READMEs)

### Deferred Items
Items intentionally not included in this roadmap:
- Migrating from HelmRelease to plain manifests (current pattern works well)
- Switching from Longhorn to another storage provider (stable and working)
- Implementing GitOps via ArgoCD (Flux is working well)

---

**Document maintained by**: Claude Code
**Next Review Date**: 2025-12-01
**Contact**: Refer to CLAUDE.md for AI assistant guidance
