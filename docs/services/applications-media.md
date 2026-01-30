# Media Stack Services

> Statusangaben: **aktiv** = `ks.yaml`, **deaktiviert** = `ks.dis` (zum Aktivieren Datei nach `ks.yaml` kopieren).

## Calibre-Web (**aktiv**)

-   **Namespace / Pfad**: `media` / `kubernetes/apps/media/calibre-web`.
-   **Zweck**: Selfhosted eBook-Verwaltung inkl. Calibre-Backend.
-   **Ingress / Zugriff**: Intern (`books.${SECRET_DOMAIN}`, class `internal`, TLS wildcard). Hajimari Icon `bookshelf`.
-   **Speicher**:
    -   PVC `config` (5 Gi, Longhorn) für App-Konfiguration.
    -   NFS-Mount `10.20.30.40:/volume2/data/media/books` für Bibliothek (Synology). Verfügbarkeit des NAS zwingend dokumentieren.
    -   `cache` via `emptyDir`.
-   **Secrets / Env**: Keine sensiblen Variablen ausser `PUID/PGID/TZ`.
-   **Backups**:
    -   PVC `config`: K8up (RPO 24 h) + Longhorn Snapshot.
    -   NFS-Daten liegen bereits auf Synology → dortige Snapshot/rsync-Strategie referenzieren.
-   **Monitoring**:
    -   Keine dedizierten Probes jenseits Standard. Gatus-Check für `books.${SECRET_DOMAIN}` hinzufügen.
    -   Alerts: PVC >80 %, NFS offline.
-   **Runbooks**:
    -   Update = HelmRelease (app-template). Reconcile: `flux reconcile kustomization calibre-web --with-source -n media`.
    -   Bei NFS-Ausfall: App in Maintenance, NFS wiederherstellen, Pod restart.

## Mediabox (\*arr Stack, Ingress-Proxy) (**aktiv**)

-   **Namespace / Pfad**: `media` / `kubernetes/apps/media/mediabox`.
-   **Zweck**: Stellt ausschliesslich Ingress + `ExternalName`-Services bereit, die auf eine externe Mediabox-Installation (`*.media.tdeutsch.ch`) verweisen (Docker Stack).
-   **Abgedeckte Apps**: Bazarr, Calibre, Gaps, lldap, Notifiarr, Prowlarr, Radarr, Readarr, Sabnzbd, Sonarr.
-   **Ingress**: Alle extern (`external` class, TLS wildcard) + Authelia/Auth Header (ausgenommen Calibre?). Pfade in einzelnen YAML-Dateien.
-   **Secrets**: Keine lokalen; Auth über zentralen `auth.${SECRET_DOMAIN}`.
-   **Backups**: Daten liegen nicht im Cluster. Trotzdem: DNS/Ingress-Definitionen versioniert; im Notfall auf Docker-Stack verweisen.
-   **Monitoring**:
    -   Gatus/Blackbox Checks pro Hostname (HTTP 200, Auth 401?). TODO: verlinken.
    -   Alert bei `ExternalName` nicht resolvbar.
-   **Runbooks**:
    -   „Mediabox Ingress Probleme“ bereits in `docs/runbooks.md`.
    -   Aktivierungsfolge: Auth → Ingress → DNS.

## Overseerr (**aktiv**)

-   **Namespace / Pfad**: `media` / `kubernetes/apps/media/overseerr`.
-   **Zweck**: Request-Workflow für Plex/Arr-Downloads.
-   **Ingress**: `requests.${SECRET_DOMAIN}` (external ingress, TLS). Gatus Annotation vorhanden.
-   **Storage**: PVC `config` 5 Gi (Longhorn). Recreate-Strategy.
-   **Secrets / Env**: Konfiguration im PVC. OAuth/API-Keys werden bei Erstkonfiguration über UI gesetzt → dokumentieren (Backlog DOC-009).
-   **Resources**: Requests `100m/128Mi`, Limits `1000m/1024Mi`.
-   **Backups**: Restic Job für Namespace `media` + Longhorn Snapshots (RPO 24 h). Vor Upgrades `velero backup create pre-overseerr`.
-   **Monitoring**:
    -   Liveness/Readiness hitting `/api/v1/status`.
    -   Add Prometheus alert: HTTP 5xx > 1 % / Pod restart.
-   **Runbooks**:
    -   Reconcile: `flux reconcile kustomization overseerr --with-source -n media`.
    -   Weekly check: Pending requests, notifications working.

## Plex Exporter (**deaktiviert**, `ks.dis`)

-   **Namespace / Pfad**: `media` / `kubernetes/apps/media/plex-exporter`.
-   **Zweck**: Prometheus Exporter (`ghcr.io/jsclayton/prometheus-plex-exporter`) liefert Plex-Statistiken (port 9000, ServiceMonitor vorhanden).
-   **Abhängigkeiten**:
    -   `cloudflared` (network namespace) laut `dependsOn`.
    -   ExternalSecret `plex-exporter` (API token). Vor Aktivierung Secret prüfen.
    -   NodeSelector `kubernetes.io/arch=amd64` → Scheduling nur auf amd64 Nodes (Talos?). Prüfen Node-Arch.
-   **Backups**: Keine persistenten Daten; nur Secrets.
-   **Monitoring**:
    -   ServiceMonitor bereits definiert. Bei Aktivierung Prometheus-Scrape checken.
-   **Runbooks / Aktivierung**:
    -   `mv ks.dis ks.yaml`, `git add`, `flux reconcile kustomization plex-exporter`.
    -   API Token Rotation im Secret dokumentieren (`docs/secrets.md`).

## Plex Trakt Sync (**deaktiviert**, `ks.dis`)

-   **Namespace / Pfad**: `media` / `kubernetes/apps/media/plex-trakt-sync`.
-   **Zweck**: Synchronisiert Plex ↔ Trakt via Deployment (`watch`) + CronJob (`sync` @daily).
-   **Konfiguration**:
    -   Env referenziert Secrets (`SECRET_PLEXTOKEN`, `${SECRET_ACME_EMAIL}`) + On-Prem Plex URL `http://10.20.30.40:32400`.
    -   ConfigMap `plex-tract-sync-configmap` mounted als `/app/config/config.yml`.
    -   PVC `config-pv` 5 Gi.
-   **Backups**: PVC via Longhorn Snapshot + Restic, ConfigMap versioniert.
-   **Monitoring**:
    -   Keine Probes (disabled). Bei Aktivierung, CronJob Status via `kubectl get jobs`. Prometheus CronJob metrics TODO.
-   **Runbooks / Aktivierung**:
    -   Vor Aktivierung Plex Endpoint + Secrets prüfen.
    -   Reconcile: `flux reconcile kustomization plex-trakt-sync --with-source -n media`.
    -   Runbook „Trakt Re-Auth“ ergänzen (Backlog DOC-009).

## Tautulli (**aktiv**)

-   **Namespace / Pfad**: `media` / `kubernetes/apps/media/tautulli`.
-   **Zweck**: Plex Monitoring/Reporting inkl. JBOPS git-sync Sidecar.
-   **Ingress**: Intern (`tautulli.${SECRET_DOMAIN}`), gatus annotation.
-   **Storage**:
    -   PVC `config` 5 Gi (Longhorn).
    -   `add-ons` emptyDir (JBOPS repo via git-sync).
-   **Containers**:
    -   Main container `ghcr.io/onedr0p/tautulli`.
    -   Sidecar `git-sync` pulling `JBOPS`.
-   **Backups**: PVC via Restic (daily). JBOPS repo self-heals.
-   **Monitoring**:
    -   Probes on `/status`.
    -   Exporter `tautulli-exporter` existiert im Observability namespace → verlinken.
    -   Alerts: HTTP errors, Pod restarts, git-sync failures (logs).
-   **Runbooks**:
    -   Reconcile: `flux reconcile kustomization tautulli --with-source -n media`.
    -   For Plex API token changes update `config.ini`.

## Daten & Backups (gesamt)

-   Namespaces `media` & `observability` brauchen K8up Schedules (Restic) + Velero Snapshots. Prüfen Task `storage/k8up`.
-   NFS Mounts (Calibre, Plex) = externe Abhängigkeiten → im DR-Plan referenzieren.
-   Longhorn Snapshots für alle PVCs (Overseerr, Tautulli, Plex Trakt Sync).

## Monitoring & TODOs

-   Exporter: radarr/sonarr/sabnzbd/tautulli etc. (archiviert, siehe `archive/apps/observability/*-exporter`). Dokumentation ergänzen.
-   Alerts zu Download Queues, Disk Usage, ExternalName Availability.
-   Runbooks laut `docs/runbooks.md` Punkt „Mediabox Ingress Probleme“ – weitere (Overseerr downtime, Tautulli token refresh) offen → siehe TODO DOC-009.
