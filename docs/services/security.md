# Security & Compliance

## Komponenten (Namespace `security`)
| Service | Pfad | Status | Zweck |
|---------|------|--------|-------|
| Kyverno | `kubernetes/apps/security/kyverno` | Aktiv | Admission/Mutation Policies (PodSecurity, labels, blocking `latest`, privilege). |
| External Secrets | `kubernetes/apps/security/external-secrets` | Aktiv | Synchronisiert Secrets aus 1Password und Doppler → Namespaces. |
| SecretStore 1Password | `kubernetes/apps/security/external-secrets/secretstores/onepassword` | Aktiv | Backend via onepassword-connect; benötigt 1Password Connect Token. |
| SecretStore Doppler | `kubernetes/apps/security/external-secrets/secretstores/doppler` | Aktiv | Direktintegration mit Doppler Service Token. |
| Trivy Operator | `archive/apps/security/trivy-operator` | Archiviert | CVE & config scanning (VulnerabilityReports, ConfigAuditReports). |

## Kyverno Policies
- Policies liegen unter `kubernetes/apps/security/kyverno/policies/`.
- Standards (Auszug):
  - `require-resources` – verlangt Requests/Limits.
  - `deny-privileged` – blockt `privileged: true`.
  - `disallow-latest-tag`.
  - `add-required-labels`.
  - `gatus-internal` / `gatus-external` – generiert automatisch Gatus ConfigMaps für Ingresses.
    - Ausnahmen: Namespace `test` und Annotation `gatus.io/enabled: "false"`
    - Siehe `docs/services/observability.md` für Details zu Gatus Annotations
- Pod Security Standards: Ziel PSModerate/Restricted – noch nicht ausgerollt (TODO).
- NetworkPolicies: derzeit kaum vorhanden → Backlog DOC-004 (erstellen + verlinken hier).

## Secrets & External Secrets
- Age/SOPS Workflow siehe `docs/secrets.md`.
- ExternalSecret Manifeste liegen bei den jeweiligen Apps (z. B. `app/externalsecret.yaml`), SecretStores unter `kubernetes/apps/security/external-secrets/secretstores/`.
- **1Password**: Connect Token und Signing Certificate in SOPS-Secret `onepassword-connect`.
- **Doppler**: Service Token direkt als ExternalSecret-Credential konfiguriert.
- Health-Check:
  - `kubectl get externalsecret -A`.
  - `kubectl -n security logs deploy/external-secrets`.
- Rotation:
  - Age key / SOPS → `task encrypt-secrets`.
  - 1Password token → Update secret, restart Connect.
  - Doppler token → ExternalSecret credential aktualisieren.
  - Document steps in TODO `Secret-Rotation Runbook`.

## Vulnerability Management
- Trivy Operator ist aktuell archiviert; Hinweise gelten bei Reaktivierung.
- Trivy Operator produziert:
  - `vulnerabilityreports.aquasecurity.github.io`.
  - `configauditreports.aquasecurity.github.io`.
  - `exposedsecretreports.aquasecurity.github.io`.
- Prometheus scrapes Trivy metrics; add alerts für `Critical` findings >0 (TODO Dashboard).
- Workflow:
  1. Trivy Alert → Identify namespace/pod.
  2. Update image (Renovate or manual bump).
  3. Document fix im jeweiligen Service-Dokument.
  4. Close alert / re-run scan.

## Compliance Checklist vor Deployments
1. Ressourcen-Limits gesetzt? (Kyverno enforced, aber validieren).
2. Container läuft non-root, readOnly FS wenn möglich.
3. Secrets: SOPS verschlüsselt + ExternalSecret referenziert; keine Klartext Tokens.
4. TLS & DNS Einträge dokumentiert (`docs/services/networking.md`).
5. Namespace mit NetworkPolicy geschützt? (falls nicht, TODO in Backlog).

## Runbooks
- **ExternalSecret schlägt fehl** → `docs/runbooks.md` (Status prüfen, 1Password Token, Connect Pods).
- **CVE gefunden**:
  1. Renovate PR or manual image update.
  2. `flux reconcile hr <app>`.
  3. Trivy re-scan.
  4. Note in Service doc + Changelog.
- **Kyverno Policy-Hit**:
  - `kubectl -n <ns> describe policyreport`.
  - Evaluate policy, patch manifest, commit.

## TODOs / Risiken
- Pod Security Standards enforcement (PSModerate/Restricted) noch offen.
- NetworkPolicy Abdeckung lückenhaft → definieren per Namespace.
- Secret-Rotation-Automation (DOC-005) fehlt.
- Policy Matrix dokumentieren (Welche Policies gelten in welchem Namespace).
