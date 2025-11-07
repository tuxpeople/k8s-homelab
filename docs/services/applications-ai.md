# AI / ML Services

## LibreChat2
- **Status**: Deaktiviert (Flux `ks.dis`). Zum Aktivieren `kubernetes/apps/ai/librechat2/ks.dis` nach `ks.yaml` kopieren.
- **Namespace / Pfad**: `ai` / `kubernetes/apps/ai/librechat2`.
- **Zweck**: Selfhosted Chat-Oberfläche mit RAG, integriertem MongoDB/Meilisearch sowie eigenem Metrics-Exporter (`9123`).
- **Ingress / Zugriff**: Interner Ingress `chat.${SECRET_DOMAIN}` (class `internal`, TLS über `${SECRET_DOMAIN/./-}-production-tls`).
- **Abhängigkeiten**:
  - Longhorn PVC `data` (5 Gi) → verlangt funktionsfähigen Storage.
  - Secrets `librechat2-secret`, `librechat2-oidc-secret`, ConfigMap `librechat2-env-config`.
  - Optional `ollama` oder externe OpenAI Keys für RAG.
  - `dependsOn`: `storage/longhorn`.
- **Backups**: PVC `data` enthält Uploads, Logs, Bilder → via K8up Job für Namespace `ai` sichern (RPO 24 h). MongoDB/Meili laufen im Pod (kein StatefulSet), daher zusätzlich regelmäßige Dumps einplanen.
- **Monitoring / Alerts**:
  - Exporter-Container liefert Prometheus-Metriken (Port 9123, Service `app-metrics`).
  - Liveness/Readiness-Probes aktiv; Alerts bei PodRestartCount > 5.
- **Runbooks**:
  - Reconcile: `flux reconcile kustomization librechat2 --with-source -n ai`.
  - TODO: Abschnitt „LLM Backend wechseln“ + „MongoDB-Dumps“ in `docs/runbooks.md`.

## Ollama
- **Status**: Deaktiviert (`ks.dis`), bereit für späteren ARM64-Betrieb.
- **Namespace / Pfad**: `ai` / `kubernetes/apps/ai/ollama`.
- **Zweck**: Lokaler LLM-Server (HTTP 11434) inkl. LoadBalancer-IP (`lbipam.cilium.io/ips: ${SECRET_CILIUMLB_OLLAMA}`) für externe Clients.
- **Ressourcen**: Requests 500 mCPU/5 Gi, Limit 16 Gi RAM. Keine GPU in der aktuellen Manifestversion.
- **Storage**:
  - PVC `models` 60 Gi (Model-Files) – Longhorn, unbedingt regelmäßig snapshotten (RPO 12 h).
  - PVC `config` 5 Gi (Cache, Pull-Status).
- **Abhängigkeiten**: Benötigt ausreichend Nodespeicher; optional OIDC/Ingress nicht definiert (LB-only). Bei Aktivierung `cilium-lb` IP muss frei sein.
- **Backups**: Longhorn Snapshot + K8up Restic auf Namespace-Ebene. Zusätzlich Modell-Liste (`ollama list`) exportieren.
- **Monitoring / TODO**:
  - Noch kein Metrics-Endpunkt erfasst → Prometheus Scrape über `11434/metrics` prüfen.
  - Runbook „Modelle aktualisieren/entfernen“ ergänzen.
- **Reconcile**: `flux reconcile kustomization ollama --with-source -n ai`.

## Open WebUI
- **Status**: Aktiv (`ks.yaml`).
- **Namespace / Pfad**: `ai` / `kubernetes/apps/ai/open-webui`.
- **Zweck**: Browser-Frontend für Ollama/weitere Backends mit OIDC-Login (Homelab Login).
- **Ingress**: `ai.${SECRET_DOMAIN}` (class `external`, TLS via Cluster-Wildcard). Auth über OIDC; Secrets aus `open-webui-values`.
- **Abhängigkeiten**:
  - OIDC Provider `auth.${SECRET_DOMAIN}`; Rollen `applications_openwebui[_admin]`.
  - Optionaler Ollama-Endpunkt (`http://192.168.8.25:11434`) – aktuell externer Host, nicht das K8s-Deployment.
  - Persistent Volume `data` 10 Gi (Longhorn) für Workspace/Uploads.
- **Backups**: PVC `data` täglich sichern (K8up). Konfiguration exportieren (`/app/backend/data/config.db`).
- **Monitoring**:
  - Resource Requests 750 mCPU/1 Gi; Ingress durch Gatus-Check `https://ai.${SECRET_DOMAIN}` abdecken.
  - Alert bei HTTP 5xx oder PVC fast voll (Longhorn).
- **Runbooks**:
  - Reconcile: `flux reconcile kustomization open-webui --with-source -n ai`.
  - Update-Prozess: Helm values (`open-webui-values` ConfigMap) anpassen, `task reconcile`.

## Paperless AI
- **Status**: Deaktiviert (`ks.dis`), wartet auf Ollama-Betrieb.
- **Namespace / Pfad**: `ai` / `kubernetes/apps/ai/paperless-ai`.
- **Zweck**: Ergänzt Paperless (Namespace `productivity`) um KI-gestützte OCR/Post-Processing.
- **Ingress**: `paperless-ai.${SECRET_DOMAIN}` (internal ingress mit Auth gegen Authelia/Authentik `auth.${SECRET_DOMAIN}`).
- **Abhängigkeiten**:
  - Paperless API (`http://paperless.productivity.svc.cluster.local:8080/api`).
  - Ollama Endpoint (`ollama:11434`) → erfordert funktionierendes Ollama Deployment oder externes DNS.
  - Secret `paperless-ai` (API Keys, Tokens).
  - PVC `config` 50 Gi (Langzeitdaten), mehrere `emptyDir`s für Logs/Public/tmp.
- **Backups**: PVC `config` via Longhorn Snapshot + Restic (RPO 24 h) synchronisiert mit Paperless Backups.
- **Monitoring / TODO**:
  - Cron `SCAN_INTERVAL */30` → Observability-Regel erstellen (Job Success, Age der letzten erfolgreichen Runs).
  - Alert bei HTTP 500 oder Paperless API unreachable (blackbox target).
- **Runbooks**:
  - Aktivierungsschritte (Dependencies, Secrets) dokumentieren.
  - Reconcile: `flux reconcile kustomization paperless-ai --with-source -n ai`.

## Betrieb & ToDos
- Ressourcenänderungen → `RESOURCE_ANALYSIS.md` aktualisieren (z.B. wenn Ollama GPU erhält).
- Monitoring-Lücken:
  - Exporter Scrapes für LibreChat2 (Port 9123) aufnehmen.
  - Prometheus Alerts für Paperless-AI Cron/Queue erstellen.
- Runbooks:
  - „Modell-Updates“ (Ollama) & „LibreChat2 Mongo Restore“ ergänzen (`docs/runbooks.md`).
  - „AI-Stack Aktivierung“ (Reihenfolge Ollama → Open WebUI → LibreChat2/Paperless AI).
