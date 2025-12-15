# WEITERENTWICKLUNG / TODO

| ID      | Thema                                | Beschreibung                                                                                          | Priorität | Owner | Status                       |
| ------- | ------------------------------------ | ----------------------------------------------------------------------------------------------------- | --------- | ----- | ---------------------------- |
| DOC-001 | Service-Steckbriefe vervollständigen | Für alle Apps unter `kubernetes/apps/*` die Detailabschnitte (Zweck, Namespace, Backups, SLO) füllen. | Hoch      | offen | Offen                        |
| DOC-002 | Architekturdiagramm einbinden        | Netzwerk-, Storage- und GitOps-Fluss visualisieren (z.B. mit Excalidraw).                             | Mittel    | offen | **✅ Erledigt** (2025-11-07) |
| DOC-003 | Backup-Testprotokoll                 | Regelmässige Restore-Tests dokumentieren (K8up + Velero + Longhorn).                                  | Mittel    | offen | **✅ Erledigt** (2025-11-07) |
| DOC-004 | Netzwerk-Policies                    | Dokument beschreiben + Beispiel-Policies für Multi-Tenancy ergänzen.                                  | Mittel    | offen | Offen                        |
| DOC-005 | Secret-Rotation-Runbook              | Konkrete Runbooks für 1Password/ExternalSecret-Rotation ausarbeiten.                                  | Mittel    | offen | Offen                        |
| DOC-006 | Kosten-/Ressourcen-Monitoring        | Ergänzen wie Ressourcen-/Kosten-Trends erfasst werden (Goldilocks, Potential OTel/Cost Exporter).     | Niedrig   | offen | Offen                        |
| DOC-007 | Renovate/CI SLOs                     | Erfolgsmetriken und Benachrichtigungen definieren, falls Pipelines länger als X min hängen.           | Niedrig   | offen | Offen                        |
| DOC-008 | DR-Übung protokollieren              | Mindestens 1x/Jahr Talos-Rebuild + Restore simulieren und Lessons Learned dokumentieren.              | Hoch      | offen | Offen                        |
| DOC-009 | Medien-Stack Runbooks                | Für Mediabox, Overseerr, Plex-Export etc. start/stop/migrations beschreiben.                          | Hoch      | offen | Offen                        |
| DOC-010 | Security-Hardening                   | Kyverno/Trivy/NetworkPolicy-Docs mit konkreten Policies & Messwerten anreichern.                      | Mittel    | offen | Offen                        |

> Aktualisiere die Tabelle, sobald Tasks abgeschlossen oder priorisiert wurden. Technische Implementation-Details sollten in `../IMPROVEMENTS.md` gespiegelt werden. Für technische Analysen siehe auch `../RESOURCE_ANALYSIS.md`.
