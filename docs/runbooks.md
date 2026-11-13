# Runbooks

> Detaillierte Schrittfolgen für die häufigsten Betriebsaufgaben. Ergänze Ergebnis/Datum nach jeder Durchführung.

## Flux Drift / Sync Fehler

1. `flux get ks -A` prüfen → betroffene Kustomization identifizieren.
2. `flux logs --kind Kustomization --name <name> -n flux-system`.
3. `git status` / `git log -1` prüfen → stimmt Git mit Cluster?
4. Fix anwenden, `git commit`, `task reconcile`.
5. Erfolg via `flux get hr -A` validieren, Ergebnis dokumentieren.

## CM4: langsame Pod-Starts und Helm-Retry-Schleifen

Bei vielen gleichzeitigen Pod-Neustarts zuerst Evictions, Image-Pulls, CSI,
CPU-/I/O-Druck und Temperatur prüfen. Im Vorfall vom 2026-11-13 verursachten
Kyverno-JSONPatch-Autogen-Regeln Admission-Fehler; Descheduler-Evictions und
unbegrenzte parallele Image-Pulls verstärkten anschließend die Kaltstarts.

1. Fehlgeschlagene HelmReleases und die Events der betroffenen Pods prüfen.
   `ContainerCreating` allein benennt noch keine Ursache: Mounts, Image-Pulls
   und Container-Runtime getrennt untersuchen.
2. Bei wiederholten `LowNodeUtilization`-Evictions den Descheduler vorübergehend
   pausieren: `kubectl --context turingpi scale deployment descheduler -n kube-system --replicas=0`.
   Den Git-Sollzustand beachten; die Pause ist kein dauerhafter Fix.
3. Talos-Dienste, `/proc/pressure/cpu`, `/proc/pressure/io` und
   `/sys/class/thermal/thermal_zone0/temp` lesen. Talos `read` jeweils mit
   genau einem Node aufrufen. Temperaturen werden in Milligrad Celsius geliefert.
4. Die Kubelet-Konfiguration begrenzt jetzt `maxParallelImagePulls` auf `2`
   bei `serializeImagePulls: false`. Änderungen gezielt mit Talos-Dry-Run
   prüfen und nodeweise mit `--mode=no-reboot` anwenden. Dabei kann Kubelet
   kurz neu starten; danach Ready-Zustand und wirksame Konfiguration prüfen.
5. Paperless und Tautulli verwenden für Installation und Upgrade
   `RetryOnFailure` mit fünf Minuten Retry-Intervall und deaktiviertem
   Upgrade-`cleanupOnFail`. Langsame Starts sollen keine wiederholten
   Helm-Deinstallationen samt chartverwalteter PVCs auslösen.
   Der Zustand bleibt bei Fehlern zur Diagnose erhalten; nach einem schlechten
   Upgrade kann eine manuelle Korrektur oder ein Rollback erforderlich sein.
6. Vor erneuter Descheduler-Aktivierung die neue Policy mit derselben
   Descheduler-Version einmalig unter `--dry-run --descheduling-interval=0s`
   prüfen. Die Policy deaktiviert Last-/Topology-Balancing, schützt PVC-Pods,
   Jobs und zentrale Infrastruktur-Namespaces, berücksichtigt NodeFit und
   erlaubt höchstens eine Eviction pro Lauf bei mindestens einer Stunde Pod-Alter.
7. Abschließend Ready-Zustände von Nodes, HelmReleases, Kustomizations und
   ExternalSecrets sowie tatsächliche Pod-Bereitschaft prüfen. Neue Events und
   Neustartzähler während einer Beobachtungsphase vergleichen.

Metrics Server fragt Kubelets alle 30 Sekunden ab und erlaubt zehn Sekunden
Antwortzeit. Der vorherige Zwei-Sekunden-Timeout führte auf den belasteten CM4
zu fehlenden Node-Metriken trotz bereiter Pods. Nach Änderungen an diesen
Werten `kubectl --context turingpi top nodes` und die Scraper-Logs prüfen.
Die Health-Endpunkte sind explizit von der API-Autorisierung ausgenommen;
Probes erlauben fünf Sekunden Antwortzeit und die Liveness-Probe startet erst
nach einer Minute. Damit lösen kurze API-Verzögerungen und die erste
Messwertsammlung keine unnötigen Neustarts aus.

Referenzen: [Image-Pull-Limits](https://kubernetes.io/docs/concepts/containers/images/#maximum-parallel-image-pulls),
[Flux Retry-Strategien](https://fluxcd.io/flux/components/helm/helmreleases/#install-strategy),
[Descheduler v0.37](https://github.com/kubernetes-sigs/descheduler/blob/v0.37.0/README.md).

Bei Tautulli zusätzlich den Container `jbops` prüfen. Git-sync läuft mit UID
568 auf einem über fsGroup beschreibbaren, aber root-eigenen `emptyDir`.
`GITSYNC_GIT_CONFIG: safe.directory:/add-ons` erlaubt Git gezielt dieses
gemeinsame Repository-Verzeichnis und verhindert den CrashLoop mit
`detected dubious ownership`. Kein globales `safe.directory: '*'` verwenden.

### Ergebnis der Stabilisierung am 2026-11-13

Die Korrekturen wurden mit `2a2062799` (Kyverno) und `0f6ecea4c`
(Kaltstarts, Descheduler, Helm-Retries und Tautulli-Git-sync) nach `main`
übernommen und durch Flux ausgerollt. Das Image-Pull-Limit wurde zusätzlich
auf allen vier Nodes per Talos-Patch ohne Reboot angewendet und anhand der
wirksamen Kubelet-Konfiguration bestätigt. Lokale MachineConfigs wurden neu generiert.

Abschlussprüfung: 50/50 HelmReleases, 58/58 Kustomizations und alle 96 aktiven
Pods bereit; keine Kustomization suspendiert. Alle Nodes sind Ready,
für Scheduling freigegeben und ohne Disk-, Memory- oder PID-Druck.
Zwischen den Pod-Aufnahmen um 18:47 und 19:31 UTC gab es keine zusätzlichen
Container-Neustarts. Zwei Descheduler-Läufe um 19:24 und 19:29 UTC meldeten
jeweils null Evictions. Tautulli-Git-sync hat JBOPS erfolgreich synchronisiert;
ExternalSecrets meldeten keine Fehler. Temporäre Dry-Run-Ressourcen wurden entfernt.

Verbleibende Beobachtungen: Die Audit-Policy `restrict-privileged` meldet
die Host-Zugriffe des Prometheus-Node-Exporters; sie blockiert den Betrieb nicht.
Während der Lastspitze wurden auf Node 2 etwa 86 °C und auf Node 4 etwa
90 °C gemessen. Auch nach der Erholung lagen mehrere Module noch um 86 °C.
Die physische Kühlung ist vor einem größeren Umbau zu prüfen.
Mit dem korrigierten Metrics-Server-Timeout wurden wieder Werte aller vier Nodes
geliefert. Beim Rollout zeigten sich zusätzlich zu kurze Health-Probes;
deren Wartezeiten und Autorisierung wurden entsprechend angepasst.
Storage-Layout und Node-Rollen wurden nicht geändert.

## Talos Node Exchange

1. Backup wichtiger Daten prüfen (Synology Snapshots, Litestream-Replikation, App-spezifische Backups gemäss `docs/backups.md`).
2. Node in Maintenance: `talosctl cordon <ip>` + `kubectl drain` (mit PodDisruptionBudgets prüfen).
3. `talosctl reset --graceful`.
4. Hardware tauschen / OS flashen → `task talos:apply-node IP=<ip>`.
5. Nach Join: `kubectl get nodes`, Flux Sync abwarten.

## Namespace hängt in Terminating

1. `kubectl get namespace <ns> -o json | jq '.status.conditions'` prüfen → oft nennt die Message bereits Kind/Anzahl der blockierenden Objekte.
2. Umfassende Suche über alle namespaced Resource-Typen (deckt CRDs/Secrets/RBAC ab, die `kubectl get all` verpasst): `task debug:stuck-namespace NS=<ns>`.
3. Gefundenes Objekt prüfen: `kubectl get <kind>/<name> -n <ns> -o jsonpath='{.metadata.finalizers}'`.
4. Verantwortlichen Controller/Operator reaktivieren, oder falls das Objekt wirklich weg soll: `kubectl patch <kind>/<name> -n <ns> --type=merge -p '{"metadata":{"finalizers":[]}}'`.
5. Bleibt nur noch der Namespace selbst in Terminating hängen (Content bereits weg, aber `metadata.finalizers` auf dem Namespace-Objekt gesetzt, z. B. `controller.cattle.io/namespace-auth` von einem entfernten Rancher): `kubectl patch namespace <ns> --type=merge -p '{"metadata":{"finalizers":[]}}'`. Server-Side-Apply reicht hier nicht, da der Finalizer-Eintrag einem fremden Field-Manager gehört.

## PVC / Storage Degraded

1. `kubectl get pvc -A` und Events der betroffenen App prüfen.
2. Synology/democratic-csi Status prüfen: iSCSI/NFS erreichbar, StorageClass korrekt, Node-Mounts fehlerfrei?
3. Falls Node betroffen: cordon/drain, App auf anderem Node neu starten lassen.
4. Falls Volume beschädigt: Restore aus Synology Snapshot oder App-spezifischem Backup gemäss `docs/backups.md`.
5. Alert schliessen, Ursache und Restore-Schritte in `docs/backups.md` protokollieren.

## Backup-Tests / Restore-Verifikation

> Siehe `docs/backups.md` Testplan und App-spezifische Hinweise.

### Synology / democratic-csi Volume Restore

1. Snapshot oder Backup auf Synology auswählen.
2. Test-PVC oder temporäres Restore-Ziel anlegen.
3. Temporären Pod/Deployment mit wiederhergestelltem PVC deployen und fachlichen Smoke-Test ausführen.
4. Ergebnisse protokollieren, Testartefakte entfernen (Pod, PVC), Snapshot optional behalten.

### Litestream SQLite Restore

1. Betroffene App und Replica-Pfad in `docs/backups.md` bzw. App-Werten prüfen.
2. Restore in temporäres Verzeichnis oder Testnamespace ausführen, bevor produktive Daten überschrieben werden.
3. Anwendung gegen wiederhergestellte DB starten und fachlichen Smoke-Test ausführen.
4. Ergebnisse protokollieren und Testartefakte entfernen.

### Namespace / GitOps Restore

1. Zielnamespace in einem Testlauf löschen oder in separatem Cluster simulieren.
2. `flux reconcile kustomization <app> --with-source -n <namespace>` ausführen.
3. Secrets, PVCs, Ingress und Gatus Endpoint prüfen.
4. Fachlichen Smoke-Test durchführen und Ergebnis dokumentieren.

### Vollständige DR-Übung (BT-DR-01)

1. Szenario definieren (Cold Start/Partial) & Kommunikationskanal festlegen.
2. Talos bootstrap (Nodes vorbereiten) → `task bootstrap:talos` → `task bootstrap:apps`.
3. Storage-, Litestream- und App-spezifische Restores durchführen, Services testen.
4. Lessons Learned in `docs/dr.md` + `docs/backups.md` festhalten.

## External Secret schlägt fehl

1. `kubectl -n <ns> describe externalsecret <name>`.
2. Logs `kubectl -n security logs deploy/external-secrets -f`.
3. 1Password Item prüfen (Name, Feld, Rechte).
4. Bei Auth-Fehler: `onepassword-connect` Pods neustarten.
5. Nach Fix: `kubectl -n <ns> get secret <name> -o yaml` verifizieren (SOPS-Block?).

## Zertifikat erneuern

1. `kubectl -n cert-manager get certificates` → Ablaufdatum.
2. Problem: `kubectl describe certificate <name>`; oft Rate-Limit.
3. Workaround: DNS-Records/Ingress prüfen, dann `kubectl -n cert-manager delete challenge <...>`.
4. Erneut ausstellen lassen (`kubectl -n cert-manager create certificaterequest ...` falls nötig).

## Paperless Stau

1. Monitoring: Paperless Queue > 100? Alerts in Grafana.
2. `kubectl -n productivity logs deploy/paperless-app` → Worker Fehler?
3. `kubectl -n productivity rollout restart deploy/paperless-app` (falls Memory Leak) – nur nach Backup.
4. Status + Ursache im Service-Dokument `services/applications-productivity.md` protokollieren.

## Mediabox Ingress Probleme

1. `kubectl -n media get ingress` – sind Hosts korrekt?
2. `kubectl -n network logs deploy/external-traefik -f | grep <host>`.
3. DNS: `dig <host> @192.168.13.1` (UniFi Gateway) oder `dig <host> @192.168.13.5` (Pi-hole) für intern bzw. Cloudflare für extern.
4. Zertifikate? s. Abschnitt oben.
5. Ggf. `kubectl -n media get httproute` falls Gateway-API genutzt wird.

## Dokumentations-Review

1. Bei jeder Feature-Änderung `docs/` durchsuchen (`rg -l <service>`), Aktualität prüfen.
2. Fehlende Infos → GitHub Issue erfassen (passendes `area/*`-Label).
3. Commit erst nach aktualisiertem `CHANGELOG`.
