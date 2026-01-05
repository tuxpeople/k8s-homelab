# UniFi DNS External-DNS Webhook

Automatische DNS-Einträge in der UniFi Dream Machine für Kubernetes Ingresses.

> **📖 Vollständige Dokumentation**: Siehe [docs/services/networking.md](../../../../docs/services/networking.md#dns-architektur-split-horizon-setup)

## Status

✅ **Deployed und aktiv** seit Dezember 2024

## Quick Reference

### Was macht dieser Service?

Erstellt automatisch DNS-Einträge in der UniFi Dream Machine für alle Ingresses mit `ingressClassName: internal`.

### Wie funktioniert es?

1. Du erstellst einen Ingress mit `ingressClassName: internal`
2. Kyverno Policy fügt automatisch Annotation hinzu: `external-dns.alpha.kubernetes.io/target: "192.168.13.64"`
3. external-dns (UniFi webhook) sieht den Ingress und erstellt Host Record in UDM
4. Service ist im LAN erreichbar über internal ingress (192.168.13.64)

### Beispiel Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: vault
  namespace: default
  # Keine Annotations nötig - Kyverno macht das automatisch!
spec:
  ingressClassName: internal  # ← Das reicht!
  rules:
  - host: vault.eighty-three.me
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: vault
            port:
              number: 8200
```

## Configuration

- **Provider**: UniFi Webhook (`kashalls/external-dns-unifi-webhook:v0.7.0`)
- **UniFi Controller**: `https://10.20.30.1`
- **Domain Filter**: `eighty-three.me`
- **IngressClass Filter**: `internal`
- **Annotation Filter**: `target=192.168.13.64`
- **TXT Owner ID**: `main`
- **Secret**: `unifi-dns-secret` (UniFi API Key aus 1Password)

## Debugging

```bash
# Logs
kubectl logs -n network -l app.kubernetes.io/name=unifi-dns -f

# Status
kubectl get pods -n network -l app.kubernetes.io/name=unifi-dns

# Secret prüfen
kubectl get secret unifi-dns-secret -n network -o jsonpath='{.data.UNIFI_API_KEY}' | base64 -d

# UniFi API Test
UNIFI_API_KEY="<key>"
curl -k -H "X-API-KEY: ${UNIFI_API_KEY}" \
  "https://10.20.30.1/proxy/network/v2/api/site/default/static-dns/"

# DNS Test
dig vault.eighty-three.me @10.20.30.11  # Pi-hole
dig vault.eighty-three.me @10.20.30.1    # UDM direkt
```

## Troubleshooting

### DNS-Eintrag wird nicht erstellt

1. Prüfe ob Ingress `ingressClassName: internal` hat
2. Prüfe ob Kyverno Annotation gesetzt hat: `kubectl get ingress <n> -o yaml`
3. Prüfe logs: `kubectl logs -n network -l app.kubernetes.io/name=unifi-dns`
4. Prüfe UniFi UI: Settings → Internet → DNS

### 401 Unauthorized Error

```bash
# Secret neu syncen
kubectl annotate externalsecret unifi-dns-secret -n network force-sync="$(date +%s)" --overwrite

# Pod restart
kubectl rollout restart deployment unifi-dns -n network
```

## Dependencies

- **1Password**: Item `unifi-api-externaldns` mit API Key und Hostname
- **ExternalSecret**: `unifi-dns-secret` (auto-synced aus 1Password)
- **Kyverno Policy**: `kubernetes/apps/security/kyverno/policies/ingress.yaml` (setzt Annotations)

## Related Services

- **Cloudflare external-dns**: Für `ingressClassName: external` (öffentliche Services)
- **k8s-gateway**: Legacy DNS, bleibt für Fallback deployed
- **Pi-hole**: LAN DNS Server (10.20.30.11)
- **UDM**: Router mit dnsmasq (10.20.30.1)

## Maintenance

### UniFi API Key erneuern

1. UniFi UI → Settings → Integrations
2. Lösche alten API Key
3. Erstelle neuen API Key
4. Update 1Password Item `unifi-api-externaldns`
5. Force sync: `kubectl annotate externalsecret unifi-dns-secret -n network force-sync="$(date +%s)" --overwrite`

### DNS-Einträge manuell bereinigen

**In UniFi UI:**
- Settings → Internet → DNS
- Lösche Host Records die nicht mehr gebraucht werden
- TXT Records mit `k8s.main.*` kennzeichnen external-dns managed Einträge

**Automatisch:**
- external-dns löscht Einträge automatisch wenn Ingress gelöscht wird

## Architecture

```
┌─────────────────┐
│  Ingress        │
│  (internal)     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Kyverno        │ ← Fügt Annotation hinzu
│  Policy         │   target=192.168.13.64
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  external-dns   │ ← Verarbeitet Ingress
│  (UniFi)        │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  UniFi API      │ ← Erstellt Host Record
│  (10.20.30.1)   │   vault.eighty-three.me → 192.168.13.64
└─────────────────┘
```

## Links

- **Full Documentation**: [docs/services/networking.md](../../../../docs/services/networking.md#dns-architektur-split-horizon-setup)
- **UniFi Webhook**: https://github.com/kashalls/external-dns-unifi-webhook
- **external-dns**: https://kubernetes-sigs.github.io/external-dns/
