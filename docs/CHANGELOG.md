# Changelog – Kubernetes Homelab Docs

> Jede inhaltliche Änderung in diesem Verzeichnis benötigt einen Eintrag mit Datum, kurzem Kontext und Referenz auf den Commit/PR.

## 2026-11-14

- SSD-Migration auf `talos-test02`: `/var` auf 1-TB-SATA-SSD, eigener iSCSI-
  Schreib-/Lesetest, persistentes Wiederlesen und DNS erfolgreich. Legacy-Mount-
  Finalizer-Wartezustand und kontrollierte Wiederholung des selektiven Resets im
  [Migrationsprotokoll](talos-storage-migration.md#zweiter-worker-ausführung) dokumentiert.
  Alle elf vorübergehend pausierten Deployments auf ihre gesicherten ursprünglichen
  Replikazahlen zurückgesetzt und wieder verfügbar.
- Node-Inventar auf die tatsächlichen Rollen korrigiert: Node 3 ist die einzige
  dedizierte Control Plane; Nodes 1, 2 und 4 sind Worker.

## 2026-11-13

- SSD-Pilot auf `talos-test01` erfolgreich: `/var` liegt auf der 1-TB-SATA-SSD.
  Alter Longhorn-GPT-Eintrag nach dem selektiven Reset explizit entfernt;
  CSI-Schreiben/Lesen, persistentes Wiederlesen und Cluster-DNS erfolgreich geprüft.
- Tautulli-Memory-Requests anhand VPA auf 384 MiB (App) und 50 MiB (Git-sync)
  gesetzt, damit der Pod beim SSD-Pilot-Drain auf die übrigen Worker passt.
  Das App-Limit bleibt 1 GiB.
- SSD-Migration auf `talos-test01` vorbereitet: EPHEMERAL erhält eine selektierte
  lokale SATA-SSD; der bisher globale Longhorn-Patch bleibt nur auf den noch nicht
  migrierten Nodes aktiv. Backups, Dry-Run und selektiver Reset-Ablauf im
  [Migrationsdokument](talos-storage-migration.md#pilot-ausführung) festgehalten.
- Cluster-Stabilisierung: Kyverno-JSONPatch-Autogen korrigiert (Commit `2a2062799`),
  parallele Image-Pulls auf zwei begrenzt, Descheduler gegen wiederholte Kaltstarts
  abgesichert und Paperless/Tautulli auf `RetryOnFailure` umgestellt.
  Tautulli-Git-sync vertraut gezielt seinem gemeinsamen `/add-ons`-Verzeichnis.
  Metrics Server fragt langsame Kubelets mit 10 Sekunden Timeout alle 30 Sekunden ab.
  Vorgehen und Validierung in [Runbooks](runbooks.md#cm4-langsame-pod-starts-und-helm-retry-schleifen).
- [Migrationsplan für Talos-Storage und Control Plane](talos-storage-migration.md)
  ergänzt: Longhorn-Laufwerke für lokale Laufzeitdaten nutzen, SATA-/PCIe-Grenzen
  des Turing Pi 2 berücksichtigen und Node 4 als dedizierte Control Plane planen.
  Planungsstand, noch nicht ausgerollt; Commit/PR nach Übernahme ergänzen.

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
