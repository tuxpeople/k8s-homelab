# Documentation Strategy

This repository follows the **Homelab Layered Documentation Architecture** to keep Kubernetes cluster documentation self-contained while delegating conceptual material to the personal Obsidian vault.

## Complete Strategy

- **Master document**: `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Personal/📚 Wissen/🏠 Persönlich/🎨 Hobbys/Homelab/Documentation Strategy.md`
- In Obsidian use the shortcut `[[Documentation Strategy]]`.

## Quick Reference

### Belongs in this repo

- **Kubernetes Manifests**: All YAML files in `kubernetes/` directory
- **Talos Configuration**: `talos/` directory with cluster configs and patches
- **Deployment Workflows**: Task runner commands, GitHub Actions, Renovate config
- **Technical Runbooks**: Operational procedures (Flux drift, node exchange, volume recovery)
- **Service-specific Documentation**: Individual service configs in `docs/services/`
- **Architecture Diagrams**: Cluster architecture, Flux dependencies (technical view)
- **Secrets Management**: SOPS/Age key workflows, external-secrets integration

### Belongs in Obsidian

- **Cross-System Architecture**: How this cluster integrates with Proxmox, NAS, networking
- **Decision Records**: Why Talos over K3s, why FluxCD, technology choices
- **Application Purpose**: What services run and why they exist (business logic)
- **Service Inventory**: Complete list of apps with their purposes and integrations
- **Disaster Recovery Strategy**: High-level backup philosophy and cross-system dependencies
- **Network Topology**: Complete homelab networking (VLANs, DNS, firewall rules)
- **Future Ideas**: Planned features, architectural improvements, wishlist

### Routing Checklist

```
Is it a Kubernetes manifest, Talos config, or Flux resource?
  → YES: document here (kubernetes/, talos/, docs/)
Is it a command or operational procedure for THIS cluster?
  → YES: document here (docs/runbooks.md, docs/automation.md)
Does it describe what services DO or why they exist?
  → YES: document in Obsidian (Services/, Decisions/)
Does it span multiple infrastructure components (K8s + Proxmox + NAS)?
  → YES: Obsidian (Infrastructure/, Systems/)
Is it a decision record or future planning?
  → YES: Obsidian (Decisions/, Ideas/)
Otherwise: keep it here.
```

## AI Assistant Guidance

### When working in this repo

- Read `CLAUDE.md` first for complete technical context
- Keep scope to Kubernetes cluster operations and GitOps workflows
- Reference Obsidian for higher-level "why" questions and cross-system integration
- Update `docs/` when operational procedures change
- Maintain Swiss German orthography in `docs/` (ss instead of ß)

### When working in Obsidian

- Link back to this repo for implementation details: `file:///Volumes/development/github/tuxpeople/k8s-homelab/`
- Use MCP servers (Kubernetes, Obsidian) for live cluster data
- Avoid duplicating technical runbooks or manifest snippets
- Focus on conceptual integration and decision documentation

## Related Homelab Documentation

**For complete homelab infrastructure documentation**, see Obsidian vault:

**Location:** `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Personal/📚 Wissen/🏠 Persönlich/🎨 Hobbys/Homelab/`

**Key Documents:**
- `README.md` - Homelab Hub and navigation center
- `Services/☸️ Kubernetes Cluster - Talos - Turing Pi.md` - This cluster's overview
- `Infrastructure/` - Cross-system architecture and hardware
- `Operations/` - Backup strategy, disaster recovery, maintenance
- `Decisions/` - Technology choice documentation

## Maintenance

### Update this repo when:
- Kubernetes manifests or Talos configs change
- Operational procedures need revision (runbooks)
- New services are deployed (add to docs/services/)
- Automation workflows are modified

### Update Obsidian when:
- New architectural decisions are made
- Services change purpose or integration points
- Cross-system dependencies are added/removed
- Future ideas need capturing

### Sync Points
- Service inventory: `docs/services/` (technical) ↔️ Obsidian `Services/` (conceptual)
- Architecture: `docs/architecture.png` (cluster) ↔️ Obsidian (homelab-wide)
- Runbooks: `docs/runbooks.md` (procedures) ↔️ Obsidian (lessons learned)

---

**Language Note**: This file is in English for AI assistant guidance. The `docs/` directory uses Swiss German (Schweizer Rechtschreibung) for operational documentation.
