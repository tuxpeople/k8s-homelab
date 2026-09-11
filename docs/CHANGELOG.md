# Changelog – Kubernetes Homelab Docs

> Jede inhaltliche Änderung in diesem Verzeichnis benötigt einen Eintrag mit Datum, kurzem Kontext und Referenz auf den Commit/PR.

## 2026-09-11
- `WEITERENTWICKLUNG.md` entfernt: Backlog-Tracking läuft jetzt über GitHub Issues statt Markdown-Listen. Verbleibende offene DOC-XXX-Punkte als Issues #4699–#4702 migriert, alle Verweise in `docs/` und `CLAUDE.md` entsprechend aktualisiert.

## 2026-07-06
- Dokumentation von nginx-ingress auf Traefik umgestellt und die Netzwerkstruktur mit `external/`, `internal/` und gemeinsamen Traefik-Middlewares aktualisiert.
- Storage- und Backup-Dokumentation auf democratic-csi/Synology, Litestream und GitOps-Restore ausgerichtet; K8up, Velero, Longhorn und alter Synology CSI Driver als archiviert markiert.
- Architektur- und Flux-Abhaengigkeitsdiagramme regeneriert.

## 2025-11-07
- Initiale Dokumentationsstruktur für den Kubernetes-Stack erstellt (Index, thematische Guides, Service-Steckbriefe, Backlog, Runbooks).
- Backlog (WEITERENTWICKLUNG.md) mit offenen Punkten aus Improvement-Plan und Service-Lücken befüllt.
- Cross-Cutting-Guides zu Automation, Secrets, Backups, Monitoring, DR und Runbooks hinzugefügt.
- Architekturdiagramm (draw.io + PNG + DOT) ergänzt und in README/TODO verlinkt.
- Backup-Testplan inkl. Protokoll in `docs/backups.md` und passendes Runbook erstellt; TODO-Liste aktualisiert.
