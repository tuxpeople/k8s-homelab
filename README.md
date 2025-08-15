# 🏠 Personal Kubernetes Homelab

This repository contains the configuration and deployment manifests for my personal Kubernetes homelab cluster, built on Talos Linux with GitOps using FluxCD. The cluster is deployed and actively running on the domain `eighty-three.me`.

## 🏗️ Infrastructure

### Core Components
- **Operating System**: [Talos Linux](https://github.com/siderolabs/talos) - Immutable OS designed for Kubernetes
- **GitOps**: [FluxCD](https://github.com/fluxcd/flux2) - Continuous deployment from Git
- **Networking**: [Cilium](https://github.com/cilium/cilium) with CNI disabled in Talos
- **Storage**: 
  - [Longhorn](https://github.com/longhorn/longhorn) for distributed block storage
  - [Synology CSI](https://github.com/SynologyOpenSource/synology-csi) for external NAS storage
- **Ingress**: nginx-ingress with internal (`192.168.13.64`) and external (`192.168.13.66`) classes
- **DNS**: 
  - [k8s_gateway](https://github.com/ori-edge/k8s_gateway) for internal DNS (`192.168.13.65`)
  - [external-dns](https://github.com/kubernetes-sigs/external-dns) for public DNS via Cloudflare
- **Secrets**: [SOPS](https://github.com/getsops/sops) encryption with Age keys + [external-secrets](https://github.com/external-secrets/external-secrets) with 1Password integration
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
- **LibreChat2** - AI chat interface
- **Open WebUI** - Web interface for AI models
- **Ollama** - Local LLM runtime

### 📊 Media
- **Overseerr** - Media request management
- **Tautulli** - Plex statistics and monitoring
- **Mediabox** - Complete *arr stack with ingress configurations

### 🛠️ Productivity
- **Code Server** - VS Code in the browser
- **FreshRSS** - RSS feed reader
- **Hajimari** - Application dashboard
- **Linkding** - Bookmark manager
- **N8N** - Workflow automation
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
- **External Secrets** - Secret management integration
- **Trivy Operator** - Vulnerability scanning

### 💾 Storage & Backup
- **K8up** - Backup operator using Restic
- **Velero** - Kubernetes backup solution
- **Snapshot Controller** - Volume snapshot management

## 🔧 Management Tools

### Template System
This repository uses [makejinja](https://github.com/mirkolenz/makejinja) to generate Kubernetes and Talos configurations from Jinja2 templates. Configuration is driven by:
- `cluster.yaml` - Main cluster configuration
- `nodes.yaml` - Node-specific settings (not present in this deployment)

### Task Runner
All operations are managed through [Task](https://taskfile.dev/) with the `Taskfile.yaml`. Common commands:

```bash
# Generate all configuration files
task configure

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
- **Secret Management**: Integration with 1Password via external-secrets operator
- **Certificate Management**: Let's Encrypt certificates via cert-manager
- **Network Security**: Split-horizon DNS and internal/external ingress separation

## 🚀 CI/CD

### GitHub Actions
- **flux-local.yaml** - Validates manifests and shows diffs on PRs
- **e2e.yaml** - End-to-end testing of template generation
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
- **Blackbox Exporter** - External service monitoring
- **Custom Exporters** - Specialized metrics for:
  - Media applications (Plex, Tautulli, Sonarr, Radarr, etc.)
  - Network services (SNMP for Synology)
  - Speed testing

## 🏠 Network Integration

### DNS Configuration
Split-horizon DNS setup:
- **Internal**: k8s_gateway provides DNS resolution for cluster services
- **External**: Cloudflare DNS for public services
- **Home DNS**: Configure your router/Pi-hole to forward `eighty-three.me` queries to `192.168.13.65`

### Service Access
- **Internal Services**: Use `internal` ingress class for private network access
- **External Services**: Use `external` ingress class for internet access via Cloudflare Tunnel
- **Service Discovery**: Hajimari dashboard provides centralized access to all services

## 🗄️ Data Management

### Storage Classes
- **Longhorn**: Default distributed storage for most workloads
- **Synology CSI**: External NAS storage for large datasets
- **Local Storage**: Direct node storage for specific use cases

### Backup Strategy
- **K8up**: Regular backups to external storage
- **Velero**: Kubernetes-native backup solution
- **Longhorn**: Built-in backup and snapshot capabilities
- **Volume Snapshots**: Point-in-time volume recovery

## 📝 Maintenance

### Regular Operations
- **Updates**: Automated via Renovate on weekends
- **Monitoring**: Continuous monitoring via Prometheus/Grafana
- **Backups**: Automated backup schedules with retention policies
- **Security**: Regular vulnerability scans via Trivy

### Emergency Procedures
- **Cluster Reset**: `task talos:reset` for emergency cluster rebuilding
- **Node Recovery**: Individual node reset and rejoin procedures
- **Data Recovery**: Volume snapshot restoration and backup recovery

---

This homelab serves as both a production environment for personal services and a learning platform for Kubernetes, GitOps, and modern infrastructure practices.