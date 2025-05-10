#!/bin/bash

# Namespace konfigurieren
NAMESPACE="storage"
MAX_AGE_SECONDS=$((24 * 60 * 60)) # 24 Stunden

# Date-Funktion: fallback auf gdate falls vorhanden
if command -v gdate >/dev/null 2>&1; then
    DATE_CMD="gdate"
else
    DATE_CMD="date"
fi

NOW=$($DATE_CMD -u +%s)

echo "📦 Prüfe Longhorn-Backups im Namespace '$NAMESPACE'..."
echo

# Liste aller Volumes
volumes=$(kubectl get volumes.longhorn.io -n "$NAMESPACE" -o json | jq -r '.items[].metadata.name')

for volume in $volumes; do
    echo "🔍 Volume: $volume"

    # Suche alle Backups dieses Volumes
    backups=$(kubectl get backups.longhorn.io -n "$NAMESPACE" -o json | jq -r --arg vol "$volume" \
        '.items[] | select(.status.volumeName == $vol) | {name: .metadata.name, created: .status.backupCreatedAt, state: .status.state}')

    if [ -z "$backups" ]; then
        echo "  ❌ Kein Backup gefunden!"
        continue
    fi

    # Suche das jüngste erfolgreiche Backup
    latest_backup=$(kubectl get backups.longhorn.io -n "$NAMESPACE" -o json | jq -r --arg vol "$volume" '
    .items[] |
    select(.status.volumeName == $vol and .status.state == "Completed" and .status.backupCreatedAt != null) |
    {name: .metadata.name, created: .status.backupCreatedAt} |
    @base64' | while read -r line; do
        data=$(echo "$line" | base64 --decode)
        name=$(echo "$data" | jq -r '.name')
        created=$(echo "$data" | jq -r '.created')
        created_ts=$($DATE_CMD -d "$created" +%s 2>/dev/null)

        if [ -n "$created_ts" ]; then
            echo "$created_ts $name $created"
        fi
    done | sort -rn | head -n 1)

    if [ -z "$latest_backup" ]; then
        echo "  ⚠️ Kein gültiges (Completed) Backup vorhanden."
        continue
    fi

    latest_ts=$(echo "$latest_backup" | awk '{print $1}')
    backup_name=$(echo "$latest_backup" | awk '{print $2}')
    created_str=$(echo "$latest_backup" | cut -d' ' -f3-)

    age_seconds=$((NOW - latest_ts))

    if ((age_seconds > MAX_AGE_SECONDS)); then
        echo "  ⚠️ Backup '$backup_name' ist zu alt: $created_str"
    else
        echo "  ✅ Backup '$backup_name' ist aktuell (Erstellt: $created_str)"
    fi
done
