# Flux Kustomization Dependency Graph

This document visualizes the dependencies between Flux Kustomizations in the cluster.

**Last Updated:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")

## Dependency Graph

```mermaid
flowchart LR

    %% Node definitions
    ai_open_webui["ai/open-webui"]
    cert_manager_cert_manager["cert-manager/cert-manager"]
    cert_manager_cert_manager_tls["cert-manager/cert-manager-tls"]
    database_postgres_operator["database/postgres-operator"]
    default_bildergallerie["default/bildergallerie"]
    default_echo_server["default/echo-server"]
    default_homepage["default/homepage"]
    media_calibre_web["media/calibre-web"]
    media_mediabox["media/mediabox"]
    media_overseerr["media/overseerr"]
    media_tautulli["media/tautulli"]
    network_cloudflared["network/cloudflared"]
    network_external_external_dns["network/external-external-dns"]
    network_external_ingress_nginx["network/external-ingress-nginx"]
    network_internal_ingress_nginx["network/internal-ingress-nginx"]
    network_python_ipam["network/python-ipam"]
    observability_gatus["observability/gatus"]
    productivity_code_server["productivity/code-server"]
    productivity_freshrss["productivity/freshrss"]
    productivity_hajimari["productivity/hajimari"]
    productivity_linkding["productivity/linkding"]
    productivity_obsidian["productivity/obsidian"]
    productivity_paperless["productivity/paperless"]
    security_external_secrets_operator["security/external-secrets-operator"]
    security_external_secrets_secretstores["security/external-secrets-secretstores"]
    security_kyverno["security/kyverno"]
    security_kyverno_policies["security/kyverno-policies"]
    storage_longhorn["storage/longhorn"]
    storage_snapshot_controller["storage/snapshot-controller"]
    storage_synology_csi["storage/synology-csi"]
    storage_velero["storage/velero"]
    system_upgrade_tuppr["system-upgrade/tuppr"]
    system_upgrade_tuppr_upgrades["system-upgrade/tuppr-upgrades"]
    test_airgapped_tools_updater["test/airgapped-tools-updater"]
    test_keycloak["test/keycloak"]
    test_oauth2_proxy["test/oauth2-proxy"]
    tools_spoolman["tools/spoolman"]
    vpa_goldilocks["vpa/goldilocks"]

    %% Dependencies
    system_upgrade_tuppr --> system_upgrade_tuppr_upgrades
    security_external_secrets_secretstores --> media_overseerr
    security_kyverno_policies --> network_python_ipam
    security_kyverno_policies --> productivity_paperless
    security_kyverno_policies --> database_postgres_operator
    security_kyverno_policies --> productivity_linkding
    security_kyverno_policies --> productivity_obsidian
    security_external_secrets_secretstores --> default_homepage
    security_kyverno_policies --> tools_spoolman
    cert_manager_cert_manager_tls --> network_external_ingress_nginx
    security_kyverno_policies --> productivity_freshrss
    security_kyverno_policies --> vpa_goldilocks
    security_kyverno_policies --> security_external_secrets_secretstores
    storage_longhorn --> media_calibre_web
    security_kyverno_policies --> default_echo_server
    security_external_secrets_secretstores --> tools_spoolman
    security_external_secrets_secretstores --> test_oauth2_proxy
    security_external_secrets_secretstores --> storage_synology_csi
    cert_manager_cert_manager_tls --> network_internal_ingress_nginx
    storage_snapshot_controller --> storage_velero
    storage_longhorn --> productivity_obsidian
    security_external_secrets_secretstores --> productivity_linkding
    cert_manager_cert_manager --> cert_manager_cert_manager_tls
    security_external_secrets_secretstores --> ai_open_webui
    storage_longhorn --> media_tautulli
    security_kyverno_policies --> default_bildergallerie
    security_kyverno_policies --> productivity_code_server
    security_external_secrets_operator --> security_external_secrets_secretstores
    security_external_secrets_secretstores --> test_airgapped_tools_updater
    security_kyverno_policies --> ai_open_webui
    storage_longhorn --> ai_open_webui
    security_external_secrets_secretstores --> test_keycloak
    security_external_secrets_secretstores --> storage_velero
    security_kyverno_policies --> productivity_hajimari
    security_kyverno_policies --> system_upgrade_tuppr
    storage_longhorn --> media_overseerr
    security_kyverno_policies --> media_calibre_web
    security_external_secrets_secretstores --> observability_gatus
    storage_longhorn --> productivity_freshrss
    security_kyverno_policies --> observability_gatus
    security_external_secrets_secretstores --> productivity_freshrss
    security_kyverno_policies --> default_homepage
    network_external_external_dns --> network_cloudflared
    storage_longhorn --> productivity_linkding
    security_kyverno_policies --> storage_longhorn
    security_kyverno --> security_kyverno_policies
    storage_longhorn --> productivity_code_server
    security_kyverno_policies --> media_overseerr
    security_kyverno_policies --> media_mediabox
    security_kyverno_policies --> media_tautulli
```

## Legend

- **Nodes**: Flux Kustomizations (labeled with namespace/name)
- **Arrows**: Dependency relationships (A --> B means B depends on A)

## Statistics

- **Total Kustomizations**: 52
- **Kustomizations with Dependencies**: 38
- **Total Dependencies**: 52

## Common Dependency Targets

The most common dependencies across all Kustomizations:

| Dependency | Dependent Count |
|------------|-----------------|
| `security/kyverno-policies` | 22 |
| `security/external-secrets-secretstores` | 12 |
| `storage/longhorn` | 8 |
| `cert-manager/cert-manager-tls` | 2 |
| `system-upgrade/tuppr` | 1 |
| `storage/snapshot-controller` | 1 |
| `security/kyverno` | 1 |
| `security/external-secrets-operator` | 1 |
| `network/external-external-dns` | 1 |
| `cert-manager/cert-manager` | 1 |

---

## Alternative Visualizations

### Graphviz/DOT Format

An alternative visualization using Graphviz DOT format is available:
- **DOT Source**: `docs/flux-dependencies.dot`
- **PNG Image**: `docs/flux-dependencies.png`

This visualization uses left-to-right layout (rankdir=LR) which can be easier to read for complex dependency chains.

#### Generating DOT Format Dependencies

**Automated Method (Recommended)**:

```bash
# Generate both DOT and PNG files automatically
./scripts/generate-flux-dependencies.sh
```

This script will:
- Fetch current Flux Kustomizations from the cluster
- Generate `docs/flux-dependencies.dot`
- Automatically create `docs/flux-dependencies.png` (if Graphviz is installed)
- Show helpful error messages if dependencies are missing

**Requirements**:
- Python 3
- kubectl with cluster access
- Graphviz (optional, for PNG generation)
  - macOS: `brew install graphviz`
  - Linux: `apt-get install graphviz`

**Manual Method**:

If you need more control or want to customize the graph:

```bash
# 1. Generate DOT file manually
kubectl get kustomizations.kustomize.toolkit.fluxcd.io -A -o yaml | \
  python3 scripts/generate-flux-dot.py > docs/flux-dependencies.dot

# 2. Convert to PNG
dot -Tpng docs/flux-dependencies.dot -o docs/flux-dependencies.png
```

**Alternative: Online Converter**:
- Visit https://dreampuf.github.io/GraphvizOnline/
- Paste contents of `docs/flux-dependencies.dot`
- Export as PNG

**Note**: The DOT format visualization may differ from the Mermaid diagram above as it uses a different layout algorithm and may include different dependency details.

**Scripts**:
- `scripts/generate-flux-dot.py` - Core Python script for DOT generation
- `scripts/generate-flux-dependencies.sh` - Automated wrapper script

---

*Mermaid graph is automatically generated by `scripts/generate-flux-dependency-graph.sh`*

*To regenerate: `./scripts/generate-flux-dependency-graph.sh`*
