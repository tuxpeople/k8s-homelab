# Runbooks

> Detaillierte Schrittfolgen für die häufigsten Betriebsaufgaben. Ergänze Ergebnis/Datum nach jeder Durchführung.

## Flux Drift / Sync Fehler

1. `flux get ks -A` prüfen → betroffene Kustomization identifizieren.
2. `flux logs --kind Kustomization --name <name> -n flux-system`.
3. `git status` / `git log -1` prüfen → stimmt Git mit Cluster?
4. Fix anwenden, `git commit`, `task reconcile`.
5. Erfolg via `flux get hr -A` validieren, Ergebnis dokumentieren.

## Talos Node Exchange

1. Backup wichtiger Daten prüfen (Synology Snapshots, Litestream-Replikation, App-spezifische Backups gemäss `docs/backups.md`).
2. Node in Maintenance: `talosctl cordon <ip>` + `kubectl drain` (mit PodDisruptionBudgets prüfen).
3. `talosctl reset --graceful`.
4. Hardware tauschen / OS flashen → `task talos:apply-node IP=<ip>`.
5. Nach Join: `kubectl get nodes`, Flux Sync abwarten.

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
3. DNS: `dig <host> @192.168.13.1` (UniFi Gateway) oder `dig <host> @10.20.30.11` (Pi-hole) für intern bzw. Cloudflare für extern.
4. Zertifikate? s. Abschnitt oben.
5. Ggf. `kubectl -n media get httproute` falls Gateway-API genutzt wird.

## Dokumentations-Review

1. Bei jeder Feature-Änderung `docs/` durchsuchen (`rg -l <service>`), Aktualität prüfen.
2. Fehlende Infos → `WEITERENTWICKLUNG.md` + Issue/Task.
3. Commit erst nach aktualisiertem `CHANGELOG`.
