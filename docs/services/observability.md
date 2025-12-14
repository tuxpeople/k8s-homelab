# Observability Services

## Komponentenübersicht (alle Namespace `observability`)
| Service | Pfad | Zweck / Besonderheiten |
|---------|------|-----------------------|
| kube-prometheus-stack (**aktiv**) | `kubernetes/apps/observability/kube-prometheus-stack` | Basis-Stack (Prometheus, Alertmanager, Grafana, node-exporter, kube-state-metrics). Retention 15 d (anpassen?). |
| Grafana (**aktiv**) | `kubernetes/apps/observability/grafana` | UI + alerting rules. Dashboards als configmaps/sidecar. Secret `grafana-admin` (SOPS). |
| Alertmanager Discord Relay | `kubernetes/apps/observability/alertmanager-discord` | Sends alert payloads → Discord webhook (secret `alertmanager-config`). |
| Gatus | `kubernetes/apps/observability/gatus` | Synthetic HTTP/S/ICMP checks + status page. Automatische Endpoint-Generierung via Kyverno Policies. |
| Blackbox Exporter | `kubernetes/apps/observability/blackbox-exporter` | Generic probes (used by Prometheus + Gatus). |
| Pushgateway | `kubernetes/apps/observability/pushgateway` | For ad-hoc metrics (jobs). |
| Speedtest Exporter | `kubernetes/apps/observability/speedtest-exporter` | Schedules Speedtest CLI. |
| SNMP Exporter | `kubernetes/apps/observability/snmp-exporter` | Scrapes Synology/Networking gear. |
| Media Exporter Suite | `kubernetes/apps/observability/*-exporter` | radarr/sonarr/sabnzbd/tautulli/plex/prowlarr metrics consumed by dashboards. |

## Datenquellen & Dashboards
- Haupt-Datasource: Prometheus (from kube-prom-stack). Additional datasources via Helm values (Longhorn, Miniflux, etc.).
- Grafana Dashboards (IDs, JSON) liegen aktuell nicht versioniert → TODO: export nach `grafana/dashboards/`.
- Kern-Dashboards:
  - `Kubernetes / Control Plane`
  - `Storage / Longhorn`
  - `Media Stack`
  - `Automation & GitOps`
  - `Backups`
- Login: Grafana admin creds via Secret `grafana-admin` (SOPS) – 2FA empfohlen.

## Alerting & Eskalation
- Alertmanager config (SOPS) sendet:
  - `critical` → Discord #k8s-alerts + push notification.
  - `warning` → Discord message.
  - Silences pflegen via Grafana or `alertmanager` UI.
- Wichtige Rules:
  - Flux Kustomization degrade
  - NodeReady / KubeComponentDown
  - Backup job failures (K8up/Velero)
  - Gatus endpoint down
  - Disk pressure / PVC usage > 80 %
  - External services (Cloudflared, Speedtest)
- SLO/Ticket-Flow: definieren in `docs/monitoring.md` (TODO #4).

## Gatus Endpoint Management

Gatus-Endpoints werden automatisch für alle Ingresses via Kyverno Policies generiert:

### Automatische Generierung

- **Trigger**: Alle Ingresses mit `ingressClassName: internal` oder `ingressClassName: external`
- **Policies**: `kubernetes/apps/security/kyverno/policies/gatus-internal.yaml` und `gatus-external.yaml`
- **Ergebnis**: ConfigMap `<ingress-name>-gatus-ep` mit Label `gatus.io/enabled: "true"`

### Ausschluss von Monitoring

Ingresses vom Gatus-Monitoring ausschließen:

1. **Namespace-basiert**: Alle Ingresses im Namespace `test` werden automatisch ignoriert
2. **Annotation-basiert**: Ingress mit Annotation `gatus.io/enabled: "false"` versehen

### Customization Annotations

- `gatus.io/host`: Überschreibt Host aus Ingress spec
- `gatus.io/path`: Überschreibt Path aus Ingress spec
- `gatus.io/name`: Überschreibt Endpoint-Name
- `gatus.io/status-code`: Überschreibt erwarteten HTTP Status Code (default: 200)

**Beispiel**:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    gatus.io/path: /health
    gatus.io/status-code: "204"
spec:
  ingressClassName: internal
  rules:
    - host: my-app.eighty-three.me
```

### Health-Check

```bash
# Gatus ConfigMaps anzeigen
kubectl get cm -A -l gatus.io/enabled=true

# Gatus Endpoints testen
kubectl -n observability port-forward svc/gatus 8080:80
# Browser: http://localhost:8080
```

## Betrieb & Wartung

1. **Upgrades**:
   - `flux reconcile kustomization kube-prometheus-stack --with-source -n observability`.
   - Vorher `flux diff hr kube-prometheus-stack`.
2. **Dashboards**: Neue Panels exportieren via Grafana UI → `git add` (noch offen).
3. **Exporter hinzufügen**:
   - HelmRelease / Deployment im Namespace `observability`.
   - Service + `ServiceMonitor`.
   - Dashboard & alerts anlegen.
4. **Secrets**: Grafana/Alertmanager/Discord Webhook in SOPS-Dateien pflegen (`*.sops.yaml`), `sops` rewrap vor Commit.

## Monitoring der Monitoring-Stack
- Prometheus targets → `/-/healthy`, `/-/ready`.
- Grafana health check via Gatus.
- Alertmanager route status `http://alertmanager.observability.svc:9093/#/status`.
- Ensure `pushgateway` cleaned up (job TTL). Cron to delete stale metrics? (TODO).

## TODOs / Verbesserungen
- Versionierte Grafana Dashboards + automated sync (e.g., `grafana-dashboard-loader`).
- Logging/Tracing Stack (Loki / Tempo / OpenSearch) evaluieren (Backlog DOC-006).
- Define Service Level Objectives + error budget policies (Backlog DOC-001).
- Add alert coverage for `speedtest-exporter` job failures + SNMP target loss.
