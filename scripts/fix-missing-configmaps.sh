#!/bin/bash

# Script to fix missing configMapGenerator entries
set -euo pipefail

# List of apps that need fixing based on the check output
apps=(
    "kubernetes/apps/security/external-secrets/secretstores/onepassword"
    "kubernetes/apps/network/external/openvpn"
    "kubernetes/apps/observability/speedtest-exporter/app"
    "kubernetes/apps/observability/tautulli-exporter/app"
    "kubernetes/apps/ai/paperless-ai/app"
    "kubernetes/apps/ai/ollama/app"
    "kubernetes/apps/productivity/ladder/app"
    "kubernetes/apps/productivity/freshrss/app"
    "kubernetes/apps/productivity/drop/app"
    "kubernetes/apps/productivity/obsidian/app"
    "kubernetes/apps/productivity/linkding/app"
    "kubernetes/apps/media/tautulli/app"
)

for app_dir in "${apps[@]}"; do
    kustomization_file="$app_dir/kustomization.yaml"
    values_file="$app_dir/values.yaml"

    if [[ ! -f "$kustomization_file" ]] || [[ ! -f "$values_file" ]]; then
        echo "Skipping $app_dir - missing files"
        continue
    fi

    # Get app name
    app_name=$(basename "$app_dir")
    if [[ "$app_name" == "app" ]]; then
        app_name=$(basename "$(dirname "$app_dir")")
    fi

    echo "Fixing $app_name in $app_dir"

    # Check if configMapGenerator already exists
    if grep -q "configMapGenerator:" "$kustomization_file"; then
        echo "  Adding to existing configMapGenerator"
        # Add to existing configMapGenerator
        yq eval -i ".configMapGenerator += [{\"name\": \"${app_name}-values\", \"files\": [\"values.yaml\"]}]" "$kustomization_file"
    else
        echo "  Creating new configMapGenerator"
        # Add configMapGenerator before generatorOptions
        sed -i.bak '/^generatorOptions:/i\
configMapGenerator:\
  - name: '"${app_name}"'-values\
    files:\
      - values.yaml
' "$kustomization_file" && rm "$kustomization_file.bak"
    fi

    echo "  ✅ Fixed $app_name"
done

echo ""
echo "All missing configMapGenerator entries have been added!"
echo "Run ./check-app-template-conversion.sh to verify."
