# Backup- & Restore-Strategie

## Komponenten

-   **Git + Flux** – Kubernetes-Manifeste und Cluster-Zielzustand sind im Repository versioniert.
-   **SOPS/Age + 1Password External Secrets** – Secret-Material liegt verschluesselt im Repo bzw. in 1Password.
-   **democratic-csi/Synology** (`kubernetes/apps/storage/democratic-csi`) – PVCs werden ueber die StorageClass `iscsi-delete` auf Synology iSCSI bereitgestellt.
-   **Snapshot-Controller** (`kubernetes/apps/storage/snapshot-controller`) – CSI Snapshot Controller ist aktiv; die aktuellen Longhorn SnapshotClasses sind ein Cleanup-Gap.
-   **Litestream** – Kontinuierliche SQLite-Datenbank-Replikation zu S3/MinIO bzw. Garage-kompatiblem Storage.
-   **Litestream Cleanup** (`kubernetes/apps/storage/litestream-cleanup`) – Bucket-Retention fuer alte Litestream-Generationen.

Archiviert und nicht Teil des aktiven Restore-Pfads: K8up, Velero, Longhorn und der alte Synology CSI Driver.

## Ziele & Abdeckung

| Ebene | Tool | Frequenz | Speicherort |
| ----- | ---- | -------- | ------------ |
| Cluster-Manifeste | Git + Flux | kontinuierlich bei Commit | GitHub Repository |
| Secrets | SOPS/Age + 1Password | bei Aenderung | Repo verschluesselt + 1Password |
| PVC/App-Daten | Synology/democratic-csi | NAS-/App-spezifisch | Synology iSCSI/NFS |
| SQLite-Datenbanken | Litestream | kontinuierlich, `sync-interval: 10s` | S3-kompatibler Bucket `litestream` |
| Litestream Retention | litestream-cleanup CronJob | sonntags 02:00 | Bucket Cleanup |

## Betriebsablauf

1. **Policies definieren**: Jede App beschreibt Datenklassifizierung, PVCs, Litestream-Nutzung und Restore-Ziel.
2. **Storage ueberwachen**: `kubectl get pvc -A`, democratic-csi Pods und Synology/NAS-Status pruefen.
3. **Prae-Upgrade Check**: Vor Talos/K8s/Helm-Upgrades sicherstellen, dass Git sauber ist, Flux synchron ist und kritische SQLite-Apps aktuelle Litestream-Replikation haben.
4. **Restore Tests**:
    - GitOps: Namespace/App aus Git in Test-Umgebung oder temporaeren Namespace wiederherstellen.
    - PVC: Synology/democratic-csi Volume oder App-Daten in Test-PVC validieren.
    - SQLite: Litestream Restore in leerem Test-PVC bzw. InitContainer-Pfad ausfuehren.

## Dokumentationspflicht pro Service

-   Datenklassifizierung (kritisch, wichtig, best-effort).
-   Speicherort (democratic-csi/Synology, Litestream Bucket, extern).
-   RPO/RTO-Ziel.
-   Letzter Restore-Test (Datum, Ergebnis, Owner).

## Monitoring & Alerts

-   Gatus und der Observability-Stack pruefen App-Verfuegbarkeit, PVC-Fuellstand und Job-Fehler.
-   Fehlgeschlagene Litestream-Cleanup-Jobs und wachsende Buckets muessen alarmiert werden.

## Testplan & Protokoll

Regelmässige Restore-Tests sind Pflicht, damit RPO/RTO-Ziele eingehalten werden.

### Testarten

| Test-ID | Typ | Scope | Frequenz | Responsible |
| ------- | --- | ----- | -------- | ----------- |
| BT-SYN-01 | Synology/democratic-csi Restore | Kritische PVC in temporaeres Test-PVC | Quartalsweise | Storage Lead |
| BT-LS-01 | Litestream Restore | SQLite Apps wie Paperless, Linkding, Spoolman, Python-IPAM | Quartalsweise | App Owner |
| BT-GIT-01 | GitOps Namespace Restore | Namespace/App aus Git in Test-Scope | Halbjaehrlich | Platform Lead |
| BT-DR-01 | Vollstaendige DR-Uebung | Cold Start mit Talos bootstrap, Flux und App-Restore | Jaehrlich | Homelab Owner |

### Protokoll

| Datum   | Test-ID  | Ergebnis | Issues / Follow-ups       | Owner |
| ------- | -------- | -------- | ------------------------- | ----- |
| _offen_ | BT-SYN-01 | –        | Nächster Termin festlegen | –     |
| _offen_ | BT-LS-01 | –        |                           |       |
| _offen_ | BT-GIT-01 | –        |                           |       |
| _offen_ | BT-DR-01 | –        |                           |       |

> Nach jedem Test Ergebnis + Lessons Learned hier eintragen und ggf. `docs/CHANGELOG.md` ergänzen.

### Durchführung

1. **Vorbereiten**:
    - Scope definieren (Namespace, PVC).
    - Test-Namespaces/temporary volumes anlegen (`<name>-restore-test`).
    - Sicherstellen, dass Monitoring-Alerts temporär unterdrückt werden.
2. **Restore starten**:
    - Synology/democratic-csi: Volume/PVC in Test-Scope bereitstellen und Datenintegritaet pruefen.
    - Litestream: Restore in leeres Test-PVC oder ueber den vorhandenen InitContainer-Pfad ausfuehren.
    - GitOps: Kustomization in temporaerem Scope anwenden und Flux/Gatus-Signale pruefen.
3. **Validieren**:
    - Anwendungen starten, Smoke Tests durchführen (UI/Login/File integrity).
    - Logs & PodEvents auf Fehler prüfen.
4. **Abräumen**:
    - Test-Namespace/PVC löschen.
    - Test-Volumes, Litestream-Testdaten und temporaere Kustomizations bereinigen.
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
-   Automatische Restore-Validierung fuer Synology/democratic-csi und Litestream definieren.
-   Litestream Prometheus-Exporter evaluieren und konfigurieren.
