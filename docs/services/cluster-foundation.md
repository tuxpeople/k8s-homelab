# Cluster-Fundament (Talos + Core Control Plane)

## Status & Überblick

-   **Status**: Aktiv – Produktion (`admin@turingpi` kubeconfig-Kontext).
-   **OS / Nodes**: Talos Linux (ARM64) auf 4 Nodes (`talos-test01`–`04`) mit kombiniertem Control-Plane-/Worker-Rollenmodell.
-   **Provisioning**: talhelper + `talos/talconfig.yaml`, direkte YAML-Manifeste (keine Templates mehr). Secrets via `talos/talsecret.sops.yaml`.
-   **GitOps**: FluxCD hält sämtliche Manifeste synchron (siehe `docs/services/fluxcd.md`).
-   **Netz**: Node-Netz `192.168.13.0/24`, Cluster API `192.168.13.10`, Pod CIDR `10.42.0.0/16`, Service CIDR `10.43.0.0/16`.
-   **Abhängigkeiten**: erfordert funktionierendes Storage (Longhorn/Synology), Git-Zugriff, Age Keys (SOPS), Cloudflare DNS.

## Node-Inventar

| Node         | CPU        | RAM    | Rolle     | Besonderheiten                      |
| ------------ | ---------- | ------ | --------- | ----------------------------------- |
| talos-test01 | 3.95 cores | 7.1 GB | CP/Worker | Führt Talos API + Flux Controllers. |
| talos-test02 | 3.95 cores | 7.1 GB | CP/Worker | Siehe RESOURCE_ANALYSIS.            |
| talos-test03 | 3.95 cores | 7.0 GB | Worker    | Für stateful workloads bevorzugt.   |
| talos-test04 | 3.95 cores | 7.1 GB | Worker    | Reserve/AZ-Balancing.               |

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
