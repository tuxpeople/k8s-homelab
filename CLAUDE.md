# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an active Kubernetes homelab cluster built on Talos Linux with GitOps using FluxCD, running on the domain `eighty-three.me`. The project uses a templating system (makejinja) to generate configuration files from templates based on cluster and node definitions.

## Core Architecture

### Template System
- **makejinja**: Template engine that generates Kubernetes and Talos configs from Jinja2 templates
- Configuration data sources: `cluster.yaml` (primary) and `nodes.yaml` (not used in this deployment)
- Templates located in `templates/` directory with custom Jinja2 delimiters (`#{` `}#` for variables, `#%` `%#` for blocks)
- Generated files are placed throughout the repository structure
- Template configuration in `makejinja.toml` defines inputs, outputs, and data sources

### Cluster Components
- **Talos Linux**: Immutable OS for Kubernetes nodes with talhelper for configuration management
- **FluxCD**: GitOps tool for continuous deployment from Git repository
- **CNI**: Cilium networking with built-in CNI disabled in Talos
- **Storage**: Longhorn for distributed block storage, Synology CSI for external NAS storage
- **Ingress**: nginx-ingress with internal (`192.168.13.64`) and external (`192.168.13.66`) classes
- **DNS**: k8s_gateway for internal DNS (`192.168.13.65`), external-dns for public DNS via Cloudflare
- **Security**: SOPS for secret encryption using Age keys, external-secrets with 1Password integration
- **Monitoring**: Kube-prometheus-stack with Grafana, custom exporters for media applications

### Directory Structure
```
kubernetes/
├── apps/           # Application deployments organized by category
├── components/     # Shared Kubernetes components
├── flux/          # FluxCD bootstrap and repository configuration
talos/
├── clusterconfig/ # Generated Talos configurations
├── patches/       # Talos configuration patches
├── talconfig.yaml # Main Talos cluster configuration
scripts/           # Utility scripts for cluster management
.taskfiles/        # Task runner configuration files
```

## Development Commands

All commands use Task runner. Run `task --list` to see all available tasks. Commands are organized in modular taskfiles under `.taskfiles/`.

### Essential Commands
```bash
# Initialize configuration files (first-time setup only)
task init

# Generate all configuration files from templates
task configure

# Bootstrap Talos cluster
task bootstrap:talos

# Bootstrap applications with FluxCD
task bootstrap:apps

# Force Flux to reconcile from Git
task reconcile

# Debug cluster resources
task debug
```

### Talos Operations
```bash
# Generate Talos configuration
task talos:generate-config

# Apply config to specific node
task talos:apply-node IP=<node-ip> MODE=<auto|try|reboot>

# Upgrade single node to newer Talos version
task talos:upgrade-node IP=<node-ip>

# Upgrade all nodes to newer Talos version
task talos:upgrade-all-nodes

# Upgrade Kubernetes version across cluster
task talos:upgrade-k8s

# Reset cluster to maintenance mode (destructive!)
task talos:reset
```

### Template Operations
```bash
# Validate configuration schemas
task validate-schemas

# Render configuration from templates
task render-configs

# Encrypt all SOPS secrets
task encrypt-secrets

# Clean up template files after setup
task template:tidy

# Remove all templated files (destructive!)
task template:reset
```

## Tool Dependencies

Managed via mise (modern runtime manager):
- **Core**: kubectl, helm, kustomize, flux, talosctl
- **Templating**: makejinja, yamlfix
- **Security**: sops, age
- **Build**: task, yq, jq
- **Network**: cilium-cli, cloudflared

Install all tools: `mise trust && pip install pipx && mise install`

## Configuration Files

### Primary Config Files
- `cluster.yaml` - Main cluster configuration (domains, networking, load balancer IPs, etc.)
- `nodes.yaml` - Node-specific configuration (IPs, hardware, etc.) - not used in this deployment
- `talos/talconfig.yaml` - Talos cluster configuration
- `talos/talenv.yaml` - Talos and Kubernetes version definitions
- `makejinja.toml` - Template engine configuration with custom delimiters

### Generated Files (Do Not Edit Directly)
- All files in `talos/clusterconfig/`
- Most files in `kubernetes/` (generated from templates)
- Files with `.j2` extension are templates

## Secret Management

- **SOPS** encrypts secrets using Age keys
- Age key stored in `age.key` (not committed)
- All `*.sops.yaml` files are encrypted
- Verify secrets are encrypted before committing

## Networking Architecture

- **Node Network**: 192.168.13.0/24
- **Cluster API**: 192.168.13.10
- **Cluster Pod CIDR**: 10.42.0.0/16
- **Cluster Service CIDR**: 10.43.0.0/16
- **Load Balancer IPs**:
  - `internal` ingress: 192.168.13.64 - Private network access
  - `external` ingress: 192.168.13.66 - Public internet access via Cloudflare Tunnel
  - DNS gateway: 192.168.13.65 - Internal DNS resolution via k8s_gateway
- **Domain**: eighty-three.me
- **DNS**: Split-horizon DNS with k8s_gateway for internal resolution, Cloudflare for external

## Application Organization

Applications in `kubernetes/apps/` are organized by function:
- `ai/` - AI/ML applications (LibreChat2, Open WebUI, Ollama)
- `cert-manager/` - Certificate management
- `database/` - Database operators and services
- `default/` - General applications (echo-server, GitLab runners, homepage)
- `flux-system/` - FluxCD operator and instance configurations
- `kube-system/` - Core Kubernetes components (Cilium, CoreDNS, metrics-server, reloader, spegel)
- `media/` - Media server applications (Overseerr, Tautulli, mediabox stack)
- `network/` - Networking components (ingress-nginx, external-dns, cloudflared, k8s-gateway)
- `observability/` - Monitoring and logging (Prometheus stack, Grafana, exporters, Gatus)
- `productivity/` - Productivity tools (Code Server, FreshRSS, Hajimari, Linkding, N8N, Obsidian, Paperless)
- `security/` - Security-related applications (external-secrets, Kyverno, Trivy)
- `storage/` - Storage systems and backup (Longhorn, Synology CSI, K8up, Velero)
- `system-upgrade/` - Talos and Kubernetes upgrade automation
- `tools/` - Utility applications (headscale, pod-cleaner, SMTP relay, Spoolman)
- `vpa/` - Vertical Pod Autoscaler (Goldilocks)

Each application typically has:
- `app/helmrelease.yaml` - Helm chart deployment
- `app/kustomization.yaml` - Kustomize configuration
- `ks.yaml` - FluxCD Kustomization resource

## Development Workflow

### Template-Based Development
This repository uses a template-driven approach where most Kubernetes manifests are generated:

1. **Never edit generated files directly** - Edit templates in `templates/` instead
2. **After template changes**: Run `task configure` to regenerate manifests
3. **Test changes**: Use `flux-local` via GitHub Actions for validation, `task debug` for cluster status
4. **Template syntax**: Uses custom Jinja2 delimiters (`#{` `}#` for variables, `#%` `%#` for blocks)
5. **Configuration validation**: Schema validation via CUE files in `.taskfiles/template/resources/`

### Secret Management Workflow
```bash
# Create new encrypted secret
echo "secretvalue" | sops --age --filename-override path/to/secret.sops.yaml --encrypt /dev/stdin > secret.sops.yaml

# Edit existing encrypted secret
sops path/to/secret.sops.yaml

# Verify encryption before commit
grep -r "ENC\[AES256_GCM" kubernetes/
```

### Debugging Applications
```bash
# Check Flux resources status
flux get sources git -A
flux get ks -A  
flux get hr -A

# Force reconciliation of specific app
flux reconcile kustomization <app-name> --with-source

# Check application logs
kubectl -n <namespace> logs -l app.kubernetes.io/name=<app> -f
```

## CI/CD Pipeline

### GitHub Actions Workflows
- **flux-local.yaml**: Validates Kubernetes manifests and shows diffs on PRs
- **e2e.yaml**: End-to-end testing of template generation
- **mise.yaml**: Tool dependency management validation
- **shellcheck.yaml**: Shell script linting

### Renovate Configuration
- **Auto-updates**: Container images, Helm charts, GitHub Actions
- **Scheduling**: Weekend updates only
- **Grouping**: Related updates bundled together
- **Auto-merge**: Patch updates and GitHub Actions

## Important Constraints & Patterns

### Application Deployment Patterns
- **HelmRelease**: Primary deployment method via Flux
- **External Secrets**: Use ExternalSecret resources for secret injection
- **Ingress**: Use `internal` class for private access, `external` for public
- **Storage**: Longhorn for persistent volumes, use StorageClass annotations

### Security Considerations
- **SOPS encryption**: All secrets must be encrypted before commit
- **Image security**: Use specific image tags, avoid `latest`
- **Network policies**: Implement for multi-tenant workloads
- **Resource limits**: Always define requests/limits in HelmReleases

### Common Issues to Avoid
1. **Hardcoded values**: Use template variables from cluster.yaml
2. **Missing health checks**: Add readiness/liveness probes
3. **No resource limits**: Can cause cluster resource exhaustion  
4. **Direct manifest editing**: Always edit templates, not generated files
5. **Ingress annotation risks**: Be cautious with `allow-snippet-annotations`

## Troubleshooting

### Common Problems
- **Template generation fails**: Check Jinja2 syntax and variable definitions in cluster.yaml/nodes.yaml
- **Schema validation errors**: Check CUE schema files in `.taskfiles/template/resources/`
- **Flux not syncing**: Verify Git repository access and webhook configuration
- **Application startup issues**: Check resource requests vs cluster capacity
- **Secret access failures**: Verify SOPS key and ExternalSecret configuration
- **Talos node issues**: Use `talhelper` commands and check talosconfig validity

## Architecture Details

### Task Runner Architecture

The project uses a modular Task runner setup with main `Taskfile.yaml` including sub-taskfiles:

- `.taskfiles/bootstrap/` - Cluster and application bootstrapping
- `.taskfiles/talos/` - Talos node management and upgrades
- `.taskfiles/template/` - Template rendering, validation, and cleanup

### Flux Architecture

FluxCD manages the cluster through a hierarchical structure:

- `flux/` - Core Flux configuration and repository definitions
- `components/` - Shared Kubernetes components and cluster-wide resources
- `apps/` - Application deployments organized by category with Kustomization resources

### Secret Management Architecture

Multi-layered secret management:

- **SOPS + Age**: Encrypt secrets at rest in Git with `age.key`
- **External Secrets**: Runtime secret injection from 1Password (vault "Homelab")
- **Cert-manager**: Automated TLS certificate management with Let's Encrypt production issuer
- **Ingress TLS**: Default wildcard certificate `${SECRET_DOMAIN/./-}-production-tls`

### Storage Architecture

Distributed storage with multiple backends:

- **Longhorn**: Primary distributed block storage with automated backups and snapshots
- **Synology CSI**: External NAS storage for large datasets via DSM integration
- **Backup Strategy**: K8up (Restic), Velero, and Longhorn's native backup capabilities

### Monitoring Architecture

Comprehensive observability stack:

- **Metrics**: Prometheus with custom recording rules and federation
- **Visualization**: Grafana with pre-configured dashboards for home automation, systems, and applications
- **Alerting**: Alertmanager with Discord webhook integration
- **Exporters**: Specialized exporters for media stack (Tautulli, *arr apps), SNMP (Synology), and network services
