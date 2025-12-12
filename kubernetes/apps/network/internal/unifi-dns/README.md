# UniFi DNS External-DNS Webhook

Automatische DNS-Einträge in der UniFi Dream Machine für Kubernetes Ingresses.

## Status

✅ **Bereit zum Deployment** - Alle notwendigen Fixes sind gemacht

## Was wurde gefixt

1. ✅ `ingress` zu sources hinzugefügt (war der Hauptgrund warum es nicht funktionierte)
2. ✅ Domain Filter auf `eighty-three.me` gesetzt
3. ✅ Kustomization in `ks.yaml` aktiviert

## Nächste Schritte zum Deployment

### 1. 1Password Secret vorbereiten

Erstelle in 1Password ein Item mit dem Namen `unifi-dns`:
- **Benutzername**: Der Admin-Username (z.B. `externaldns`)
- **Anmeldedaten**: Das Passwort des Admin-Users
- **Hostname**: `https://10.20.30.1`

**Hinweis**: Dieses Setup verwendet Username/Password statt API Keys, da ältere UniFi OS Versionen keine API Keys unterstützen.

### 2. Commit & Push

```bash
cd /Volumes/development/github/tuxpeople/k8s-homelab
git add .
git commit -m "feat(network): activate external-dns-unifi-webhook"
git push
```

### 3. Deployment überwachen

```bash
# Flux reconciliation
flux reconcile kustomization internal-unifi-dns --namespace network

# Pod logs
kubectl logs -n network -l app.kubernetes.io/name=unifi-dns -f

# Check if it's running
kubectl get pods -n network -l app.kubernetes.io/name=unifi-dns
```

### 4. Test mit einem bestehenden Ingress

Füge die Annotation zu einem bestehenden Ingress hinzu:

```yaml
annotations:
  external-dns.alpha.kubernetes.io/target: "192.168.13.64"
```

Dann schaue in der UDM nach ob der DNS-Eintrag erstellt wurde.

### 5. Debugging

Falls es nicht funktioniert:

```bash
# External-DNS logs
kubectl logs -n network -l app.kubernetes.io/name=unifi-dns | grep -i error

# Check Secret
kubectl get secret unifi-dns-secret -n network -o yaml

# Test Ingress erstellen (siehe test-ingress.yaml.example)
kubectl apply -f test-ingress.yaml.example
```

## Wie es funktioniert

1. external-dns überwacht alle Ingresses mit `ingressClassName: internal`
2. Wenn ein Ingress die Annotation `external-dns.alpha.kubernetes.io/target` hat:
   - Hostname aus Ingress: `vault.eighty-three.me`
   - IP aus Annotation: `192.168.13.64`
   - → external-dns erstellt in UDM: `host-record=vault.eighty-three.me,192.168.13.64`
3. Wenn der Ingress gelöscht wird, wird auch der DNS-Eintrag gelöscht

## Nach erfolgreichem Test

1. k8s-gateway kann deprecated werden
2. Alle Ingresses mit der Annotation versehen
3. `server=/eighty-three.me/192.168.13.65` aus UDM entfernen

## Für zweiten Kubernetes-Cluster

Einfach das gleiche Setup deployen mit:
- Anderem `txtOwnerId` (z.B. `cluster-2`)
- Gleicher UDM
- Gleicher Domain

Beide Cluster schreiben dann ihre Ingresses in die gleiche UDM → kein Conflict!
