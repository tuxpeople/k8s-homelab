# Scripts Directory

This directory contains operational scripts for managing the Kubernetes homelab cluster built on Talos Linux.

## Common Library

### `lib/common.sh`
Shared utility library providing standardized logging, error handling, and dependency checking.

**Features:**
- Structured logging with levels (debug, info, warn, error)
- Colored output with timestamps
- Environment variable validation (`check_env`)
- CLI tool dependency checking (`check_cli`)
- Configurable log levels via `LOG_LEVEL` environment variable

**Usage:**
```bash
source "$(dirname "${0}")/lib/common.sh"
log info "Starting process" "component=backup"
check_cli kubectl jq
```

## Core Operational Scripts

### `bootstrap-apps.sh`
Bootstraps the cluster applications after Talos installation.

**Purpose:** Applies namespaces, SOPS secrets, CRDs, and Helm releases in the correct order
**Usage:** `./bootstrap-apps.sh`
**Dependencies:** helmfile, kubectl, kustomize, sops, talhelper, yq

### `redo_cluster.sh`
Complete cluster reset and redeployment script.

**Purpose:** Safely destroys the entire cluster and rebuilds it from scratch
**Usage:** `./redo_cluster.sh`
**Safety:** Includes confirmation prompts and comprehensive error checking
**Dependencies:** task, kubectl

## Backup and Storage Scripts

### `backup-checksh.sh`
Validates Longhorn backup freshness across all volumes.

**Purpose:** Checks if all volumes have recent backups (within 24 hours)
**Usage:** `./backup-checksh.sh`
**Output:** Reports backup status for each volume with timestamps
**Dependencies:** kubectl, jq

### `view_backups.sh`
Displays formatted Longhorn backup information.

**Purpose:** Shows tabular view of all backups with metadata
**Usage:** `./view_backups.sh`
**Output:** Table with Namespace, BackupName, PVName, PVCName, SnapshotCreatedAt
**Dependencies:** kubectl, jq, column

### `restore-pv.py`
Python script for restoring persistent volumes from Longhorn backups.

**Purpose:** Automates PV restoration process
**Usage:** `python restore-pv.py <backup-name>`
**Dependencies:** Python, kubectl access

## Security and Secrets

### `missing-secrets.sh`
Identifies referenced secrets that aren't defined in SOPS files.

**Purpose:** Validates that all `${SECRET_*}` references have corresponding definitions
**Usage:** `./missing-secrets.sh`
**Output:** Lists any missing secret definitions
**Dependencies:** grep, awk, sort, comm

## Development and Conversion Scripts

### `add_yaml_schema.sh`
Adds YAML schema headers to Kubernetes manifests.

**Purpose:** Enables IDE validation for Kubernetes resources
**Usage:** `./add_yaml_schema.sh`
**Target:** Files in `kubernetes/` directory

### `convert-app-template.sh`
Converts app-template HelmReleases to use external values files.

**Purpose:** Migrates inline values to separate values.yaml files with schema validation
**Usage:** `./convert-app-template.sh`
**Result:** Creates values.yaml files and updates kustomization.yaml/helmrelease.yaml

### `check-app-template-conversion.sh`
Verifies successful app-template conversions.

**Purpose:** Validates that conversions were completed correctly
**Usage:** `./check-app-template-conversion.sh`
**Output:** Shows conversion status for each application

### `fix-missing-configmaps.sh`
Repairs missing configMapGenerator entries in kustomization files.

**Purpose:** Fixes kustomization.yaml files that are missing configMapGenerator sections
**Usage:** `./fix-missing-configmaps.sh`

### `rebuild-kustomizations.sh`
Regenerates kustomization.yaml files for applications.

**Purpose:** Rebuilds kustomization manifests with proper resource references
**Usage:** `./rebuild-kustomizations.sh`

## Documentation and Visualization Scripts

### `generate-flux-dependencies.sh`
Automated Flux Kustomization dependency graph generator.

**Purpose:** Generates DOT and PNG visualizations of Flux Kustomization dependencies
**Usage:** `./generate-flux-dependencies.sh`
**Output:**
- `docs/flux-dependencies.dot` - Graphviz DOT format
- `docs/flux-dependencies.png` - PNG visualization (requires Graphviz)
**Dependencies:** kubectl, Python 3, Graphviz (optional)
**Features:**
- Automatic cluster connection verification
- Generates both DOT and PNG formats
- Helpful error messages for missing dependencies
- Shows file sizes after generation

**Note:** This script uses `generate-flux-dot.py` internally.

### `generate-flux-dot.py`
Core Python script for generating Flux dependency graphs in DOT format.

**Purpose:** Converts Flux Kustomizations to Graphviz DOT format
**Usage:** `kubectl get kustomizations.kustomize.toolkit.fluxcd.io -A -o yaml | python3 generate-flux-dot.py`
**Output:** DOT format graph to stdout
**Dependencies:** Python 3, kubectl
**Source:** Based on https://gist.github.com/darinc/1c02d567b059b26bc0ab491be60d45da

**Note:** Typically used via the `generate-flux-dependencies.sh` wrapper script.

### `generate-flux-dependency-graph.sh`
Generates Flux dependency visualization in Mermaid format.

**Purpose:** Creates Mermaid flowchart of Flux dependencies for `docs/flux-dependency-graph.md`
**Usage:** `./generate-flux-dependency-graph.sh`
**Output:** Updates `docs/flux-dependency-graph.md` with Mermaid diagram
**Dependencies:** kubectl, Python 3

**Note:** This generates a different format (Mermaid) compared to `generate-flux-dependencies.sh` (DOT/Graphviz).

## Maintenance Scripts

### `ensure-yaml-separator.sh`
Ensures all YAML files start with `---` separator.

**Purpose:** Standardizes YAML file format across the repository
**Usage:** `./ensure-yaml-separator.sh [directory]`
**Default:** Operates on `kubernetes/` directory
**Dependencies:** find, head, gsed

### `nsenter-talos.sh`
Creates privileged debug pods for Talos node access.

**Purpose:** Provides shell access to Talos nodes for troubleshooting
**Usage:** `./nsenter-talos.sh <node-name>`
**Security:** Creates privileged pods with full host access
**Dependencies:** kubectl

**Examples:**
```bash
./nsenter-talos.sh control-01
./nsenter-talos.sh worker-02
```

## Cluster Management Scripts

### `validate-cluster.sh`
Comprehensive cluster health validation.

**Purpose:** Performs health checks on cluster components and applications
**Usage:** `./validate-cluster.sh`
**Checks:** Node status, pod health, Flux status, critical services

### `emergency-shutdown.sh`
Safe cluster shutdown procedure.

**Purpose:** Gracefully shuts down cluster services in proper order
**Usage:** `./emergency-shutdown.sh`
**Safety:** Includes confirmation and progress tracking

### `troubleshoot.sh`
Common debugging commands and diagnostics.

**Purpose:** Provides quick access to troubleshooting information
**Usage:** `./troubleshoot.sh [component]`
**Components:** flux, storage, network, apps

## Script Development Standards

All scripts follow these standards:

### Header Template
```bash
#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${0}")/lib/common.sh"

function main() {
    check_cli <required_tools>
    # Script logic here
}

main "$@"
```

### Error Handling
- Use `set -euo pipefail` for strict error handling
- Leverage `common.sh` logging functions
- Validate inputs and dependencies
- Provide clear error messages

### Logging
- Use structured logging via `common.sh`
- Include relevant context in log messages
- Separate informational and error output
- Support configurable log levels

### Documentation
- Include usage information and examples
- Document all dependencies
- Explain security implications for privileged operations
- Provide clear success/failure indicators

## Dependencies

### Required Tools
Most scripts require these tools available via `mise`:
- `kubectl` - Kubernetes CLI
- `jq` - JSON processor
- `yq` - YAML processor
- `helmfile` - Helm deployment tool
- `sops` - Secret encryption
- `flux` - GitOps toolkit

### Platform Requirements
- macOS/Linux environment
- Access to Kubernetes cluster
- Appropriate RBAC permissions
- SOPS decryption keys (for secret operations)

## Security Considerations

### Privileged Operations
- `nsenter-talos.sh` creates privileged pods
- `redo_cluster.sh` performs destructive operations
- Backup scripts may access sensitive data

### Secret Handling
- Never log secret values
- Use SOPS for encryption at rest
- Validate secret references before deployment
- Rotate secrets regularly

### Access Control
- Scripts assume cluster-admin privileges
- Some operations require SOPS decryption keys
- Review permissions before running in production

## Troubleshooting

### Common Issues

**Permission Errors:**
```bash
# Ensure kubectl context is correct
kubectl config current-context

# Verify cluster access
kubectl get nodes
```

**SOPS Errors:**
```bash
# Check age key is available
ls -la ~/.config/sops/age/keys.txt

# Verify SOPS can decrypt
sops -d kubernetes/components/common/cluster-secrets.sops.yaml
```

**Tool Dependencies:**
```bash
# Install missing tools
mise install

# Verify tool availability
which kubectl jq yq
```

### Log Levels
Control script verbosity:
```bash
# Debug output
LOG_LEVEL=debug ./script.sh

# Quiet operation
LOG_LEVEL=error ./script.sh
```

## Contributing

When adding new scripts:

1. Follow the standard header template
2. Use `lib/common.sh` for logging and validation
3. Include comprehensive error handling
4. Add documentation to this README
5. Test thoroughly in development environment
6. Consider security implications
