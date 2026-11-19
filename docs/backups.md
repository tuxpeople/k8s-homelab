# Backup- & Restore-Strategie

## Komponenten

-   **Git + Flux** – Kubernetes-Manifeste und Cluster-Zielzustand sind im Repository versioniert.
-   **SOPS/Age + 1Password External Secrets** – Secret-Material liegt verschluesselt im Repo bzw. in 1Password.
-   **democratic-csi/Synology** (`kubernetes/apps/storage/democratic-csi`) – PVCs werden ueber die StorageClass `iscsi-delete` auf Synology iSCSI bereitgestellt.
-   **Snapshot-Controller** (`kubernetes/apps/storage/snapshot-controller`) – CSI Snapshot Controller ist aktiv; democratic-csi stellt `synology-iscsi-snapshots` bereit.
-   **Litestream** – Kontinuierliche SQLite-Datenbank-Replikation in den Bucket `litestream` auf SeaweedFS (`core1`).

Archiviert und nicht Teil des aktiven Restore-Pfads: K8up, Velero, Longhorn und der alte Synology CSI Driver.

## Ziele & Abdeckung

| Ebene | Tool | Frequenz | Speicherort |
| ----- | ---- | -------- | ------------ |
| Cluster-Manifeste | Git + Flux | kontinuierlich bei Commit | GitHub Repository |
| Secrets | SOPS/Age + 1Password | bei Aenderung | Repo verschluesselt + 1Password |
| PVC/App-Daten | Synology/democratic-csi | NAS-/App-spezifisch | Synology iSCSI/NFS |
| SQLite-Datenbanken | Litestream | kontinuierlich, `sync-interval: 10s` | S3-kompatibler Bucket `litestream` |

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
-   Litestream-Fehler (Sidecar-Logs) und wachsende Buckets muessen alarmiert werden.

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
    - Ergebnistabelle oben aktualisieren, Befunde als GitHub Issue erfassen.

## Litestream: SQLite-Replikation

### Übersicht

Litestream läuft als Sidecar bei Paperless, Linkding, FreshRSS, Spoolman,
Python-IPAM, simple-cmdb und dorflade-mhd. Ziel ist der Bucket `litestream`
auf SeaweedFS (`http://core1.server.tdeutsch.ch:8333`, verwaltet in
`homelab-automation`, Rolle `seaweedfs`), ein Pfad pro App. Endpoint und
Zugangsdaten (S3-User `litestream`, darf nur diesen Bucket) kommen für alle
Apps aus dem OpenBao-Secret `k8s/turingpi/_shared/seaweedfs-litestream`
(`LITESTREAM-HOST`, `LITESTREAM-REGION`, `LITESTREAM-ACCESS-KEY`,
`LITESTREAM-ACCESS-SECRET`) über den ClusterSecretStore `openbao-shared`.

Bis 2026-11 lagen die Replicas auf Garage (`thiazi`) bzw. MinIO (`core2`).
Beim Wechsel wurde nichts kopiert: Die Datenbanken liegen auf den PVCs, und
Litestream legt im neuen Bucket beim Start einen frischen Snapshot an.

### Retention

Litestream 0.5 räumt den Bucket selbst auf: Es löscht Snapshots, die älter als
die Snapshot-Retention sind, und danach alle älteren Dateien der unteren
Stufen. Ein externer Cleanup-Job ist nicht nötig (der frühere
`litestream-cleanup`-CronJob wurde entfernt).

Die Felder `retention` und `snapshot-interval` pro Replica stammen aus
Litestream 0.3 und wirken in 0.5 nicht. Es gelten die globalen Defaults
(`snapshot.interval` und `snapshot.retention` je 24h), also etwa ein Tag
Point-in-Time-Historie.

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
- **Bucket-Grösse**: Platz auf `core1` (Alert `NodeFilesystemSpaceLow` in `homelab-automation`)

### Referenzen

- Litestream-Konfiguration: `litestream-configmap.yaml` bzw. `values.yaml` der jeweiligen App
- Application-spezifische Docs: `docs/services/applications-productivity.md`

## Offene ToDos

-   Offsite-Backup-Ziel definieren (Cloud Bucket vs. externes NAS).
-   Automatische Restore-Validierung fuer Synology/democratic-csi und Litestream definieren.
-   Litestream Prometheus-Exporter evaluieren und konfigurieren.
