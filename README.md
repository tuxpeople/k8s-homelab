# 🏠 Personal Kubernetes Homelab

This repository contains the configuration and deployment manifests for my personal Kubernetes homelab cluster, built on Talos Linux with GitOps using FluxCD. The cluster is deployed and actively running on the domain `eighty-three.me`.

## 🏗️ Infrastructure

### Core Components
- **Operating System**: [Talos Linux](https://github.com/siderolabs/talos) - Immutable OS designed for Kubernetes
- **GitOps**: [FluxCD](https://github.com/fluxcd/flux2) - Continuous deployment from Git
- **Networking**: [Cilium](https://github.com/cilium/cilium) with CNI disabled in Talos
- **Storage**:
  - [democratic-csi](https://github.com/democratic-csi/democratic-csi) for Synology iSCSI/NFS volumes
  - [Snapshot Controller](https://github.com/kubernetes-csi/external-snapshotter) for CSI VolumeSnapshots
- **Ingress**: nginx-ingress with internal (`192.168.13.64`) and external (`192.168.13.66`) classes
- **DNS**:
  - [external-dns](https://github.com/kubernetes-sigs/external-dns) with dual providers:
    - Cloudflare for public DNS (`external` ingress class)
    - UniFi webhook for internal LAN DNS (`internal` ingress class)
- **Secrets**: [SOPS](https://github.com/getsops/sops) encryption with Age keys + [external-secrets](https://github.com/external-secrets/external-secrets) with 1Password and Doppler integration
- **Tunnels**: [Cloudflared](https://github.com/cloudflare/cloudflared) for secure public access

### Network Configuration
- **Node Network**: `192.168.13.0/24`
- **Cluster API**: `192.168.13.10`
- **Pod CIDR**: `10.42.0.0/16`
- **Service CIDR**: `10.43.0.0/16`
- **Domain**: `eighty-three.me`

## 📦 Applications

The cluster runs various applications organized by category:

### 🤖 AI/ML
- **Open WebUI** - Web interface for AI models

### 📊 Media
- **Calibre-Web** - eBook library management
- **Tautulli** - Plex statistics and monitoring

### 🛠️ Productivity
- **dorflade-mhd** - Custom product/inventory tracker
- **FreshRSS** - RSS feed reader
- **Hajimari** - Application dashboard
- **Linkding** - Bookmark manager
- **Obsidian** - Note-taking application
- **Paperless** - Document management system

### 📈 Observability
- **Kube Prometheus Stack** - Complete monitoring solution
- **Grafana** - Metrics visualization with custom dashboards
- **Alertmanager Discord** - Discord notifications for alerts
- **Gatus** - Service monitoring
- **Various Exporters** - Custom metrics for media stack

### 🔒 Security
- **Kyverno** - Policy engine for Kubernetes
- **External Secrets** - Secret management (1Password + Doppler)

### 💾 Storage & Backup
- **democratic-csi** - Synology iSCSI/NFS CSI driver
- **Snapshot Controller** - CSI VolumeSnapshot management
- **Litestream Cleanup** - S3 replica housekeeping for Litestream apps

## 🔧 Management Tools

### Configuration Management
This repository uses direct manifest editing for Kubernetes configurations. The cluster has moved beyond template-based generation to direct YAML editing for better simplicity and maintainability.

### Task Runner
All operations are managed through [Task](https://taskfile.dev/) with the `Taskfile.yaml`. Common commands:

```bash
# Core cluster operations

# Bootstrap Talos cluster
task bootstrap:talos

# Bootstrap applications
task bootstrap:apps

# Force Flux reconciliation
task reconcile

# Debug cluster resources
task debug

# Talos node operations
task talos:apply-node IP=<node-ip> MODE=<auto|try|reboot>
task talos:upgrade-node IP=<node-ip>
task talos:upgrade-k8s
```

### Development Environment
Tool dependencies are managed via [mise](https://mise.jdx.dev/):
```bash
mise trust && pip install pipx && mise install
```

## 🔐 Security & Secrets

- **Encryption**: All secrets encrypted with SOPS using Age keys
- **Secret Management**: Integration with 1Password and Doppler via external-secrets operator
- **Certificate Management**: Let's Encrypt certificates via cert-manager
- **Network Security**: Split-horizon DNS and internal/external ingress separation

## 🚀 CI/CD

### GitHub Actions
- **flux-local.yaml** - Validates manifests and shows diffs on PRs
- **mise.yaml** - Tool dependency validation
- **shellcheck.yaml** - Shell script linting

### Renovate
Automated dependency updates for:
- Container images
- Helm charts
- GitHub Actions
- Scheduled for weekend updates with auto-merge for patches

## 🔍 Monitoring & Observability

### Metrics & Alerting
- **Prometheus** - Metrics collection
- **Grafana** - Visualization with custom dashboards for:
  - Home automation (Xiaomi climate)
  - System monitoring (SSH logs)
  - Application metrics (Tautulli, media stack)
- **Discord Integration** - Alert notifications

### Application Monitoring
- **Gatus** - Endpoint monitoring with Kyverno-generated config
- **Custom Exporters** - Tautulli exporter, SNMP (Synology)

## 🏠 Network Integration

### DNS Configuration
Split-horizon DNS setup:
- **Internal**: UniFi external-dns creates DNS records in UniFi Dream Machine for `internal` ingress services
- **External**: Cloudflare external-dns creates public DNS records for `external` ingress services
- **Cluster DNS**: CoreDNS forwards to Pi-hole (10.20.30.11) and UniFi Gateway (192.168.13.1)

### Service Access
- **Internal Services**: Use `internal` ingress class for private network access
- **External Services**: Use `external` ingress class for internet access via Cloudflare Tunnel
- **Service Discovery**: Hajimari dashboard provides centralized access to all services

## 🗄️ Data Management

### Storage Classes
- **democratic-csi (Synology)**: Primary storage via iSCSI/NFS from Synology NAS
- **Local Storage**: Direct node storage for specific use cases

### Backup Strategy
- **Litestream**: SQLite replication to MinIO S3 for stateful apps (Linkding, dorflade-mhd, simple-cmdb)
- **Volume Snapshots**: CSI VolumeSnapshot via snapshot-controller for point-in-time recovery
- **NAS-native**: Synology snapshots/rsync for NFS-mounted data (Paperless, Calibre)

## 📝 Maintenance

### Regular Operations
- **Updates**: Automated via Renovate on weekends
- **Monitoring**: Continuous monitoring via Prometheus/Grafana
- **Backups**: Automated backup schedules with retention policies
- **Security**: Kyverno admission policies enforce resource limits and image standards

### Emergency Procedures
- **Cluster Reset**: `task talos:reset` for emergency cluster rebuilding
- **Node Recovery**: Individual node reset and rejoin procedures
- **Data Recovery**: Volume snapshot restoration and backup recovery

## 📚 Homelab Documentation

**This Kubernetes cluster is PART of a larger homelab infrastructure.**

For complete homelab documentation including cross-system architecture, hardware details, network topology, and decision records, see the Obsidian vault:

**Location:** `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Personal/📚 Wissen/🏠 Persönlich/🎨 Hobbys/Homelab/`

**Key Documents:**
- `README.md` - Homelab Hub and navigation center
- `Services/☸️ Kubernetes Cluster - Talos - Turing Pi.md` - This cluster's overview and integration
- `Infrastructure/` - Cross-system architecture (Proxmox, NAS, networking)
- `Operations/` - Backup strategy, disaster recovery, maintenance schedules
- `Decisions/` - Technology choices and architectural decisions
- `Documentation Strategy.md` - Where information lives (this repo vs. Obsidian)

**Documentation Strategy:** This repository contains technical implementation details (manifests, configs, runbooks). For conceptual architecture, service purposes, and cross-system integration, see the Obsidian vault. Read `docs/documentation_strategy.md` for the complete strategy.

---

This homelab serves as both a production environment for personal services and a learning platform for Kubernetes, GitOps, and modern infrastructure practices.
