# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Kubernetes homelab cluster template built on Talos Linux with GitOps using FluxCD. The project uses a templating system (makejinja) to generate configuration files from templates based on cluster and node definitions.

## Core Architecture

### Template System
- **makejinja**: Template engine that generates Kubernetes and Talos configs from Jinja2 templates
- Configuration data sources: `cluster.yaml` and `nodes.yaml`
- Templates located in `templates/` directory
- Generated files are placed throughout the repository structure

### Cluster Components
- **Talos Linux**: Immutable OS for Kubernetes nodes
- **FluxCD**: GitOps tool for continuous deployment
- **CNI**: Cilium networking with built-in CNI disabled in Talos
- **Storage**: Longhorn for persistent storage, Synology CSI for external storage
- **Ingress**: nginx-ingress with internal/external classes
- **DNS**: k8s_gateway for internal DNS, external-dns for public DNS
- **Security**: SOPS for secret encryption using Age keys

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

All commands use Task runner. Run `task --list` to see all available tasks.

### Essential Commands
```bash
# Initialize configuration files (first-time setup)
task init

# Generate all configuration files from templates
task configure

# Bootstrap Talos cluster
task bootstrap:talos

# Bootstrap applications with FluxCD
task bootstrap:apps

# Force Flux to reconcile from Git
task reconcile
```

### Talos Operations
```bash
# Generate Talos configuration
task talos:generate-config

# Apply config to specific node
task talos:apply-node IP=<node-ip> MODE=<auto|try|reboot>

# Upgrade node to newer Talos version
task talos:upgrade-node IP=<node-ip>

# Upgrade Kubernetes version across cluster
task talos:upgrade-k8s

# Reset cluster to maintenance mode
task talos:reset
```

### Template Operations
```bash
# Clean up template files after setup
task template:tidy
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
- `cluster.yaml` - Main cluster configuration (domains, networking, etc.)
- `nodes.yaml` - Node-specific configuration (IPs, hardware, etc.)
- `talos/talconfig.yaml` - Talos cluster configuration
- `makejinja.toml` - Template engine configuration

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

- **Cluster Pod CIDR**: 10.42.0.0/16
- **Cluster Service CIDR**: 10.43.0.0/16
- **Ingress Classes**: 
  - `internal` - Private network access
  - `external` - Public internet access via Cloudflare Tunnel
- **DNS**: Split-horizon DNS with k8s_gateway for internal resolution

## Application Organization

Applications in `kubernetes/apps/` are organized by function:
- `ai/` - AI/ML applications
- `cert-manager/` - Certificate management
- `default/` - General applications
- `media/` - Media server applications
- `network/` - Networking components
- `observability/` - Monitoring and logging
- `productivity/` - Productivity tools
- `security/` - Security-related applications
- `storage/` - Storage systems and backup

Each application typically has:
- `app/helmrelease.yaml` - Helm chart deployment
- `app/kustomization.yaml` - Kustomize configuration
- `ks.yaml` - FluxCD Kustomization resource

## Development Workflow

### Template-Based Development
This repository uses a template-driven approach where most Kubernetes manifests are generated:

1. **Never edit generated files directly** - Edit templates in `templates/` instead
2. **After template changes**: Run `task configure` to regenerate manifests
3. **Test changes**: Use `flux-local` via GitHub Actions for validation
4. **Template syntax**: Uses custom Jinja2 delimiters (`#{` `}#` for variables, `#%` `%#` for blocks)

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
- **Flux not syncing**: Verify Git repository access and webhook configuration
- **Application startup issues**: Check resource requests vs cluster capacity
- **Secret access failures**: Verify SOPS key and ExternalSecret configuration