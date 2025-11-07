# Disaster Recovery (DR)

## Ziele
- **RTO**: < 4h für Control-Plane (Talos + Flux) / < 8h für kritische Apps.
- **RPO**: ≤ 24h für Medien/Produktivdaten, ≤ 1h für Cluster-Konfiguration (Git = Source of Truth).

## Szenarien
1. **Kompletter Cluster-Ausfall** (Hardware, Storage):
   - Talos-Cluster nach `talos/talconfig.yaml` + `talos/clusterconfig/` neu provisionieren (`task bootstrap:talos`).
   - Flux neu bootstrappen: `task bootstrap:apps` bzw. `flux bootstrap git ...` falls notwendig.
   - Longhorn/Synology Storage mounten, PVCs per Velero/Restic wiederherstellen.
2. **Single Node Fail**:
   - Node taints → workloads evakuiert.
   - Talos `talosctl reset` + Reprovision laut Runbook (siehe `runbooks.md`).
3. **GitOps-Drift / zerstörte Manifeste**:
   - Git-History revertieren, `task reconcile`, `flux get ks -A` prüfen.
   - Notfalls `flux suspend/resume` nutzen.
4. **Secrets kompromittiert**:
   - Age Key neu erzeugen, alle SOPS-Secrets re-encrypten.
   - 1Password Tokens rotieren, Talos Secrets aktualisieren.

## Pflicht-Ressourcen außerhalb des Clusters
- `age.key` Backup im Passwort-Manager + Offline.
- Talos `clusterconfig`-Artefakte.
- S3/Ceph/MinIO Storage für Restic/Velero.
- DNS / Cloudflare API Token.

## Wiederherstellungsablauf (Kurzform)
1. Hardware bereitstellen, Talos Image flashen, Nodes booten.
2. `task talos:generate-config` (falls Version gewechselt) → `task talos:apply-node`.
3. Control Plane online → kubeconfig unter `kubeconfig` verifizieren.
4. Flux bootstrap → Warte auf Sync (`flux get kustomizations -A`).
5. Storage Schicht prüfen (Longhorn UI, Synology).
6. Backups / Restores je Namespace.
7. Gatus / Monitoring / Dashboards checken.
8. Abschlussbericht in `docs/CHANGELOG.md` + Post Mortem.

## Tests & Übungen
- Mind. jährliche DR-Übung (siehe Backlog DOC-008).
- Testplan = "Cold Start" (alle Nodes neu) + "Namespace Restore" (Paperless, Mediabox).

## Kommunikation
- Status-Updates in privatem Mattermost/Discord.
- Nach erfolgreicher Wiederherstellung Lessons Learned dokumentieren (`IMPROVEMENT_PLAN.md`).
