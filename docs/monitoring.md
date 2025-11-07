# Monitoring & Observability

## Stack
- **Kube-Prometheus-Stack** (`kubernetes/apps/observability/kube-prometheus-stack`): Prometheus, Alertmanager, Grafana, node-exporter, kube-state-metrics.
- **Grafana** (`kubernetes/apps/observability/grafana`): Dashboards für Infrastruktur, Medien-Stack, Netzwerk, Home-Automation.
- **Exporters**: blackbox, speedtest, snmp, tautulli, radarr, sonarr, sabnzbd, plex, prowlarr, pushgateway.
- **Gatus** (`kubernetes/apps/observability/gatus`): Synthetic Checks + Statusseite.
- **Alertmanager-Discord**: Alerts → Discord Webhook.

## Kennzahlen
| Bereich | Beispiele | Ziel |
|---------|-----------|------|
| Cluster Health | API Latency, etcd, Controller Manager | grün < 200ms |
| Ressourcen | Node CPU/Mem Pressure, Pod OOM | <70% Auslastung laut RESOURCE_ANALYSIS |
| Apps | Erfolgsraten, Queue-Längen (*arr, Paperless, N8N) | definierte SLOs (TODO) |
| Uptime extern | Cloudflared, Public Ingress, DNS | 99% rolling 30d |

## Dashboards
- `Cluster / Control Plane`
- `Storage / Longhorn`
- `Media Stack`
- `AI & Productivity`
- `Backups`

> Jede neue Applikation muss einen Monitoring-Abschnitt im Service-Dokument erhalten (Metriken, Alerts, Dashboard-Link).

## Alerting-Flows
1. Prometheus Rule → Alertmanager → Discord Kanal `#k8s-alerts`.
2. Kritisch = Paging (Push Notification), Warnung = Only Message.
3. Eskalation nach 15 Minuten ohne ACK → persönliche DM.

## Logging / Tracing
- Aktuell kein zentrales Loki/OTel-Stack. TODO: Evaluieren, ob Medien- und AI-Dienste zusätzliche Logs brauchen (`WEITERENTWICKLUNG DOC-006`).

## Wartung
- `task observability:sync` (TODO) für Dashboard-Jsonnet? Derzeit manuelle sync via Grafana UI Export.
- Versionen von kube-prom-stack werden über Renovate aktualisiert – nach Update Dashboards validieren.
