# FluxCD & GitOps Layer

## Status & Komponenten

| Ressource                 | Namespace   | Pfad                                        | Zweck                                                                       | Hinweise                                             |
| ------------------------- | ----------- | ------------------------------------------- | --------------------------------------------------------------------------- | ---------------------------------------------------- |
| Flux Operator (**aktiv**) | flux-system | `kubernetes/apps/flux-system/flux-operator` | Managt Installation/Upgrades aller Flux-Controller.                         | `dependsOn` Kyverno Policies, stellt CRDs bereit.    |
| Flux Instance (**aktiv**) | flux-system | `kubernetes/apps/flux-system/flux-instance` | Definiert GitRepository (`flux-system`), Kustomizations & HelmRepositories. | Sync Intervall 1 m, `path: ./clusters/eighty-three`. |
| Sources                   | flux-system | `kubernetes/flux/`                          | Basiskomponenten (`gotk-components.yaml`, sources, alerts).                 | Enthält ImageRepositories, Notification Provider.    |

**Git Repo**: `github.com/tuxpeople/k8s-homelab` → Branch `main`. Deploy-Key `github-deploy.key` (SOPS-verschlüsselt) + GitHub token `github-push-token.txt` (für automation) lokal verfügbar.

## Bootstrap / Wiederherstellung

1. Voraussetzungen: `age.key`, Deploy-Key (`github-deploy.key`), Kubeconfig `admin@turingpi`.
2. `task bootstrap:apps` (wrappt `flux bootstrap git --url=ssh://git@github.com/tuxpeople/k8s-homelab --path=clusters/eighty-three --branch=main --components-extra=image-reflector-controller,image-automation-controller`).
3. Nach Bootstrap:
    - `flux reconcile source git flux-system -n flux-system`.
    - `flux get kustomizations -A` → alle `Ready`.
    - `flux get helmreleases -A` zur Kontrolle.
4. Secrets prüfen: `sops -d kubernetes/apps/flux-system/flux-instance/app/secrets.sops.yaml` (falls vorhanden).

## Struktur & Patterns

-   `kubernetes/apps/<group>/<service>/ks.yaml` = Flux Kustomization pro Service, setzt Labels/dependsOn.
-   `.dis` Dateien markieren deaktivierte Deployments; Aktivierung durch Umbenennen in `ks.yaml` + Commit.
-   Cross-cutting Komponenten (Kyverno, Storage, Networking) haben `dependsOn`-Ketten; Reihenfolge einhalten.
-   Reconcile-Intervalle: Standard 1 h, kritische Komponenten kürzer.
-   Notification-Workflow: Flux Alerts → Discord via `kubernetes/flux/notifications/`.

## Betrieb & Kommandos

-   **Drift/Sync**:
    -   `flux reconcile kustomization <name> --with-source -n <ns>` (Services).
    -   `flux reconcile source git flux-system -n flux-system`.
    -   `flux diff kustomization <name> --kustomization-file ...` vor Änderungen (oder GH Action `flux-local.yaml`).
-   **Suspend/Resume**:
    -   `flux suspend kustomization <name>` für riskante Deployments, anschliessend `flux resume ...`.
-   **Logs & Debug**:
    -   `flux logs --kind Kustomization --name <name> -n <ns>`.
    -   `kubectl -n flux-system logs deploy/<controller>` bei Controller-Issues.
-   **Health**:
    -   `flux get sources git -A`, `flux get helmreleases -A`.
    -   `task reconcile` (Taskfile) erzwingt globale Sync-Sequenz.

## Sicherheit & Secrets

-   Deploy-Key + token NIEMALS ins Repo committen (liegen unverschlüsselt im Root – bei Commits entfernen!).
-   Age Key zwingend für SOPS (Flux decrypts via `sops-age` secret). Check `kubernetes/flux/age-key` secret existiert.
-   GitHub Actions `flux-local.yaml` führt `flux diff` aus, um Syntaxfehler vor Merge zu finden.
-   Pod Security: Flux Operator läuft im `flux-system` Namespace → include in Kyverno policies (non-root, readOnly FS).

## Monitoring & Alerts

-   Flux controllers exportieren metrics (`/metrics` on 8080) – scrape via kube-prom-stack.
-   Alerts:
    -   `FluxKustomizationNotReady`, `FluxReconciliationFailed` → Alertmanager Discord.
    -   Drift detection (Flux Alerts) – Dashboard TODO (Grafana panel).
-   GitHub Action `claude.yml` analysiert automatisch fehlgeschlagene Workflows (inkl. Flux-Validierung) und schlägt Fixes vor.

## Runbooks

-   `docs/runbooks.md` → Abschnitt „Flux Drift / Sync Fehler“ (Log analyse, reconcile, git diff).
-   Add runbook for "Flux deploy key rotation": regenerate key, update GitHub Deploy-key, rotate secret.
-   For mass-changes: `flux suspend ks <group>`, push commits, unsuspend.

## TODO / Risiken

-   Image Automation Controller installiert, aber keine `ImageUpdateAutomation` CRs konfiguriert → definieren oder entfernen.
-   `.dis` Deployments (27 Stück lt. `IMPROVEMENT_PLAN`) durchgehen und entweder löschen oder wieder aktivieren (Doku-Vermerk).
-   Setup Grafana dashboard for Flux events + add runbook for Source auth failures.
