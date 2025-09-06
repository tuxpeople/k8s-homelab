#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${0}")/lib/common.sh"

function view_longhorn_backups() {
    check_cli kubectl jq column

    log info "Retrieving Longhorn backup information..."

    (
        printf '%s\t%s\t%s\t%s\t%s\n' 'Namespace' 'BackupName' 'PVName' 'PVCName' 'SnapshotCreatedAt'
        kubectl get backups.longhorn.io -A -o=json |
        jq -r '
          .items
          | sort_by(.status.backupCreatedAt | fromdateiso8601)
          | reverse
          | .[] |
          [
            .metadata.namespace,
            .metadata.name,
            (.spec.labels.KubernetesStatus | fromjson | .pvName),
            (.spec.labels.KubernetesStatus | fromjson | .pvcName),
            (
              .status.backupCreatedAt
              | fromdateiso8601
              | strflocaltime("%Y-%m-%d %H:%M:%S %Z")
            )
          ]
          | @tsv
        '
    ) | column -s $'\t' -t

    log info "Backup listing completed"
}

function main() {
    view_longhorn_backups
}

main "$@"
