#!/usr/bin/env bash
_pwd="$(pwd)"
_basedir="${_pwd}/$(dirname $(which ${0}))"
cd ${_basedir} && cd $(git rev-parse --show-toplevel)

git pull

task infrastructure:create
task pre-commit:init
task ansible:deps
task ansible:clean-cache
task ansible:playbook:ubuntu-prepare
task ansible:playbook:k3s-install || task ansible:playbook:k3s-install
task ansible:playbook:flux

sleep 800

export KUBECONFIG=~/iCloudDrive/Allgemein/kubectl/homelab.yaml

task flux:reconcile

echo "$(date +%X) - Check for helmreleases"
while kubectl get helmreleases.helm.toolkit.fluxcd.io -A | grep -v STATUS | grep -v succeeded > /dev/null; do
echo "$(date +%X) - Wait until all helmreleases are ready"
echo "$(date +%X) - Trying to speed that up..."
while kubectl get helmreleases.helm.toolkit.fluxcd.io -A | grep "failed\|exhausted" | grep -v STATUS; do
    kubectl get helmreleases.helm.toolkit.fluxcd.io -A | grep "failed\|exhausted" | grep -v STATUS | awk '{ print $1 " " $2 }' | xargs -L1 kubectl delete helmreleases.helm.toolkit.fluxcd.io -n
    sleep 60
done
task flux:reconcile
done

# kubectl logs -n utils -l app=pv-restore-job -f

cd ${_pwd}
