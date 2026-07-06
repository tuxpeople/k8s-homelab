# Productivity & Personal Tools

> Statusangaben: **aktiv** = `ks.yaml`. Namespace ist immer `productivity`, sonst explizit angegeben. Archivierte Apps liegen unter `archive/apps/productivity/`.

## Dorflade-MHD (**aktiv**)
- **Pfad**: `kubernetes/apps/productivity/dorflade-mhd`.
- **Zweck**: Eigene Anwendung zur Produkt-/Inventarverwaltung (MHD = Mindesthaltbarkeitsdatum). Image: `ghcr.io/tuxpeople/dorflade-mhd`.
- **Ingress**: `dorflade-mhd.${SECRET_DOMAIN}` (external ingress) mit Basic-Auth Middleware.
- **Storage**: SQLite-Datenbank unter `/app/data/products.db`; Litestream repliziert zur MinIO S3 Instanz.
- **Backups**: Litestream-Replikation zu MinIO (S3). Bucket-Konfiguration via `litestream-configmap.yaml`.
- **Secrets**: `dorflade-mhd-secrets` (Litestream MinIO Credentials via ExternalSecret/Doppler).
- **Runbooks**: Reconcile `flux reconcile kustomization dorflade-mhd --with-source -n productivity`. Für DB-Restore Litestream restore-Workflow nutzen.

## FreshRSS (**aktiv**)
- **Pfad**: `kubernetes/apps/productivity/freshrss`.
- **Zweck**: RSS Reader mit OIDC Auth.
- **Ingress**: `freshrss.${SECRET_DOMAIN}` (external).
- **Secrets**: `freshrss-secrets` (DB creds, admin). OIDC gegen `auth.${SECRET_DOMAIN}`.
- **Speicher**: PVC `data` 5 Gi (democratic-csi/Synology). Backup-Pfad ist Litestream plus Synology/PVC-Restore.
- **Monitoring**: Cron env `CRON_MIN` (18,48). Add alert wenn Cron älter >2h.
- **Runbooks**: Reconcile `flux reconcile kustomization freshrss --with-source -n productivity`. Für DB Migration: export OPML/feeds.

## Hajimari (**aktiv**)
- **Pfad**: `kubernetes/apps/productivity/hajimari`.
- **Zweck**: Service-Discovery Dashboard für alle Namespaces.
- **Ingress**: `hajimari.${SECRET_DOMAIN}` (internal). Homepage annotations (`gethomepage.dev`).
- **Speicher**: Nur `emptyDir` (stateless). Config via Helm values; Bookmark-Liste hier pflegen.
- **Monitoring**: Add Gatus check. Alerts auf Pod CrashLoop.
- **Runbooks**: `flux reconcile kustomization hajimari --with-source -n productivity`. Bei fehlenden Apps → Labels im Cluster prüfen.

## Linkding (**aktiv**)
- **Pfad**: `kubernetes/apps/productivity/linkding`.
- **Zweck**: Bookmark Manager mit Authelia Auth.
- **Secrets**: `linkding-secrets` (Litestream S3 creds + Age keys). ConfigMap `linkding-config` steuert Litestream replicate/restore.
- **Storage**: `emptyDir` für DB; Litestream repliziert zu MinIO S3 (Retention 168 h, verschlüsselt via Age).
- **Backups**: Litestream-Replikation zu MinIO. Bucket-Standort in `docs/backups.md` dokumentieren.
- **Monitoring**: Alerts für Litestream-Fehler (stderr). HTTP check auf `linkding.${SECRET_DOMAIN}`.
- **Runbooks**:
  - Disaster Recovery: `litestream restore ...` per initContainer-Beispiel in `litestream-configmap.yaml`.
  - Reconcile `flux reconcile kustomization linkding --with-source -n productivity`.

## Obsidian (**aktiv**)
- **Pfad**: `kubernetes/apps/productivity/obsidian`.
- **Ingress**: `obsidian.${SECRET_DOMAIN}` (external) + Authelia.
- **Storage**: PVC 20 Gi (democratic-csi/Synology) für Vault. Backup/Restore über Synology/PVC-Strategie in `docs/backups.md` sicherstellen.
- **Monitoring**: Add Gatus check; alert für PVC >80 %.
- **Runbooks**: Reconcile `flux reconcile kustomization obsidian --with-source -n productivity`. Für Vault-Sync-Probleme Container-Logs prüfen.

## Paperless (**aktiv**)
- **Pfad**: `kubernetes/apps/productivity/paperless`.
- **Zweck**: Dokumenten-DMS inklusive Redis, Tika, Gotenberg Side-Controller + Public Share Ingress.
- **Ingress**:
  - Internal: `paperless.${SECRET_DOMAIN}` (internal, Authelia).
  - Public share: `documents.${SECRET_CH_DOMAIN}` (external, share-only).
- **Storage**:
  - NFS Mount `/volume2/scanner` (Synology).
  - ConfigMap-mounted Scripts + Secret-basierte Passwörter.
  - Resource heavy: main container requests 500 mCPU/1.1 Gi, limit 2.5 CPU/2.5 Gi.
- **Secrets**: `paperless-secret-values`, `paperless-secret-passwords`.
- **Backups**:
  - Dateien auf Synology (rsync/Snapshots).
  - SQLite-Datenbank via Litestream. RPO ≤24 h dokumentieren.
- **Monitoring**: Alert on Paperless queue backlog, ingestion errors, Cron `SCAN_INTERVAL` (30 min).
- **Runbooks**: Bereits `runbooks.md` re: Paperless backlog. Reconcile `flux reconcile kustomization paperless --with-source -n productivity`.

## Archivierte Productivity-Apps

Die folgenden Anwendungen wurden aus dem Cluster entfernt. Manifeste liegen in `archive/apps/productivity/`.

| App | Zweck | Archivpfad |
|-----|-------|------------|
| Code-Server | Remote VS Code Arbeitsumgebung | `archive/apps/productivity/code-server` |
| Drop / Pwndrop | Temporäre Dateiablage mit Expiring Links | `archive/apps/productivity/drop` |
| Kasm | Ingress zu externem Kasm-Cluster | `archive/apps/productivity/kasm` |
| Ladder | Habit Tracker | `archive/apps/productivity/ladder` |
| Miniflux | Lightweight RSS Reader | `archive/apps/productivity/miniflux` |
| N8N | Workflow Automation | `archive/apps/productivity/n8n` |
| Pi-hole | Reverse Proxy + ExternalName zu On-Prem Pi-hole | `archive/apps/productivity/pi-hole` |
| Webtrees | Genealogie-DMS mit MariaDB + CronJob Dumps | `archive/apps/productivity/webtrees` |

## Allgemeine Backups & Monitoring

- **Backups**:
  - Litestream-Apps (dorflade-mhd, Linkding): Sicherstellen dass MinIO-Retention und Offsite-Kopien konfiguriert sind.
  - NFS-Mount-Punkte (Paperless, Calibre, Obsidian) in `docs/backups.md` dokumentieren.
- **Monitoring**:
  - Gatus targets für alle externen URLs (FreshRSS, Obsidian, Paperless share, Linkding, Hajimari).
  - Prometheus alerts: Queue depth (Paperless), Job failures, Litestream-Fehler.
