# AI / ML Services

> Statusangaben: **aktiv** = `ks.yaml`. Alle anderen AI-Apps sind vollständig archiviert und aus dem Cluster entfernt (Manifeste unter `archive/apps/ai/`).

## Open WebUI (**aktiv**)

-   **Namespace / Pfad**: `ai` / `kubernetes/apps/ai/open-webui`.
-   **Zweck**: Browser-Frontend für Ollama/weitere Backends mit OIDC-Login (Homelab Login).
-   **Ingress**: `ai.${SECRET_DOMAIN}` (class `external`, TLS via Cluster-Wildcard). Auth über OIDC; Secrets aus `open-webui-values`.
-   **Abhängigkeiten**:
    -   OIDC Provider `auth.${SECRET_DOMAIN}`; Rollen `applications_openwebui[_admin]`.
    -   Optionaler Ollama-Endpunkt (`http://192.168.8.25:11434`) – aktuell externer Host, nicht das K8s-Deployment.
    -   Persistent Volume `data` 10 Gi (democratic-csi/Synology) für Workspace/Uploads.
-   **Backups**: PVC `data` täglich sichern. Konfiguration exportieren (`/app/backend/data/config.db`).
-   **Monitoring**:
    -   Resource Requests 750 mCPU/1 Gi; Ingress durch Gatus-Check `https://ai.${SECRET_DOMAIN}` abdecken.
-   **Runbooks**:
    -   Reconcile: `flux reconcile kustomization open-webui --with-source -n ai`.
    -   Update-Prozess: Helm values (`open-webui-values` ConfigMap) anpassen, `task reconcile`.

## Archivierte AI-Apps

Die folgenden Anwendungen wurden aus dem Cluster entfernt. Manifeste liegen in `archive/apps/ai/` und können bei Bedarf reaktiviert werden.

| App | Zweck | Archivpfad |
|-----|-------|------------|
| LibreChat2 | Selfhosted Chat-Oberfläche mit RAG, MongoDB/Meilisearch | `archive/apps/ai/librechat2` |
| Ollama | Lokaler LLM-Server (HTTP 11434) | `archive/apps/ai/ollama` |
| Paperless-AI | KI-gestützte OCR/Post-Processing für Paperless | `archive/apps/ai/paperless-ai` |

Vor Reaktivierung prüfen: StorageClass/PVC-Abhängigkeiten, Secrets noch vorhanden, Ressourcen verfügbar.
