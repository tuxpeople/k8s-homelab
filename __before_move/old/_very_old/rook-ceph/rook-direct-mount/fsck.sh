#!/usr/bin/env bash

# PVC=sonarr-config-v1 \
# NS=media \
# l
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
