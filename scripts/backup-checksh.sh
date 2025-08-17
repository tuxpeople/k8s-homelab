#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${0}")/lib/common.sh"

# Configuration
NAMESPACE="storage"
MAX_AGE_SECONDS=$((24 * 60 * 60)) # 24 hours

# Date command: fallback to gdate if available
if command -v gdate >/dev/null 2>&1; then
    DATE_CMD="gdate"
else
    DATE_CMD="date"
fi

function check_longhorn_backups() {
    check_cli kubectl jq
    
    local now=$($DATE_CMD -u +%s)
    
    log info "Checking Longhorn backups in namespace '$NAMESPACE'..."

    # Get all volumes
    local volumes
    volumes=$(kubectl get volumes.longhorn.io -n "$NAMESPACE" -o json | jq -r '.items[].metadata.name')

    for volume in $volumes; do
        log debug "Checking volume: $volume"

        # Find all backups for this volume
        local backups
        backups=$(kubectl get backups.longhorn.io -n "$NAMESPACE" -o json | jq -r --arg vol "$volume" \
            '.items[] | select(.status.volumeName == $vol) | {name: .metadata.name, created: .status.backupCreatedAt, state: .status.state}')

        if [ -z "$backups" ]; then
            log warn "No backup found for volume: $volume"
            continue
        fi

        # Find the latest successful backup
        local latest_backup
        latest_backup=$(kubectl get backups.longhorn.io -n "$NAMESPACE" -o json | jq -r --arg vol "$volume" '
        .items[] |
        select(.status.volumeName == $vol and .status.state == "Completed" and .status.backupCreatedAt != null) |
        {name: .metadata.name, created: .status.backupCreatedAt} |
        @base64' | while read -r line; do
            local data name created created_ts
            data=$(echo "$line" | base64 --decode)
            name=$(echo "$data" | jq -r '.name')
            created=$(echo "$data" | jq -r '.created')
            created_ts=$($DATE_CMD -d "$created" +%s 2>/dev/null)

            if [ -n "$created_ts" ]; then
                echo "$created_ts $name $created"
            fi
        done | sort -rn | head -n 1)

        if [ -z "$latest_backup" ]; then
            log warn "No valid (Completed) backup found for volume: $volume"
            continue
        fi

        local latest_ts backup_name created_str age_seconds
        latest_ts=$(echo "$latest_backup" | awk '{print $1}')
        backup_name=$(echo "$latest_backup" | awk '{print $2}')
        created_str=$(echo "$latest_backup" | cut -d' ' -f3-)
        age_seconds=$((now - latest_ts))

        if ((age_seconds > MAX_AGE_SECONDS)); then
            log warn "Backup is too old" "volume=$volume" "backup=$backup_name" "created=$created_str"
        else
            log info "Backup is current" "volume=$volume" "backup=$backup_name" "created=$created_str"
        fi
    done
}

function main() {
    check_longhorn_backups
}

main "$@"
