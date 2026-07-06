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
- Policies liegen unter `kubernetes/apps/security/kyverno/policies/` und werden über die Flux Kustomization `kyverno-policies` ausgerollt.
- `kubernetes/apps/security/kyverno/policies/kustomization.yaml` ist die aktive Policy-Liste; `ghcr-pullsecret.yaml` ist vorbereitet, aber aktuell auskommentiert.

| Policy | Typ | Wirkung |
| ------ | --- | ------- |
| `sync-production-tls` | Generate | Kopiert `*-production-tls` Secrets aus `cert-manager` nach `network`; RBAC liegt in `sync-production-tls-rbac.yaml`. |
| `gatus-external` / `gatus-internal` | Generate | Erzeugt Gatus ConfigMaps für Ingresses mit `ingressClassName: external` oder `internal`. Ausnahmen: Namespace `test`, Annotation `gatus.io/enabled: "false"`, Namespace-Label `kyverno.io/exclude: "true"`. |
| `helmrelease-defaults` | Mutate | Setzt fehlendes `spec.upgrade.remediation.strategy: uninstall` bei HelmReleases. |
| `ingress` | Mutate | Setzt `external-dns.alpha.kubernetes.io/target` für externe Ingresses auf `external.${SECRET_DOMAIN}` und für interne Ingresses auf `192.168.13.64`, ohne bestehende Werte zu überschreiben. |
| `limits` | Mutate | Entfernt CPU-Limits aus Pods und Init-Containern; systemnahe oder ausgeschlossene Namespaces bleiben ausgenommen. |
| `ndots` | Mutate | Setzt DNS `ndots: "1"` für Pods. |
| `label-existing-namespaces` | Mutate existing | Labelt bestehende Namespaces nach, ausser sie tragen `kyverno.io/exclude: "true"`. |
| `add-reloader-annotations` | Mutate | Ergänzt Reloader-Annotationen für Secret/ConfigMap-Neustarts. |
| `require-storageclass` | Validate, Audit | Auditiert PVCs und StatefulSets ohne `storageClassName`. |
| `restrict-deprecated-registry` | Validate, Enforce | Blockiert Pods mit deprecated Registry-Pfaden. |
| `restrict-latest-tag` | Validate, Audit | Auditiert fehlende Image-Tags und `:latest`. |
| `restrict-privileged` | Validate, Audit | Auditiert `privileged: true` sowie Host-Namespace-Nutzung. |
| `seccomp-default` | Mutate | Setzt `RuntimeDefault` Seccomp-Profil, wenn keines definiert ist. |

- Pod Security Standards: teilweise über `restrict-privileged` und `seccomp-default` abgedeckt; vollständige PSModerate/Restricted-Enforcement ist noch nicht aktiv.
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
1. Ressourcen-Requests gesetzt? CPU-Limits werden durch Kyverno entfernt; Memory-Limits weiterhin bewusst setzen.
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
