# Backup- & Restore-Strategie

## Komponenten

-   **K8up** (`kubernetes/apps/storage/k8up`) – CronJob-basierte Restic-Backups Richtung externes Storage.
-   **Velero** (`kubernetes/apps/storage/velero`) – Clusterweite Backups/Restores von Ressourcen & PVCs.
-   **Longhorn** (`kubernetes/apps/storage/longhorn`) – Native Snapshots/Backups von Volumes.
-   **Snapshot-Controller** – Kubernetes CSI Snapshots (Synology + Longhorn).

## Ziele & Abdeckung

| Ebene                | Tool     | Frequenz                               | Speicherort             |
| -------------------- | -------- | -------------------------------------- | ----------------------- |
| Namespace / Workload | K8up     | mind. täglich                          | S3-kompatibler Storage  |
| Cluster-Ressourcen   | Velero   | täglich + vor Upgrades                 | S3-kompatibel           |
| Block Storage        | Longhorn | stündliche Snapshots, tägliche Backups | Synology / externe Disk |

## Betriebsablauf

1. **Policies definieren**: Jede App beschreibt in ihrem Service-Dokument, ob PVC gesichert wird (K8up Schedule) oder nur Snapshots reichen.
2. **Backups überwachen**: `kubectl -n storage get jobs,pods | grep k8up`; Velero Status via `velero backup get` (Task ergänzen?).
3. **Prä-Upgrade Hook**: Vor Talos/K8s/Helm-Upgrades `velero backup create pre-<topic> --include-namespaces ...`.
4. **Restore Tests**:
    - PVC: Mit Longhorn Snapshot → Clone → Test-Pod.
    - Namespace: `velero restore create --from-backup <name> --namespace-mappings old:new`.
    - Restic: `k8up job run --schedule <name> --restore` (siehe K8up-Doku).

## Dokumentationspflicht pro Service

-   Datenklassifizierung (kritisch, wichtig, best-effort).
-   Speicherort (Longhorn, Synology CSI, extern).
-   RPO/RTO-Ziel.
-   Letzter Restore-Test (Datum, Ergebnis, Owner).

## Monitoring & Alerts

-   Prometheus sammelt Longhorn/K8up/Velero-Metriken → Grafana Dashboard "Backups" (TODO: Link hinterlegen).
-   Alertmanager meldet fehlgeschlagene Jobs (Label `severity=warning|critical`).

## Testplan & Protokoll

Regelmässige Restore-Tests sind Pflicht, damit RPO/RTO-Ziele eingehalten werden.

### Testarten

| Test-ID  | Typ                                | Scope                                                  | Frequenz      | Responsible   |
| -------- | ---------------------------------- | ------------------------------------------------------ | ------------- | ------------- |
| BT-LH-01 | Longhorn Snapshot Restore          | Kritische PVC (Paperless, N8N, Overseerr)              | Quartalsweise | Storage Lead  |
| BT-K8-01 | K8up Restic Restore                | Namespace `media` (Restic → temp namespace)            | Halbjährlich  | App Owner     |
| BT-VL-01 | Velero Cluster Restore (teilweise) | Namespace `productivity` (dry-run + selective restore) | Halbjährlich  | Platform Lead |
| BT-DR-01 | Vollständige DR-Übung              | Cold Start (Talos bootstrap + Flux + Restore)          | Jährlich      | Homelab Owner |

### Protokoll

| Datum   | Test-ID  | Ergebnis | Issues / Follow-ups       | Owner |
| ------- | -------- | -------- | ------------------------- | ----- |
| _offen_ | BT-LH-01 | –        | Nächster Termin festlegen | –     |
| _offen_ | BT-K8-01 | –        |                           |       |
| _offen_ | BT-VL-01 | –        |                           |       |
| _offen_ | BT-DR-01 | –        |                           |       |

> Nach jedem Test Ergebnis + Lessons Learned hier eintragen und ggf. `docs/CHANGELOG.md` ergänzen.

### Durchführung

1. **Vorbereiten**:
    - Scope definieren (Namespace, PVC).
    - Test-Namespaces/temporary volumes anlegen (`<name>-restore-test`).
    - Sicherstellen, dass Monitoring-Alerts temporär unterdrückt werden.
2. **Restore starten**:
    - Longhorn: Snapshot → Clone → Test Pod (siehe Runbook `Backup-Tests`).
    - K8up: `k8up job run --schedule <name> --restore --restore-pvc <...>`.
    - Velero: `velero restore create bt-<date> --from-backup <name> --namespace-mappings <ns>:<ns>-restore`.
3. **Validieren**:
    - Anwendungen starten, Smoke Tests durchführen (UI/Login/File integrity).
    - Logs & PodEvents auf Fehler prüfen.
4. **Abräumen**:
    - Test-Namespace/PVC löschen.
    - Snapshot/Restic Restore cleanup.
    - Ergebnistabelle oben aktualisieren, Issues → `WEITERENTWICKLUNG.md` / `IMPROVEMENT_PLAN.md`.

## Offene ToDos

-   Backup-Test-Runbook detaillieren (`WEITERENTWICKLUNG.md` DOC-003).
-   Offsite-Backup-Ziel definieren (Cloud Bucket vs. externes NAS).
-   Automatische Validierung von Velero-Backups (z.B. mittels `velero backup logs <name>` + Alerting).
