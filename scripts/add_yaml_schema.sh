#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="kubernetes"
# Find yaml files without yaml-language-server comment that contain apiVersion
files=$(grep -L "yaml-language-server" -r "$TARGET_DIR" | xargs grep -l "apiVersion" || true)

for file in $files; do
  apiver=$(grep -m1 '^apiVersion:' "$file" | awk '{print $2}')
  kind=$(grep -m1 '^kind:' "$file" | awk '{print tolower($2)}')
  if [[ -z "$apiver" || -z "$kind" ]]; then
    continue
  fi
  if [[ "$apiver" == kustomize.config.k8s.io/* ]]; then
    schema="https://json.schemastore.org/kustomization"
  else
    if [[ "$apiver" == */* ]]; then
      group=${apiver%%/*}
      version=${apiver#*/}
    else
      group="v1"
      version="$apiver"
    fi
    schema="https://kubernetes-schemas.pages.dev/${group}/${kind}_${version}.json"
  fi
  if head -n1 "$file" | grep -q '^---'; then
    sed -i "1a # yaml-language-server: \$schema=${schema}" "$file"
  else
    sed -i "1i # yaml-language-server: \$schema=${schema}" "$file"
  fi
  echo "Added schema to $file"
done
