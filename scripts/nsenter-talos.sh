#!/bin/sh
set -x

node=${1}
#nodeName=$(kubectl get node ${node} -o template --template='{{index .metadata.labels "kubernetes.io/hostname"}}')
nodeSelector='"nodeSelector": { "kubernetes.io/hostname": "'${node:?}'" },'
podName=${USER}-nsenter-${node}
kubectl -n kube-system run ${podName:?} --restart=Never -it --rm --image overriden --overrides '
{
  "spec": {
    "hostPID": true,
    "hostNetwork": true,
    '"${nodeSelector?}"'
    "tolerations": [{
        "operator": "Exists"
    }],
    "containers": [
      {
        "name": "nsenter",
        "image": "mirror.gcr.io/library/busybox:musl",
        "command": ["sh", "-c", "mkdir -p /host/var/lib/busybox; cp -r /bin/busybox /host/var/lib/busybox/; export PATH=\"$PATH:/var/lib/busybox\"; /host/var/lib/busybox/busybox --install /host/var/lib/busybox; nsenter -t1 -m -u -i -n /var/lib/busybox/busybox sh"],
        "stdin": true,
        "tty": true,
        "securityContext": {
          "privileged": true
        },
        "volumeMounts": [
          {
            "name": "host-tmp",
            "mountPath": "/host/var"
          }
        ]
      }
    ],
    "volumes": [
      {
        "name": "host-tmp",
        "hostPath": {
          "path": "/var"
        }
      }
    ]
  }
}'