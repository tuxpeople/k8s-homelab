# Monitoring & Observability

Stand: 2026-11-14, nach SSD-Migration und Wechsel der Control Plane auf Node 4.

## Aktiver Aufbau

- Im Cluster läuft [kube-prometheus-stack](../kubernetes/apps/observability/kube-prometheus-stack/app/helmrelease.yaml)
  mit Prometheus **im Agent-Modus**, Operator, node-exporter und kube-state-metrics.
  Der Agent überträgt Metriken per Remote Write an
  `http://monitoring-mqtt.lab.tdeutsch.ch:9090/api/v1/write`.
- Prometheus-Server, Grafana, Alertmanager und Loki laufen auf der VM
  `monitoring-mqtt`. Deren Quelle ist die
  [Ansible-Rolle monitoring_mqtt](https://github.com/tuxpeople/homelab-automation/tree/main/ansible/proxmox/roles/monitoring_mqtt)
  im Repo `homelab-automation`.
- [Alloy](../kubernetes/apps/observability/alloy/app/helmrelease.yaml) liest Kubernetes-Podlogs
  und Events für den zentralen Loki. [Gatus](../kubernetes/apps/observability/gatus)
  prüft die über Kyverno generierten Ingress-Endpunkte. Exportarr liefert App-Metriken.

Der [Prometheus-Agent](https://prometheus.io/docs/prometheus/latest/prometheus_agent/)
wertet keine Recording- oder Alarmregeln aus. Kubernetes-`PrometheusRule`-Objekte
werden durch Remote Write nicht automatisch auf den VM-Prometheus übertragen.
Die dort tatsächlich ausgewerteten Regeln stehen im
[VM-Regeltemplate](https://github.com/tuxpeople/homelab-automation/blob/main/ansible/proxmox/roles/monitoring_mqtt/templates/prometheus-alert-rules.yml.j2).

## Geprüfter Istzustand

Die folgenden Befunde stammen aus der laufenden Agent-Target-API und dem VM-Prometheus,
nicht nur aus den Manifesten. Neue Collector- oder Alarmkonfigurationen wurden bei
dieser Bestandsaufnahme noch nicht ausgerollt.

| Bereich | Befund |
| --- | --- |
| Scrape-Targets | 64 von 64 up |
| Neue Control Plane | API, Controller Manager und Scheduler korrekt auf `192.168.13.14` erfasst |
| Nodes | Vier node-exporter-Targets; NodeReady-Metriken für alle vier Nodes vorhanden |
| Laufzeit-Dateisystem | `/var` auf drei SATA-SSDs und der eMMC von Node 4 wird korrekt erfasst |
| Temperaturen / Unterspannung | Für alle vier CM4 vorhanden; Temperaturalarm für alle vier aktiv |
| etcd | Native Metriken unter `http://192.168.13.14:2381/metrics` erreichbar, aber bisher nicht eingesammelt |
| SSD-SMART | Keine entsprechenden Metriken vorhanden |
| eMMC-Gesundheit | `life_time` und `pre_eol_info` auf Node 4 lesbar, bisher keine Prometheus-Metriken |
| Alarmregeln | 14 aktive VM-Prometheus-Regeln; keine Regeln für Dateisystemfüllstand, NodeReady oder etcd enthalten |
| Logs | Aktuelle Kubernetes-Logs kommen im VM-Loki an; Talos-Hostdienste und Kernel sind damit nicht abgedeckt |

Bei der Prüfung lagen die CM4 bei ungefähr 82–86 °C. Die vorhandene Regel
`RaspberryPiHighTemperature` war bereits für alle vier aktiv. Die Regel verwendet
`host` in ihrer Beschreibung; den Remote-Write-Metriken der Talos-Nodes fehlt dieses
Label bislang. Ein einheitliches Hostnamen-Label würde die Meldungen verständlicher machen.

## Empfohlene Ergänzungen

1. **Vorhandene Daten nutzen und alarmieren.** Auf der VM Regeln für `/var`-Platz,
   Inodes, unerwartet schreibgeschützte Laufzeit-Dateisysteme, NodeNotReady,
   fehlende Cluster-Metriken beziehungsweise Remote-Write-Ausfall ergänzen.
   Bei Talos muss ein Readonly-Alarm gezielt `/var` prüfen; das unveränderliche
   Betriebssystem-Root ist absichtlich schreibgeschützt. Bestehende Temperatur-
   und Unterspannungsalarme beibehalten und Hostnamen-Labels vereinheitlichen.
2. **etcd anbinden.** Den bereits verfügbaren Metrics-Port über die Control-Plane-Rolle
   entdecken, statt die alte oder neue Node-IP dauerhaft in Alarmregeln einzubauen.
   Leader-Status, WAL-fsync-/Backend-Latenz und fehlgeschlagene Proposals überwachen.
   Die beabsichtigte einzelne Control Plane berücksichtigen; eine Mindestzahl von
   drei etcd-Mitgliedern wäre hier kein sinnvoller Daueralarm.
3. **Hardware-Gesundheit.** Einen kleinen SMART-Collector zuerst gegen die konkreten
   P3-1TB-SATA-SSDs testen. Nur die lokalen SSDs von Nodes 1–3 abfragen, keine
   Synology-iSCSI-LUNs oder die ungenutzte USB-HDD. Ein Polling alle fünf Minuten
   ist für die Gesundheitswerte ein ressourcenschonender Ausgangspunkt.
   Für eMMC die eigenen Lebensdauer-/Vorwarnwerte aus sysfs erfassen;
   SATA-SMART ersetzt diese Werte nicht. Node 4 hat dabei Priorität.
4. **Talos-Dienste und Kernel protokollieren.** Native Dienstlogs, insbesondere etcd,
   containerd und machined, sowie Disk-/Dateisystemfehler des Kernels zentral erfassen.
   Talos-JSON-Logs benötigen einen passenden Eingang; der vorhandene RFC-Syslog-
   Eingang auf der VM ist nicht automatisch ein Talos-JSON-Eingang.
5. **Backups überwachen.** Regelmäßige externe Talos-etcd-Sicherungen mit Erfolgszeitpunkt
   und Alarm bei veralteter Sicherung automatisieren. Die Migration hat geprüfte
   externe Snapshots erstellt; in diesem Cluster-Repo ist bislang kein regelmäßiger
   Talos-etcd-Backup-Job konfiguriert.

Für die Darstellung genügt ein kompaktes Talos-Dashboard auf der vorhandenen Grafana-VM:
Nodes und Temperaturen, `/var` je Medium, SSD-/eMMC-Gesundheit, etcd und Backup-Frische.
Ein vollständiger zusätzlicher Prometheus-/Grafana-Stack auf den CM4 ist dafür nicht nötig.

## Ressourcenbedarf der Logsammlung

Alloy läuft derzeit als DaemonSet, während seine Kubernetes-Discovery jeweils alle
Pods und Events betrachtet. Die Konfiguration enthält weder einen Filter auf den
lokalen Node noch Clustering. Dadurch wird dieselbe Logsammlung mehrfach ausgeführt.
Da der Collector über die Kubernetes-API liest, wäre ein einzelnes Deployment eine
passende Vereinfachung; alternativ müssten Discovery und Event-Sammlung gezielt
aufgeteilt werden. Talos-Hostlogs sollten über einen eigenen, getesteten Eingang
auf der VM angebunden werden.

## Betrieb

- Cluster-Änderungen erfolgen über die aktiven Manifeste und Flux; die früheren
  Charts unter `archive/apps/observability` bleiben historische Konfigurationen.
- VM-Scrapes, Alarmregeln, Benachrichtigungen und Dashboard-Provisionierung werden
  in der Rolle `monitoring_mqtt` gepflegt. Keine Alarmwirkung allein aus vorhandenen
  Kubernetes-`PrometheusRule`-Objekten ableiten.
- Nach Änderungen Target-Status, Eingang frischer Daten auf der VM und die dort
  geladenen Regeln prüfen. Dashboards und Alarme gemeinsam mit Änderungen versionieren.
- Neue Services dokumentieren ihre Metriken, Alarmbedingungen und Dashboard-Zuordnung.
