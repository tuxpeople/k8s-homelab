#!/bin/bash

kubectl delete ns k10 --force &
kubectl get volumesnapshots.snapshot.storage.k8s.io -A -o json | kubectl delete -f -
kubectl delete volumesnapshotclasses.snapshot.storage.k8s.io k10-clone-portworx-csi-snapclass
kubectl delete volumesnapshotclasses.snapshot.storage.k8s.io portworx-csi-snapclass
kubectl get pods -n kube-system -l app=snapshot-controller -o json | kubectl delete -f -
kubectl get volumesnapshots.snapshot.storage.k8s.io -A -o json | kubectl delete -f -
sleep 60
killall kubectl
(
NAMESPACE=k10
kubectl proxy &
kubectl get namespace $NAMESPACE -o json |jq '.spec = {"finalizers":[]}' >temp.json
curl -k -H "Content-Type: application/json" -X PUT --data-binary @temp.json 127.0.0.1:8001/api/v1/namespaces/$NAMESPACE/finalize
rm temp.json
)
killall kubectl
