#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${0}")/lib/common.sh"

function usage() {
    cat << EOF
Usage: $0 [component] [options]

Provides quick access to troubleshooting information for cluster components.

Components:
    flux        GitOps and reconciliation issues
    storage     Longhorn, PVs, and storage problems  
    network     Cilium, ingress, and connectivity issues
    apps        Application deployment and runtime issues
    nodes       Node health and Talos diagnostics
    all         Run diagnostics for all components

Options:
    --logs      Show recent logs (where applicable)
    --events    Show events for the component
    --detailed  Show detailed information
    -h, --help  Show this help message

Examples:
    $0 flux                    # Quick Flux status
    $0 storage --logs          # Storage status with logs
    $0 network --events        # Network issues with events
    $0 apps myapp              # Specific app troubleshooting
    $0 all --detailed          # Comprehensive diagnostics

Troubleshooting quick reference:
    kubectl get events --sort-by=.metadata.creationTimestamp
    kubectl describe pod <pod-name>
    kubectl logs <pod-name> --previous
    flux get all
    talosctl logs
EOF
}

function show_flux_diagnostics() {
    log info "Flux GitOps Diagnostics"
    echo "========================"
    
    # Flux system status
    log info "Flux Controller Status:"
    kubectl get pods -n flux-system -o wide 2>/dev/null || log warn "Cannot access flux-system namespace"
    echo
    
    # GitRepository sources
    log info "Git Repository Sources:"
    kubectl get gitrepository -A 2>/dev/null || log warn "No GitRepository resources found"
    echo
    
    # Kustomizations
    log info "Kustomization Status:"
    kubectl get kustomization -A 2>/dev/null || log warn "No Kustomization resources found"
    echo
    
    # HelmReleases
    log info "Helm Release Status:"
    kubectl get helmrelease -A 2>/dev/null || log warn "No HelmRelease resources found"
    echo
    
    if [[ "${SHOW_LOGS:-false}" == "true" ]]; then
        log info "Recent Flux Controller Logs:"
        kubectl logs -n flux-system -l app=source-controller --tail=20 2>/dev/null || true
        echo
        kubectl logs -n flux-system -l app=kustomize-controller --tail=20 2>/dev/null || true
        echo
    fi
    
    if [[ "${SHOW_EVENTS:-false}" == "true" ]]; then
        log info "Recent Flux Events:"
        kubectl get events -n flux-system --sort-by=.metadata.creationTimestamp --field-selector type=Warning 2>/dev/null || true
        echo
    fi
}

function show_storage_diagnostics() {
    log info "Storage Diagnostics"
    echo "==================="
    
    # PersistentVolumes
    log info "PersistentVolume Status:"
    kubectl get pv -o wide 2>/dev/null || log warn "Cannot access PersistentVolumes"
    echo
    
    # PersistentVolumeClaims by namespace
    log info "PersistentVolumeClaim Status:"
    kubectl get pvc -A -o wide 2>/dev/null || log warn "Cannot access PersistentVolumeClaims"
    echo
    
    # Longhorn system
    if kubectl get namespace longhorn-system &>/dev/null; then
        log info "Longhorn System Status:"
        kubectl get pods -n longhorn-system -o wide 2>/dev/null || true
        echo
        
        log info "Longhorn Volume Status:"
        kubectl get volumes.longhorn.io -A 2>/dev/null || true
        echo
        
        log info "Longhorn Engine Status:"
        kubectl get engines.longhorn.io -A 2>/dev/null || true
        echo
        
        if [[ "${SHOW_LOGS:-false}" == "true" ]]; then
            log info "Recent Longhorn Manager Logs:"
            kubectl logs -n longhorn-system -l app=longhorn-manager --tail=20 2>/dev/null || true
            echo
        fi
    fi
    
    # Storage classes
    log info "StorageClass Status:"
    kubectl get storageclass 2>/dev/null || log warn "Cannot access StorageClasses"
    echo
    
    if [[ "${SHOW_EVENTS:-false}" == "true" ]]; then
        log info "Recent Storage Events:"
        kubectl get events -A --sort-by=.metadata.creationTimestamp --field-selector type=Warning | grep -E "(Volume|PV|PVC|Storage)" || true
        echo
    fi
}

function show_network_diagnostics() {
    log info "Network Diagnostics"
    echo "==================="
    
    # Node network status
    log info "Node Network Status:"
    kubectl get nodes -o wide 2>/dev/null || log warn "Cannot access nodes"
    echo
    
    # Cilium status
    if kubectl get daemonset -n kube-system cilium &>/dev/null; then
        log info "Cilium DaemonSet Status:"
        kubectl get daemonset -n kube-system cilium -o wide 2>/dev/null || true
        echo
        
        log info "Cilium Pod Status:"
        kubectl get pods -n kube-system -l k8s-app=cilium -o wide 2>/dev/null || true
        echo
        
        if [[ "${SHOW_LOGS:-false}" == "true" ]]; then
            log info "Recent Cilium Logs:"
            kubectl logs -n kube-system -l k8s-app=cilium --tail=20 2>/dev/null || true
            echo
        fi
    fi
    
    # Ingress controllers
    if kubectl get namespace network &>/dev/null; then
        log info "Ingress Controller Status:"
        kubectl get pods -n network -o wide 2>/dev/null || true
        echo
        
        log info "Ingress Resources:"
        kubectl get ingress -A 2>/dev/null || true
        echo
    fi
    
    # Services
    log info "Service Status (LoadBalancer and NodePort):"
    kubectl get svc -A --field-selector spec.type=LoadBalancer 2>/dev/null || true
    kubectl get svc -A --field-selector spec.type=NodePort 2>/dev/null || true
    echo
    
    # Network policies
    log info "Network Policies:"
    kubectl get networkpolicy -A 2>/dev/null || log debug "No NetworkPolicies found"
    echo
    
    if [[ "${SHOW_EVENTS:-false}" == "true" ]]; then
        log info "Recent Network Events:"
        kubectl get events -A --sort-by=.metadata.creationTimestamp --field-selector type=Warning | grep -E "(Network|Service|Ingress|DNS)" || true
        echo
    fi
}

function show_app_diagnostics() {
    local app_name="${1:-}"
    
    if [[ -n "$app_name" ]]; then
        log info "Application Diagnostics for: $app_name"
        echo "========================================"
        
        # Find namespace for the app
        local namespace
        namespace=$(kubectl get pods -A --field-selector metadata.name~="$app_name" -o jsonpath='{.items[0].metadata.namespace}' 2>/dev/null || echo "")
        
        if [[ -z "$namespace" ]]; then
            # Try to find by label
            namespace=$(kubectl get pods -A -l "app.kubernetes.io/name=$app_name" -o jsonpath='{.items[0].metadata.namespace}' 2>/dev/null || echo "")
        fi
        
        if [[ -z "$namespace" ]]; then
            log warn "Could not find application: $app_name"
            return 1
        fi
        
        log info "Found application in namespace: $namespace"
        
        # Pod status
        log info "Pod Status:"
        kubectl get pods -n "$namespace" -l "app.kubernetes.io/name=$app_name" -o wide 2>/dev/null || \
        kubectl get pods -n "$namespace" | grep "$app_name" || true
        echo
        
        # HelmRelease status if exists
        if kubectl get helmrelease -n "$namespace" "$app_name" &>/dev/null; then
            log info "HelmRelease Status:"
            kubectl get helmrelease -n "$namespace" "$app_name" -o wide
            echo
        fi
        
        if [[ "${SHOW_LOGS:-false}" == "true" ]]; then
            log info "Recent Application Logs:"
            kubectl logs -n "$namespace" -l "app.kubernetes.io/name=$app_name" --tail=50 2>/dev/null || \
            kubectl logs -n "$namespace" -l "app=$app_name" --tail=50 2>/dev/null || true
            echo
        fi
        
    else
        log info "Application Overview"
        echo "==================="
        
        # Failed pods across all namespaces
        log info "Failed/Problematic Pods:"
        kubectl get pods -A --field-selector status.phase!=Running,status.phase!=Succeeded 2>/dev/null || true
        echo
        
        # HelmRelease failures
        log info "Failed HelmReleases:"
        kubectl get helmrelease -A 2>/dev/null | grep -v "True" || log debug "All HelmReleases are healthy"
        echo
        
        # Resource usage
        if [[ "${DETAILED:-false}" == "true" ]]; then
            log info "Node Resource Usage:"
            kubectl top nodes 2>/dev/null || log warn "Metrics server not available"
            echo
            
            log info "Pod Resource Usage (Top 10):"
            kubectl top pods -A --sort-by=memory 2>/dev/null | head -10 || log warn "Metrics server not available"
            echo
        fi
    fi
    
    if [[ "${SHOW_EVENTS:-false}" == "true" ]]; then
        log info "Recent Application Events:"
        kubectl get events -A --sort-by=.metadata.creationTimestamp --field-selector type=Warning | head -20 || true
        echo
    fi
}

function show_node_diagnostics() {
    log info "Node Diagnostics"
    echo "================"
    
    # Node status
    log info "Node Status:"
    kubectl get nodes -o wide 2>/dev/null || log warn "Cannot access nodes"
    echo
    
    # Node conditions
    log info "Node Conditions:"
    kubectl get nodes -o custom-columns=NAME:.metadata.name,READY:.status.conditions[?(@.type==\"Ready\")].status,MEMORY:.status.conditions[?(@.type==\"MemoryPressure\")].status,DISK:.status.conditions[?(@.type==\"DiskPressure\")].status,PID:.status.conditions[?(@.type==\"PIDPressure\")].status 2>/dev/null || true
    echo
    
    # Resource capacity and allocation
    if [[ "${DETAILED:-false}" == "true" ]]; then
        log info "Node Resource Capacity:"
        kubectl describe nodes | grep -E "(Name:|Capacity:|Allocatable:|Allocated resources:)" || true
        echo
    fi
    
    # Talos specific diagnostics
    if command -v talosctl &>/dev/null; then
        log info "Talos Node Health:"
        talosctl health --server=false 2>/dev/null || log warn "Cannot connect to Talos nodes"
        echo
        
        if [[ "${SHOW_LOGS:-false}" == "true" ]]; then
            log info "Recent Talos System Logs:"
            talosctl logs --tail=20 2>/dev/null || log warn "Cannot retrieve Talos logs"
            echo
        fi
    fi
    
    # System pods on each node
    log info "System Pods per Node:"
    kubectl get pods -A -o wide --field-selector spec.nodeName!="" | grep -E "(kube-system|flux-system)" || true
    echo
    
    if [[ "${SHOW_EVENTS:-false}" == "true" ]]; then
        log info "Recent Node Events:"
        kubectl get events -A --sort-by=.metadata.creationTimestamp --field-selector type=Warning | grep -E "(Node|Kubelet)" || true
        echo
    fi
}

function show_all_diagnostics() {
    log info "Comprehensive Cluster Diagnostics"
    echo "=================================="
    echo
    
    show_flux_diagnostics
    echo "----------------------------------------"
    show_storage_diagnostics  
    echo "----------------------------------------"
    show_network_diagnostics
    echo "----------------------------------------"
    show_app_diagnostics
    echo "----------------------------------------"
    show_node_diagnostics
    
    log info "Diagnostics completed"
}

function main() {
    local component="${1:-}"
    local app_name=""
    local show_logs=false
    local show_events=false
    local detailed=false
    
    # If first arg is not a known component, treat it as an app name
    if [[ -n "$component" ]] && [[ ! "$component" =~ ^(flux|storage|network|apps|nodes|all)$ ]] && [[ ! "$component" =~ ^- ]]; then
        app_name="$component"
        component="apps"
        shift
    elif [[ -n "$component" ]] && [[ ! "$component" =~ ^- ]]; then
        shift
    fi
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --logs)
                show_logs=true
                export SHOW_LOGS="true"
                shift
                ;;
            --events)
                show_events=true
                export SHOW_EVENTS="true"
                shift
                ;;
            --detailed)
                detailed=true
                export DETAILED="true"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                if [[ "$component" == "apps" ]] && [[ -z "$app_name" ]]; then
                    app_name="$1"
                else
                    log error "Unknown option: $1"
                    usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    check_cli kubectl
    
    case "$component" in
        flux)
            show_flux_diagnostics
            ;;
        storage)
            show_storage_diagnostics
            ;;
        network)
            show_network_diagnostics
            ;;
        apps)
            show_app_diagnostics "$app_name"
            ;;
        nodes)
            show_node_diagnostics
            ;;
        all|"")
            show_all_diagnostics
            ;;
        *)
            log error "Unknown component: $component"
            usage
            exit 1
            ;;
    esac
}

main "$@"