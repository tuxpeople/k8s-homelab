# Runbooks

> Detaillierte Schrittfolgen für die häufigsten Betriebsaufgaben. Ergänze Ergebnis/Datum nach jeder Durchführung.

## Flux Drift / Sync Fehler
1. `flux get ks -A` prüfen → betroffene Kustomization identifizieren.
2. `flux logs --kind Kustomization --name <name> -n flux-system`.
3. `git status` / `git log -1` prüfen → stimmt Git mit Cluster?
4. Fix anwenden, `git commit`, `task reconcile`.
5. Erfolg via `flux get hr -A` validieren, Ergebnis dokumentieren.

## Talos Node Exchange
1. Backup wichtiger Daten (Longhorn Replizierung sicherstellen).
2. Node in Maintenance: `talosctl cordon <ip>` + `kubectl drain` (mit PodDisruptionBudgets prüfen).
3. `talosctl reset --graceful`.
4. Hardware tauschen / OS flashen → `task talos:apply-node IP=<ip>`.
5. Nach Join: `kubectl get nodes`, Flux Sync abwarten.

## Longhorn Volume Degraded
1. Longhorn UI → Volume Details (Replica Health).
2. Ursache feststellen (Node down? Disk voll?).
3. Falls Node ok → Replica rebuild via UI.
4. Falls Disk defekt → Node cordon + Disk entfernen, Replacement.
5. Alert schließen, `backups.md` Eintrag aktualisieren falls Restore nötig war.

## Backup-Tests / Restore-Verifikation
> Siehe `docs/backups.md` Testplan (BT-LH-01, BT-K8-01, BT-VL-01, BT-DR-01).

### Longhorn Snapshot (BT-LH-01)
1. Snapshot wählen oder neu erstellen (`Volumes → Snapshots → Create`).
2. Snapshot → Create Backup → über "Backups" als neues Volume (`<volume>-bt`) restoren.
3. Temporären Pod/Deployment mit wiederhergestelltem PVC deployen und fachlichen Smoke-Test ausführen.
4. Ergebnisse protokollieren, Testartefakte entfernen (Pod, PVC), Snapshot optional behalten.

### K8up Restic (BT-K8-01)
1. `kubectl -n storage get schedule` → Schedule auswählen.
2. `k8up job run --schedule <name> --restore --restore-pvc <target>` ausführen (Namespace `<ns>-restore`).
3. Anwendung in Testnamespace prüfen, Logs auf Fehler kontrollieren.
4. Namespace/PVC löschen, Tabelle in `docs/backups.md` aktualisieren.

### Velero Namespace Restore (BT-VL-01)
1. `velero backup get` und geeigneten Backup-Run wählen.
2. `velero restore create bt-<date> --from-backup <backup> --namespace-mappings <ns>:<ns>-restore`.
3. Prüfen, ob Ressourcen/Pods sauber starten; `velero restore logs` sichern.
4. Testnamespace löschen, Ergebnisse dokumentieren.

### Vollständige DR-Übung (BT-DR-01)
1. Szenario definieren (Cold Start/Partial) & Kommunikationskanal festlegen.
2. Talos bootstrap (Nodes vorbereiten) → `task bootstrap:talos` → `task bootstrap:apps`.
3. Longhorn/K8up/Velero Restores durchführen, Services testen.
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
2. `kubectl -n network logs deploy/external-ingress-nginx -f | grep <host>`.
3. DNS: `dig <host> @192.168.13.65` (intern) bzw. Cloudflare.
4. Zertifikate? s. Abschnitt oben.
5. Ggf. `kubectl -n media get httproute` falls Gateway-API genutzt wird.

## Dokumentations-Review
1. Bei jeder Feature-Änderung `docs/` durchsuchen (`rg -l <service>`), Aktualität prüfen.
2. Fehlende Infos → `WEITERENTWICKLUNG.md` + Issue/Task.
3. Commit erst nach aktualisiertem `CHANGELOG`.
