#!/usr/bin/env bash
set -euo pipefail

# get all pvcs that match the label pv-backup/enabled=true
source_ns_pvcs=$(kubectl get pvc --all-namespaces -l pv-backup/enabled=true -o=json | jq -c '.items[] | {name: .metadata.name, namespace: .metadata.namespace}')

for ns_pvc in $source_ns_pvcs; do
  source_pvc_name=$(jq -r '.name'<<<"$ns_pvc")
  source_pvc_ns=$(jq -r '.namespace'<<<"$ns_pvc")

  # get the associated deployment for this pvc
  deploy_details=$(kubectl get deploy --all-namespaces -o=json | \
    jq --arg pvc "$source_pvc_name" -c '.items[] | {name: .metadata.name, namespace: .metadata.namespace, claimName: .spec.template.spec |  select( has ("volumes") ).volumes[] | select( has ("persistentVolumeClaim") ).persistentVolumeClaim.claimName } | select(.claimName==$pvc)')
  deploy_name=$(jq -r '.name'<<<"$deploy_details")
  deploy_ns=$(jq -r '.namespace'<<<"$deploy_details")

  # scale down the deployment so we can mount the PVC later
  kubectl scale -n "$deploy_ns" deploy "$deploy_name" --replicas=0

  # wait for the deployment to successfully scale down
  # shellcheck disable=SC2046
  while [ $(kubectl get po -l app.kubernetes.io/name="$deploy_name" -n "$deploy_ns" -ojson | jq -r '.items | length') -ne 0 ]; do
    sleep 1
  done

  # copy from source pvc to dest pvc
  kubectl -n rook-ceph exec -it $(kubectl -n rook-ceph get pod -l "app=rook-direct-mount" -o jsonpath='{.items[0].metadata.name}') -- /scripts/backup.sh --rbd $(kubectl get pv/$(kubectl get pv | grep "$source_pvc_name" | awk -F' ' '{print $1}') -n "${deploy_ns}" -o json | jq -rj '.spec.csi.volumeAttributes.imageName') --pvc "$source_pvc_name"
  # scale deployment back up; blindly do not wait so we can move on to the next backup
  # TODO: maybe wait in background?
  kubectl scale -n "$deploy_ns" deploy "$deploy_name" --replicas=1
done
