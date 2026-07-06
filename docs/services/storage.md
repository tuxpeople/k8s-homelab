# Storage & Backup Services

## Storage Layer

| Service             | Namespace | Pfad                                          | Status | Beschreibung / Hinweise |
| ------------------- | --------- | --------------------------------------------- | ------ | ----------------------- |
| Democratic CSI      | storage   | `kubernetes/apps/storage/democratic-csi`      | Aktiv  | iSCSI Driver fuer Synology. Stellt die StorageClass `iscsi-delete` bereit und nutzt `hostPID: true` fuer `iscsiadm` im Host-Namespace. |
| Snapshot Controller | storage   | `kubernetes/apps/storage/snapshot-controller` | Aktiv  | CSI Snapshot CRDs + Controller. SnapshotClass `synology-iscsi-snapshots` wird durch democratic-csi bereitgestellt. |
| Litestream Cleanup  | storage   | `kubernetes/apps/storage/litestream-cleanup`  | Aktiv  | CronJob fuer Retention/Cleanup des `litestream` Buckets. |
| Longhorn            | storage   | `archive/apps/storage/longhorn`               | Archiviert | Ehemaliger Distributed Block Storage. Nicht als aktive StorageClass dokumentieren. |
| Synology CSI        | storage   | `archive/apps/storage/synology-csi`           | Archiviert | Ersetzt durch democratic-csi. |
| K8up                | storage   | `archive/apps/storage/k8up`                   | Archiviert | Ehemaliger Restic Backup Operator. |
| Velero              | storage   | `archive/apps/storage/velero`                 | Archiviert | Ehemalige Cluster/PVC Backup-Loesung. |

Aktive StorageClass:

- `iscsi-delete` aus democratic-csi, global als `${MAIN_SC}` in `kubernetes/components/common/cluster-settings.yaml` gesetzt.
- Workloads mit PVCs haengen explizit von `storage/democratic-csi-iscsi` ab, wenn sie iSCSI Storage brauchen.

## Backup & Protection

| Ebene | Mechanismus | Hinweise |
| ----- | ----------- | -------- |
| Kubernetes-Manifeste | Git + Flux | Git ist Source of Truth. Restore erfolgt durch Bootstrap und Flux-Reconcile. |
| Secrets | SOPS/Age + 1Password External Secrets | Age Key und 1Password Tokens offsite sichern. |
| PVC/App-Daten | Synology/democratic-csi | Restore ueber NAS/Synology-Backups oder neu provisionierte PVCs je App. |
| SQLite-Datenbanken | Litestream | Sidecars replizieren nach S3-kompatiblem `litestream` Bucket. Cleanup via `litestream-cleanup`. |

## Betrieb

1. **democratic-csi pruefen**
    - `kubectl -n storage get pods -l app.kubernetes.io/instance=democratic-csi-iscsi`
    - `kubectl get sc iscsi-delete`
    - Bei Mount-Problemen iSCSI/NAS-Erreichbarkeit und Node-Events pruefen.
2. **PVC Health**
    - `kubectl get pvc -A`
    - `kubectl describe pvc -n <namespace> <name>`
    - `kubectl get events -A --field-selector involvedObject.kind=PersistentVolumeClaim`
3. **Litestream**
    - Sidecar-Logs der betroffenen App pruefen.
    - `kubectl -n storage get cronjobs litestream-cleanup-main`
    - Bucket-Groesse und alte Generationen kontrollieren.
4. **Restore Tests**
    - App-spezifische Restore-Tests in temporischem Namespace/PVC durchfuehren.
    - SQLite-Apps per Litestream Restore testen.
    - Ergebnisse in `docs/backups.md` protokollieren.

## Monitoring

- PVC-Fuellstand, Node Disk Pressure und Pod-Restarts ueber den Observability-Stack bzw. Gatus pruefen.
- democratic-csi Controller/Node Pods muessen Ready sein.
- Litestream Cleanup Jobs duerfen nicht dauerhaft fehlschlagen.
- Snapshot Controller ist aktiv; SnapshotClass `synology-iscsi-snapshots` kommt aus democratic-csi.

## Runbooks

- `docs/runbooks.md` -> `PVC / Storage Degraded`
- `docs/runbooks.md` -> `Synology / democratic-csi Volume Restore`
- `docs/backups.md` -> Litestream Restore und Backup-Testprotokoll

## TODOs / Gaps

1. Storage usage report + data classification pro App ergaenzen.
2. Automatische Restore-Validierung fuer Synology/democratic-csi und Litestream definieren.
3. Offsite-Backup-Ziel fuer nicht-replizierte PVC-Daten dokumentieren.
