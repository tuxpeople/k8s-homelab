# Kubernetes-Homelab Dokumentation

Dieses Verzeichnis beschreibt den Kubernetes-Teil des Homelabs. Die Struktur folgt denselben Leitplanken wie bei der Docker-Dokumentation: erst den Ist-Zustand festhalten, dann gezielt weiterentwickeln. Alle Inhalte sind Git-verwaltet – Änderungen gehören in diese Dokumentation **vor** sie ins Cluster ausgerollt werden.

## Struktur & Inhaltsverzeichnis
- `services/` – Detailblätter pro Service/Komponente (Cluster-Fundament, Flux, Networking, Storage, Security, Observability, Applikationen)
- `automation.md` – Task Runner, GitHub Actions, Renovate und Policies
- `secrets.md` – SOPS-/Age-Fluss, External Secrets, Rotationsprozesse
- `backups.md` – K8up, Velero, Longhorn-Snapshots, Restore-Tests
- `monitoring.md` – Observability-Stack, Dashboards, Alerting, SLOs
- `dr.md` – Disaster-Recovery-Pläne inkl. Talos-Rebuild & DNS
- `runbooks.md` – Operative Schritt-für-Schritt-Anleitungen
- `WEITERENTWICKLUNG.md` – Backlog/ToDo mit Priorisierung
- `CHANGELOG.md` – Jede inhaltliche Änderung dokumentieren

## Arbeitsweise
1. **Ist-Zustand prüfen**: Vor Anpassungen alle thematisch relevanten Dateien lesen (Manifeste unter `kubernetes/`, Talos-Konfigs, bisherige Docs).
2. **Dokumentieren**: Änderungen zuerst hier beschreiben (Service-Steckbrief, Runbook, Policy etc.).
3. **Validieren**: Tasks/Skripte ausführen, Secrets auf Leaks prüfen (`pre-commit`, `sops`), dann erst committen.
4. **Changelog pflegen**: Jede fachliche Änderung mit Datum, Kontext und PR/Git-Commit verlinken.

## Quick Links
- [Automation & Policies](automation.md)
- [Secrets & Sensitive Data](secrets.md)
- [Backup-Strategie](backups.md)
- [Monitoring & Alerting](monitoring.md)
- [Disaster Recovery](dr.md)
- [Runbooks](runbooks.md)
- [Backlog / Weiterentwicklung](WEITERENTWICKLUNG.md)
- [Changelog](CHANGELOG.md)
- [Architekturdiagramm (PNG)](architecture.png) & [Quelle (draw.io)](architecture.drawio)

## Offenstände
Alle Lücken oder offenen Fragen gehören nach `WEITERENTWICKLUNG.md`. Service-Dokumente dürfen TODO-Blöcke enthalten, solange klar ist, wer sie bearbeitet oder in welcher Priorität die Ergänzung erfolgt.
