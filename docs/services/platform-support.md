# Platform & Supporting Services

## Zertifikate & PKI
| Service | Namespace | Pfad | Status | Hinweise |
|---------|-----------|------|--------|----------|
| cert-manager | cert-manager | `kubernetes/apps/cert-manager/cert-manager` | Aktiv | ACME (Let's Encrypt) mit ClusterIssuer `letsencrypt-production` + Namespaced Issuer. Secrets via `cert-manager/secret.sops.yaml`. |

- Certificates: Standard wildcard `${SECRET_DOMAIN}` + Spezial-Zonen (`${SECRET_CH_DOMAIN}` etc.). Neue Domains hier dokumentieren.
- DNS01? Aktuell HTTP-01 über ingress + Cloudflare? (prüfen). Wenn neue Wildcards → Cloudflare API Token notwendig.
- Runbook „Zertifikat erneuern“ existiert (siehe `docs/runbooks.md`). Ergänze `cert-manager` troubleshooting (Order/Challenge).

## Datenbanken & Operators
| Service | Namespace | Pfad | Zweck |
|---------|-----------|------|-------|
| Postgres Operator (Zalando) | database | `kubernetes/apps/database/postgres-operator` | Managed Postgres clusters (CRDs `postgresqls.acid.zalan.do`). |

- Aktuell keine produktiven Postgres clusters definiert? (Check `kubernetes/apps/database`). Bei Nutzung → Service-Doku verlinken (z.B. Paperless DB).
- Operator Werte: `resync_period 5m`, `workers 32`, Upgrades manuell. Secrets: `pod-config` optional (TODO).
- Backup/Restore: rely on operator's `logical-backup` CronJob (noch nicht konfiguriert).

## Default Namespace („default“)
| Service | Pfad | Zweck / Bemerkung |
|---------|-----|-------------------|
| Bildergallerie | `kubernetes/apps/default/bildergallerie` | Demo-App, testet media ingress. |
| Echo-Server | `kubernetes/apps/default/echo-server` | HTTP echo for ingress troubleshooting. |
| GitLab Runner / Runner2 | `kubernetes/apps/default/gitlab-runner*` | Self-hosted GitLab CI runners. Secrets (GitLab token) via ExternalSecret. |
| Homepage | `kubernetes/apps/default/homepage` | Alte Startseite, kann ggf. ersetzt werden durch Hajimari. |

- Sicherstellen, dass default namespace kein produktives Secret enthält.
- GitLab Runner Runbook fehlt: Kapazität, token rotation, auto-update.

## System Maintenance Components
| Service | Namespace | Pfad | Notizen |
|---------|-----------|------|---------|
| System Upgrade Controller | system-upgrade | `kubernetes/apps/system-upgrade/system-upgrade-controller` | Steuert Talos/Kubernetes Upgrades über Plans unter `kubernetes/apps/system-upgrade/system-upgrade-controller/plans`. Änderung nur nach Review (Talos channel!). |
| Goldilocks (VPA) | vpa | `kubernetes/apps/vpa/goldilocks` | VPA + dashboard. Ingress? (intern). Ergebnisse in `RESOURCE_ANALYSIS.md`. |

- System Upgrade Plans definieren Node selection, versions. Before edits: run in lab, update docs.

## Tools Namespace
| Service | Pfad | Zweck / Hinweise |
|---------|-----|------------------|
| Headscale | `kubernetes/apps/tools/headscale` | TailScale-compatible control plane. Secrets via ExternalSecret (`headscale-secret`). Ingress? Check values. |
| Pod Cleaner | `kubernetes/apps/tools/pod-cleaner` | CronJob cleaning old pods (evicts Completed/Failed). Ensure it ignores critical namespaces. |
| SMTP Relay | `kubernetes/apps/tools/smtp-relay` | Provides SMTP endpoint for alerts/emails. Secrets (SMTP creds) per ExternalSecret. Document upstream provider. |
| Spoolman | `kubernetes/apps/tools/spoolman` | Filament inventory for 3D printing. Ingress internal. Ensure PVC/backups exist. |

## Test Namespace
| Service | Pfad | Zweck |
|---------|-----|-------|
| airgapped_tools_updater | `kubernetes/apps/test/airgapped_tools_updater` | Validates tool upgrades offline. |
| Keycloak | `kubernetes/apps/test/keycloak` | Identity experiments (nicht produktiv). |
| oauth2-proxy | `kubernetes/apps/test/oauth2-proxy` | Proxy experiments. |

- Regeln: Keine produktiven Secrets wiederverwenden; Ressourcen nach Tests entfernen. Setup Cron to delete old namespaces? (TODO).

## Betrieb & Runbooks
- Cert-Manager:
  - Monitor `kubectl -n cert-manager get certificaterequests,orders,challenges`.
  - `docs/runbooks.md` → Zertifikat erneuern.
- GitLab Runner:
  - Document tokens under `docs/secrets.md`.
  - Setup alert for `runner not registered`.
- Goldilocks:
  - Access via `https://goldilocks.${SECRET_DOMAIN}` (falls Ingress). Export recommendations to `RESOURCE_ANALYSIS.md`.
- System Upgrade Controller:
  - Pre-check: `kubectl get plan -n system-upgrade`.
  - Runbook: create plan, watch jobs, confirm.

## Betriebshinweise
- Test-Namespaces nie mit Prod Secrets koppeln; optional `networkpolicy` to restrict.
- Keep `default` namespace minimal; prefer dedicated namespaces for new services.
- Document headscale/pod-cleaner scheduling to avoid interfering with upgrades.

## TODOs
1. Runbook für cert-manager Herausforderungstypen (HTTP/DNS-01) ergänzen.
2. GitLab Runner Kapazität & Token-Rotation dokumentieren.
3. Tools/Test Namespace regelmäßig auditieren (Cron/Task).
4. Postgres Operator usage plan – definieren, welche Apps datastores anfordern.
