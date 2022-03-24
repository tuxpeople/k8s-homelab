# Problems with Rook

Infos:
- https://github.com/rook/rook/blob/master/Documentation/ceph-common-issues.md
- https://github.com/rook/rook/blob/master/Documentation/ceph-csi-troubleshooting.md
- https://github.com/rook/rook/blob/master/Documentation/common-issues.md

## CephClusterWarningState
See https://hub.syn.tools/rook-ceph/runbooks/CephClusterWarningState.html

```
kubectl -n rook-ceph exec -it deploy/rook-direct-mount -- ceph status
```

# ceph status: "x daemons have recently crashed"
See https://it-ops.dev/ceph-daemons-have-recently-crashed

## Failed Mount rdb image XY is still being used

Scale down the deployment.

Get RBD image name from PV:
```
kubectl describe pv pvc-******************3 | grep imageName
```

Search for rdb images on all machines:
```
for pod in `kubectl -n rook-ceph get pods|grep rbdplugin|grep -v provisioner|awk '{print $1}'`; do
  echo "--- $pod ---"
  kubectl exec -it -n rook-ceph $pod -c csi-rbdplugin -- /usr/bin/rbd device list
done
```
[Source](https://github.com/rook/rook/issues/4772#issuecomment-601064683)

Alternative:
```
for pod in `kubectl -n rook-ceph get pods|grep rbdplugin|grep -v provisioner|awk '{print $1}'`; do echo $pod; kubectl exec -it -n rook-ceph $pod -c csi-rbdplugin -- rbd device list; done
```
[Source](https://github.com/rook/rook/issues/4772#issuecomment-880130455)

Go to the corresponding pod:

```
kubectl exec -it -n rook-ceph csi-rbdplugin-******** -c csi-rbdplugin /bin/sh
```

Try to unmap:
```
rbd unmap -p ceph-blockpool csi-vol-*********
```

This can be forced (eg. if `Device or resource busy`):
```
rbd unmap -o force -p ceph-blockpool csi-vol-*********
```

Scale up the deployment.

Once the pod starts, you should see a corresponding `volumeattachment` in the cluster:
```
kubectl get volumeattachment
```
See: https://github.com/rook/rook/blob/master/Documentation/ceph-csi-troubleshooting.md#volume-attachment
