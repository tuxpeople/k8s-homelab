---
description: Establish collaborative GitOps workflow and investigate cluster state for k8s-homelab
argument-hint: [scope or directive] - Optional natural language description of investigation focus
---

# Cluster Debug Protocol

**MISSION**: Check Kubernetes events first at each investigation cycle, then systematically
investigate cluster state using read-only operations to identify issues and propose GitOps-based
solutions for the k8s-homelab cluster.

**SCOPE**: $ARGUMENTS

*If no arguments provided, infer investigation scope from recent conversation context.*

## Investigation Priority

1. **Events First** - Always check `kubectl get events --all-namespaces --sort-by='.lastTimestamp' --output=wide`
2. **Follow the Pipeline** - Flux Kustomization → HelmRelease → Pod → Container logs
3. **Use Task Runner** - Leverage existing `task` commands for common operations
4. **Research When Stuck** - Use web search to verify approaches, find latest docs, break assumption cycles
5. **Direct Editing** - Files are edited directly in `kubernetes/` directory
6. **Collaborative** - Present findings, ask questions, propose solutions

## What I Will Do

**Immediate Actions:**

- Check recent Kubernetes events across ALL namespaces using kubectl
- Assess Flux reconciliation status with `flux get` commands
- Use `task debug` for cluster overview
- Identify pod/container issues
- Compare cluster state to GitOps configuration

**Collaboration Mode:**

- Present findings with evidence
- Ask clarifying questions when multiple solutions exist
- Explain tradeoffs of different approaches
- Wait for your approval before making changes

**When Struggling:**

- Stop and step back to question current approach
- Web search for accurate information and latest documentation
- Cross-reference findings to avoid assumption-based cycles
- Verify understanding before continuing

**GitOps Changes Only:**

- Edit manifests directly in `kubernetes/` directory
- Run pre-commit checks if available
- Stop and wait for you to commit/push
- Never modify cluster directly with kubectl apply/patch/delete

## Investigation Flow

```yaml
1. Events: Recent warnings/errors across namespaces
2. Task Debug: Use `task debug` for cluster overview
3. Flux Status: GitRepository, Kustomization, HelmRelease status
4. Resources: Pods, Services, ConfigMaps, Secrets, PVCs
5. Logs: Application and system container logs
6. Network: Ingress, Services, Endpoints (nginx-ingress internal/external)
7. Dependencies: Databases, Longhorn storage, external services
8. Manifests: Check if issue requires manifest modification
```

## Read-Only Operations

**Primary (kubectl commands):**

- `kubectl get events --all-namespaces --sort-by='.lastTimestamp' --output=wide` - Recent events
- `kubectl get pods -A -o wide` - Pod overview across namespaces
- `kubectl describe <resource>` - Detailed resource information
- `kubectl logs -n <namespace> <pod> -c <container> --tail=100` - Container logs
- `kubectl get ingress -A` - Ingress status (internal/external classes)

**Task Runner Operations:**

- `task debug` - Cluster status overview
- `task --list` - Available task commands
- `flux get sources git -A` - Git repository status
- `flux get ks -A` - Kustomization status
- `flux get hr -A` - HelmRelease status
- `flux reconcile kustomization <name> --with-source` - Force reconciliation

**Manifest Operations:**

- Edit Kubernetes manifests directly in `kubernetes/` directory
- Validate YAML syntax with standard tools
- Test changes with `kubectl apply --dry-run`

**PROHIBITED**: apply, delete, patch, edit, scale, or any cluster mutations

## Cluster-Specific Context

**Architecture Knowledge:**
- **Domain**: eighty-three.me
- **Network**: 192.168.13.0/24 (Cluster API: .10, Internal Ingress: .64, External Ingress: .66, DNS: .65)
- **Storage**: Longhorn (primary), Synology CSI (large datasets)
- **Template System**: makejinja with custom delimiters (`#{` `}#` for variables, `#%` `%#` for blocks)
- **Secret Management**: SOPS + Age keys, ExternalSecrets with 1Password

**Application Organization:**
- `kubernetes/apps/` organized by function (ai, media, productivity, observability, etc.)
- Each app typically has: `app/helmrelease.yaml`, `app/kustomization.yaml`, `ks.yaml`

**Common Troubleshooting Areas:**
- Flux reconciliation issues
- Template generation problems
- Secret access failures (SOPS/ExternalSecrets)
- Ingress routing (internal vs external classes)
- Storage issues (Longhorn/Synology)
- Resource limits and requests

## Communication Style

**Default**: Focused and actionable

- Lead with event findings
- Highlight issues with evidence and file references (`path/file.yaml:line`)
- Present solutions with reasoning
- Ask questions when direction needed
- Reference Task commands when applicable

**When Complex**: Educational explanations for learning opportunities

## Session Agreement

This command establishes our collaborative workflow:

1. **Investigation** → I check cluster state starting with events and `task debug`
2. **Analysis** → I identify root causes and propose solutions
3. **Discussion** → We discuss options and agree on approach
4. **Implementation** → I modify manifests directly or suggest task commands
5. **Validation** → I run available validation tasks
6. **Handoff** → You commit/push changes
7. **Next Cycle** → Return to step 1 to verify resolution or identify new issues

## Critical Reminders

- **EVENTS FIRST** - Always start with `kubectl get events --all-namespaces --sort-by='.lastTimestamp'`
- **TEMPLATES NOT GENERATED FILES** - Edit templates in `templates/` directory, then `task configure`
- **TASK RUNNER** - Use existing task commands: `task debug`, `task --list`, flux commands
- **RESEARCH OVER ASSUMPTIONS** - Web search when uncertain, verify approaches
- **COLLABORATIVE** - No unilateral decisions, always discuss
- **GITOPS ONLY** - Never modify cluster directly, only repository files
- **VALIDATE** - Run `task validate-schemas` and other validation tasks
- **REFERENCE** - Use `file.yaml:123` format when citing code locations
- **SCOPE** - Focus on session task but remain open to root causes

## Quick Reference Commands

```bash
# Essential debugging commands
kubectl get events --all-namespaces --sort-by='.lastTimestamp' --output=wide
task debug
flux get ks -A
flux get hr -A

# Application-specific debugging
kubectl get pods -n <namespace> -o wide
kubectl logs -n <namespace> <pod> -f
kubectl describe pod -n <namespace> <pod>

# Manifest validation
kubectl apply --dry-run=client -f manifest.yaml
yq eval . manifest.yaml

# Force Flux reconciliation
flux reconcile kustomization <app-name> --with-source
```
