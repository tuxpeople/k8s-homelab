#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${0}")/lib/common.sh"

function usage() {
    cat << EOF
Usage: $0 [options]

Performs a safe emergency shutdown of the Kubernetes cluster.

This script gracefully shuts down cluster services in the proper order:
1. Scale down non-critical applications
2. Stop data-intensive workloads 
3. Drain worker nodes
4. Shut down control plane components
5. Power down Talos nodes

Options:
    --skip-apps     Skip application scaling (faster shutdown)
    --force         Force shutdown without confirmations
    --dry-run       Show what would be done without executing
    -h, --help      Show this help message

Examples:
    $0                  # Interactive safe shutdown
    $0 --force          # Non-interactive shutdown
    $0 --dry-run        # Preview shutdown steps
    $0 --skip-apps      # Skip app scaling for faster shutdown

WARNING: This will shut down the entire cluster!
EOF
}

function confirm_shutdown() {
    if [[ "${FORCE_SHUTDOWN:-false}" == "true" ]]; then
        log warn "Force shutdown mode enabled, skipping confirmation"
        return 0
    fi
    
    log warn "This will perform an EMERGENCY SHUTDOWN of the entire cluster!"
    log warn "All running applications will be stopped and nodes will be powered down"
    echo
    read -p "Are you absolutely sure you want to continue? (type 'SHUTDOWN' to confirm): " confirm
    
    if [[ "$confirm" != "SHUTDOWN" ]]; then
        log info "Shutdown cancelled by user"
        exit 0
    fi
    
    log warn "Emergency shutdown confirmed, proceeding..."
}

function scale_down_applications() {
    if [[ "${SKIP_APPS:-false}" == "true" ]]; then
        log info "Skipping application scaling (--skip-apps enabled)"
        return 0
    fi
    
    log info "Step 1: Scaling down non-critical applications..."
    
    # Scale down HelmReleases in order of priority (least critical first)
    local app_namespaces=("media" "productivity" "tools" "ai" "default")
    
    for namespace in "${app_namespaces[@]}"; do
        if ! kubectl get namespace "$namespace" &>/dev/null; then
            log debug "Namespace does not exist, skipping" "namespace=$namespace"
            continue
        fi
        
        log info "Scaling down applications in namespace" "namespace=$namespace"
        
        # Suspend all HelmReleases in namespace
        local helm_releases
        helm_releases=$(kubectl get helmrelease -n "$namespace" -o name 2>/dev/null || true)
        
        for release in $helm_releases; do
            if [[ "${DRY_RUN:-false}" == "true" ]]; then
                log info "[DRY-RUN] Would suspend HelmRelease: $release"
            else
                log debug "Suspending HelmRelease" "release=$release"
                kubectl patch "$release" -n "$namespace" -p '{"spec":{"suspend":true}}' --type=merge &
            fi
        done
        
        # Scale down deployments
        local deployments
        deployments=$(kubectl get deployment -n "$namespace" -o name 2>/dev/null || true)
        
        for deployment in $deployments; do
            if [[ "${DRY_RUN:-false}" == "true" ]]; then
                log info "[DRY-RUN] Would scale down deployment: $deployment"
            else
                log debug "Scaling down deployment" "deployment=$deployment"
                kubectl scale "$deployment" -n "$namespace" --replicas=0 &
            fi
        done
        
        # Scale down StatefulSets
        local statefulsets
        statefulsets=$(kubectl get statefulset -n "$namespace" -o name 2>/dev/null || true)
        
        for statefulset in $statefulsets; do
            if [[ "${DRY_RUN:-false}" == "true" ]]; then
                log info "[DRY-RUN] Would scale down StatefulSet: $statefulset"
            else
                log debug "Scaling down StatefulSet" "statefulset=$statefulset"
                kubectl scale "$statefulset" -n "$namespace" --replicas=0 &
            fi
        done
        
        wait # Wait for scaling operations to complete
        log info "Scaled down applications in namespace" "namespace=$namespace"
        sleep 5
    done
}

function shutdown_storage_workloads() {
    log info "Step 2: Shutting down storage-intensive workloads..."
    
    # Stop backup operations
    if kubectl get namespace storage &>/dev/null; then
        log info "Stopping backup operations..."
        
        # Scale down backup controllers
        local backup_controllers=("k8up-operator" "velero")
        for controller in "${backup_controllers[@]}"; do
            if kubectl get deployment -n storage "$controller" &>/dev/null; then
                if [[ "${DRY_RUN:-false}" == "true" ]]; then
                    log info "[DRY-RUN] Would scale down backup controller: $controller"
                else
                    log debug "Scaling down backup controller" "controller=$controller"
                    kubectl scale deployment -n storage "$controller" --replicas=0
                fi
            fi
        done
    fi
    
    # Gracefully shutdown Longhorn if present
    if kubectl get namespace longhorn-system &>/dev/null; then
        log info "Preparing Longhorn for shutdown..."
        
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log info "[DRY-RUN] Would prepare Longhorn volumes for shutdown"
        else
            # Detach all volumes
            log debug "Detaching Longhorn volumes..."
            local volumes
            volumes=$(kubectl get volumes.longhorn.io -n longhorn-system -o name 2>/dev/null || true)
            
            for volume in $volumes; do
                kubectl patch "$volume" -n longhorn-system -p '{"spec":{"nodeID":""}}' --type=merge || true
            done
            
            sleep 10
        fi
    fi
}

function drain_worker_nodes() {
    log info "Step 3: Draining worker nodes..."
    
    local worker_nodes
    worker_nodes=$(kubectl get nodes --no-headers -l '!node-role.kubernetes.io/control-plane' -o custom-columns=NAME:.metadata.name 2>/dev/null || true)
    
    for node in $worker_nodes; do
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log info "[DRY-RUN] Would drain worker node: $node"
        else
            log info "Draining worker node" "node=$node"
            kubectl drain "$node" --ignore-daemonsets --delete-emptydir-data --force --timeout=300s || true
        fi
    done
}

function shutdown_system_components() {
    log info "Step 4: Shutting down system components..."
    
    # Stop monitoring and observability
    if kubectl get namespace observability &>/dev/null; then
        log info "Stopping monitoring stack..."
        
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log info "[DRY-RUN] Would suspend monitoring HelmReleases"
        else
            local monitoring_releases
            monitoring_releases=$(kubectl get helmrelease -n observability -o name 2>/dev/null || true)
            
            for release in $monitoring_releases; do
                kubectl patch "$release" -n observability -p '{"spec":{"suspend":true}}' --type=merge &
            done
            wait
        fi
    fi
    
    # Stop Flux GitOps
    log info "Stopping Flux controllers..."
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log info "[DRY-RUN] Would scale down Flux controllers"
    else
        local flux_controllers=("source-controller" "kustomize-controller" "helm-controller" "notification-controller")
        
        for controller in "${flux_controllers[@]}"; do
            if kubectl get deployment -n flux-system "$controller" &>/dev/null; then
                kubectl scale deployment -n flux-system "$controller" --replicas=0 &
            fi
        done
        wait
    fi
    
    # Stop ingress controllers
    log info "Stopping ingress controllers..."
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log info "[DRY-RUN] Would scale down ingress controllers"
    else
        if kubectl get namespace network &>/dev/null; then
            local ingress_deployments
            ingress_deployments=$(kubectl get deployment -n network -o name 2>/dev/null || true)
            
            for deployment in $ingress_deployments; do
                kubectl scale "$deployment" -n network --replicas=0 &
            done
            wait
        fi
    fi
}

function shutdown_talos_nodes() {
    log info "Step 5: Shutting down Talos nodes..."
    
    if ! command -v talosctl &>/dev/null; then
        log warn "talosctl not found, skipping Talos shutdown"
        log warn "Nodes will need to be manually powered down"
        return 0
    fi
    
    # Get all nodes
    local all_nodes
    all_nodes=$(kubectl get nodes --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null || true)
    
    # Shutdown worker nodes first
    local worker_nodes
    worker_nodes=$(kubectl get nodes --no-headers -l '!node-role.kubernetes.io/control-plane' -o custom-columns=NAME:.metadata.name 2>/dev/null || true)
    
    for node in $worker_nodes; do
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log info "[DRY-RUN] Would shutdown worker node: $node"
        else
            log info "Shutting down worker node" "node=$node"
            talosctl shutdown --nodes "$node" || true
        fi
    done
    
    sleep 30
    
    # Shutdown control plane nodes
    local control_nodes
    control_nodes=$(kubectl get nodes --no-headers -l 'node-role.kubernetes.io/control-plane' -o custom-columns=NAME:.metadata.name 2>/dev/null || true)
    
    for node in $control_nodes; do
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log info "[DRY-RUN] Would shutdown control plane node: $node"
        else
            log info "Shutting down control plane node" "node=$node"
            talosctl shutdown --nodes "$node" || true
        fi
    done
}

function emergency_shutdown() {
    log warn "Beginning emergency cluster shutdown sequence..."
    
    local start_time
    start_time=$(date +%s)
    
    scale_down_applications
    shutdown_storage_workloads  
    drain_worker_nodes
    shutdown_system_components
    shutdown_talos_nodes
    
    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log info "Emergency shutdown dry-run completed" "duration=${duration}s"
    else
        log warn "Emergency shutdown completed" "duration=${duration}s"
        log warn "All cluster nodes should be powering down"
    fi
}

function main() {
    local skip_apps=false
    local force_shutdown=false
    local dry_run=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-apps)
                skip_apps=true
                export SKIP_APPS="true"
                shift
                ;;
            --force)
                force_shutdown=true
                export FORCE_SHUTDOWN="true"
                shift
                ;;
            --dry-run)
                dry_run=true
                export DRY_RUN="true"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    check_cli kubectl
    
    if [[ "$dry_run" == "true" ]]; then
        log info "DRY-RUN MODE: No actual changes will be made"
    fi
    
    confirm_shutdown
    emergency_shutdown
}

main "$@"