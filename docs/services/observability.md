# Observability Services

## Aktiver Aufbau

Im Cluster laufen Prometheus-Agent, Prometheus Operator, node-exporter,
kube-state-metrics, Alloy, Gatus und die aktiven Exportarr-Exporter.
Prometheus-Server, Grafana, Alertmanager und Loki laufen auf der VM `monitoring-mqtt`.
Deren Deployment wird durch die
[Ansible-Rolle monitoring_mqtt](https://github.com/tuxpeople/homelab-automation/tree/main/ansible/proxmox/roles/monitoring_mqtt)
im Repo `homelab-automation` verwaltet.

| Komponente | Quelle | Aufgabe |
| --- | --- | --- |
| Prometheus-Agent und Basis-Exporter | `kubernetes/apps/observability/kube-prometheus-stack` | Metriken einsammeln und an die VM übertragen |
| Prometheus / Grafana / Alertmanager / Loki | externe VM, Rolle `monitoring_mqtt` | Speicherung, Regeln, Benachrichtigungen, Dashboards und Logs |
| Alloy | `kubernetes/apps/observability/alloy` | Kubernetes-Podlogs und Events an Loki übertragen |
| Gatus | `kubernetes/apps/observability/gatus` | Synthetische Ingress-Checks und Statusseite |
| Exportarr | `kubernetes/apps/observability/exportarr` | Sonarr-, Radarr-, Prowlarr- und SABnzbd-Metriken |

Die Konfigurationen unter `archive/apps/observability` beschreiben frühere
Cluster-Deployments und sind nicht der aktuelle Laufzeitstand.

## Metriken und Alarme

Der Agent schreibt nach `http://monitoring-mqtt.lab.tdeutsch.ch:9090/api/v1/write`;
seine externen Labels identifizieren den Cluster als `turingpi`.
Er wertet selbst keine Alarmregeln aus. Die tatsächlichen Prometheus-Regeln werden
auf der VM aus dem Ansible-Template `prometheus-alert-rules.yml.j2` geladen;
Alertmanager ist dort aktiv.

Die [Monitoring-Übersicht](../monitoring.md) hält die Live-Prüfung nach der
SSD-/Control-Plane-Migration, die am 2026-11-15 ergänzte etcd-/Storage-Alarmierung
und die noch fehlenden Hardware-Gesundheitsmetriken fest. Die vorhandene Temperaturüberwachung erfasst bereits
alle vier CM4. Talos-Hostdienst- und Kernel-Logs benötigen zusätzlich eine eigene
Anbindung; die bestehende Kubernetes-Logsammlung deckt diese nicht ab.

## Gatus Endpoint Management

Gatus-Endpoints werden automatisch für alle Ingresses via Kyverno Policies generiert:

### Automatische Generierung

-   **Trigger**: Alle Ingresses mit `ingressClassName: internal` oder `ingressClassName: external`
-   **Policies**: `kubernetes/apps/security/kyverno/policies/gatus-internal.yaml` und `gatus-external.yaml`
-   **Ergebnis**: ConfigMap `<ingress-name>-gatus-ep` mit Label `gatus.io/enabled: "true"`

### Veraltete Endpoint-ConfigMaps

Die ConfigMap trägt im Label `generate.kyverno.io/trigger-uid` die UID des Ingress, aus dem sie erzeugt wurde.
Wird ein Ingress gelöscht und neu erstellt, ohne dass Kyverno das Löschen mitbekommt, bleibt die alte
ConfigMap stehen und wird nicht mehr aktualisiert. Gatus prüft dann weiter, aber Änderungen an den
`gatus.io/*`-Annotations kommen nicht mehr an.

Der CronJob `kubernetes/apps/tools/gatus-ep-reconciler` prüft das stündlich:

-   **Stale** (Ingress existiert mit anderer UID): ConfigMap löschen, Ingress kurz mit
    `gatus-ep-reconciler/retrigger` annotieren, bis Kyverno neu erzeugt hat, Annotation wieder entfernen.
-   **Orphan** (Ingress existiert nicht mehr): ConfigMap löschen.
-   Wird eine ConfigMap nicht innerhalb von 60 s neu erzeugt, schlägt der Job fehl.

```bash
# Manuell auslösen und Log ansehen
kubectl -n tools create job --from=cronjob/gatus-ep-reconciler gatus-ep-reconciler-manual
kubectl -n tools logs job/gatus-ep-reconciler-manual
```

### Ausschluss von Monitoring

Ingresses vom Gatus-Monitoring ausschliessen:

1. **Namespace-basiert**: Alle Ingresses im Namespace `test` werden automatisch ignoriert
2. **Annotation-basiert**: Ingress mit Annotation `gatus.io/enabled: "false"` versehen

### Customization Annotations

-   `gatus.io/host`: Überschreibt Host aus Ingress spec
-   `gatus.io/path`: Überschreibt Path aus Ingress spec
-   `gatus.io/name`: Überschreibt Endpoint-Name
-   `gatus.io/status-code`: Überschreibt erwarteten HTTP Status Code (default: 200)

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

- Cluster-Konfigurationen über Flux und die aktiven HelmReleases pflegen.
- VM-seitige Scrapes, Regeln, Benachrichtigungen und Dashboard-Provisionierung
  in `homelab-automation` ändern; dafür die dortigen Betriebs- und Ansible-Regeln beachten.
- Nach Änderungen die aktiven Targets im Agenten und den Eingang auf dem
  VM-Prometheus prüfen. Geladene Alarmregeln separat auf der VM kontrollieren.
- Für neue Exporter ServiceMonitor, sinnvolle Alarmbedingungen und die Grafana-
  Darstellung gemeinsam berücksichtigen; PrometheusRule-Objekte werden durch
  Remote Write nicht auf den VM-Prometheus übertragen.
