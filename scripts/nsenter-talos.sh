#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${0}")/lib/common.sh"

# Script for creating a privileged debug pod that provides shell access to Talos nodes
# This is useful for debugging node-level issues when standard kubectl exec isn't available

function usage() {
    cat << EOF
Usage: $0 <node-name>

Creates a privileged debug pod on the specified Talos node for troubleshooting.

Arguments:
    node-name    The name of the Kubernetes node to debug

Examples:
    $0 control-01
    $0 worker-02

Note: This creates a privileged pod with full host access. Use with caution.
EOF
}

function validate_node() {
    local node="$1"
    
    log debug "Validating node exists" "node=$node"
    
    if ! kubectl get node "$node" &>/dev/null; then
        log error "Node does not exist" "node=$node"
        return 1
    fi
    
    log debug "Node validation successful" "node=$node"
}

function create_debug_pod() {
    local node="$1"
    local pod_name="${USER}-nsenter-${node}"
    
    log info "Creating debug pod on node" "node=$node" "pod=$pod_name"
    
    # Check if pod already exists
    if kubectl -n kube-system get pod "$pod_name" &>/dev/null; then
        log warn "Debug pod already exists, deleting it first" "pod=$pod_name"
        kubectl -n kube-system delete pod "$pod_name" --wait=true
    fi
    
    local node_selector='"nodeSelector": { "kubernetes.io/hostname": "'${node}'" },'
    
    kubectl -n kube-system run "$pod_name" \
        --restart=Never \
        -it \
        --rm \
        --image=overridden \
        --overrides='{
          "spec": {
            "hostPID": true,
            "hostNetwork": true,
            '"${node_selector}"'
            "tolerations": [{
                "operator": "Exists"
            }],
            "containers": [
              {
                "name": "nsenter",
                "image": "mirror.gcr.io/library/busybox:musl",
                "command": [
                  "sh", 
                  "-c", 
                  "mkdir -p /host/var/lib/busybox; cp -r /bin/busybox /host/var/lib/busybox/; export PATH=\"$PATH:/var/lib/busybox\"; /host/var/lib/busybox/busybox --install /host/var/lib/busybox; nsenter -t1 -m -u -i -n /var/lib/busybox/busybox sh"
                ],
                "stdin": true,
                "tty": true,
                "securityContext": {
                  "privileged": true
                },
                "volumeMounts": [
                  {
                    "name": "host-var",
                    "mountPath": "/host/var"
                  }
                ]
              }
            ],
            "volumes": [
              {
                "name": "host-var",
                "hostPath": {
                  "path": "/var"
                }
              }
            ]
          }
        }'
}

function main() {
    local node="${1:-}"
    
    if [[ -z "$node" ]]; then
        log error "Node name is required"
        usage
        exit 1
    fi
    
    check_cli kubectl
    validate_node "$node"
    create_debug_pod "$node"
}

main "$@"