#!/usr/bin/env bash
set -euo pipefail

_step_counter=0
step() {
  _step_counter=$(( _step_counter + 1 ))
  printf '\n\033[1;36m%d) %s\033[0m\n' $_step_counter "$@" >&2  # bold cyan
}

disable_monitoring() {
  step "Disable monitoring"
  SECRET=$(kubectl -n flux-system get secrets cluster-secrets -o go-template='{{ .data.SECRET_UPTIMEROBOT_APIKEY | base64decode }}')
  MONITORS=$(curl -s -X POST -H "Content-Type: application/x-www-form-urlencoded" -H "Cache-Control: no-cache" -d "api_key=${SECRET}&format=json&logs=1" "https://api.uptimerobot.com/v2/getMonitors" | jq '.monitors[].id')
  for i in $(echo ${MONITORS}); do
    sleep 10
    curl -s -X POST -H "Cache-Control: no-cache" -H "Content-Type: application/x-www-form-urlencoded" -d "api_key=${SECRET}&format=json&id=${i}&status=0" "https://api.uptimerobot.com/v2/editMonitor"
    echo
  done
}

enable_monitoring() {
  step "Enable monitoring"
  sleep 30
  SECRET=$(kubectl -n flux-system get secrets cluster-secrets -o go-template='{{ .data.SECRET_UPTIMEROBOT_APIKEY | base64decode }}')
  MONITORS=$(curl -s -X POST -H "Content-Type: application/x-www-form-urlencoded" -H "Cache-Control: no-cache" -d "api_key=${SECRET}&format=json&logs=1" "https://api.uptimerobot.com/v2/getMonitors" | jq '.monitors[].id')
  for i in $(echo ${MONITORS}); do
    sleep 10
    curl -s -X POST -H "Cache-Control: no-cache" -H "Content-Type: application/x-www-form-urlencoded" -d "api_key=${SECRET}&format=json&id=${i}&status=1" "https://api.uptimerobot.com/v2/editMonitor"
    echo
  done
}

wait_for_helmreleases() {
  while kubectl get helmreleases.helm.toolkit.fluxcd.io -A | grep -v STATUS | grep -v succeeded > /dev/null; do
    echo "$(date +%X) - Wait until all helmreleases are ready"
    echo "$(date +%X) - Trying to speed that up..."
    while kubectl get helmreleases.helm.toolkit.fluxcd.io -A | grep "failed\|exhausted" | grep -v STATUS; do
      kubectl get helmreleases.helm.toolkit.fluxcd.io -A | grep "failed\|exhausted" | grep -v STATUS | awk '{ print $1 " " $2 }' | xargs -L1 kubectl delete helmreleases.helm.toolkit.fluxcd.io -n
      sleep 30
    done
    sleep 30
  done
}

wait_for_helmreleases

disable_monitoring

step "Get all pvcs that match the label pv-backup/enabled=true"
source_ns_pvcs=$(kubectl get pvc --all-namespaces -l pv-backup/enabled=true -o=json | jq -c '.items[] | {name: .metadata.name, namespace: .metadata.namespace}')

for ns_pvc in $source_ns_pvcs; do
  source_pvc_name=$(jq -r '.name'<<<"$ns_pvc")
  source_pvc_ns=$(jq -r '.namespace'<<<"$ns_pvc")

  # get the associated deployment for this pvc
  deploy_details=$(kubectl get deploy --all-namespaces -o=json | \
    jq --arg pvc "$source_pvc_name" -c '.items[] | {name: .metadata.name, namespace: .metadata.namespace, claimName: .spec.template.spec |  select( has ("volumes") ).volumes[] | select( has ("persistentVolumeClaim") ).persistentVolumeClaim.claimName } | select(.claimName==$pvc)')
  deploy_name=$(jq -r '.name'<<<"$deploy_details")
  deploy_ns=$(jq -r '.namespace'<<<"$deploy_details")

  step "Scale down the deployent $deploy_name down, backup pvc $source_pvc_name and scale the deployment up."
  # scale down the deployment so we can mount the PVC later
  kubectl scale -n "$deploy_ns" deploy "$deploy_name" --replicas=0

  # wait for the deployment to successfully scale down
  # shellcheck disable=SC2046
  while [ $(kubectl get po -l app.kubernetes.io/name="$deploy_name" -n "$deploy_ns" -ojson | jq -r '.items | length') -ne 0 ]; do
    sleep 1
  done

  sleep 5

  # copy from source pvc to dest pvc
  kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-direct-mount" -o jsonpath='{.items[0].metadata.name}') -- /scripts/restore.sh --rbd $(kubectl get pv/$(kubectl get pv | grep "$source_pvc_name" | awk -F' ' '{print $1}') -n "${deploy_ns}" -o json | jq -rj '.spec.csi.volumeAttributes.imageName') --pvc "$source_pvc_name"
  # scale deployment back up; blindly do not wait so we can move on to the next backup
  # TODO: maybe wait in background?

  sleep 5

  kubectl scale -n "$deploy_ns" deploy "$deploy_name" --replicas=1
done

trap enable_monitoring EXIT
