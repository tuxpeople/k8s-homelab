# Media Stack Services

> Statusangaben: **aktiv** = `ks.yaml`. Archivierte Apps liegen unter `archive/apps/media/`.

## Calibre-Web (**aktiv**)

-   **Namespace / Pfad**: `media` / `kubernetes/apps/media/calibre-web`.
-   **Zweck**: Selfhosted eBook-Verwaltung inkl. Calibre-Backend.
-   **Ingress / Zugriff**: Intern (`books.${SECRET_DOMAIN}`, class `internal`, TLS wildcard). Hajimari Icon `bookshelf`.
-   **Speicher**:
    -   PVC `config` (5 Gi, democratic-csi/Synology) für App-Konfiguration.
    -   NFS-Mount `10.20.30.40:/volume2/data/media/books` für Bibliothek (Synology). Verfügbarkeit des NAS zwingend dokumentieren.
    -   `cache` via `emptyDir`.
-   **Secrets / Env**: Keine sensiblen Variablen ausser `PUID/PGID/TZ`.
-   **Backups**:
    -   PVC `config`: Snapshot via snapshot-controller + Restic.
    -   NFS-Daten liegen bereits auf Synology → dortige Snapshot/rsync-Strategie referenzieren.
-   **Monitoring**:
    -   Gatus-Check für `books.${SECRET_DOMAIN}` hinzufügen.
    -   Alerts: PVC >80 %, NFS offline.
-   **Runbooks**:
    -   Update = HelmRelease (app-template). Reconcile: `flux reconcile kustomization calibre-web --with-source -n media`.
    -   Bei NFS-Ausfall: App in Maintenance, NFS wiederherstellen, Pod restart.

## Tautulli (**aktiv**)

-   **Namespace / Pfad**: `media` / `kubernetes/apps/media/tautulli`.
-   **Zweck**: Plex Monitoring/Reporting inkl. JBOPS git-sync Sidecar.
-   **Ingress**: Intern (`tautulli.${SECRET_DOMAIN}`), gatus annotation.
-   **Storage**:
    -   PVC `config` 5 Gi (democratic-csi/Synology).
    -   `add-ons` emptyDir (JBOPS repo via git-sync).
-   **Containers**:
    -   Main container `ghcr.io/home-operations/tautulli`.
    -   Sidecar `git-sync` pulling `JBOPS`.
-   **Backups**: PVC via Restic (daily). JBOPS repo self-heals.
-   **Monitoring**:
    -   Probes on `/status`.
    -   Exporter `tautulli-exporter` existiert im Observability namespace → verlinken.
    -   Alerts: HTTP errors, Pod restarts, git-sync failures (logs).
-   **Runbooks**:
    -   Reconcile: `flux reconcile kustomization tautulli --with-source -n media`.
    -   For Plex API token changes update `config.ini`.

## Archivierte Media-Apps

Die folgenden Anwendungen wurden aus dem Cluster entfernt. Manifeste liegen in `archive/apps/media/`.

| App | Zweck | Archivpfad |
|-----|-------|------------|
| Mediabox (\*arr Stack) | Ingress + ExternalName-Services für externe Mediabox-Installation | `archive/apps/media/mediabox` |
| Overseerr | Request-Workflow für Plex/Arr-Downloads | `archive/apps/media/overseerr` |
| Plex Exporter | Prometheus Exporter für Plex-Statistiken | `archive/apps/media/plex-exporter` |
| Plex Trakt Sync | Synchronisiert Plex ↔ Trakt (Deployment + CronJob) | `archive/apps/media/plex-trakt-sync` |
