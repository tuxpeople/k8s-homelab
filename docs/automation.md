# Automation & Policies

Diese Datei fasst alle Automatisierungen zusammen, die den Kubernetes-Stack betreffen.

## Task Runner & lokale Workflows
- Taskfile (`Taskfile.yaml` + `.taskfiles/`): Standard-Einstiegspunkte für Bootstrap, Flux-Reconcile, Talos-Operationen, Pre-Commit.
- Empfehlung: `task --list` nach jedem Pull ausführen, weil neue Tasks häufig ergänzt werden.
- Kritische Tasks
  - `task bootstrap:talos` / `task bootstrap:apps` – vollständiger Cluster-/App-Rollout
  - `task reconcile` – Flux Sync erzwingen bei Drift
  - `task debug` – Sammelte Diagnosebefehle (kubectl, flux, talosctl)
  - `task talos:*` – Node-spezifische Aktionen (Upgrade, Apply, Reset)

## CI/CD
- **GitHub Actions** (`.github/workflows/`)
  - `flux-local.yaml`: Manifest-Validierung, Diff-Preview
  - `shellcheck.yaml`: Shell-Skripte linten
  - `mise.yaml`: Tool-Chain-Konsistenz
  - `claude-*`: Automatischer Helfer bei fehlgeschlagenen Workflows
- Richtlinie: Neue Workflows hier dokumentieren (Zweck, Trigger, Secrets, Outputs).

## Renovate
- Läuft am Wochenende, aktualisiert Container-Images, Helm-Charts, GitHub Actions.
- Auto-Merge für Patches aktiviert → nach Merge Flux-Drift prüfen.
- Dokumentationspflicht: Bei neuen Paketquellen/Regeln kurz im Changelog erwähnen.

## Pre-Commit & Qualitätssicherung
- `.pre-commit-config.yaml` erzwingt Yamllint, Shellcheck, detect-secrets etc.
- Lokale Installation via `task pre-commit:install`.
- `task pre-commit:run` bei größeren Refactorings oder bevor Renovate-PRs gemergt werden.
- Verstöße → Commit blockiert, daher ggf. `pre-commit run --all-files` frühzeitig laufen lassen.

## Policies & Reviews
1. **Dokumentationspflicht**: Änderungen an Manifeste/Tasks/Skripten → passende Datei unter `docs/` aktualisieren.
2. **Secrets**: Vor jedem Commit `git status --short | grep sops` prüfen, ungeverschlüsselte Dateien dürfen nicht eingecheckt werden.
3. **Changelog**: Jede fachliche Ergänzung → Eintrag in `docs/CHANGELOG.md`.
4. **Peer Review** (auch privat sinnvoll): Mindestens ein „4-Augen“-Check via PR, besonders bei Netzwerk, Storage, Security.
5. **Flux Drift Checks**: Nach Merge `task reconcile` oder `flux reconcile ks <name>` ausführen, Ergebnisse dokumentieren.

## Automatisierungslücken (siehe Backlog)
- Pre-Commit Hook für Kubernetes Schema-Validierung erweitert? (Goldilocks/kyverno).
- Automatisierte Backup-Verifikation (Restic + Velero) fehlt noch.
- Renovate-Metriken in Grafana Dashboard integrieren.
