#!/usr/bin/env bash

# PVC=sonarr-config-v1 \
# NS=media \
# kubectl -n rook-ceph exec -it $(kubectl -n rook-ceph get pod -l "app=rook-direct-mount" -o jsonpath='{.items[0].metadata.name}') -- /scripts/fsck.sh --rbd $(kubectl get pv/$(kubectl get pv | grep "$PVC" | awk -F' ' '{print $1}') -n "${NS}" -o json | jq -rj '.spec.csi.volumeAttributes.imageName')

# Set defaults
rbd=""

# Collect command line parameters
while [ $# -gt 0 ]; do
    if [[ "$1" == *"--"* ]]; then
        param="${1/--/}"
        declare "$param"="$2"
    fi
    shift
done

if [[ -z "${rbd}" ]]; then
    echo "Required parameter '--rbd' not set!"
    exit 1
fi

# ceph osd pool ls
rbd map -p ceph-blockpool "${rbd}" | xargs fsck -fvy
rbd unmap -p ceph-blockpool "${rbd}"
