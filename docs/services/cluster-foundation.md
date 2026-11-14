# Cluster-Fundament (Talos + Core Control Plane)

## Status & Überblick

-   **Status**: Aktiv – Produktion (`admin@turingpi` kubeconfig-Kontext).
-   **OS / Nodes**: Talos Linux (ARM64) auf 4 Nodes (`talos-test01`–`04`) mit einer dedizierten Control Plane auf `talos-test04` und drei Workern.
-   **Provisioning**: talhelper + `talos/talconfig.yaml`, direkte YAML-Manifeste (keine Templates mehr). Secrets via `talos/talsecret.sops.yaml`.
-   **GitOps**: FluxCD hält sämtliche Manifeste synchron (siehe `docs/services/fluxcd.md`).
-   **Netz**: Node-Netz `192.168.13.0/24`, Cluster API `192.168.13.10`, Pod CIDR `10.42.0.0/16`, Service CIDR `10.43.0.0/16`.
-   **Abhängigkeiten**: erfordert funktionierendes Storage (democratic-csi/Synology), Git-Zugriff, Age Keys (SOPS), Cloudflare DNS.

## Node-Inventar

| Node         | CPU        | RAM    | Rolle     | Besonderheiten                      |
| ------------ | ---------- | ------ | --------- | ----------------------------------- |
| talos-test01 | 3.95 cores | 7.1 GB | Worker | `/var` auf lokaler SATA-SSD. |
| talos-test02 | 3.95 cores | 7.1 GB | Worker | `/var` auf lokaler SATA-SSD. |
| talos-test03 | 3.95 cores | 7.0 GB | Worker | `/var` auf lokaler SATA-SSD. |
| talos-test04 | 3.95 cores | 7.1 GB | Control Plane | `/var` auf eMMC, `NoSchedule`-Taint; API-VIP und etcd. |

> Siehe `RESOURCE_ANALYSIS.md` für VPA-Empfehlungen; Node-spezifische Labels/taints bitte hier ergänzen.

## Verzeichnis & Artefakte

-   `talos/talconfig.yaml` – Canonical Talos-Clusterdefinition (Versionen, Netz, Secrets, patches).
-   `talos/talenv.yaml` – Versions-Pinning (Talos/Kubernetes) + Plattform-spezifische Settings.
-   `talos/patches/` – MachineConfig-Overlays (z.B. CNI disable, kubelet settings).
-   `talos/clusterconfig/` – Generierte Node-/ControlPlane-Konfigurationen (nicht editieren, aber Offsite sichern).
-   `talos/manifests/` – Zusatz-Manifeste, die Talos während Bootstrap ausrollt.
-   `kubeconfig` – aktueller kubeconfig, enthält Kontext `admin@turingpi`. Zugriff streng schützen.
-   `nodes.sample.yaml`, `cluster.sample.yaml` – Vorlage für zusätzliche Cluster/Nursery-Umgebungen.

## Betriebsaufgaben

Kubelet lädt maximal zwei Images gleichzeitig pro Node
(`maxParallelImagePulls: 2`, `serializeImagePulls: false`), um CPU und eMMC
bei vielen gleichzeitigen Starts zu entlasten. Die Einstellung liegt in
`talos/patches/global/machine-kubelet.yaml`; Änderungen werden mit Talos-Dry-Run
und anschließend nodeweise ohne Reboot angewendet. Ein kurzer Kubelet-Neustart
ist dabei möglich. Siehe [Stabilisierungs-Runbook](../runbooks.md#cm4-langsame-pod-starts-und-helm-retry-schleifen).

SSD-Migration vom 2026-11-13/14: `talos-test01`, `talos-test02` und `talos-test03`
booten weiterhin von eMMC und verwenden für `EPHEMERAL` beziehungsweise `/var`
jeweils die lokale 1-TB-SATA-SSD (`/dev/sda1`). `talos-test04` ist die einzige
dedizierte Control Plane und nutzt eMMC. Talos-Endpunkt: `192.168.13.14:50000`;
die Kubernetes-API bleibt unter der VIP `192.168.13.10:6443`.
Durchführung und iSCSI-/DNS-Tests stehen im [Migrationsprotokoll](../talos-storage-migration.md#ergebnis-von-node-1).

1. **Upgrades**
    - Kubernetes: `task talos:upgrade-k8s` (nutzt Versionen aus `talos/talenv.yaml`).
    - Talos OS: `task talos:upgrade-all-nodes` bzw. `task talos:upgrade-node`.
    - Nachlauf: `flux get ks -A`, `kubectl get nodes`, Dashboards kontrollieren.
2. **Node Lifecycle**
    - Neuer Node: `nodes.sample.yaml` befüllen → `task talos:generate-config` → `task talos:apply-node IP=<...>`.
    - Austausch: `talosctl cordon/drain`, `talosctl reset --graceful`, Hardware tauschen, Konfig anwenden (siehe `docs/runbooks.md` Abschnitt „Talos Node Exchange“).
3. **Maintenance & Access**
    - Cordon/Drain via `talosctl` oder `kubectl` mit `admin@turingpi`.
    - Secrets (Age key, Git deploy key, Talos secrets) lokal und Offsite spiegeln.
4. **Bootstrap / DR**
    - Komplettausfall: `task bootstrap:talos` → `task bootstrap:apps` (siehe `docs/dr.md`).
    - Talos API erreichbar unter `https://<node-ip>:50000`.

## Monitoring & Observability

-   **Metriken**: Node Exporter + Talos health metrics → Grafana Dashboard „Cluster / Control Plane“.
-   **Alerts**: NodeNotReady, Talos Upgrade Pending, Certificate Expiry, Disk/Memory Pressure (Alertmanager → Discord).
-   **Logs**: Talos API logs via `talosctl logs kubelet`; Audit events (falls reaktiviert) unter `archive/apps/observability/*`.
-   **Capacity Tracking**: Goldilocks (namespace `vpa`) liefert Empfehlung; Ergebnisse in `RESOURCE_ANALYSIS.md`.

## Backups & Wiederherstellung

-   `talos/clusterconfig` + `talos/talsecret.sops.yaml` + Age keys → Passwortmanager & Offline Storage.
-   `kubeconfig` (admin context) verschlüsselt speichern.
-   Offsite-Backup der Node images/firmware empfehlenswert.
-   RTO/RPO siehe `docs/dr.md` (Control Plane <4 h, Konfig RPO 1 h via Git history).

## Runbooks & Checks

-   **Talos Drift**: `task talos:node-health` (falls vorhanden) oder `talosctl -n <ip> health`.
-   **Bootstrap Validation**: `kubectl get pods -A`, `flux get ks -A`.
-   **Secret Rotation**: Wenn Age Key rotiert → `task encrypt-secrets`, Talos machine config neu rendern.
-   **Access Review**: Regelmässig prüfen, wer `admin@turingpi` nutzt; kubeconfig rotation planen.

## Offene Punkte / TODO

-   Resource Limits/Requests in System-Namespaces ergänzen (`IMPROVEMENT_PLAN.md` Punkt 1).
-   Architekturdiagramm (Talos ↔ Flux ↔ Ingress ↔ Storage) erstellen (`docs/TODO.md` #1 / Backlog DOC-002).
-   Automatisierte Health-Checks für Talos Upgrades (pre/post) definieren.
