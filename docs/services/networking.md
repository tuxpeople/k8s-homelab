# Networking & Ingress

## Überblick & Status
- **CNI**: Cilium (`kubernetes/apps/kube-system/cilium`, aktiv) mit kube-proxy ersetzt. CNI in Talos deaktiviert → Cilium übernimmt IPAM.
- **Ingress Layer**: Zwei dedizierte nginx-Instanzen (`internal` @ 192.168.13.64, `external` @ 192.168.13.66) inkl. Authelia-Auth-Flow.
- **DNS**:
  - **Split-Horizon Architektur** für `eighty-three.me`:
    - **External (Public)**: `external-dns` → Cloudflare (für Ingresses mit `ingressClassName: external`)
    - **Internal (LAN)**: `unifi-dns` (external-dns mit UniFi webhook) → UniFi Dream Machine (für Ingresses mit `ingressClassName: internal`)
  - **Cluster DNS**: CoreDNS forwarded zu Pi-hole (10.20.30.126) → UDM → Public DNS
  - **Automatische DNS-Verwaltung**: Kyverno Policy setzt automatisch `external-dns.alpha.kubernetes.io/target` Annotation basierend auf IngressClass
  - **k8s-gateway**: Bleibt deployed für Legacy-Support, aber wird nicht mehr aktiv von external-dns verwendet
- **Tunnels & Remote Access**: Cloudflared (public ingress) + OpenVPN fallback (Status prüfen).
- **LoadBalancer IPAM**: Cilium LB IPs über `lbipam.cilium.io/ips` Annotation (z.B. Ollama).

## Kernkomponenten (aktiv, sofern nicht anders vermerkt)
### Netzwerk (Namespace `kube-system`)
| Service | Pfad | Zweck / Hinweise |
|---------|------|------------------|
| Cilium | `kubernetes/apps/kube-system/cilium` | L3/L4 Networking, Hubble optional (derzeit deaktiviert). |
| CoreDNS | `kubernetes/apps/kube-system/coredns` | Cluster DNS, forwarded via k8s-gateway. |
| Node Feature Discovery | `kubernetes/apps/kube-system/node-feature-discovery` | Labels für Hardware-Offloading (ARM64, NVMe). |
| Descheduler | `kubernetes/apps/kube-system/descheduler` | Räumt Pods um bei Hotspots. |
| Metrics-server / Reloader / Spegel | (siehe Verzeichnisse) | Teil des System Monitorings / Image Cache. |

### Externe Ingress-Schicht (`kubernetes/apps/network/external`)
| Service | Zweck | Secrets / Hinweise |
|---------|-------|-------------------|
| `ingress-nginx` (external) | Public HTTP/S Endpoints (`external` class) – routet nur Cloudflared IPs. | TLS via cert-manager wildcard `${SECRET_DOMAIN}`. Rate Limiting TODO. |
| `cloudflared` | Tunnel von `external` ingress ins Internet. | Secret `cloudflare-tunnel.json` (SOPS). Reconcile `flux reconcile kustomization cloudflared -n network`. |
| `external-dns` | Erstellt/aktualisiert Cloudflare Records. | API Token im ExternalSecret `external-dns` (1Password). TTL konfiguriert. |
| `openvpn` | Legacy Remotezugang fallback (Status unbekannt). | Prüfen, ob Deployment aktiv; falls obsolet → dekommissionieren. |

### Interne Ingress-Schicht (`kubernetes/apps/network/internal`)
| Service | Zweck | Hinweise |
|---------|-------|----------|
| `ingress-nginx` (internal) | LAN-only Services (`internal` class). | Binds auf 192.168.13.64, Authelia Standard. |
| `k8s-gateway` | DNS Gateway, bedient `*.eighty-three.me` intern. | Upstream: CoreDNS; pflegt ServiceRecords aus K8s. |
| `python-ipam` | Hilfsservice zur IP-Adressverwaltung/Reservations. | TODO: Doku der API/DB. |
| `unifi-dns` | external-dns mit UniFi Webhook für automatisches DNS in UDM. | Verarbeitet `ingressClassName: internal`, erstellt Host Records in UniFi. API Key via 1Password (`unifi-api-externaldns`). |

## Abhängigkeiten & Secrets
- Kyverno Policies müssen vor Ingress/Cloudflared bereitstehen (`dependsOn` in `ks.yaml`).
- Cert-Manager (Namespace `cert-manager`) liefert Zertifikate (`${SECRET_DOMAIN/./-}-production-tls`).
- Cloudflare API Token (external-dns & cloudflared) via ExternalSecret + 1Password vault.
- Authelia/Authentik (`auth.${SECRET_DOMAIN}`) muss laufen, bevor Ingress mit Auth-Annotations deployed wird.

## Betrieb & Runbooks
- Reconcile Ingress: `flux reconcile kustomization network-external --with-source -n network` bzw. `network-internal`.
- Zertifikatsprobleme: siehe `docs/runbooks.md` Abschnitt „Zertifikat erneuern“.
- Ingress-Triage: `kubectl -n network logs deploy/<ingress> -f | grep <host>`, `kubectl -n network describe ingress <name>`.
- DNS Debug:
  - Intern: `dig <host> @192.168.13.65`.
  - Extern: `dig <host> @1.1.1.1` (Cloudflare).
- Cloudflared Tunnel Down: `kubectl -n network logs deploy/cloudflared`, check token expiration.

## Monitoring & Alerts
- `blackbox-exporter`, `gatus`, `speedtest-exporter` prüfen Endpunkte/Connectivity.
- Prometheus scrapes ingress-nginx metrics (connection saturation, HTTP errors). Alerts für:
  - Pod `Ready` status,
  - Certificate expiry (<7 d),
  - Cloudflared disconnections,
  - external-dns sync failures (increase in errors gauge),
  - Cilium health (agent restarts, drop metrics).
- Dashboards: „Networking / Ingress“, „DNS / Cloudflare“, „Cloudflared Tunnel“ (TODO: Link IDs).

## TODOs / Risiken
- NetworkPolicies flächendeckend definieren (Backlog DOC-004) – aktuell keine Isolation.
- Rate Limiting + Security Headers standardisieren für `external` ingress (IMPROVEMENT PLAN #12).
- Dokumentation für `python-ipam`, `openvpn` nachtragen (Status, Secrets, DR).
- Evaluate enabling Hubble UI / Cilium NetworkPolicy enforcement.

## DNS-Architektur (Split-Horizon Setup)

### Übersicht
Das Cluster verwendet eine Split-Horizon DNS-Architektur für die Domain `eighty-three.me`:
- **Public DNS** (Cloudflare): Für Services die über das Internet erreichbar sein sollen
- **Internal DNS** (UniFi): Für Services die nur im LAN erreichbar sein sollen

Beide nutzen `external-dns`, aber mit verschiedenen Providern und Filtern.

### Komponenten

#### 1. Cloudflare external-dns (`kubernetes/apps/network/external/external-dns`)
**Zweck**: Erstellt DNS-Einträge in Cloudflare für öffentlich erreichbare Services

**Config**:
- Provider: Cloudflare API
- IngressClass Filter: `--ingress-class=external`
- Annotation Filter: `--annotation-filter=external-dns.alpha.kubernetes.io/target=external.${SECRET_DOMAIN}`
- Domain: `${SECRET_DOMAIN}` (eighty-three.me)
- TXT Owner ID: `default`

**Verarbeitet**:
- Nur Ingresses mit `ingressClassName: external`
- Nur Ingresses mit Annotation `target=external.eighty-three.me`

**Secret**: `external-dns-secret` (Cloudflare API Token aus 1Password)

#### 2. UniFi external-dns (`kubernetes/apps/network/internal/unifi-dns`)
**Zweck**: Erstellt DNS-Einträge in der UniFi Dream Machine für LAN-only Services

**Config**:
- Provider: UniFi Webhook (`kashalls/external-dns-unifi-webhook`)
- IngressClass Filter: `--ingress-class=internal`
- Annotation Filter: `--annotation-filter=external-dns.alpha.kubernetes.io/target=192.168.13.64`
- Domain: `eighty-three.me`
- TXT Owner ID: `main`
- UniFi Controller: `https://10.20.30.1`

**Verarbeitet**:
- Nur Ingresses mit `ingressClassName: internal`
- Nur Ingresses mit Annotation `target=192.168.13.64` (internal ingress VIP)

**Secret**: `unifi-dns-secret` (UniFi API Key aus 1Password Item `unifi-api-externaldns`)

**Setup**:
- API Key wurde unter UniFi UI → Settings → Integrations erstellt
- ExternalSecret holt API Key und Hostname aus 1Password

#### 3. Kyverno Policy (Automatische Annotation)
**Pfad**: `kubernetes/apps/security/kyverno/policies/ingress.yaml`

**Funktion**: Setzt automatisch `external-dns.alpha.kubernetes.io/target` Annotation basierend auf IngressClass:

```yaml
# Rule 1: external ingresses
ingressClassName: external → target: "external.${SECRET_DOMAIN}"

# Rule 2: internal ingresses
ingressClassName: internal → target: "192.168.13.64"
```

**Vorteil**: Entwickler müssen keine Annotations manuell setzen - nur die richtige IngressClass wählen!

### Workflow: Ingress erstellen

#### Für öffentliche Services (external):
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: public-app
  namespace: default
  # Keine Annotations nötig!
spec:
  ingressClassName: external  # ← Das reicht!
  rules:
  - host: app.eighty-three.me
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app
            port:
              number: 80
```

**Was passiert**:
1. Kyverno fügt automatisch hinzu: `external-dns.alpha.kubernetes.io/target: "external.eighty-three.me"`
2. Cloudflare external-dns sieht den Ingress und erstellt CNAME in Cloudflare: `app.eighty-three.me → external.eighty-three.me`
3. Cloudflared Tunnel macht `external.eighty-three.me` öffentlich erreichbar

#### Für interne Services (internal):
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: vault
  namespace: default
  # Keine Annotations nötig!
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

**Was passiert**:
1. Kyverno fügt automatisch hinzu: `external-dns.alpha.kubernetes.io/target: "192.168.13.64"`
2. UniFi external-dns sieht den Ingress und erstellt Host Record in UDM: `vault.eighty-three.me → 192.168.13.64`
3. Service ist nur im LAN über internal ingress erreichbar

### Zuständigkeitsmatrix

| Ingress erstellt mit | Kyverno Annotation | Cloudflare external-dns | UniFi external-dns | Resultat |
|---|---|---|---|---|
| `ingressClassName: external` | `target: external.eighty-three.me` | ✅ Verarbeitet | ❌ Ignoriert | CNAME in Cloudflare |
| `ingressClassName: internal` | `target: 192.168.13.64` | ❌ Ignoriert | ✅ Verarbeitet | Host Record in UDM |
| Keine ingressClassName | Keine Annotation | ❌ Ignoriert | ❌ Ignoriert | Kein DNS-Eintrag |

### Debugging

#### External DNS (Cloudflare)
```bash
# Logs
kubectl logs -n network -l app.kubernetes.io/name=external-dns -f

# Welche Ingresses werden verarbeitet?
kubectl logs -n network -l app.kubernetes.io/name=external-dns | grep -i "processing"

# Secret prüfen
kubectl get secret external-dns-secret -n network -o jsonpath='{.data.api-token}' | base64 -d

# DNS Test
dig app.eighty-three.me @1.1.1.1
```

#### Internal DNS (UniFi)
```bash
# Logs
kubectl logs -n network -l app.kubernetes.io/name=unifi-dns -f

# Secret prüfen
kubectl get secret unifi-dns-secret -n network -o jsonpath='{.data.UNIFI_API_KEY}' | base64 -d

# UniFi API Test
UNIFI_API_KEY="<key>"
curl -k -H "X-API-KEY: ${UNIFI_API_KEY}" \
  "https://10.20.30.1/proxy/network/v2/api/site/default/static-dns/"

# DNS Test
dig vault.eighty-three.me @10.20.30.126  # Pi-hole
dig vault.eighty-three.me @10.20.30.1    # UDM direkt

# In UniFi UI prüfen
# Settings → Internet → DNS
# Sollte Host Records mit 192.168.13.64 zeigen
```

#### Kyverno Policy
```bash
# Policy Status
kubectl get clusterpolicy ingress

# Prüfen ob Annotation gesetzt wurde
kubectl get ingress <name> -n <namespace> -o yaml | grep -A2 annotations

# Manuell triggern (falls nötig)
kubectl annotate ingress <name> -n <namespace> kyverno.io/trigger=update --overwrite
```

### Troubleshooting

#### Problem: DNS-Eintrag wird nicht erstellt

**Für external:**
1. Prüfe ob Ingress `ingressClassName: external` hat
2. Prüfe ob Kyverno Annotation gesetzt hat: `kubectl get ingress <name> -o yaml`
3. Prüfe external-dns logs: `kubectl logs -n network -l app.kubernetes.io/name=external-dns`
4. Prüfe Cloudflare API Token

**Für internal:**
1. Prüfe ob Ingress `ingressClassName: internal` hat
2. Prüfe ob Kyverno Annotation gesetzt hat: `kubectl get ingress <name> -o yaml`
3. Prüfe unifi-dns logs: `kubectl logs -n network -l app.kubernetes.io/name=unifi-dns`
4. Prüfe UniFi API Key: curl-Test (siehe oben)
5. Prüfe UniFi UI ob Records erscheinen

#### Problem: Falsche DNS-Einträge (CNAME statt Host Record in UniFi)

**Ursache**: Filter nicht aktiv oder alte Einträge

**Lösung**:
```bash
# 1. Prüfe Filter in Deployment
kubectl get deployment unifi-dns -n network -o yaml | grep -A5 "args:"

# Sollte enthalten:
# --ingress-class=internal
# --annotation-filter=external-dns.alpha.kubernetes.io/target=192.168.13.64

# 2. Lösche alte CNAME Records in UniFi UI manuell
# Settings → Internet → DNS
# Alle CNAME zu "external.eighty-three.me" löschen

# 3. Warte 2 Minuten, prüfe ob sie zurückkommen
# Sie sollten NICHT mehr zurückkommen wenn Filter aktiv ist
```

#### Problem: external-dns crash loop

**Typische Fehler**:
- `401 Unauthorized`: API Key falsch oder abgelaufen
- `"!=" is not a valid label selector operator`: Falscher annotation-filter Syntax
- `failed to sync *v1beta1.Gateway`: gateway-httproute in sources aber keine GatewayAPI CRDs

**Lösung**:
```bash
# Logs checken
kubectl logs -n network -l app.kubernetes.io/name=unifi-dns | grep -i error

# Secret neu syncen
kubectl annotate externalsecret unifi-dns-secret -n network force-sync="$(date +%s)" --overwrite

# Pod restart
kubectl rollout restart deployment unifi-dns -n network
```

### Cleanup / Migration

#### Von k8s-gateway zu external-dns migrieren

Die Migration ist bereits abgeschlossen:
- ✅ `unifi-dns` (external-dns mit UniFi webhook) ist aktiv
- ✅ Alle internal Ingresses nutzen automatisch UniFi DNS
- ✅ `k8s-gateway` bleibt deployed für Legacy-Support
- ✅ UDM forwarding `server=/eighty-three.me/192.168.13.65` bleibt aktiv (Fallback)

**Kein Action Item nötig** - beide Systeme koexistieren sauber.

#### Manuelles Cleanup von DNS-Einträgen

**In UniFi:**
1. Settings → Internet → DNS
2. Suche nach Einträgen mit `eighty-three.me`
3. Lösche alle `host-record=` Einträge die nicht mehr gebraucht werden
4. Lösche zugehörige TXT-Records mit `k8s.main.`

**Automatisches Cleanup**:
- external-dns löscht Einträge automatisch wenn Ingress gelöscht wird
- TXT Records (`k8s.main.*`) kennzeichnen alle Einträge die von external-dns verwaltet werden

### Für zweiten Kubernetes-Cluster

Wenn ein zweiter Cluster hinzugefügt wird:

1. **Gleicher UniFi external-dns Setup** mit:
   - Anderem `txtOwnerId` (z.B. `cluster-2` statt `main`)
   - Gleicher UDM und API Key
   - Gleicher Domain

2. **Unterschiedliche Subdomains** (empfohlen):
   ```yaml
   domainFilters: ["c1.eighty-three.me"]  # Cluster 1
   domainFilters: ["c2.eighty-three.me"]  # Cluster 2
   ```

3. **Beide Cluster schreiben in gleiche UDM** → kein Conflict dank verschiedener `txtOwnerId`

### Referenzen
- UniFi Webhook: https://github.com/kashalls/external-dns-unifi-webhook
- external-dns Docs: https://kubernetes-sigs.github.io/external-dns/
- Kyverno Policies: `kubernetes/apps/security/kyverno/policies/ingress.yaml`
