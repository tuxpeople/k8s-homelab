# Networking & Ingress

## Überblick & Status
- **CNI**: Cilium (`kubernetes/apps/kube-system/cilium`, aktiv) mit kube-proxy ersetzt. CNI in Talos deaktiviert → Cilium übernimmt IPAM.
- **Ingress Layer**: Zwei dedizierte nginx-Instanzen (`internal` @ 192.168.13.64, `external` @ 192.168.13.66) inkl. Authelia-Auth-Flow.
- **DNS**:
  - Intern: `k8s-gateway` (Gateway API DNS) + `k8s-gateway` Service (IP 192.168.13.65).
  - Extern: `external-dns` pflegt Cloudflare Zone `eighty-three.me`.
  - Zusatz: `python-ipam` & `unifi-dns` synchronisieren lokale Netze / DHCP.
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
| `unifi-dns` | Synct DNS-Einträge ins UniFi Controller / Edge Router. | Prüfen, ob Cron/Controller-Connectivity aktiv. |

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
- Dokumentation für `python-ipam`, `unifi-dns`, `openvpn` nachtragen (Status, Secrets, DR).
- Evaluate enabling Hubble UI / Cilium NetworkPolicy enforcement.
