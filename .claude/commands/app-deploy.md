---
description: Guided workflow for deploying new applications to k8s-homelab cluster
argument-hint: [app-name or category] - Name of app to deploy or category (ai, media, productivity, etc.)
---

# App Deployment Protocol

**MISSION**: Guide the structured deployment of new applications to the k8s-homelab cluster
following GitOps best practices, direct manifest editing, and security requirements.

**SCOPE**: $ARGUMENTS

*If no arguments provided, start with application discovery and category selection.*

## Deployment Priority

1. **Application Research** - Find suitable Helm charts and understand requirements
2. **Category & Placement** - Determine correct app category and namespace strategy
3. **Manifest Creation** - Create Kubernetes manifests following cluster patterns
4. **Security Integration** - Configure secrets, ingress, and network policies
5. **Resource Planning** - Set appropriate requests, limits, and storage
6. **Testing & Validation** - Deploy safely and verify functionality

## What I Will Do

**Pre-Deployment Research:**

- Research available Helm charts and official documentation
- Analyze resource requirements and dependencies
- Identify security considerations and best practices
- Determine integration points with existing cluster services

**Direct Manifest Implementation:**

- Create manifests in `kubernetes/apps/[category]/[app]/`
- Follow established patterns from existing applications
- Configure secrets using SOPS or ExternalSecrets
- Set up ingress routing (internal vs external)

**Collaborative Deployment:**

- Present template structure and configuration choices
- Explain security and resource decisions
- Guide through testing and validation process
- Document any special considerations or requirements

## Deployment Flow

```yaml
1. Research: Chart options, requirements, best practices
2. Planning: Category, namespace, dependencies, security
3. Manifests: Create Kubernetes manifests following cluster patterns
4. Configuration: Helm values, ingress, secrets, storage
5. Validation: Schema validation and dry-run testing
6. Deployment: Commit manifests and monitor Flux reconciliation
7. Testing: Verify functionality and access
```

## Application Categories & Patterns

**Category Structure:**
```
kubernetes/apps/
├── ai/           # AI/ML applications (LibreChat, Ollama, Open WebUI)
├── database/     # Database operators and services
├── default/      # General applications, GitLab runners
├── media/        # Media servers (*arr stack, Overseerr, Tautulli)
├── productivity/ # Productivity tools (Code Server, N8N, Obsidian)
├── observability/# Monitoring (Grafana, exporters, Gatus)
├── security/     # Security tools (external-secrets, Trivy)
├── storage/      # Storage and backup (Longhorn, K8up, Velero)
├── tools/        # Utilities (headscale, SMTP relay, Spoolman)
└── network/      # Networking (ingress, external-dns, k8s-gateway)
```

**Standard App Structure:**
```
kubernetes/apps/[category]/[app-name]/
├── app/
│   ├── helmrelease.yaml        # Main Helm chart deployment
│   ├── kustomization.yaml      # Kustomize configuration
│   └── externalsecret.yaml     # Secret configuration (if needed)
├── ks.yaml                     # Flux Kustomization resource
└── secrets.sops.yaml           # SOPS encrypted secrets (if needed)
```

## Manifest Patterns & Examples

**Basic HelmRelease:**
```yaml
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: app-name
  namespace: category
spec:
  interval: 30m
  chart:
    spec:
      chart: app-name
      version: "1.0.0"
      sourceRef:
        kind: HelmRepository
        name: app-name
        namespace: flux-system
  values:
    global:
      nameOverride: app-name
    ingress:
      main:
        enabled: true
        ingressClassName: "internal"  # or "external" for public access
        hosts:
          - host: "app-name.eighty-three.me"
            paths:
              - path: /
                pathType: Prefix
        tls:
          - hosts:
              - "app-name.eighty-three.me"
            secretName: "eighty-three-me-production-tls"
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 512Mi
```

**Kustomization:**
```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: category
resources:
  - ./helmrelease.yaml
  - ./externalsecret.yaml  # if secrets needed
```

**Flux Kustomization Resource:**
```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: app-name-category
  namespace: flux-system
spec:
  interval: 10m
  path: "./kubernetes/apps/category/app-name/app"
  prune: true
  sourceRef:
    kind: GitRepository
    name: home-kubernetes
  wait: false
  dependsOn:
    - name: category-namespace
```

## Security & Configuration Guidelines

**Ingress Classes:**
- **internal** (`192.168.13.64`): Private network access only
- **external** (`192.168.13.66`): Public internet via Cloudflare Tunnel

**Secret Management:**
```yaml
# ExternalSecret for 1Password integration
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: #{app}#-secret
  namespace: #{namespace}#
spec:
  refreshInterval: 5m
  secretStoreRef:
    kind: ClusterSecretStore
    name: onepassword
  target:
    name: #{app}#-secret
    template:
      type: Opaque
  data:
    - secretKey: username
      remoteRef:
        key: #{app}#
        property: username
```

**Storage Classes:**
- **longhorn**: Default distributed storage
- **synology-iscsi**: Large datasets via Synology NAS
- **longhorn-static**: Static provisioning when needed

**Resource Patterns:**
```yaml
resources:
  requests:
    cpu: 100m      # Start conservative
    memory: 128Mi  # Based on application requirements
  limits:
    cpu: 500m      # 2-5x requests typically
    memory: 512Mi  # Based on observed usage
```

## Common Integration Points

**Database Dependencies:**
- PostgreSQL: Use `postgresql-ha` cluster in `database` namespace
- Redis: Deploy per-app or use shared instance
- ConfigMaps: For application configuration

**Monitoring Integration:**
- **ServiceMonitor**: For Prometheus scraping
- **Grafana Dashboard**: Custom dashboards in `observability/grafana`
- **Alerts**: Configure in `observability/kube-prometheus-stack`

**Backup Integration:**
- **K8up**: Automatic backup annotations
- **Velero**: For persistent volume backups
- **Longhorn**: Storage-level backups and snapshots

## Deployment Workflow

**Research Phase:**
1. Find official Helm chart or reliable community chart
2. Review chart documentation and default values
3. Check resource requirements and dependencies
4. Identify security considerations

**Manifest Creation:**
1. Choose appropriate category and namespace
2. Create manifest structure following patterns
3. Configure Helm values for cluster environment
4. Set up ingress routing and TLS
5. Configure secrets if needed

**Validation & Testing:**
1. Review created YAML files
2. Test with `kubectl apply --dry-run`
3. Validate YAML syntax and Kubernetes resources
4. Check dependencies and resource references

**Deployment & Monitoring:**
1. Commit manifests to Git repository
2. Monitor Flux reconciliation: `flux get hr -A`
3. Check pod status: `kubectl get pods -n <namespace>`
4. Verify ingress and connectivity
5. Test application functionality

## Communication Style

**Structured Guidance:**
- Present research findings with chart options and recommendations
- Explain category placement and naming decisions
- Show template structure before implementation
- Highlight security and resource considerations

**Decision Points:**
- Ask about ingress requirements (internal vs external)
- Confirm resource allocation based on app requirements
- Discuss secret management approach
- Validate namespace and category choices

## Session Agreement

This command establishes app deployment workflow:

1. **Research** → I investigate chart options and requirements
2. **Planning** → We decide on category, configuration, and security
3. **Templates** → I create templates following cluster patterns
4. **Review** → We review configuration and make adjustments
5. **Generation** → I run `task configure` to create manifests
6. **Validation** → I validate schemas and test configuration
7. **Deployment** → You commit changes and we monitor deployment
8. **Testing** → We verify functionality and troubleshoot if needed

## Critical Reminders

- **TEMPLATE FIRST** - Always create templates, never direct manifests
- **CATEGORY PLACEMENT** - Choose appropriate app category for organization
- **SECURITY BY DEFAULT** - Configure proper ingress, secrets, and resource limits
- **RESOURCE PLANNING** - Set appropriate requests/limits based on app requirements
- **FLUX PATTERNS** - Follow established Kustomization and dependency patterns
- **TEST THOROUGHLY** - Validate templates and test functionality before considering complete
- **DOCUMENT DECISIONS** - Explain configuration choices for future reference

## Quick Reference

```bash
# Manifest validation workflow
kubectl apply --dry-run=client  # Test created manifests
yq eval . manifest.yaml          # Validate YAML syntax

# Deployment monitoring
flux get hr -A                  # Monitor HelmRelease status
kubectl get pods -n <namespace> # Check pod status
kubectl logs -n <namespace> -l app=<app-name> # Application logs

# Common troubleshooting
flux reconcile hr <app-name> --with-source
kubectl describe pod -n <namespace> <pod-name>
```
