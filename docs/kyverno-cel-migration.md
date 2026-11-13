# Kyverno: einmalige Umstellung auf CEL

Chart 3.10.0 installiert Kyverno 1.20. Legacy-Policies unter `kyverno.io`
werden dort nicht mehr ausgeführt. Der Acknowledge-Schalter ist kein Ersatz
für die Migration und bleibt ausgeschaltet.

Die Manifeste enthalten 14 aktive CEL-Policies unter `policies.kyverno.io/v1`.
Die vorbereitete GHCR-Policy bleibt deaktiviert. Audit bleibt Audit;
`restrict-deprecated-registry` bleibt im Modus Deny. Die Namespace-Ausnahmen
für `restrict-privileged` und `seccomp-default` gelten jetzt wie dokumentiert
auch ohne zusätzliches Exclude-Label: In den alten Regeln standen Name und
Label im selben Match-Block und waren dadurch UND-verknüpft.
`label-existing-namespaces` gilt wie bisher für alle Namespaces.

## Lokal prüfen

```bash
mise install aqua:kyverno/kyverno@1.20.0
mise exec aqua:kyverno/kyverno@1.20.0 aqua:mikefarah/yq@4.54.3 python@3.15.2 -- python tests/kyverno/test_policies.py
kustomize build kubernetes/apps/security/kyverno/policies
```

Die Tests prüfen Mutationen, erhaltene Werte, fehlende optionale Felder,
Namespace-Ausnahmen, Validierungen sowie Gatus- und TLS-Generierung ohne
Clusterzugriff. Synchronisation, Hintergrundverarbeitung und die Übernahme
bestehender generierter Ressourcen müssen zusätzlich im Cluster geprüft werden.

Der lokale Aqua-Eintrag `.config/mise/aqua-kyverno.yaml` korrigiert für
Kyverno >=1.20 die Signer-Identität von `release.yaml` auf
`release-publish.yaml`. SHA256 und Sigstore werden weiterhin geprüft.
Sobald die gebündelte Aqua-Registry diese Änderung enthält, kann der lokale
Eintrag samt `settings.aqua.registries` entfallen.

## Vor dem Merge / Push

Die folgenden Schritte sind eine einmalige Clusteränderung. Zunächst bleibt
Kyverno 1.19.2 aktiv. Die neue Policy-Kustomization hängt nur von den CRDs ab,
damit das blockierte Helm-Upgrade die Policy-Migration nicht mehr verhindert.

**Vor dem ersten Reconcile der neuen Manifeste** die drei alten
Generate-Policies so umstellen, dass ihre Ressourcen beim Pruning erhalten
bleiben. Sonst könnten TLS-Kopien und Gatus-ConfigMaps gelöscht werden.

```bash
flux --context turingpi suspend kustomization kyverno-policies -n security
flux --context turingpi suspend kustomization kyverno -n security
flux --context turingpi suspend helmrelease kyverno -n security

umask 077
migration_dir="$(mktemp -d /tmp/kyverno-cel.XXXXXX)"
kubectl --context turingpi get clusterpolicies -o yaml > "$migration_dir/legacy-policies.yaml"

for policy in sync-production-tls gatus-external gatus-internal; do
  kubectl --context turingpi patch clusterpolicy "$policy" --type=json \
    -p='[{"op":"add","path":"/spec/rules/0/generate/orphanDownstreamOnPolicyDelete","value":true}]'
done
```

Während der Umstellung keine alten Git-Manifeste erneut reconciliieren.
Die übergeordneten Flux-Kustomizations dürfen die Suspend-Felder ebenfalls
nicht vorzeitig zurücksetzen.

## CEL-Policies installieren und überprüfen

`flux build` übernimmt die Substitutionen der bestehenden Cluster-Kustomization,
insbesondere `${SECRET_DOMAIN}`. Ein reines `kustomize build | kubectl apply`
würde diesen Platzhalter unverändert installieren.

```bash
flux --context turingpi build kustomization kyverno-policies -n security \
  --path ./kubernetes/apps/security/kyverno/policies --strict-substitute \
  > "$migration_dir/cel-policies.yaml"
kubectl --context turingpi apply --dry-run=server -f "$migration_dir/cel-policies.yaml"
kubectl --context turingpi apply -f "$migration_dir/cel-policies.yaml"
kubectl --context turingpi get generatingpolicies,mutatingpolicies,validatingpolicies
```

Vor dem Entfernen der alten Policies die Status-Conditions aller neuen Policies
auf Fehler prüfen. Zusätzlich prüfen, dass die Gatus-ConfigMaps vorhanden sind,
die TLS-Secrets in `network` weiterhin den Quellen in `cert-manager` entsprechen
und keine Fehler in den Admission-/Background-Controller-Logs auftreten.
Die CLI-Tests allein bestätigen diese Übernahme nicht.

## GitOps übernehmen und Upgrade freigeben

Nach erfolgreicher Prüfung die Repository-Änderungen committen und pushen.
Der Cluster muss diese Revision als Source-Artifact geladen haben, bevor
`kyverno-policies` fortgesetzt wird:

```bash
flux --context turingpi reconcile source git flux-system -n flux-system
flux --context turingpi resume kustomization kyverno-policies -n security
flux --context turingpi reconcile kustomization kyverno-policies -n security
kubectl --context turingpi get clusterpolicies
```

Flux übernimmt die CEL-Policies in sein Inventar und entfernt die alten
ClusterPolicies durch Pruning. Erst fortfahren, wenn keine Legacy-Policies
mehr vorhanden sind und die neuen Policies sowie ihre generierten Ressourcen
weiterhin gesund sind. Keine CRDs löschen.

```bash
flux --context turingpi resume kustomization kyverno -n security
flux --context turingpi resume helmrelease kyverno -n security
flux --context turingpi reconcile helmrelease kyverno -n security --reset
kubectl --context turingpi get helmrelease kyverno -n security
kubectl --context turingpi get deployments -n security -l app.kubernetes.io/part-of=kyverno
```

Das Upgrade darf nun ohne `upgrade.acknowledgeLegacyPoliciesNotEnforced`
durchlaufen. Anschliessend Policy-Status, TLS-Kopien und Gatus erneut prüfen.

## Abbruch vor dem Upgrade

Solange weiterhin Kyverno 1.19.2 läuft, können die gesicherten alten Policies
wiederhergestellt werden. Zuerst die neuen Generate-Policies auf
`spec.evaluation.orphanDownstreamOnPolicyDelete.enabled: true` setzen, damit
deren erzeugte Ressourcen bei einer Rücknahme erhalten bleiben. Anschliessend
die CEL-Policies anhand der gerenderten Datei entfernen und die alten Policies
aus der Sicherung wiederherstellen. Git auf die alte Policy-Revision und Chart
3.9.2 zurückführen, bevor Flux fortgesetzt wird. Nach dem Wechsel auf 1.20
werden Legacy-Policies nicht mehr ausgeführt; dann ist zusätzlich ein geplanter
Controller-Downgrade erforderlich.

Referenz: [Kyverno-Migrationsleitfaden](https://kyverno.io/docs/guides/migration-to-cel/).
