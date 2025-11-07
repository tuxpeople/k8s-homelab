# Productivity & Personal Tools

> Statusangaben: **aktiv** = `ks.yaml`, **deaktiviert** = `ks.dis`. Namespace ist immer `productivity`, sonst explizit angegeben.

## Code-Server (**aktiv**)
- **Pfad**: `kubernetes/apps/productivity/code-server`.
- **Zweck**: Remote VS Code Arbeitsumgebung (LinuxServer Image) mit vorinstallierten Extensions/Mods.
- **Ingress**: `code.${SECRET_DOMAIN}` (external ingress) hinter Authelia (`auth.${SECRET_DOMAIN}`).
- **Secrets / Auth**: Passwort `CODESERVER_PASSWORD` aus Secret (`secret-values.sops.yaml`). Zusatz-Mods installieren Tools wie git/terraform.
- **Speicher**: PVC `config` 5 Gi (Longhorn) + ConfigMap `custom-cont-init`. RPO 24 h (Restic) empfohlen; Backup enthält Workspace.
- **Monitoring**: Add Gatus HTTP check + alert auf PVC >80 %. `task pre-commit`/`kubectl logs deploy/code-server` für Fehler.
- **Runbooks**: Reconcile via `flux reconcile kustomization code-server --with-source -n productivity`. Vor Updates: Backup Workspace, verifiziere Authelia-Entrypoint.

## Drop / Pwndrop (**aktiv**)
- **Pfad**: `kubernetes/apps/productivity/drop`.
- **Zweck**: Temporäre Dateiablage mit Expiring Links.
- **Ingress**: `drop.${SECRET_DOMAIN}` (external). Kein zusätzlicher Auth, optional via Authelia ergänzen.
- **Speicher**: PVC `config` 5 Gi. Enthält Uploads + User-Daten -> K8up Job definieren (Fehlt, siehe TODO).
- **Monitoring**: Basic readiness; HTTP check via Gatus.
- **Runbooks**: Reconcile `flux reconcile kustomization drop --with-source -n productivity`. Bei kompromittierten Uploads PVC löschen + aus Backup wiederherstellen.

## FreshRSS (**aktiv**)
- **Pfad**: `kubernetes/apps/productivity/freshrss`.
- **Zweck**: RSS Reader mit OIDC Auth.
- **Ingress**: `freshrss.${SECRET_DOMAIN}` (external).
- **Secrets**: `freshrss-secrets` (DB creds, admin). OIDC gegen `auth.${SECRET_DOMAIN}`.
- **Speicher**: PVC `data` 5 Gi (Longhorn) + `k8up.io/backup` Annotation aktiv → Restic Job vorhanden. Prüfen RPO 12 h.
- **Monitoring**: Cron env `CRON_MIN` (18,48). Add alert wenn Cron älter >2h. Pod resources minimal; watchers in Grafana.
- **Runbooks**: Reconcile `flux reconcile kustomization freshrss --with-source -n productivity`. Für DB Migration: export OPML/feeds.

## Hajimari (**aktiv**)
- **Pfad**: `kubernetes/apps/productivity/hajimari`.
- **Zweck**: Service-Discovery Dashboard für alle Namespaces.
- **Ingress**: `hajimari.${SECRET_DOMAIN}` (internal). Homepage annotations (`gethomepage.dev`).
- **Speicher**: Nur `emptyDir` (stateless). Config via Helm values; Bookmark-Liste hier pflegen.
- **Monitoring**: Add Gatus check (Annotation `gethomepage.dev/siteMonitor`). Alerts auf Pod CrashLoop.
- **Runbooks**: `flux reconcile kustomization hajimari --with-source -n productivity`. Bei fehlenden Apps -> Labels im Cluster prüfen.

## Kasm (**aktiv**, ExternalName)
- **Pfad**: `kubernetes/apps/productivity/kasm`.
- **Zweck**: Ingress/Service-Eintrag zu externem Kasm-Cluster (`kasm.vm.tdeutsch.ch`).
- **Ingress**: `kasm.${SECRET_DOMAIN}` (external). Backend spricht HTTPS, TLS passthrough via annotations.
- **Speicher**: Keine (alles extern). Dokumentiere Off-Cluster Backup/DR.
- **Monitoring**: Gatus check `https://kasm.${SECRET_DOMAIN}`; alert wenn ExternalName nicht resolvbar.
- **Runbooks**: Bei Zertifikatsproblemen → check remote host. Flux reconcile `kasm`.

## Ladder (**aktiv**)
- **Pfad**: `kubernetes/apps/productivity/ladder`.
- **Zweck**: Habit Tracker, lädt Ruleset aus GitHub.
- **Ingress**: `ladder.${SECRET_DOMAIN}` (internal).
- **Speicher**: Kein PVC → prüfe, ob Daten dauerhaft benötigt werden; ggf. Persistent Storage ergänzen (Backlog DOC-009).
- **Monitoring**: Basic HTTP check. Ruleset Download Failure = Pod Crash (watch logs).
- **Runbooks**: Reconcile `flux reconcile kustomization ladder --with-source -n productivity`.

## Linkding (**aktiv**)
- **Pfad**: `kubernetes/apps/productivity/linkding`.
- **Zweck**: Bookmark Manager mit Authelia Auth.
- **Secrets**: `linkding-secrets` (Litestream S3 creds + Age keys). ConfigMap `linkding-config` steuert Litestream replicate/restore.
- **Storage**: Uses `emptyDir` for DB but Litestream replicates to MinIO (see config). Consider migrating to PVC for local caching.
- **Backups**: Litestream replicates to MinIO bucket (retention 168h) encrypted via Age. Document bucket location in `docs/backups.md`.
- **Monitoring**: Add alerts for Litestream failures (stderr). HTTP check on `linkding.${SECRET_DOMAIN}`.
- **Runbooks**:
  - Activation: ensure MinIO creds valid.
  - Disaster: use `litestream restore ...` per initContainer example.
  - Flux reconcile command analog zu anderen.

## Miniflux (**aktiv**)
- **Pfad**: `kubernetes/apps/productivity/miniflux`.
- **Zweck**: Lightweight RSS Reader alternative.
- **Storage / DB**: Kein PVC definiert → Container-internal SQLite. Risiko bei Pod reschedule. TODO: Externes Postgres/ PVC anlegen (Backlog DOC-001).
- **Monitoring**: ServiceMonitor `/metrics` aktiv, Dashboard importiert (Grafana). Alerts für `miniflux_up==0`, error rates.
- **Ingress**: `miniflux.${SECRET_DOMAIN}` (external). Auth handled in-app.
- **Runbooks**: Reconcile `flux reconcile kustomization miniflux --with-source -n productivity`. Vor Updates Export OPML.

## N8N (**aktiv**)
- **Pfad**: `kubernetes/apps/productivity/n8n`.
- **Zweck**: Workflow Automation.
- **Secrets**: `n8n-secret` (encryption key etc.). Additional credentials stored via ExternalSecret or environment; document each flow separately.
- **Ingress**: `n8n.${SECRET_DOMAIN}` (internal, body-size 32 Mi).
- **Storage**: PVC `/home/node/.n8n` 5 Gi.
- **Monitoring**: ServiceMonitor for `/metrics`; add dashboards for queue size, execution age. Alerts: Job Execution Failures, Pod restarts.
- **Backups**: Export workflows (JSON) + Restic (PVC). Document location in `backups.md`.
- **Runbooks**:
  - `flux reconcile kustomization n8n --with-source -n productivity`.
  - "Upgrade Steps" (Stop triggers, backup workflows, apply, verify) – TODO.

## Obsidian (**aktiv**)
- **Pfad**: `kubernetes/apps/productivity/obsidian`.
- **Ingress**: `obsidian.${SECRET_DOMAIN}` (external) + Authelia.
- **Storage**: PVC 20 Gi (Longhorn) for vault. Ensure Restic schedule.
- **Monitoring**: Add Gatus check; alert for PVC >80 %.
- **Runbooks**: Reconcile `flux reconcile kustomization obsidian --with-source -n productivity`. For vault sync issues, inspect container logs.

## Paperless (**aktiv**)
- **Pfad**: `kubernetes/apps/productivity/paperless`.
- **Zweck**: Dokumenten-DMS inklusive Redis, Tika, Gotenberg side controllers + public share ingress.
- **Ingress**:
  - Internal: `paperless.${SECRET_DOMAIN}` (internal, Authelia).
  - Public share: `documents.${SECRET_CH_DOMAIN}` (external, share-only).
- **Storage**:
  - NFS mount `/volume2/scanner`.
  - Additional ConfigMap-mounted scripts + secret-based passwords.
  - Resource heavy: main container requests 500 mCPU/1.1 Gi, limit 2.5 CPU/2.5 Gi. Aux containers (redis/tika/gotenberg) also defined.
- **Secrets**: `paperless-secret-values`, `paperless-secret-passwords`.
- **Backups**: Multi-layer:
  - Files on Synology (rsync snapshots) + Restic job.
  - DB sits in Postgres? (Check `paperless-config`). Document RPO ≤24 h.
- **Monitoring**: Alert on Paperless queue backlog, ingestion errors, Cron `SCAN_INTERVAL` (30 min). Export metrics via custom script? TODO.
- **Runbooks**: Already `runbooks.md` re: Paperless backlog. Add “Public share issues” & “NFS offline” steps. Reconcile `flux reconcile kustomization paperless --with-source -n productivity`.

## Pi-hole (**deaktiviert**, `ks.dis`)
- **Pfad**: `kubernetes/apps/productivity/pi-hole`.
- **Zweck**: Reverse proxy + ExternalName zu On-Prem Pi-hole (`pihole.home`).
- **Ingress**: `pi-hole.${SECRET_DOMAIN}` (internal) mit Authelia.
- **Aktivierung**: Rename `ks.dis → ks.yaml`, prüfe dass On-Prem Pi-hole läuft + TLS passt. Alternative: Ersetzt inzwischen Unifi-DNS; entscheide, ob dieses Ingress benötigt wird.
- **Monitoring / Runbooks**: HTTP check, verify certificate. Document pi-hole admin credentials outside Git.

## Webtrees (**aktiv**)
- **Pfad**: `kubernetes/apps/productivity/webtrees`.
- **Architektur**:
  - App HelmRelease + separater MariaDB HelmRelease (`webtrees-db`).
  - CronJob (`db/cronjob.yaml`) dump’t täglich per mysqldump auf NFS (`/volume2/data/backup/kubernetes`).
- **Ingress**: `webtrees.${SECRET_DOMAIN}` (internal + Authelia).
- **Secrets**: `mariadb-secret`, `webtrees-admin-pass`.
- **Storage**: PVC for app data (5 Gi) + `emptyDir` modules. MariaDB uses default Longhorn SC (`${MAIN_SC}`).
- **Backups**: Daily Cron + Velero/Restic recommended. Track success metrics (job completions).
- **Monitoring**: Add alert for CronJob failures, MariaDB exporter already enabled (Bitnami). Gatus check for HTTP `/`.
- **Runbooks**:
  - DB restore: Use dumps on NFS, apply via `mysql` client.
  - Reconcile app/db separately.

## Allgemeine Backups & Monitoring
- **Backups**:
  - Ensure `storage/k8up` schedules cover namespace `productivity`.
  - Document NFS mount points (Paperless, Webtrees DB dumps, Calibre etc.) in `docs/backups.md`.
  - Review Litestream/MinIO retention + offsite copies.
- **Monitoring**:
  - Gatus targets für alle externen URLs (Code, Drop, FreshRSS, Miniflux, N8N, Obsidian, Paperless share, Kasm, Pi-hole, Webtrees).
  - Prometheus alerts: queue depth (Paperless), job failures (n8n, CronJobs), ServiceMonitor coverage (n8n, miniflux).
  - Dashboard section „Productivity“ verlinken (Grafana).

## TODOs & Runbooks
- Ergänze in `docs/runbooks.md`:
  - Code-Server maintenance window.
  - Linkding Litestream restore.
  - N8N workflow backup/restore + encryption key rotation.
  - Paperless share outage handling.
- `docs/WEITERENTWICKLUNG.md` DOC-009 referenziert fehlende Media/Prod Runbooks – aktualisieren nach Erstellung.
