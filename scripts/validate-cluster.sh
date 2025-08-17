#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${0}")/lib/common.sh"

function usage() {
    cat << EOF
Usage: $0 [options]

Performs comprehensive health checks on the Kubernetes cluster.

Options:
    -q, --quick     Quick validation (skip non-critical checks)
    -v, --verbose   Verbose output with detailed information
    -h, --help      Show this help message

Examples:
    $0              # Full cluster validation
    $0 --quick      # Quick health check
    $0 --verbose    # Detailed validation output
EOF
}

function check_node_health() {
    log info "Checking node health..."
    
    local unhealthy_nodes
    unhealthy_nodes=$(kubectl get nodes --no-headers | grep -v "Ready" || true)
    
    if [[ -n "$unhealthy_nodes" ]]; then
        log warn "Found unhealthy nodes:"
        echo "$unhealthy_nodes" | while read -r line; do
            log warn "Unhealthy node: $line"
        done
        return 1
    else
        local node_count
        node_count=$(kubectl get nodes --no-headers | wc -l)
        log info "All nodes are healthy" "count=$node_count"
    fi
}

function check_system_pods() {
    log info "Checking system pods..."
    
    local namespaces=("kube-system" "flux-system" "cert-manager" "storage")
    local failed_pods=0
    
    for namespace in "${namespaces[@]}"; do
        if ! kubectl get namespace "$namespace" &>/dev/null; then
            log debug "Namespace does not exist, skipping" "namespace=$namespace"
            continue
        fi
        
        local unhealthy_pods
        unhealthy_pods=$(kubectl get pods -n "$namespace" --no-headers | grep -E "(Error|CrashLoopBackOff|ImagePullBackOff|Pending)" || true)
        
        if [[ -n "$unhealthy_pods" ]]; then
            log warn "Found unhealthy pods in namespace" "namespace=$namespace"
            echo "$unhealthy_pods" | while read -r line; do
                log warn "Unhealthy pod: $line"
            done
            ((failed_pods++))
        else
            local pod_count
            pod_count=$(kubectl get pods -n "$namespace" --no-headers | wc -l)
            log debug "All pods healthy in namespace" "namespace=$namespace" "count=$pod_count"
        fi
    done
    
    if ((failed_pods > 0)); then
        log warn "Found issues in $failed_pods namespace(s)"
        return 1
    else
        log info "All system pods are healthy"
    fi
}

function check_flux_status() {
    log info "Checking Flux GitOps status..."
    
    # Check if Flux is installed
    if ! kubectl get namespace flux-system &>/dev/null; then
        log warn "Flux namespace not found"
        return 1
    fi
    
    # Check Flux controllers
    local flux_controllers=("source-controller" "kustomize-controller" "helm-controller" "notification-controller")
    
    for controller in "${flux_controllers[@]}"; do
        if ! kubectl get deployment -n flux-system "$controller" &>/dev/null; then
            log warn "Flux controller not found" "controller=$controller"
            continue
        fi
        
        local ready_replicas available_replicas
        ready_replicas=$(kubectl get deployment -n flux-system "$controller" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        available_replicas=$(kubectl get deployment -n flux-system "$controller" -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")
        
        if [[ "$ready_replicas" != "$available_replicas" ]] || [[ "$ready_replicas" == "0" ]]; then
            log warn "Flux controller not ready" "controller=$controller" "ready=$ready_replicas" "available=$available_replicas"
        else
            log debug "Flux controller healthy" "controller=$controller"
        fi
    done
    
    # Check GitRepository source
    local git_sources
    git_sources=$(kubectl get gitrepository -n flux-system --no-headers 2>/dev/null | grep -v "True" || true)
    
    if [[ -n "$git_sources" ]]; then
        log warn "Found GitRepository sources with issues:"
        echo "$git_sources" | while read -r line; do
            log warn "GitRepository issue: $line"
        done
    else
        log info "All GitRepository sources are healthy"
    fi
    
    # Check Kustomizations
    local failed_kustomizations
    failed_kustomizations=$(kubectl get kustomization -A --no-headers 2>/dev/null | grep -v "True" || true)
    
    if [[ -n "$failed_kustomizations" ]]; then
        log warn "Found Kustomizations with issues:"
        echo "$failed_kustomizations" | while read -r line; do
            log warn "Kustomization issue: $line"
        done
        return 1
    else
        log info "All Kustomizations are reconciled"
    fi
}

function check_helm_releases() {
    log info "Checking Helm releases..."
    
    local failed_releases
    failed_releases=$(kubectl get helmrelease -A --no-headers 2>/dev/null | grep -v "True" || true)
    
    if [[ -n "$failed_releases" ]]; then
        log warn "Found HelmReleases with issues:"
        echo "$failed_releases" | while read -r line; do
            log warn "HelmRelease issue: $line"
        done
        return 1
    else
        local release_count
        release_count=$(kubectl get helmrelease -A --no-headers 2>/dev/null | wc -l)
        log info "All Helm releases are deployed successfully" "count=$release_count"
    fi
}

function check_storage_health() {
    log info "Checking storage health..."
    
    # Check Longhorn if present
    if kubectl get namespace longhorn-system &>/dev/null; then
        local longhorn_volumes
        longhorn_volumes=$(kubectl get volumes.longhorn.io -A --no-headers 2>/dev/null | grep -v "Healthy" || true)
        
        if [[ -n "$longhorn_volumes" ]]; then
            log warn "Found unhealthy Longhorn volumes:"
            echo "$longhorn_volumes" | while read -r line; do
                log warn "Unhealthy volume: $line"
            done
        else
            local volume_count
            volume_count=$(kubectl get volumes.longhorn.io -A --no-headers 2>/dev/null | wc -l)
            log info "All Longhorn volumes are healthy" "count=$volume_count"
        fi
    fi
    
    # Check PVs
    local failed_pvs
    failed_pvs=$(kubectl get pv --no-headers 2>/dev/null | grep -v "Bound" || true)
    
    if [[ -n "$failed_pvs" ]]; then
        log warn "Found PersistentVolumes not in Bound state:"
        echo "$failed_pvs" | while read -r line; do
            log warn "PV issue: $line"
        done
    else
        local pv_count
        pv_count=$(kubectl get pv --no-headers 2>/dev/null | wc -l)
        log info "All PersistentVolumes are bound" "count=$pv_count"
    fi
}

function check_network_health() {
    log info "Checking network health..."
    
    # Check Cilium if present
    if kubectl get namespace kube-system &>/dev/null && kubectl get daemonset -n kube-system cilium &>/dev/null; then
        local cilium_ready desired_ready
        cilium_ready=$(kubectl get daemonset -n kube-system cilium -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
        desired_ready=$(kubectl get daemonset -n kube-system cilium -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "1")
        
        if [[ "$cilium_ready" != "$desired_ready" ]]; then
            log warn "Cilium pods not ready" "ready=$cilium_ready" "desired=$desired_ready"
        else
            log info "Cilium network is healthy" "pods=$cilium_ready"
        fi
    fi
    
    # Check ingress controllers
    local ingress_namespaces=("network")
    
    for namespace in "${ingress_namespaces[@]}"; do
        if ! kubectl get namespace "$namespace" &>/dev/null; then
            continue
        fi
        
        local ingress_controllers
        ingress_controllers=$(kubectl get deployment -n "$namespace" --no-headers 2>/dev/null | grep -E "(ingress|nginx)" || true)
        
        if [[ -n "$ingress_controllers" ]]; then
            echo "$ingress_controllers" | while read -r controller _ready _up_to_date _available _age; do
                local ready_replicas available_replicas
                ready_replicas=$(kubectl get deployment -n "$namespace" "$controller" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
                available_replicas=$(kubectl get deployment -n "$namespace" "$controller" -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")
                
                if [[ "$ready_replicas" != "$available_replicas" ]] || [[ "$ready_replicas" == "0" ]]; then
                    log warn "Ingress controller not ready" "controller=$controller" "ready=$ready_replicas" "available=$available_replicas"
                else
                    log debug "Ingress controller healthy" "controller=$controller"
                fi
            done
        fi
    done
}

function check_certificates() {
    log info "Checking certificate health..."
    
    if ! kubectl get namespace cert-manager &>/dev/null; then
        log debug "cert-manager namespace not found, skipping certificate checks"
        return 0
    fi
    
    local failed_certificates
    failed_certificates=$(kubectl get certificate -A --no-headers 2>/dev/null | grep -v "True" || true)
    
    if [[ -n "$failed_certificates" ]]; then
        log warn "Found certificates with issues:"
        echo "$failed_certificates" | while read -r line; do
            log warn "Certificate issue: $line"
        done
        return 1
    else
        local cert_count
        cert_count=$(kubectl get certificate -A --no-headers 2>/dev/null | wc -l)
        log info "All certificates are ready" "count=$cert_count"
    fi
}

function quick_validation() {
    log info "Performing quick cluster validation..."
    
    local errors=0
    
    check_node_health || ((errors++))
    check_system_pods || ((errors++))
    check_flux_status || ((errors++))
    
    if ((errors > 0)); then
        log warn "Quick validation found $errors issue(s)"
        return 1
    else
        log info "Quick validation passed successfully"
    fi
}

function full_validation() {
    log info "Performing full cluster validation..."
    
    local errors=0
    
    check_node_health || ((errors++))
    check_system_pods || ((errors++))
    check_flux_status || ((errors++))
    check_helm_releases || ((errors++))
    check_storage_health || ((errors++))
    check_network_health || ((errors++))
    check_certificates || ((errors++))
    
    if ((errors > 0)); then
        log warn "Full validation found $errors issue(s)"
        return 1
    else
        log info "Full validation passed successfully"
    fi
}

function main() {
    local quick_mode=false
    local verbose_mode=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -q|--quick)
                quick_mode=true
                shift
                ;;
            -v|--verbose)
                verbose_mode=true
                export LOG_LEVEL="debug"
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
    
    if [[ "$quick_mode" == "true" ]]; then
        quick_validation
    else
        full_validation
    fi
}

main "$@"