#!/usr/bin/env bash
_step_counter=0
step() {
        _step_counter=$(( _step_counter + 1 ))
        printf '\n\033[1;36m%d) %s\033[0m\n' $_step_counter "$@" >&2  # bold cyan
}

if ! kubectl get nodes | grep k3s > /dev/null; then
    echo "Fatal error"
    exit 1
fi

export KUBECONFIG=~/iCloudDrive/Allgemein/kubectl/homelab.yaml

step "Label the volumes"
for i in $(kubectl get pvc -A -l recurring-job-group.longhorn.io/normal=enabled -o=custom-columns=VOLUME:.spec.volumeName | grep -v VOLUME); do
    kubectl -n longhorn-system label volume/$i recurring-job.longhorn.io/normal=enabled
done
