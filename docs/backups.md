# Backup- & Restore-Strategie

## Komponenten

-   **K8up** (`kubernetes/apps/storage/k8up`) – CronJob-basierte Restic-Backups Richtung externes Storage.
-   **Velero** (`kubernetes/apps/storage/velero`) – Clusterweite Backups/Restores von Ressourcen & PVCs.
-   **Longhorn** (`kubernetes/apps/storage/longhorn`) – Native Snapshots/Backups von Volumes.
-   **Snapshot-Controller** – Kubernetes CSI Snapshots (Synology + Longhorn).
-   **Litestream** – Kontinuierliche SQLite-Datenbank-Replikation zu S3/MinIO (Paperless, Linkding).

## Ziele & Abdeckung

| Ebene                | Tool       | Frequenz                               | Speicherort             |
| -------------------- | ---------- | -------------------------------------- | ----------------------- |
| Namespace / Workload | K8up       | mind. täglich                          | S3-kompatibler Storage  |
| Cluster-Ressourcen   | Velero     | täglich + vor Upgrades                 | S3-kompatibel           |
| Block Storage        | Longhorn   | stündliche Snapshots, tägliche Backups | Synology / externe Disk |
| SQLite-Datenbanken   | Litestream | kontinuierlich (10s sync)              | MinIO (S3-kompatibel)   |

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

## Litestream: SQLite-Replikation & MinIO Lifecycle

### Übersicht

Litestream wird für kontinuierliche SQLite-Datenbank-Backups verwendet bei:
- **Paperless** (`kubernetes/apps/productivity/paperless`)
- **Linkding** (`kubernetes/apps/productivity/linkding`)
- **Spoolman** (`kubernetes/apps/tools/spoolman`)
- **Python-IPAM** (`kubernetes/apps/network/internal/python-ipam`)

### Architektur

- **Sidecar-Container**: Litestream läuft neben der Hauptanwendung
- **Sync-Intervall**: 10 Sekunden
- **Snapshot-Intervall**: 1 Stunde (verhindert lokale WAL-Akkumulation)
- **Retention**: 168h (7 Tage) in Litestream-Konfiguration
- **Ziel**: MinIO Bucket `litestream` (S3-kompatibel)

### Bekanntes Problem: Lokales WAL-Verzeichnis wächst stark

**Problem**: Ohne `snapshot-interval` sammelt Litestream WAL-Dateien (Write-Ahead Log) im lokalen Pod-Verzeichnis `.db.sqlite3-litestream/` an, was zu sehr grossem Speicherverbrauch führt.

**Symptome**:
- `/data/.db.sqlite3-litestream/` verbraucht 10+ GB lokalen Speicher
- Lokaler Speicher füllt sich schneller als erwartet
- PVC wird unerwartet voll

**Lösung**: `snapshot-interval: 1h` in Litestream-Konfiguration hinzufügen

```yaml
replicas:
  - name: minio
    retention: 168h
    snapshot-interval: 1h  # Regelmässige Snapshots → bereinigt lokale WALs
    validation-interval: 24h
    sync-interval: 10s
```

**Auswirkung**:
- Litestream erstellt stündlich Snapshots
- Alte lokale WAL-Dateien werden nach Snapshot-Erstellung aufgeräumt
- Lokaler Speicherverbrauch bleibt unter 1GB

**Angewandt auf**:
- Paperless: `kubernetes/apps/productivity/paperless/app/litestream-configmap.yaml`
- Linkding: `kubernetes/apps/productivity/linkding/app/values.yaml`
- Spoolman: `kubernetes/apps/tools/spoolman/app/values.yaml`
- Python-IPAM: `kubernetes/apps/network/internal/python-ipam/litestream-configmap.yaml`

### Bekanntes Problem: Generation Cleanup (S3-Speicher)

**Problem**: Litestream's `retention: 168h` löscht nur Snapshots **innerhalb** einer Generation, aber **nicht** alte Generationen selbst. Dies führt zu einem kontinuierlich wachsenden MinIO Bucket.

**Symptome**:
- MinIO Bucket `litestream` füllt sich kontinuierlich
- Alte Generationen (0000, 0001, 0002, ...) bleiben dauerhaft bestehen
- Manuelle Bucket-Bereinigung wird notwendig

**Lösung**: Kubernetes CronJob für automatisches Cleanup (Garage unterstützt kein ILM)

Da Garage keine vollständige Lifecycle-Management-Unterstützung hat, verwenden wir einen **Kubernetes CronJob** zum automatischen Cleanup:

```yaml
# kubernetes/apps/storage/litestream-cleanup/
# Läuft sonntags um 2 Uhr, bereinigt das gesamte litestream Bucket
```

**Konfiguration**:
- **Schedule**: Sonntags 2 Uhr (`0 2 * * 0`)
- **Retention**: 7 Tage (konfigurierbar via `RETENTION_DAYS`)
- **Scope**: Gesamtes `garage/litestream/` Bucket (alle Apps)

**Manuelle Bereinigung** (falls notwendig):
```bash
mc rm --recursive --force --older-than 7d garage/litestream/
```

### Verifikation & Wartung

```bash
# Bucket-Grösse überwachen
mc du garage/litestream

# CronJob Logs anzeigen
kubectl -n storage logs -l app.kubernetes.io/name=litestream-cleanup --tail=100

# Letzte CronJob-Ausführungen prüfen
kubectl -n storage get cronjobs litestream-cleanup-main
kubectl -n storage get jobs -l app.kubernetes.io/name=litestream-cleanup

# CronJob manuell triggern (für Tests)
kubectl -n storage create job --from=cronjob/litestream-cleanup-main litestream-cleanup-manual-$(date +%s)
```

### Restore-Prozedur

Litestream-Backups werden automatisch via Init-Container wiederhergestellt:

```yaml
initContainers:
  01-litestream-restore:
    args: ["restore", "-if-db-not-exists", "-if-replica-exists", "/data/db.sqlite3"]
```

**Manuelle Wiederherstellung**:
```bash
# In Pod einsteigen
kubectl exec -it -n productivity paperless-app-xyz -c litestream -- sh

# Restore durchführen
litestream restore -config /etc/litestream.yml /data/db.sqlite3
```

### Monitoring

- **Alert bei Litestream-Fehlern**: Container-Logs überwachen (`stderr`)
- **Garage Bucket-Grösse**: Alert bei >80% Kapazität (`mc du garage/litestream`)
- **CronJob-Failures**: Alert bei fehlgeschlagenen Cleanup-Jobs (`kubectl get jobs`)
- **Generationen-Count**: Periodisch prüfen, dass alte Generationen gelöscht werden

**Prometheus-Metriken** (TODO):
- `litestream_replication_lag_seconds`
- `litestream_backup_size_bytes`

### Referenzen

- Litestream-Konfiguration: `kubernetes/apps/productivity/*/app/litestream-configmap.yaml`
- Cleanup CronJob: `kubernetes/apps/storage/litestream-cleanup/`
- Application-spezifische Docs: `docs/services/applications-productivity.md`
- Garage S3 Compatibility: https://garagehq.deuxfleurs.fr/documentation/reference-manual/s3-compatibility/

## Offene ToDos

-   Backup-Test-Runbook detaillieren (`WEITERENTWICKLUNG.md` DOC-003).
-   Offsite-Backup-Ziel definieren (Cloud Bucket vs. externes NAS).
-   Automatische Validierung von Velero-Backups (z.B. mittels `velero backup logs <name>` + Alerting).
-   Litestream Prometheus-Exporter evaluieren und konfigurieren.
