# Secrets & Sensitive Data

## Überblick

-   **Verschlüsselung**: SOPS + Age, Keys liegen lokal (`age.key`) und werden nicht committed.
-   **Laufzeit-Secrets**: `external-secrets` + 1Password Connect liefern Werte zur Laufzeit in die Namespaces.
-   **TLS**: cert-manager stellt Let's-Encrypt-Zertifikate, Standard-Wildcard `${SECRET_DOMAIN}`.

## Arbeitsablauf

1. **Neues Secret anlegen**
    ```bash
    sops --age <recipient> --encrypt secret.yaml > secret.sops.yaml
    ```
    - Pfad beachten (`kubernetes/apps/<bereich>/<service>/app/secret.sops.yaml`).
    - Datei erst committen, wenn `sops`-Footer (`ENC[AES256_GCM,...`) sichtbar ist.
2. **Secret ändern**: `sops path/to/secret.sops.yaml` und anschliessend `task encrypt-secrets`, falls mehrere Dateien betroffen sind.
3. **External Secrets**: Definitionen unter `kubernetes/apps/security/external-secrets`. Jede neue Referenz dokumentieren (Vault, Item, Field).
4. **Validation**: `pre-commit` startet `detect-secrets`, SOPS-Dateien sind ausgeschlossen. Trotzdem `git diff` prüfen.

## Rotationskonzept

-   **Age Key**: Backup im Passwort-Manager; Rotation → alle Secrets neu verschlüsseln (`task encrypt-secrets`).
-   **1Password Connect Token**: Liegt als Talos Secret, Rotation erfordert Update der Talos Machine Config + Redeploy des Connect-Pods.
-   **Ingress-Zertifikate**: cert-manager erneuert automatisch; Failures im `monitoring.md` (Alertmanager) beschrieben.

## Do's & Don'ts

-   ✅ Secrets nur via ExternalSecret oder SOPS speichern.
-   ✅ Namespace + SecretName im Service-Dokument verlinken.
-   ✅ `kubectl get externalsecret -A` regelmässig prüfen.
-   ❌ Keine Klartext-Secrets in Git, Task-Ausgaben oder Issue-Texten.
-   ❌ Keine `kubectl create secret generic --from-literal` direkt im Cluster ohne Git-Historie.

## Audit & Monitoring

-   `external-secrets` Status → `kubectl describe externalsecret/<name>`.
-   1Password Connect Logs → Namespace `security`, Deployment `onepassword-connect`.
-   Alerts: Grafana/Alertmanager melden bei `ExternalSecret`-Sync-Fehlern.

## Offene Punkte

-   Automatisierte Secret-Rotation (siehe `WEITERENTWICKLUNG.md` DOC-005).
-   Dokumentation aller 1Password Vaults/Items pro Namespace steht aus.
