#!/bin/bash

kubectl delete ns k10 --force
kubectl get volumesnapshots.snapshot.storage.k8s.io -A -o json | kubectl delete -f -
kubectl delete volumesnapshotclasses.snapshot.storage.k8s.io k10-clone-portworx-csi-snapclass
kubectl delete volumesnapshotclasses.snapshot.storage.k8s.io portworx-csi-snapclass
kubectl get pods -n kube-system -l app=snapshot-controller -o json | kubectl delete -f -
kubectl get volumesnapshots.snapshot.storage.k8s.io -A -o json | kubectl delete -f -
