# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an active Kubernetes homelab cluster built on Talos Linux with GitOps using FluxCD, running on the domain `eighty-three.me`. The project uses direct manifest editing for Kubernetes configurations.

## Core Architecture

### Configuration Management
- **Direct Editing**: Kubernetes manifests are edited directly in the `kubernetes/` directory
- **No Template System**: The cluster has moved beyond template-based generation to direct manifest editing
- **Configuration Files**: `cluster.yaml` and related files are preserved for reference but no longer used for generation

### Cluster Components
- **Talos Linux**: Immutable OS for Kubernetes nodes with talhelper for configuration management
- **FluxCD**: GitOps tool for continuous deployment from Git repository
- **CNI**: Cilium networking with built-in CNI disabled in Talos
- **Storage**: Longhorn for distributed block storage, Synology CSI for external NAS storage
- **Ingress**: nginx-ingress with internal (`192.168.13.64`) and external (`192.168.13.66`) classes
- **DNS**: Split-horizon DNS with k8s_gateway (`192.168.13.65`), dual external-dns (Cloudflare for public, UniFi for internal LAN)
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
docs/              # Operational documentation (see below)
```

### Documentation Structure

The `docs/` directory contains operational documentation for humans:

**Core Documentation:**
- `README.md` - Documentation overview and guidelines
- `automation.md` - Task runner, GitHub Actions, Renovate automation
- `monitoring.md` - Monitoring stack overview, dashboards, alerting flows
- `secrets.md` - Secret management workflows (SOPS, Age, External Secrets)
- `backups.md` - Backup strategy, test procedures, restoration workflows
- `dr.md` - Disaster recovery scenarios (cold start, namespace restore, full cluster rebuild)
- `runbooks.md` - Operational procedures (Flux drift, node exchange, volume degraded, etc.)

**Technical Documentation:**
- `architecture.png` / `architecture.dot` - Cluster architecture diagram
- `flux-dependency-graph.md` - Flux resource dependencies visualization (Mermaid format)
- `flux-dependencies.png` / `flux-dependencies.dot` - Alternative Flux dependency visualization (DOT/Graphviz format)
- `yaml-checks.md` - YAML validation tools and pre-commit hooks
- `CHANGELOG.md` - Infrastructure change log
- `TODO.md` - Known issues and planned improvements
- `WEITERENTWICKLUNG.md` - Development backlog (DOC-001 through DOC-010)

**Service Documentation** (`docs/services/`):
- `cluster-foundation.md` - Talos, Kubernetes, node inventory
- `fluxcd.md` - FluxCD configuration and workflows
- `networking.md` - DNS (k8s_gateway, external-dns dual setup), ingress, Cloudflare
- `storage.md` - Longhorn, Synology CSI, storage classes
- `observability.md` - Prometheus, Grafana, exporters, Gatus endpoint management
- `security.md` - Kyverno policies, External Secrets, Trivy, compliance
- `platform-support.md` - Supporting services (cert-manager, reloader, etc.)
- `applications-*.md` - Application-specific documentation (AI, media, productivity)

**Note**: CLAUDE.md serves as guidance for Claude Code AI sessions, while docs/ serves as operational documentation for humans. Both must be kept in sync where information overlaps.

## Development Commands

All commands use Task runner. Run `task --list` to see all available tasks. Commands are organized in modular taskfiles under `.taskfiles/`.

### Essential Commands
```bash
# Initialize configuration files (first-time setup only)
task init

# No longer needed - manifests are edited directly

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

# Check node health status
task talos:node-health

# Apply config to specific node
task talos:apply-node IP=<node-ip> MODE=<auto|try|reboot>

# Upgrade single node to newer Talos version
task talos:upgrade-node IP=<node-ip>

# Upgrade all nodes to newer Talos version
task talos:upgrade-all-nodes

# Upgrade Kubernetes version across cluster
task talos:upgrade-k8s

# Shutdown operations
task talos:shutdown-workers             # Shutdown all worker nodes
task talos:shutdown-control-plane       # Shutdown control-plane node
task talos:shutdown-cluster             # Orchestrated cluster shutdown (workers → control-plane)

# Reboot operations
task talos:reboot-cluster               # Orchestrated cluster reboot (workers → control-plane)

# Reset cluster to maintenance mode (destructive!)
task talos:reset
```

### Configuration Operations
```bash
# Encrypt all SOPS secrets
task encrypt-secrets

# Rebuild kustomization.yaml files for flux repositories and apps
./scripts/rebuild-kustomizations.sh

# Validate YAML syntax
yq eval . file.yaml

# Test manifests
kubectl apply --dry-run=client -f manifest.yaml
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
- All files in `talos/clusterconfig/` (generated by Talos tooling)

## Secret Management

- **SOPS** encrypts secrets using Age keys
- Age key stored in `age.key` (not committed)
- All `*.sops.yaml` files are encrypted
- Verify secrets are encrypted before committing

## Code Quality & Pre-commit Hooks

The repository uses pre-commit hooks to automatically validate code quality and prevent common issues before they reach the repository.

### Pre-commit Setup

Pre-commit hooks are configured to catch issues that previously caused problems (like the YAML parsing errors that broke Renovate digest updates).

#### Installation
```bash
# Install pre-commit hooks (automatic with mise)
task pre-commit:install

# Or manually if mise is not available
python -m pip install pre-commit
pre-commit install
```

#### Available Commands
```bash
# Run pre-commit on all files
task pre-commit:run

# Run pre-commit on specific files
pre-commit run --files path/to/file.yaml

# Update hook versions
task pre-commit:update

# Skip hooks for emergency commits
git commit --no-verify -m "emergency fix"
```

#### Configured Hooks

The `.pre-commit-config.yaml` includes:

- **YAML Validation**: Prevents syntax errors and duplicate keys that break Renovate
  - `check-yaml`: Basic YAML syntax validation
  - `yamllint`: Advanced YAML linting with 120-character line limit
  - Custom Kubernetes YAML validation using `yq`

- **Code Quality**:
  - `trailing-whitespace`: Removes trailing spaces
  - `end-of-file-fixer`: Ensures files end with newlines
  - `check-merge-conflict`: Detects merge conflict markers

- **Security**:
  - `detect-secrets`: Scans for potential secrets (uses `.secrets.baseline`)
  - Excludes SOPS-encrypted files and age keys

- **Shell & Markdown**:
  - `shellcheck`: Validates shell scripts
  - `markdownlint`: Validates Markdown files

#### Configuration Files

- `.pre-commit-config.yaml`: Main pre-commit configuration
- `.yamllint`: YAML linting rules (120 char line limit, 2-space indentation)
- `.secrets.baseline`: Baseline for secret detection to avoid false positives

#### Workflow Integration

Pre-commit hooks run automatically on `git commit` and will:
- **Block commits** with YAML syntax errors (preventing Renovate failures)
- **Auto-fix** formatting issues where possible
- **Warn about** potential security issues

The hooks are designed to work with the GitOps workflow and exclude:
- SOPS-encrypted files (`*.sops.yaml`)
- Generated template files
- Age encryption keys
- Log files

### VS Code Integration

The repository includes VS Code workspace configuration that aligns YAML formatting with yamllint standards to prevent conflicts between editor auto-formatting and pre-commit hooks.

#### Configuration Files

- `.vscode/settings.json`: Workspace settings that configure YAML formatting to match yamllint rules
  - 160 character line limit (matching yamllint config)
  - 2-space indentation for YAML files
  - Disables Prettier for YAML files to avoid conflicts
  - Enables format-on-save with RedHat YAML extension
  - Configures Kubernetes and Helm schemas for validation

- `.vscode/extensions.json`: Recommended extensions for optimal development experience
  - `redhat.vscode-yaml`: Primary YAML formatter and validator
  - `ms-kubernetes-tools.vscode-kubernetes-tools`: Kubernetes integration
  - `signageos.signageos-vscode-sops`: SOPS integration
  - `timonwong.shellcheck`: Shell script validation

- `.vscode/tasks.json`: Quick tasks for running linting and validation
  - `Ctrl+Shift+P` > "Run Task" > "Run pre-commit on current file"
  - `Ctrl+Shift+P` > "Run Task" > "Run yamllint on current file"

- `.editorconfig`: Cross-editor configuration ensuring consistent formatting

#### Usage

1. **Install Recommended Extensions**: VS Code will prompt to install recommended extensions when opening the workspace
2. **Automatic Formatting**: Files will auto-format on save according to yamllint rules
3. **Real-time Validation**: YAML errors appear as you type with proper schema validation
4. **Quick Tasks**: Use Command Palette tasks to run validation on current file

This setup prevents the common issue where VS Code formats YAML files in a way that conflicts with pre-commit hooks, ensuring consistency between editor formatting and repository standards.

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
- **DNS**: Split-horizon DNS architecture
  - k8s_gateway (`192.168.13.65`) for internal service discovery
  - external-dns (Cloudflare provider) for `external` ingress class → public DNS
  - external-dns (UniFi webhook) for `internal` ingress class → local LAN DNS
  - Kyverno policy auto-adds `external-dns.alpha.kubernetes.io/target` annotation based on ingress class
  - See docs/services/networking.md for detailed DNS architecture

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

### Direct Manifest Development
This repository uses direct manifest editing:

1. **Edit manifests directly** - Modify YAML files in `kubernetes/` directory
2. **Test changes**: Use `kubectl apply --dry-run` for validation, `task debug` for cluster status
3. **YAML validation**: Use standard YAML validation tools
4. **GitOps workflow**: Commit changes and let Flux handle deployment

### Claude Code Integration
The repository includes automated Claude Code assistance for failed workflows:

**Automatic Failure Detection:**
- Failed PRs are automatically labeled with `🤖 needs-claude-fix` and `🔴 workflow-failed`
- Detailed failure logs and fix suggestions are posted as PR comments
- Filter PRs needing attention: `is:pr label:needs-claude-fix`

**Manual Claude Assistance:**
- Comment `@claude-code <request>` on any PR to get analysis
- Examples: `@claude-code fix shellcheck errors`, `@claude-code analyze flux validation`
- Provides PR context, workflow status, and exact local command to run
- PRs are labeled with `🤖 claude-requested` for tracking

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
- **claude-helper.yaml**: Automatically labels failed PRs and provides Claude Code assistance
- **claude-manual-trigger.yaml**: Manual Claude Code trigger via `@claude-code` PR comments

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
  - Automatic Gatus monitoring via Kyverno policies for both ingress classes
  - Exclude from monitoring: Add annotation `gatus.io/enabled: "false"` or deploy in `test` namespace
  - Customize monitoring: Use `gatus.io/host`, `gatus.io/path`, `gatus.io/name`, `gatus.io/status-code` annotations
- **Storage**: Longhorn for persistent volumes, use StorageClass annotations

### Security Considerations
- **SOPS encryption**: All secrets must be encrypted before commit
- **Image security**: Use specific image tags, avoid `latest`
- **Network policies**: Implement for multi-tenant workloads
- **Resource limits**: Always define requests/limits in HelmReleases

### Common Issues to Avoid
1. **Hardcoded values**: Use consistent values across similar resources
2. **Missing health checks**: Add readiness/liveness probes
3. **No resource limits**: Can cause cluster resource exhaustion
4. **Inconsistent patterns**: Follow established manifest patterns in the repository
5. **Ingress annotation risks**: Be cautious with `allow-snippet-annotations`

## Troubleshooting

### Common Problems
- **YAML syntax errors**: Use `yq` or other YAML validators to check syntax
- **Flux not syncing**: Verify Git repository access and webhook configuration
- **Application startup issues**: Check resource requests vs cluster capacity
- **Secret access failures**: Verify SOPS key and ExternalSecret configuration
- **Talos node issues**: Use `talhelper` commands and check talosconfig validity

For detailed troubleshooting procedures and operational runbooks, see docs/runbooks.md
For disaster recovery scenarios, see docs/dr.md

### Quick Links to Operational Documentation

When working with operational issues, refer to these docs/ files:

**Daily Operations:**
- Cluster monitoring and alerts → docs/monitoring.md
- Application troubleshooting → docs/runbooks.md
- Secret rotation and management → docs/secrets.md
- Backup verification → docs/backups.md

**Infrastructure Changes:**
- Network/DNS modifications → docs/services/networking.md
- Storage operations → docs/services/storage.md
- Security policy updates → docs/services/security.md
- Application deployments → docs/services/applications-*.md

**Emergency Procedures:**
- Disaster recovery → docs/dr.md
- Cluster rebuild → docs/services/cluster-foundation.md
- Flux recovery → docs/services/fluxcd.md
- Node failures → docs/runbooks.md

**Development & Planning:**
- Planned improvements → docs/TODO.md
- Development backlog → docs/WEITERENTWICKLUNG.md
- Change history → docs/CHANGELOG.md

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

For Flux dependency visualization, see docs/flux-dependency-graph.md
For automation and CI/CD details, see docs/automation.md and docs/services/fluxcd.md

### Secret Management Architecture

Multi-layered secret management:

- **SOPS + Age**: Encrypt secrets at rest in Git with `age.key`
- **External Secrets**: Runtime secret injection from 1Password (vault "Homelab")
- **Cert-manager**: Automated TLS certificate management with Let's Encrypt production issuer
- **Ingress TLS**: Default wildcard certificate `${SECRET_DOMAIN/./-}-production-tls`

For detailed procedures, see docs/secrets.md and docs/services/security.md

### Storage Architecture

Distributed storage with multiple backends:

- **Longhorn**: Primary distributed block storage with automated backups and snapshots
- **Synology CSI**: External NAS storage for large datasets via DSM integration
- **Backup Strategy**: K8up (Restic), Velero, and Longhorn's native backup capabilities

For storage operations and backup procedures, see docs/services/storage.md and docs/backups.md

### Monitoring Architecture

Comprehensive observability stack:

- **Metrics**: Prometheus with custom recording rules and federation
- **Visualization**: Grafana with pre-configured dashboards for home automation, systems, and applications
- **Alerting**: Alertmanager with Discord webhook integration
- **Exporters**: Specialized exporters for media stack (Tautulli, *arr apps), SNMP (Synology), and network services
- **Gatus**: Automated endpoint monitoring via Kyverno policies
  - Automatically monitors all Ingresses with `internal` or `external` ingressClassName
  - Exclusions: Ingresses in `test` namespace or with annotation `gatus.io/enabled: "false"`
  - Customization annotations:
    - `gatus.io/host`: Override default host from Ingress spec
    - `gatus.io/path`: Override default path from Ingress spec
    - `gatus.io/name`: Override default endpoint name
    - `gatus.io/status-code`: Override expected HTTP status code (default: 200)
  - Generates ConfigMaps with Gatus endpoint definitions automatically
  - Alerts via Discord webhook on endpoint failures

For detailed monitoring setup and troubleshooting, see docs/monitoring.md and docs/services/observability.md

## Documentation Maintenance Protocol

**CRITICAL: Documentation must be kept current with ALL changes**

When making ANY changes to this repository, you MUST check and update documentation files:

### Required Documentation Review for ALL Changes:

1. **CLAUDE.md** (this file) - Update for:
   - New Tasks, commands, or scripts
   - Architecture changes (networking, storage, etc.)
   - Workflow modifications
   - Tool dependency changes
   - New applications or removed applications
   - Security/secret management changes

2. **docs/** (operational documentation) - Update for:
   - New operational procedures or runbooks (docs/runbooks.md)
   - Service deployments/removals/significant changes (docs/services/*.md)
   - Infrastructure changes affecting operations (docs/monitoring.md, docs/networking.md, docs/storage.md)
   - Backup/disaster recovery procedure updates (docs/backups.md, docs/dr.md)
   - Application configuration changes (docs/services/applications-*.md)
   - Security policy changes (docs/services/security.md)
   - Cluster architecture updates (docs/architecture.png, docs/flux-dependency-graph.md)

3. **README.md** - Update for:
   - Major infrastructure changes
   - New core components or removed components
   - Updated network configuration
   - Changed application lists or categories

4. **scripts/README.md** - Update for:
   - New scripts in scripts/ directory
   - Modified script functionality
   - Changed script dependencies

### Documentation Review Checklist:

**Before ANY commit, ask:**
- [ ] Does this change affect commands/tasks users run?
- [ ] Are new tools, scripts, or workflows introduced?
- [ ] Are applications added, removed, or significantly changed?
- [ ] Do networking, DNS, or ingress configurations change?
- [ ] Are storage classes, backup procedures, or security practices modified?
- [ ] Would a new Claude Code session need this information?

**If YES to any question → Update relevant documentation files FIRST**

### Special Cases Requiring Documentation:
- Adding/removing applications in kubernetes/apps/ → Update CLAUDE.md + docs/services/applications-*.md
- Modifying Taskfile.yaml or .taskfiles/ → Update CLAUDE.md + docs/automation.md
- Changes to networking (IPs, domains, ingress classes) → Update CLAUDE.md + docs/networking.md
- New GitHub Actions workflows → Update CLAUDE.md + docs/automation.md
- Script modifications in scripts/ → Update scripts/README.md + docs/automation.md
- Tool dependency changes in .mise.toml → Update CLAUDE.md
- Security/SOPS/secret management changes → Update CLAUDE.md + docs/secrets.md + docs/services/security.md
- Operational procedures (backup, DR, troubleshooting) → Update docs/runbooks.md, docs/backups.md, docs/dr.md
- Architecture diagrams changes → Update docs/architecture.png, docs/flux-dependency-graph.md

This prevents confusion and ensures future Claude Code sessions have accurate guidance. Always prioritize keeping documentation aligned with the actual repository state.

**Note**: CLAUDE.md serves as guidance for Claude Code sessions, while docs/ serves as operational documentation for humans. Both must be kept in sync where information overlaps.
