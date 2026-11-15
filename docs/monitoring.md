# Monitoring & Observability

Stand: 2026-11-15, nach SSD-Migration und Ergänzung der Talos-Basisalarme.

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

## Umsetzung am 2026-11-15

- [ScrapeConfig talos-etcd](../kubernetes/apps/observability/kube-prometheus-stack/app/talos-etcd.yaml)
  entdeckt Nodes mit `node-role.kubernetes.io/control-plane` und liest ihre interne
  IP auf Port 2381 aus. Der aktuelle Target ist Node 4; eine spätere Rollenänderung
  benötigt keine statische IP-Anpassung. `job="talos-etcd"`, `host` und das externe
  Cluster-Label identifizieren die Metriken auf der VM.
- Der node-exporter-ServiceMonitor erhält ebenfalls das Kubernetes-Node-Label `host`,
  damit bestehende Temperatur-/Unterspannungsalarme einen Hostnamen anzeigen können.
- Die VM lädt zusätzlich die Gruppe `talos-turingpi` mit **16 Regeln**: fehlender
  Cluster-Datenstrom, unvollständiges Node-/Exporter-/Dateisysteminventar,
  NodeNotReady, Exporter-Ausfall, `/var`-Platz/Inodes/Readonly und etcd-Ausfall,
  fehlender Leader, WAL-/Backend-Latenzen sowie fehlgeschlagene Proposals.
- Warnung unter 15 % freiem `/var`-Platz beziehungsweise 10 % freien Inodes;
  kritisch unter 5 % beziehungsweise 3 %. Latenzwarnungen prüfen das 99. Perzentil
  über fünf Minuten: WAL-fsync über 10 ms, Backend-Commit über 25 ms, jeweils
  zehn Minuten anhaltend. Diese Werte sind in der Ansible-Rolle konfigurierbar.
- Deployment über das eigene Playbook `monitoring-prometheus-rules.yml` in
  `homelab-automation`: promtool validiert vor dem Ersetzen der Datei, eine Sicherung
  bleibt erhalten, nur Prometheus wird bei Änderungen neu gestartet. Der anschliessende
  Check war unverändert. Acht promtool-Verhaltenstests und ansible-lint bestanden.

Live bestätigt: etcd-Target auf Node 4 erreichbar, `etcd_server_has_leader = 1`
und WAL-/Backend-Metriken kommen auf der VM an. Alle vier Nodes liefern `host`-Labels.
HelmRelease und Flux-Kustomization sind Ready. Alle 30 VM-Prometheus-Regeln
(14 bestehende und 16 neue) werden ohne Auswertungsfehler geladen.
Bei der Erstprüfung waren die Latenzwarnungen vorgemerkt: ungefähr 26 ms WAL-fsync
und 51 ms Backend-Commit am 99. Perzentil während der Reconciliation. Die Regeln
benötigen zehn Minuten anhaltende Überschreitung; dies ist kein Leader-Ausfall.

Neue Hardware-Collector, Talos-Hostlog-Eingänge oder Backup-Jobs gehören nicht zu
dieser Umsetzung.

## Bestandsaufnahme vom 2026-11-14

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

## Ausbau und verbleibende Ergänzungen

1. **Vorhandene Daten nutzen und alarmieren (Basis umgesetzt am 2026-11-15).** Auf der VM Regeln für `/var`-Platz,
   Inodes, unerwartet schreibgeschützte Laufzeit-Dateisysteme, NodeNotReady,
   fehlende Cluster-Metriken beziehungsweise Remote-Write-Ausfall ergänzen.
   Bei Talos muss ein Readonly-Alarm gezielt `/var` prüfen; das unveränderliche
   Betriebssystem-Root ist absichtlich schreibgeschützt. Bestehende Temperatur-
   und Unterspannungsalarme beibehalten und Hostnamen-Labels vereinheitlichen.
2. **etcd anbinden (umgesetzt am 2026-11-15).** Den bereits verfügbaren Metrics-Port über die Control-Plane-Rolle
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

## Control-Plane-Last: VPA

Goldilocks/VPA läuft ausschliesslich im Empfehlungsmodus (`updateMode: Off`).
Am 2026-11-15 waren 96 VPA-Checkpoints vorhanden. Die 15-Minuten-Baseline zeigte
ungefähr 1,38 Checkpoint-Schreibzugriffe und 0,53 VPA-Schreibzugriffe pro Sekunde.

Der [Goldilocks-HelmRelease](../kubernetes/apps/vpa/goldilocks/app/helmrelease.yaml)
setzt deshalb `vpa.recommender.extraArgs.recommender-interval: 5m` statt des
Standardwerts von einer Minute. VPA 1.7.1 koppelt Metrikabfrage, Empfehlungen und
Checkpoint-Schreiben an denselben Zyklus; ein eigenes Checkpoint-Schreibintervall
steht dort nicht zur Verfügung. Erwartet werden rund 80 % weniger periodische
Checkpoint-Schreibzugriffe. Der Kompromiss: Empfehlungen aktualisieren sich nur
alle fünf Minuten, und kurze Lastspitzen können eher unbemerkt bleiben.
Checkpoint-Historie und Empfehlungskomponenten bleiben erhalten.

Der Parameter wurde mit dem tatsächlich von Flux verwendeten Goldilocks-Chart
11.2.1 lokal gerendert. Die Wirkung muss über API-Schreibzähler und etcd-Latenzen
verglichen werden; eine geringere Schreibrate garantiert noch keine geringere
Latenz bei weiterhin hoher Temperatur oder CPU-Auslastung.

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
