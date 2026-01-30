# Storage & Backup Services

## Storage Layer

| Service             | Namespace | Pfad                                          | Status | Beschreibung / Hinweise                                                                                          |
| ------------------- | --------- | --------------------------------------------- | ------ | ---------------------------------------------------------------------------------------------------------------- |
| Longhorn            | storage   | `archive/apps/storage/longhorn`               | Archiviert | Primärer Distributed Block Storage (default StorageClass `longhorn`). Multi-replica, supports snapshots/backups. |
| Synology CSI        | storage   | `archive/apps/storage/synology-csi`           | Archiviert | Bindet NAS-Volumes via iSCSI/NFS ein (`synology-iscsi` SC) für grosse Datenmengen.                               |
| Democratic CSI      | storage   | `kubernetes/apps/storage/democratic-csi`      | Aktiv  | iSCSI Driver für Synology. Benötigt `hostPID: true` im Node-Driver (nsenter für iscsiadm).                      |
| Snapshot Controller | storage   | `kubernetes/apps/storage/snapshot-controller` | Aktiv  | CSI Snapshot CRDs + Controller für Longhorn/Synology Snapshots.                                                  |

-   StorageClasses:
    -   `longhorn` (default)
    -   `longhorn-backup` (höhere Replikation/backup policy)
    -   `synology-iscsi`
    -   ggf. `local-path`? (prüfen `kubectl get sc`)
-   Longhorn UI: https://longhorn.${SECRET_DOMAIN}` (internal). Credentials stored in 1Password? document.

Hinweis: Abschnitte zu Longhorn/K8up/Velero gelten, falls die Komponenten reaktiviert werden.

## Backup & Protection

| Service | Namespace | Pfad                             | Zweck                                             |
| ------- | --------- | -------------------------------- | ------------------------------------------------- |
| K8up    | storage   | `archive/apps/storage/k8up`   | Archiviert: Restic Backup Operator (Schedules per namespace). |
| Velero  | storage   | `archive/apps/storage/velero` | Archiviert: Cluster resource & PVC backups (S3 backend).      |

-   K8up: Each namespace should have `Schedule` CR (check `kubernetes/clusterconfig`?). Document per app in service docs.
-   Restic Credentials: via ExternalSecret referencing S3 target (MinIO/Wasabi?). Update `docs/backups.md` when changed.
-   Velero Credentials secret `velero-credentials` (SOPS). Storage location: S3 bucket (document name). Includes `restic` integration for PV snapshots.

## Betrieb

1. **Longhorn**:
    - Monitor replica health (`kubectl get volumes.longhorn.io -A`).
    - Snapshots/backups policy per PVC; configure retention.
    - When nodes drained, ensure volume eviction works.
2. **Synology CSI**:
    - Requires on-prem NAS connectivity (10.20.30.40). Document credentials outside repo.
    - Validate `synology-csi` driver pods before scheduling.
3. **Backups**:
    - Ensure `k8up.io/backup: "true"` annotations for PVCs needing backup.
    - Velero pre-upgrade snapshots: `velero backup create pre-<change>`.
4. **Restores**:
    - Longhorn: snapshot → clone volume → attach test pod.
    - Velero: `velero restore create --from-backup ...`.
    - K8up: `k8up job run --schedule <name> --restore`.

## Monitoring

-   Prometheus metrics:
    -   Longhorn: `longhorn_volume_healthy`, `longhorn_disk_usage`.
    -   K8up: `k8up_job_success`, `k8up_job_failed`.
    -   Velero: `velero_backup_success_total`.
-   Alerts:
    -   `VolumeDegraded`, `VolumeScheduledOnSingleNode`.
    -   `BackupFailed` (K8up/Velero) – escalate to `#k8s-alerts`.
    -   `ResticRepoStatus` degrade.

## Runbooks

-   `docs/runbooks.md` → „Longhorn Volume Degraded“, „Backup-Testprotokoll (TODO)“.
-   Additional:
    -   `Velero restore`: capture command examples.
    -   `Synology CSI outage`: failover to Longhorn or degrade apps.

## TODOs / Gaps

1. Storage usage report + data classification pro App (Backlog).
2. Automatisches Cleanup alter Longhorn snapshots definieren.
3. Document K8up schedules per namespace (table in `docs/backups.md`).
4. Validate Velero S3 credentials rotation + multi-region backup.
