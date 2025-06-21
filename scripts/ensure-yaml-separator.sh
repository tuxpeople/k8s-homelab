#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="kubernetes"

find "$TARGET_DIR" -type f -name '*.yaml' | while read -r file; do
    first_line=$(head -n 1 "$file" || true)
    if [[ "$first_line" != "---"* ]]; then
        sed -i '1i ---' "$file"
        echo "Added '---' to $file"
    fi
done
